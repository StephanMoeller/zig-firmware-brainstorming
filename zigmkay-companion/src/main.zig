const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
// This is the correct import for code completion, don't change it
const SDLBackend = @import("sdl-backend");
const keymap = @import("keymap");
const zkeymap = @import("zkeymap");
const zigmkay = @import("zigmkay");
const Modifiers = zigmkay.core.Modifiers;

const core = keymap.core;
const sdl = SDLBackend.c;
const log = std.log.scoped(.companion);
const assert = std.debug.assert;

// Components
const key_component = @import("components/key.zig");
const cache = @import("components/cache.zig");
const EncoderComponent = @import("components/encoder.zig").EncoderComponent;
const log_component = @import("components/log.zig");
const layout_component = @import("components/layout.zig");

pub const std_options: std.Options = .{
    // Set the default log level to debug
    .log_level = if (builtin.mode == .Debug) .debug else .info,
};

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

/// Global KeyMap for dynamic labeling
var km: zkeymap.KeyMap = undefined;

/// Current active layer (synced with firmware)
var current_layer: usize = 0;

/// App control triggers (thread-safe shutdown)
var app_running = std.atomic.Value(bool).init(true);
var is_companion_visible = std.atomic.Value(bool).init(true);
var is_log_visible = std.atomic.Value(bool).init(false);

/// Log Component Instance
var log_comp = log_component.LogComponent{};

var active_keys: [128]bool = [_]bool{false} ** 128;
var active_mods: Modifiers = .{};

/// Comptime indices of the encoder keys in keymap.sides.
/// encoder_indices[0] = CW (clockwise, first .E entry)
/// encoder_indices[1] = CCW (counter-clockwise, second .E entry)
/// Defaults to .{ 999, 999 } if no encoder exists (branch is unreachable in that case).
const encoder_indices: struct { usize, usize } = blk: {
    var found: [2]usize = .{ 999, 999 };
    var count: usize = 0;
    for (keymap.sides, 0..) |side, i| {
        if (side == .E) {
            if (count < 2) found[count] = i;
            count += 1;
        }
    }
    break :blk .{ found[0], found[1] };
};
/// initialize Encode only it there is an encoder present in the keymap
var maybe_encoder_comp: ?EncoderComponent = if (encoder_indices[0] != 999) .{} else null;

/// Global DVUI Window Pointer for background thread refresh
var dvui_win: dvui.Window = undefined;

/// Configuration for layout scaling
const scale: f32 = 2.0;
const key_size: f32 = 45.0 * scale;
const spacing: f32 = 8.0 * scale;
const gap: f32 = 80.0 * scale;

/// Monitors stdin to detect if the parent process (e.g. `zig build`) died abruptly.
/// When the pipe breaks, this returns 0 (EOF) or error, and we cleanly exit.
fn monitorParentDeath() void {
    const stdin = std.fs.File.stdin();
    var buf: [1]u8 = undefined;
    while (app_running.load(.acquire)) {
        const amt = stdin.read(&buf) catch 0;
        if (amt == 0) {
            log.info("Parent process detached or stdin closed. Terminating...", .{});
            app_running.store(false, .release);
            var event: sdl.SDL_Event = undefined;
            @memset(std.mem.asBytes(&event), 0);
            event.type = sdl.SDL_EVENT_QUIT;
            _ = sdl.SDL_PushEvent(&event);
            break;
        }
    }
}

/// Background thread to handle cross-platform HID communication via SDL3
fn hidThread() void {
    const vid = 0xFAFA;
    const pid = 0x00F0;

    var last_companion_press_time: i64 = 0;
    var last_companion_visibility = true;

    while (app_running.load(.acquire)) {
        // Attempt to open the RAWHID device
        const handle = sdl.SDL_hid_open(vid, pid, null);
        if (handle) |dev| {
            log.info("HID: Connected to keyboard (0x{X}:0x{X})", .{ vid, pid });
            defer _ = sdl.SDL_hid_close(dev);

            var report: [32]u8 = undefined;
            while (app_running.load(.acquire)) {
                // Read with 200ms timeout
                const bytes_read = sdl.SDL_hid_read_timeout(dev, &report, report.len, 200);
                if (bytes_read > 0) {
                    const signal_id = report[0];
                    const payload = report[1];
                    var update_ui = false;

                    if (signal_id == core.RAWHID_SIGNAL_LAYER_CHANGED) { // Layer changed
                        current_layer = payload;
                        update_ui = true;
                        log.debug("HID: Layer changed to {}", .{payload});
                    } else if (signal_id == core.RAWHID_SIGNAL_COMPANION_KEY) { // Companion key
                        const pressed = (payload != 0);
                        const now = std.time.milliTimestamp();
                        if (pressed) {
                            last_companion_press_time = now;
                            if (!is_companion_visible.load(.acquire)) {
                                // If currently hidden, show immediately on press
                                is_companion_visible.store(true, .release);
                                update_ui = true;
                            }
                        } else {
                            const duration = now - last_companion_press_time;

                            // Determine the new visibility state
                            const new_visibility = if (duration > 300)
                                false // Momentary Hold: Hide on release
                            else
                                !last_companion_visibility; // Tap: Toggle based on persistent state

                            // Only update if the state actually changes
                            if (new_visibility != is_companion_visible.load(.acquire)) {
                                is_companion_visible.store(new_visibility, .release);
                                update_ui = true;
                            }

                            // Sync the persistence tracker on release
                            last_companion_visibility = new_visibility;
                        }
                        log.debug("HID: Companion key {s}", .{if (pressed) "pressed" else "released"});
                    } else if (signal_id == core.RAWHID_SIGNAL_KEY_EVENT) { // Key Event (including encoder)
                        const log_msg = log_comp.handleSignal(report[1..5].*);
                        assert(log_msg.key_index < keymap.sides.len); // keyboard not compatible with companion (too many keys)

                        active_keys[log_msg.key_index] = log_msg.pressed;

                        active_mods = log_msg.modifiers;

                        if (keymap.sides[log_msg.key_index] == .E) {
                            if (log_msg.pressed) {
                                if (maybe_encoder_comp) |*encoder_comp| {
                                    encoder_comp.handleSignal(if (log_msg.key_index == encoder_indices[0]) 0 else 1);
                                    log.debug("HID: Encoder rotated {s}", .{if (log_msg.key_index == encoder_indices[0]) "CW" else "CCW"});
                                }
                            }
                        }
                        update_ui = true;
                    } else if (signal_id == core.RAWHID_SIGNAL_COMPANION_LOG_TOGGLE) { // Log Toggle Signal
                        is_log_visible.store(!is_log_visible.load(.acquire), .release);
                        update_ui = true;
                    } else if (signal_id == core.RAWHID_SIGNAL_SHUTDOWN_COMPANION) { // Shutdown Signal
                        app_running.store(false, .release);
                        log.debug("HID: Remote shutdown requested", .{});
                        update_ui = true;
                    }

                    // Wake up the UI thread if we have a window pointer
                    if (update_ui) dvui.refresh(&dvui_win, @src(), null);
                } else if (bytes_read < 0) {
                    log.info("HID: Device disconnected", .{});
                    break;
                }
            }
        }
        std.Thread.sleep(1 * std.time.ns_per_s);
    }
}

fn handleAndFilterSDLEvents(backend: *SDLBackend) !void {
    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {
        if (event.type == sdl.SDL_EVENT_QUIT) {
            log.info("Received SDL_EVENT_QUIT", .{});
            app_running.store(false, .release);
        }
        if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
            // close application if escape key is pressed while in foreground
            if (event.key.scancode == sdl.SDL_SCANCODE_ESCAPE) {
                app_running.store(false, .release);
            }
            // Filter out volume/media keys to prevent log spam from DVUI backend
            switch (event.key.key) {
                sdl.SDLK_VOLUMEUP,
                sdl.SDLK_VOLUMEDOWN,
                sdl.SDLK_MUTE,
                sdl.SDLK_MEDIA_PLAY,
                sdl.SDLK_MEDIA_NEXT_TRACK,
                sdl.SDLK_MEDIA_PREVIOUS_TRACK,
                => continue,
                else => {},
            }
        }
        if (event.type == sdl.SDL_EVENT_KEY_UP) {
            switch (event.key.key) {
                sdl.SDLK_VOLUMEUP,
                sdl.SDLK_VOLUMEDOWN,
                sdl.SDLK_MUTE,
                sdl.SDLK_MEDIA_PLAY,
                sdl.SDLK_MEDIA_NEXT_TRACK,
                sdl.SDLK_MEDIA_PREVIOUS_TRACK,
                => continue,
                else => {},
            }
        }
        _ = try backend.addEvent(&dvui_win, event);
    }
}

pub fn main() !void {
    defer _ = gpa_instance.deinit();

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_EVENTS)) {
        log.err("SDL_Init failed: {s}", .{sdl.SDL_GetError()});
        return error.SDLInitFailed;
    }
    defer sdl.SDL_Quit();

    // SDL3 Window Creation
    const win_w: i32 = @intFromFloat(800.0 * scale);
    const win_h: i32 = @intFromFloat(600.0 * scale);
    // Start visible for debugging, we will add auto-toggle logic once telemetry is verified
    const win_flags = sdl.SDL_WINDOW_TRANSPARENT | sdl.SDL_WINDOW_BORDERLESS | sdl.SDL_WINDOW_ALWAYS_ON_TOP | sdl.SDL_WINDOW_NOT_FOCUSABLE;
    const sdl_win = sdl.SDL_CreateWindow("Zigmkay Companion SDL3", win_w, win_h, win_flags);
    if (sdl_win == null) {
        log.err("SDL_CreateWindow failed: {s}", .{sdl.SDL_GetError()});
        return error.SDLWindowCreationFailed;
    }
    defer sdl.SDL_DestroyWindow(sdl_win);

    // SDL_WINDOW_NOT_FOCUSABLE prevents keyboard focus, but does not consistently
    // provide mouse click-through across all platforms. On Windows, we must
    // explicitly set WS_EX_TRANSPARENT via the Win32 API.
    // TODO: Linux and macOS might also require platform-specific extensions
    // (like XShape or NSWindow.ignoresMouseEvents) if SDL's default behavior
    // is insufficient.
    if (builtin.os.tag == .windows) {
        const hwnd_ptr = sdl.SDL_GetPointerProperty(sdl.SDL_GetWindowProperties(sdl_win), sdl.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null);
        if (hwnd_ptr) |hwnd| {
            const GWL_EXSTYLE: i32 = -20;
            const WS_EX_LAYERED: isize = 0x00080000;
            const WS_EX_TRANSPARENT: isize = 0x00000020;
            const user32 = struct {
                extern "user32" fn GetWindowLongPtrA(hWnd: *anyopaque, nIndex: i32) isize;
                extern "user32" fn SetWindowLongPtrA(hWnd: *anyopaque, nIndex: i32, dwNewLong: isize) isize;
            };
            var style = user32.GetWindowLongPtrA(hwnd, GWL_EXSTYLE);
            style |= WS_EX_LAYERED | WS_EX_TRANSPARENT;
            _ = user32.SetWindowLongPtrA(hwnd, GWL_EXSTYLE, style);
        }
    }

    const renderer = sdl.SDL_CreateRenderer(sdl_win, null);
    if (renderer == null) {
        log.err("SDL_CreateRenderer failed: {s}", .{sdl.SDL_GetError()});
        return error.SDLRendererCreationFailed;
    }
    defer sdl.SDL_DestroyRenderer(renderer);

    // Initialize zkeymap
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    // Initialize label cache for key labels
    var label_cache = try cache.buildLabelCache(gpa, &km);
    defer label_cache.deinit();

    // Initialize DVUI SDL3 Backend
    var backend = SDLBackend.init(sdl_win.?, renderer.?);
    defer backend.deinit();

    dvui_win = try dvui.Window.init(@src(), gpa, backend.backend(), .{
        .theme = dvui.Theme.builtin.adwaita_dark,
    });
    defer dvui_win.deinit();

    // Start HID Polling Thread
    const thread = try std.Thread.spawn(.{}, hidThread, .{});
    thread.detach();

    // Start dead parent / stdin EOF monitoring
    if (builtin.os.tag == .windows) {
        if (std.Thread.spawn(.{}, monitorParentDeath, .{})) |t| {
            t.detach();
        } else |_| {}
    }

    var interrupted = false;

    while (app_running.load(.acquire)) {
        try handleAndFilterSDLEvents(&backend);

        const nstime = dvui_win.beginWait(interrupted);
        try dvui_win.begin(nstime);

        // Handle companion visibility triggers during the frame
        if (is_companion_visible.load(.acquire)) {
            _ = sdl.SDL_ShowWindow(sdl_win);
        } else {
            _ = sdl.SDL_HideWindow(sdl_win);
        }

        // Clear background
        _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
        _ = sdl.SDL_RenderClear(renderer);

        const center_x = @as(f32, @floatFromInt(win_w)) / 2.0;
        const center_y = @as(f32, @floatFromInt(win_h)) / 2.0;
        const layout = comptime layout_component.generateKeyPositions(keymap.key_count, keymap.sides, .{
            .scale = 2.0,
            .key_size = 45.0,
            .spacing = 8.0,
            .gap = 80.0,
            .thumb_cluster_gap = 10.0,
        });
        const start_y = center_y - layout.total_height / 2.0;

        // Layer Indicator Grid
        {
            const grid_size = 40.0 * scale;
            var grid_box = dvui.box(@src(), .{}, .{
                .rect = .{ .x = center_x - grid_size / 2.0, .y = start_y + layout.total_height / 2.0 - grid_size / 2.0, .w = grid_size, .h = grid_size },
            });
            defer grid_box.deinit();
            try key_component.drawLayerGrid(current_layer, keymap.keymap.len, grid_size, scale);
        }

        try layout_component.drawKeysAndEncoder(&layout, &label_cache, current_layer, &active_keys, active_mods, maybe_encoder_comp, center_x, center_y, start_y);

        // Draw Log Window
        if (is_log_visible.load(.acquire)) {
            try log_comp.draw(&km, center_x, start_y, scale);
        }

        const end_micros = try dvui_win.end(.{});
        _ = sdl.SDL_RenderPresent(renderer);

        // waitTime and waitEventTimeout combine to achieve responsive frame timing
        const wait_event_micros = dvui_win.waitTime(end_micros);
        interrupted = try backend.waitEventTimeout(wait_event_micros);
    }
    log.info("Main loop exited cleanly", .{});
}
