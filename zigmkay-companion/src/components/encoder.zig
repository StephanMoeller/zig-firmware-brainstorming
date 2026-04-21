const std = @import("std");
const dvui = @import("dvui");
const key_component = @import("key.zig");
const cache = @import("cache.zig");
const zkeymap = @import("zkeymap");
const keymap = @import("keymap");

const core = keymap.core;
const Modifiers = core.Modifiers;

pub const EncoderComponent = struct {
    last_activity: i64 = 0,
    last_direction: u8 = 0,

    pub fn handleSignal(self: *EncoderComponent, direction: u8) void {
        self.last_direction = direction;
        self.last_activity = std.time.milliTimestamp();
    }

    pub fn draw(self: *const EncoderComponent, current_layer: usize, label_cache: *const cache.LabelCache, physical_mods: Modifiers, center_x: f32, y: f32, size: f32, scale: f32) !void {
        const active = (std.time.milliTimestamp() - self.last_activity < 150);
        const radius = size / 2.0;
        const x = center_x - radius;

        const layer_color = if (current_layer < key_component.layer_colors.len) key_component.layer_colors[current_layer] else dvui.Color.white;
        const muted_layer_color = key_component.getMutedColor(layer_color);

        const bg_color = if (active) muted_layer_color else dvui.Color.black;
        const border_color = if (active) layer_color else muted_layer_color;
        const text_color = dvui.Color.white;

        // Resolve content from keymap
        // Encoders are mapped to indices 38 (CW) and 39 (CCW)
        const enc_idx: usize = if (self.last_direction == 2) 39 else 38;
        const content = label_cache.lookup(current_layer, enc_idx, physical_mods).*;

        var b = dvui.box(@src(), .{}, .{
            .id_extra = 5000,
            .rect = .{ .x = x, .y = y, .w = size, .h = size },
            .background = true,
            .color_fill = bg_color,
            .color_border = border_color,
            .border = dvui.Rect.all(1.5 * scale),
            .corner_radius = dvui.Rect.all(radius),
        });
        defer b.deinit();

        if (content.icon) |icon_bytes| {
            dvui.icon(@src(), content.icon_name, icon_bytes, .{}, .{
                .id_extra = 5001,
                .color_text = text_color,
                .gravity_x = 0.5,
                .gravity_y = 0.5,
                .min_size_content = .{ .w = size * 0.5, .h = size * 0.5 },
            });
        } else if (content.label) |l| {
            dvui.label(@src(), "{s}", .{l}, .{
                .id_extra = 5001,
                .color_text = text_color,
                .font = dvui.Font.theme(.body).larger(2),
                .gravity_x = 0.5,
                .gravity_y = 0.5,
            });
        }
    }
};
