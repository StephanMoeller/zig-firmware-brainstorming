const std = @import("std");
const testing = std.testing;
const dvui = @import("dvui");
const keymap = @import("keymap");
const zkeymap = @import("zkeymap");
const icons = @import("icons");

const log = std.log.scoped(.companion);

const core = keymap.core;
const Modifiers = core.Modifiers;

/// Cached key content for UI rendering.
///
/// This struct holds all the visual information needed to display a key:
/// - label: UTF-8 text label (e.g., "A", "DEL", "Esc")
/// - icon: SVG icon bytes for keys with icons
/// - icon_name: Name identifier for the icon
/// - hold_layer: Layer index for layer-hold keys
/// - hold_mods: Modifier state for modifier-hold keys
/// - hid_code: HID keycode from firmware
///
/// Labels are allocated from a LabelCache arena and remain valid
/// for the lifetime of the cache.
pub const CachedKeyContent = struct {
    label: ?[]const u8 = null,
    icon: ?[]const u8 = null,
    icon_name: []const u8 = "",
    hold_layer: ?core.LayerIndex = null,
    hold_mods: ?core.Modifiers = null,
    hid_code: ?u8 = null,

    pub fn withIcon(self: CachedKeyContent, icon: []const u8, name: []const u8) CachedKeyContent {
        var c = self;
        c.icon = icon;
        c.icon_name = name;
        return c;
    }

    pub fn withLabel(self: CachedKeyContent, label: []const u8) CachedKeyContent {
        var c = self;
        c.label = label;
        return c;
    }
};

/// Pre-computed label lookup cache for all key states.
///
/// LabelCache stores the rendered content for every possible key+layer+modifier
/// combination in a flat array for O(1) lookup during UI rendering.
///
/// # Indexing
/// Entry index = (layer * key_count + key_index) * 256 + mods_byte
/// - layer: 0 to layer_count-1
/// - key_index: 0 to key_count-1
/// - mods_byte: 0 to 255 (8-bit modifier mask from Modifiers.toByte())
///
/// # Memory Management
/// The cache owns an arena allocator that stores all duplicated label strings.
/// Call `deinit()` to properly clean up when the cache is no longer needed.
pub const LabelCache = struct {
    entries: []CachedKeyContent,
    arena: std.heap.ArenaAllocator,
    layer_count: usize,
    key_count: usize,

    pub fn init(allocator: std.mem.Allocator, layer_count: usize, key_count: usize) !LabelCache {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const entries = try arena.allocator().alloc(CachedKeyContent, layer_count * key_count * 256);
        for (entries) |*entry| {
            entry.* = .{};
        }
        return LabelCache{
            .entries = entries,
            .arena = arena,
            .layer_count = layer_count,
            .key_count = key_count,
        };
    }

    pub fn lookup(self: *const LabelCache, layer: usize, key_index: usize, mods: Modifiers) *const CachedKeyContent {
        const idx = (layer * self.key_count + key_index) * 256 + @as(usize, mods.toByte());
        return &self.entries[idx];
    }

    pub fn deinit(self: *LabelCache) void {
        self.arena.deinit();
    }
};

fn scanCodeFromInt(code: u8) !zkeymap.ScanCode {
    return @enumFromInt(code);
}

/// Computes the visual content for a key based on its definition and modifier state.
///
/// This function handles:
/// - Special keys (media keys, mouse actions, custom commands)
/// - Layer-hold and modifier-hold indicators
/// - Scancode-based icon mapping (backspace, enter, arrows, etc.)
/// - Layout-dependent text via zkeymap.keyToText()
///
/// The caller provides a `label_buf` buffer that computeKeyContent may use
/// for temporary string formatting. The returned CachedKeyContent.label
/// may point into this buffer or to arena-allocated memory.
pub fn computeKeyContent(km: *zkeymap.KeyMap, def: core.KeyDef, physical_mods: Modifiers, label_buf: *[64]u8) CachedKeyContent {
    var maybe_key_code_fire: ?core.KeyCodeFire = null;
    var content = CachedKeyContent{};

    switch (def) {
        .tap_only => |t| {
            if (t.custom == keymap.COM_TOG) return content.withIcon(icons.tvg.lucide.@"circuit-board", "companion");
            if (t.custom == keymap.COM_OFF) return content.withIcon(icons.tvg.lucide.power, "shutdown");
            if (t.media_key != 0) {
                switch (t.media_key) {
                    core.MEDIA_VOLUME_UP => return content.withIcon(icons.tvg.lucide.@"volume-2", "vol_up"),
                    core.MEDIA_VOLUME_DOWN => return content.withIcon(icons.tvg.lucide.@"volume-1", "vol_down"),
                    core.MEDIA_MUTE => return content.withIcon(icons.tvg.lucide.@"volume-x", "mute"),
                    core.MEDIA_PLAY_PAUSE => return content.withIcon(icons.tvg.lucide.play, "play"),
                    core.MEDIA_NEXT_TRACK => return content.withIcon(icons.tvg.lucide.@"skip-forward", "next"),
                    core.MEDIA_PREV_TRACK => return content.withIcon(icons.tvg.lucide.@"skip-back", "prev"),
                    else => content.label = "MED",
                }
            }
            if (t.mouse_action != .None) {
                switch (t.mouse_action) {
                    .LeftClick => return content.withIcon(icons.tvg.lucide.mouse, "m_left"),
                    .RightClick => return content.withIcon(icons.tvg.lucide.mouse, "m_right"),
                    .MiddleClick => return content.withIcon(icons.tvg.lucide.mouse, "m_mid"),
                    .WheelUp => return content.withIcon(icons.tvg.lucide.@"chevron-up", "w_up"),
                    .WheelDown => return content.withIcon(icons.tvg.lucide.@"chevron-down", "w_down"),
                    .WheelLeft => return content.withIcon(icons.tvg.lucide.@"chevron-left", "w_left"),
                    .WheelRight => return content.withIcon(icons.tvg.lucide.@"chevron-right", "w_right"),
                    else => content.label = "MS",
                }
            }
            if (t.key_press) |kp| {
                maybe_key_code_fire = kp;
            }
        },
        .tap_hold => |th| {
            if (th.tap.custom == keymap.COM_TOG) {
                content = content.withIcon(icons.tvg.lucide.@"circuit-board", "companion");
            } else if (th.tap.custom == keymap.COM_OFF) {
                content = content.withIcon(icons.tvg.lucide.power, "shutdown");
            } else if (th.tap.key_press) |kp| {
                maybe_key_code_fire = kp;
            }
            content.hold_layer = th.hold.hold_layer;
            content.hold_mods = th.hold.hold_modifiers;
        },
        .tap_with_autofire => |af| if (af.tap.key_press) |kp| {
            maybe_key_code_fire = kp;
        },
        .hold_only => |h| {
            content.hold_layer = h.hold_layer;
            content.hold_mods = h.hold_modifiers;
            if (h.hold_modifiers) |m| {
                if (m.left_shift or m.right_shift) content.label = "shft";
                if (m.left_ctrl or m.right_ctrl) content.label = "ctrl";
                if (m.left_alt or m.right_alt) content.label = "alt";
                if (m.left_gui or m.right_gui) content.icon = icons.tvg.lucide.command;
            } else if (h.hold_layer) |l| {
                content.icon = dvui.entypo.layers;
                const printed = std.fmt.bufPrint(label_buf, "L{any}", .{l}) catch "L?";
                content.label = printed;
            }
        },
        else => {},
    }
    const key_code_fire = maybe_key_code_fire orelse return content;

    content.hid_code = key_code_fire.tap_keycode;

    const scancode = scanCodeFromInt(key_code_fire.tap_keycode) catch {
        content.label = "???";
        return content;
    };

    switch (scancode) {
        .KC_BACKSPACE => return content.withIcon(icons.tvg.lucide.delete, "backspace"),
        .KC_ENTER => return content.withIcon(icons.tvg.lucide.@"corner-down-left", "enter"),
        .KC_LEFT => return content.withIcon(icons.tvg.lucide.@"arrow-left", "left"),
        .KC_RIGHT => return content.withIcon(icons.tvg.lucide.@"arrow-right", "right"),
        .KC_UP => return content.withIcon(icons.tvg.lucide.@"arrow-up", "up"),
        .KC_DOWN => return content.withIcon(icons.tvg.lucide.@"arrow-down", "down"),
        .KC_TAB => return content.withIcon(icons.tvg.lucide.@"arrow-right-left", "tab"),
        .KC_SPACE => return content.withIcon(icons.tvg.lucide.space, "space"),
        .KC_PAGE_DOWN => return content.withIcon(icons.tvg.lucide.@"arrow-down-to-line", "page_down"),
        .KC_PAGE_UP => return content.withIcon(icons.tvg.lucide.@"arrow-up-to-line", "page_up"),
        .KC_HOME => return content.withIcon(icons.tvg.lucide.@"arrow-left-to-line", "home"),
        .KC_END => return content.withIcon(icons.tvg.lucide.@"arrow-right-to-line", "end"),
        else => {},
    }

    const final_kcf: core.KeyCodeFire = .{
        .tap_keycode = key_code_fire.tap_keycode,
        .tap_modifiers = key_code_fire.tap_modifiers orelse physical_mods,
        .dead = key_code_fire.dead,
    };
    const result = km.keyToText(final_kcf);

    if (result.isLabel()) {
        const lbl = result.getLabel();
        if (lbl.len > 0 and lbl.len < 64) {
            @memcpy(label_buf[0..lbl.len], lbl);
            label_buf[lbl.len] = 0;
            content.label = label_buf[0..lbl.len];
        }
        return content;
    } else if (result.len > 0) {
        const slice = result.slice();
        if (slice.len == 1 and slice[0] < 32) {
            // Ignore unprintable control characters
        } else {
            if (slice.len < 64) {
                @memcpy(label_buf[0..slice.len], slice);
                label_buf[slice.len] = 0;
                content.label = label_buf[0..slice.len];
            }
            return content;
        }
    }

    if (content.label == null and content.icon == null) {
        content.label = switch (def) {
            .none => "",
            .transparent => "---",
            else => "?",
        };
    }

    return content;
}

/// Builds a complete label cache for all keys, layers, and modifier combinations.
///
/// This function pre-computes the visual content for every possible key state
/// and stores it in a flat array for O(1) runtime lookup. The cache includes:
/// - All layers in the keymap
/// - All keys per layer
/// - All 256 possible modifier byte values
///
/// # Arguments
/// - `allocator`: Memory allocator for the cache and string storage
/// - `km`: Initialized KeyMap for layout-dependent text rendering
///
/// # Returns
/// A fully populated LabelCache. Call `deinit()` when done.
///
/// # Memory Usage
/// Approximately: layer_count * key_count * 256 * sizeof(CachedKeyContent) bytes
/// plus arena allocations for label strings.
pub fn buildLabelCache(allocator: std.mem.Allocator, km: *zkeymap.KeyMap) !LabelCache {
    const layer_count = keymap.keymap.len;
    const key_count = keymap.key_count;
    var cache = try LabelCache.init(allocator, layer_count, key_count);

    for (0..layer_count) |layer| {
        for (0..key_count) |key_idx| {
            const def = keymap.keymap[layer][key_idx];
            for (0..256) |mods_byte| {
                const mods_u8 = @as(u8, @intCast(mods_byte));
                const mods: Modifiers = @bitCast(mods_u8);
                const idx = (layer * key_count + key_idx) * 256 + mods_byte;
                var label_buf: [64]u8 = undefined;
                @memset(&label_buf, 0);
                var entry = computeKeyContent(km, def, mods, &label_buf);
                if (entry.label) |label| {
                    entry.label = try cache.arena.allocator().dupe(u8, label);
                }
                cache.entries[idx] = entry;
            }
        }
    }

    return cache;
}

test "computeKeyContent: KC_A returns lowercase a label" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_A),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("a", label);
    }
}

test "computeKeyContent: KC_A with shift returns uppercase A label" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_A),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{ .left_shift = true }, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("A", label);
    }
}

test "computeKeyContent: KC_DELETE returns label from zkeycodes" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_DELETE),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("DEL", label);
    }
}

test "computeKeyContent: KC_PRINT_SCREEN returns label from zkeycodes" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_PRINT_SCREEN),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("PScr", label);
    }
}

test "computeKeyContent: KC_ESCAPE returns label from zkeycodes" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_ESCAPE),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings("Esc", label);
    }
}

test "computeKeyContent: KC_SPACE returns space character" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_SPACE),
        },
    } };

    var buf: [64]u8 = undefined;
    const content = computeKeyContent(&km, def, .{}, &buf);

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expectEqualStrings(" ", label);
    }
}

test "LabelCache: buildLabelCache creates entries for all layers and keys" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    var cache = try buildLabelCache(testing.allocator, &km);
    defer cache.deinit();

    try testing.expectEqual(@as(usize, keymap.keymap.len), cache.layer_count);
    try testing.expectEqual(@as(usize, keymap.key_count), cache.key_count);

    const total_entries = cache.layer_count * cache.key_count * 256;
    try testing.expectEqual(@as(usize, total_entries), cache.entries.len);
}

test "LabelCache: lookup returns valid pointer for KC_A" {
    var km: zkeymap.KeyMap = undefined;
    zkeymap.KeyMap.init(&km);
    defer zkeymap.KeyMap.deinit(&km);

    var cache = try buildLabelCache(testing.allocator, &km);
    defer cache.deinit();

    const content = cache.lookup(0, 0, .{}.toByte());

    try testing.expect(content.label != null);
    if (content.label) |label| {
        try testing.expect(label.len > 0);
    }
}
