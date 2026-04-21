const std = @import("std");
const testing = std.testing;
const dvui = @import("dvui");
const keymap = @import("keymap");
const zkeymap = @import("zkeymap");
const icons = @import("icons");

const log = std.log.scoped(.companion);

const core = keymap.core;

const cache = @import("cache.zig");
pub const CachedKeyContent = cache.CachedKeyContent;
pub const LabelCache = cache.LabelCache;
pub const buildLabelCache = cache.buildLabelCache;

/// Vibrant color palette for up to 9 layers.
pub const layer_colors = [9]dvui.Color{
    .{ .r = 255, .g = 50, .b = 50, .a = 255 }, // 0: Red
    .{ .r = 50, .g = 150, .b = 255, .a = 255 }, // 1: Blue
    .{ .r = 255, .g = 150, .b = 50, .a = 255 }, // 2: Orange
    .{ .r = 150, .g = 255, .b = 50, .a = 255 }, // 3: Lime
    .{ .r = 180, .g = 50, .b = 255, .a = 255 }, // 4: Purple
    .{ .r = 50, .g = 255, .b = 200, .a = 255 }, // 5: Teal
    .{ .r = 50, .g = 255, .b = 50, .a = 255 }, // 6: Green
    .{ .r = 255, .g = 230, .b = 50, .a = 255 }, // 7: Yellow
    .{ .r = 255, .g = 50, .b = 180, .a = 255 }, // 8: Pink
};

/// Returns a muted version of a layer color.
pub fn getMutedColor(color: dvui.Color) dvui.Color {
    return .{
        .r = @intCast(@as(u32, color.r) / 2),
        .g = @intCast(@as(u32, color.g) / 2),
        .b = @intCast(@as(u32, color.b) / 2),
        .a = 180,
    };
}

/// Color for layers not present in the keymap.
pub const empty_layer_color = dvui.Color{ .r = 40, .g = 40, .b = 40, .a = 255 };

/// Content representation for a keyboard key, supporting main label/icon
/// and secondary indicators for layers and modifiers.
pub const KeyContent = struct {
    label: ?[]const u8 = null,
    icon: ?[]const u8 = null,
    icon_name: []const u8 = "",
    /// If non-null, show a layer indicator in the top right
    hold_layer: ?core.LayerIndex = null,
    /// If non-null, show modifier icons on the left
    hold_mods: ?core.Modifiers = null,
    /// HID keycode decoded from firmware
    hid_code: ?u8 = null,

    pub fn withIcon(self: KeyContent, icon: []const u8, name: []const u8) KeyContent {
        var c = self;
        c.icon = icon;
        c.icon_name = name;
        return c;
    }

    pub fn withLabel(self: KeyContent, label: []const u8) KeyContent {
        var c = self;
        c.label = label;
        return c;
    }
};

/// Renders a 3x3 grid representing layers.
pub fn drawLayerGrid(active_layer: usize, total_layers: usize, size: f32, scale: f32) !void {
    var outer = dvui.box(@src(), .{}, .{
        .min_size_content = .{ .w = size, .h = size },
        .gravity_x = 0.5,
    });
    defer outer.deinit();

    const cell_size = (size - 8 * scale) / 3.0;

    for (0..9) |i| {
        const row: f32 = @floatFromInt(i / 3);
        const col: f32 = @floatFromInt(i % 3);

        const color = if (i >= total_layers)
            empty_layer_color
        else if (i == active_layer)
            layer_colors[i]
        else
            getMutedColor(layer_colors[i]);

        var cell = dvui.box(@src(), .{}, .{
            .id_extra = i + 9000,
            .rect = .{
                .x = col * (cell_size + 2 * scale),
                .y = row * (cell_size + 2 * scale),
                .w = cell_size,
                .h = cell_size,
            },
            .background = true,
            .color_fill = color,
            .corner_radius = dvui.Rect.all(2 * scale),
        });
        cell.deinit();
    }
}

/// Renders a single keyboard key box with its associated label or icon.
pub fn drawKey(current_layer: usize, index: usize, x: f32, y: f32, size: f32, scale: f32, content: CachedKeyContent, active: bool) !void {
    const rect = dvui.Rect{ .x = x, .y = y, .w = size, .h = size };

    const layer_color = if (current_layer < layer_colors.len) layer_colors[current_layer] else dvui.Color.white;
    const muted_layer_color = getMutedColor(layer_color);

    const bg_color = if (active) muted_layer_color else dvui.Color.black;
    const border_color = if (active) layer_color else muted_layer_color;
    const text_color = dvui.Color.white;
    const mod_color = dvui.Color{ .r = 0, .g = 255, .b = 255, .a = 255 }; // Cyan

    var b = dvui.box(@src(), .{}, .{
        .id_extra = index,
        .rect = rect,
        .background = true,
        .color_fill = bg_color,
        .color_border = border_color,
        .border = dvui.Rect.all(1.5 * scale),
        .corner_radius = dvui.Rect.all(8 * scale),
    });
    defer b.deinit();

    // 1. Main Content (Center)
    if (content.icon) |icon_bytes| {
        dvui.icon(@src(), content.icon_name, icon_bytes, .{}, .{
            .id_extra = index,
            .color_text = text_color,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
            .min_size_content = .{ .w = size * 0.4, .h = size * 0.4 },
        });
    } else if (content.label) |l| {
        if (std.unicode.utf8ValidateSlice(l)) {
            dvui.label(@src(), "{s}", .{l}, .{
                .id_extra = index,
                .color_text = text_color,
                .font = dvui.Font.theme(.body).larger(if (l.len <= 2) 12 else 6),
                .gravity_x = 0.5,
                .gravity_y = 0.5,
            });
        }
    }

    // 2. Layer Indicator (Top Right)
    if (content.hold_layer) |l| {
        const icon_size = size * 0.3;
        const padding = 4 * scale;
        const color = if (l < layer_colors.len) layer_colors[l] else dvui.Color.white;

        dvui.icon(@src(), "layer_ind", dvui.entypo.layers, .{}, .{
            .id_extra = index + 1000,
            .color_text = color,
            .rect = .{ .x = size - icon_size - padding, .y = padding, .w = icon_size, .h = icon_size },
        });
    }

    // 3. Hold Modifier Indicators (Left Side)
    if (content.hold_mods) |m| {
        const item_h = size * 0.25;
        const padding_x = 2 * scale;
        var offset_y: f32 = 2 * scale;

        const font = dvui.Font.theme(.body);
        const col_w = size * 0.6; // width of the mod column on the left

        if (m.left_gui or m.right_gui) {
            const gui_icon_size = item_h * 0.8;
            dvui.icon(@src(), "gui_ind", icons.tvg.lucide.command, .{}, .{
                .id_extra = index + 6000,
                .color_text = mod_color,
                // Center icon horizontally in col_w and vertically in its slot
                .rect = .{
                    .x = padding_x + (col_w - gui_icon_size) / 2.0,
                    .y = offset_y + (item_h - gui_icon_size) / 2.0,
                    .w = gui_icon_size,
                    .h = gui_icon_size,
                },
            });
            offset_y += item_h + 1 * scale;
        }

        if (m.left_ctrl or m.right_ctrl) {
            dvui.label(@src(), "ctrl", .{}, .{
                .id_extra = index + 3000,
                .color_text = mod_color,
                .font = font,
                // Use a significantly taller rect for the label itself to prevent clipping,
                // but keep the offset_y increment standard.
                .rect = .{ .x = padding_x, .y = offset_y, .w = col_w, .h = item_h * 1.5 },
                .gravity_x = 0.5,
                .gravity_y = 0.5,
            });
            offset_y += item_h + 1 * scale;
        }

        if (m.left_alt or m.right_alt) {
            dvui.label(@src(), "alt", .{}, .{
                .id_extra = index + 4000,
                .color_text = mod_color,
                .font = font,
                .rect = .{ .x = padding_x, .y = offset_y, .w = col_w, .h = item_h * 1.5 },
                .gravity_x = 0.5,
                .gravity_y = 0.5,
            });
            offset_y += item_h + 1 * scale;
        }

        if (m.left_shift or m.right_shift) {
            dvui.label(@src(), "shft", .{}, .{
                .id_extra = index + 5000,
                .color_text = mod_color,
                .font = font,
                .rect = .{ .x = padding_x, .y = offset_y, .w = col_w, .h = item_h * 1.5 },
                .gravity_x = 0.5,
                .gravity_y = 0.5,
            });
        }
    }
}

test "getLabel: KC_A tap_only produces correct KeyDef" {
    const def = core.KeyDef{ .tap_only = .{
        .key_press = .{
            .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_A),
        },
    } };

    try testing.expect(def.tap_only.key_press != null);
    try testing.expectEqual(@as(u8, @intFromEnum(zkeymap.ScanCode.KC_A)), def.tap_only.key_press.?.tap_keycode);
}

test "getLabel: transparent key returns transparent variant" {
    const def = core.KeyDef.transparent;
    try testing.expect(def == .transparent);
}

test "getLabel: none key returns none variant" {
    const def = core.KeyDef.none;
    try testing.expect(def == .none);
}

test "getLabel: media key volume up has correct media_key" {
    const def = core.KeyDef{ .tap_only = .{
        .media_key = core.MEDIA_VOLUME_UP,
    } };
    try testing.expectEqual(@as(u16, core.MEDIA_VOLUME_UP), def.tap_only.media_key);
}

test "getLabel: COM_TOG custom has correct id" {
    const def = core.KeyDef{ .tap_only = .{
        .custom = keymap.COM_TOG,
    } };
    try testing.expectEqual(@as(u8, keymap.COM_TOG), def.tap_only.custom);
}

test "getLabel: mouse left click has correct action" {
    const def = core.KeyDef{ .tap_only = .{
        .mouse_action = .LeftClick,
    } };
    try testing.expect(def.tap_only.mouse_action == .LeftClick);
}

test "getLabel: tap_hold with layer has correct hold_layer" {
    const def = core.KeyDef{ .tap_hold = .{
        .tap = .{ .key_press = .{ .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_SPACE) } },
        .hold = .{ .hold_layer = 2 },
        .tapping_term = .{ .ms = 200 },
    } };
    try testing.expectEqual(@as(?core.LayerIndex, 2), def.tap_hold.hold.hold_layer);
}

test "getLabel: hold_only with modifiers shows modifier" {
    const def = core.KeyDef{ .hold_only = .{
        .hold_modifiers = .{ .left_shift = true, .right_shift = true },
    } };
    try testing.expect(def.hold_only.hold_modifiers != null);
    try testing.expect(def.hold_only.hold_modifiers.?.left_shift);
    try testing.expect(def.hold_only.hold_modifiers.?.right_shift);
}

test "getLabel: tap_with_autofire has correct structure" {
    const def = core.KeyDef{ .tap_with_autofire = .{
        .tap = .{ .key_press = .{ .tap_keycode = @intFromEnum(zkeymap.ScanCode.KC_B) } },
        .initial_delay = .{ .ms = 100 },
        .repeat_interval = .{ .ms = 50 },
    } };
    try testing.expect(def.tap_with_autofire.tap.key_press != null);
}
