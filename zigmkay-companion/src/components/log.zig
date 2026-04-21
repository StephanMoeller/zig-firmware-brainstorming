const std = @import("std");
const dvui = @import("dvui");
const keymap = @import("keymap");
const zkeymap = @import("zkeymap");

const core = keymap.core;
const Modifiers = core.Modifiers;
const LogMessage = core.LogMessage;
const key_component = @import("key.zig");

// Ring buffer entry
pub const TimedLogMessage = struct {
    delta_ms: i64 = 0, // Duration since the prior event (or 0 for the first)
    msg: LogMessage = .{
        .pressed = false,
        .key_index = 0,
        .layer = 0,
        .modifiers = .{},
    },
};

pub const LogComponent = struct {
    events: [100]TimedLogMessage = [_]TimedLogMessage{.{}} ** 100,
    head: usize = 0,
    last_event_timestamp: i64 = 0,

    /// Decodes rawHID packet array, logs structural variables, and fires internal event loop payload.
    /// Payload input is a 2-byte structure generated directly by core.zig LogMessage bitcasting.
    pub fn handleSignal(self: *LogComponent, payload: [4]u8) core.LogMessage {
        const log_msg = core.LogMessage.fromBytes(payload);

        // Compute delta timestamp since last handled push
        const now = std.time.milliTimestamp();
        var delta: i64 = 0;
        if (self.last_event_timestamp != 0) {
            delta = now - self.last_event_timestamp;
        }
        self.last_event_timestamp = now;

        // Push into local struct events history queue
        self.events[self.head] = .{
            .delta_ms = delta,
            .msg = log_msg,
        };
        self.head = (self.head + 1) % self.events.len;

        return log_msg;
    }

    /// Renders the event ring buffer list UI inside the application loop.
    pub fn draw(self: *LogComponent, km: *zkeymap.KeyMap, center_x: f32, start_y: f32, scale: f32) !void {
        const safe_log_y = @max(10.0 * scale, start_y - (160.0 * scale));
        const safe_log_h = @min(160.0 * scale, start_y - 20.0 * scale);
        // Increase Box Width to 600.0 * scale
        const ui_w = 600.0 * scale;
        var log_box = dvui.box(@src(), .{}, .{
            .rect = .{ .x = center_x - ui_w / 2.0, .y = safe_log_y, .w = ui_w, .h = safe_log_h },
            .background = true,
            .color_fill = .{ .r = 20, .g = 20, .b = 20, .a = 240 },
            .color_border = .{ .r = 80, .g = 80, .b = 80, .a = 255 },
            .border = dvui.Rect.all(1.0 * scale),
            .corner_radius = dvui.Rect.all(4.0 * scale),
        });
        defer log_box.deinit();

        var log_col = dvui.box(@src(), .{}, .{ .expand = .both });
        defer log_col.deinit();

        dvui.label(@src(), "Recent Events (Log)", .{}, .{ .color_text = .{ .r = 200, .g = 200, .b = 200, .a = 255 } });

        // Calculate maximum elements per column depending on safe height
        const row_h = 24.0 * scale;
        const avail_h = safe_log_h - (24.0 * scale); // 24 header deduction
        var items_per_col = @as(usize, @intFromFloat(avail_h / row_h)) + 3;
        if (items_per_col == 0) items_per_col = 1;

        var columns_row = dvui.box(@src(), .{ .dir = .horizontal, .equal_space = true }, .{ .expand = .both });
        defer columns_row.deinit();

        const count = self.events.len;

        for (0..3) |col_idx| {
            var col_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .both, .id_extra = col_idx });
            defer col_box.deinit();

            for (0..items_per_col) |row_idx| {
                const j = (col_idx * items_per_col) + row_idx;
                if (j >= count) continue; // Exceeds array size

                // Read backwards starting immediately before log_head
                const backwards_offset = count - 1 - j;
                const idx = (self.head + backwards_offset) % count;
                const ev = self.events[idx];

                if (ev.delta_ms != 0 or ev.msg.key_index != 0) { // filter out zero-filled slots except true first
                    var key_name_buf: [32]u8 = undefined;
                    var key_name: []const u8 = "???";
                    const mods = ev.msg.modifiers;

                    if (ev.msg.key_index < 40) {
                        const key_def = keymap.keymap[ev.msg.layer][ev.msg.key_index];
                        var maybe_kcf: ?core.KeyCodeFire = null;
                        switch (key_def) {
                            .tap_only => |t| maybe_kcf = t.key_press,
                            .tap_hold => |th| maybe_kcf = th.tap.key_press,
                            .tap_with_autofire => |af| maybe_kcf = af.tap.key_press,
                            else => {},
                        }

                        if (maybe_kcf) |kcf| {
                            const result = km.keyToText(.{
                                .tap_keycode = kcf.tap_keycode,
                                .tap_modifiers = mods,
                                .dead = kcf.dead,
                            });
                            if (result.isLabel()) {
                                const lbl = result.getLabel();
                                if (lbl.len < key_name_buf.len) {
                                    @memcpy(key_name_buf[0..lbl.len], lbl);
                                    key_name_buf[lbl.len] = 0;
                                    key_name = key_name_buf[0..lbl.len];
                                }
                            } else if (result.len > 0) {
                                const slice = result.slice();
                                if (slice.len >= 1 and slice[0] >= 32 and slice.len < key_name_buf.len) {
                                    @memcpy(key_name_buf[0..slice.len], slice);
                                    key_name_buf[slice.len] = 0;
                                    key_name = key_name_buf[0..slice.len];
                                }
                            }
                        }
                    }
                    if (ev.msg.key_index == 38) key_name = "Encoder CW";
                    if (ev.msg.key_index == 39) key_name = "Encoder CCW";

                    var mod_str_buf: [64]u8 = undefined;
                    var mod_str: []const u8 = "";
                    if (@as(u8, @bitCast(mods)) != 0) {
                        var fbs = std.io.fixedBufferStream(&mod_str_buf);
                        const w = fbs.writer();
                        _ = w.writeAll(" [") catch {};
                        if (mods.left_ctrl) _ = w.writeAll("CtrlL ") catch {};
                        if (mods.right_ctrl) _ = w.writeAll("CtrlR ") catch {};
                        if (mods.left_shift) _ = w.writeAll("ShiftL ") catch {};
                        if (mods.right_shift) _ = w.writeAll("ShiftR ") catch {};
                        if (mods.left_alt) _ = w.writeAll("AltL ") catch {};
                        if (mods.right_alt) _ = w.writeAll("AltR ") catch {};
                        if (mods.left_gui) _ = w.writeAll("GuiL ") catch {};
                        if (mods.right_gui) _ = w.writeAll("GuiR ") catch {};

                        const len = fbs.getPos() catch 0;
                        if (len > 2 and mod_str_buf[len - 1] == ' ') {
                            mod_str_buf[len - 1] = ']';
                            mod_str = mod_str_buf[0..len];
                        } else {
                            _ = w.writeAll("]") catch {};
                            mod_str = fbs.getWritten();
                        }
                    }

                    var text_buf1: [32]u8 = undefined;
                    const txt1 = std.fmt.bufPrint(&text_buf1, "[{d: >6} ms] ", .{ev.delta_ms}) catch "";

                    var text_buf2: [128]u8 = undefined;
                    const txt2 = std.fmt.bufPrint(&text_buf2, " K{d: <3} ({s}){s}", .{ ev.msg.key_index, key_name, mod_str }) catch "Err";

                    const arrow_color = if (ev.msg.pressed) dvui.Color{ .r = 100, .g = 250, .b = 100, .a = 255 } else dvui.Color{ .r = 250, .g = 100, .b = 100, .a = 255 };
                    const arrow_str = if (ev.msg.pressed) "[+]" else "[-]";

                    const layer_color = if (ev.msg.layer < key_component.layer_colors.len) key_component.layer_colors[ev.msg.layer] else dvui.Color.white;
                    var row_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = j, .color_border = layer_color, .border = dvui.Rect.all(1.0 * scale), .corner_radius = dvui.Rect.all(2.0 * scale), .margin = dvui.Rect.all(1.0 * scale) });
                    defer row_box.deinit();

                    dvui.label(@src(), "{s}", .{txt1}, .{ .color_text = .{ .r = 150, .g = 150, .b = 150, .a = 255 }, .font = dvui.Font.theme(.mono) });
                    dvui.label(@src(), "{s}", .{arrow_str}, .{ .color_text = arrow_color, .font = dvui.Font.theme(.mono) });
                    dvui.label(@src(), "{s}", .{txt2}, .{ .color_text = .{ .r = 150, .g = 150, .b = 150, .a = 255 }, .font = dvui.Font.theme(.mono) });
                }
            }
        }
    }
};
