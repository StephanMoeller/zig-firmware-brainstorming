const std = @import("std");
const core = @import("zigmkay").core;
const zkeymap = @import("zkeymap");
const keymap = @import("keymap");
const Modifiers = core.Modifiers;

const key_comp = @import("key.zig");
const cache = @import("cache.zig");
const EncoderComponent = @import("encoder.zig").EncoderComponent;

/// Represents the visual coordinates and grid-indices (rows/cols)
/// for a single physical key or encoder within the keyboard overlay.
pub const KeyPosition = struct {
    x_offset: f32, // The Horizontal offset relative to the center of the application window.
    y_offset: f32, // The Vertical offset relative to the calculated start_y of the layout block.
    row: f32, // The physical row index this key currently inhabits.
    col: f32, // The physical column index on its respective side (starts at 0 per side).
    side: core.Side, // Side denomination extracted from the `sides` enum (e.g Left, Right, Encoder).
};

/// Layout container generated at `comptime` that sets parameters for the draw function.
pub fn LayoutMap(comptime key_count: usize) type {
    return struct {
        positions: [key_count]KeyPosition,
        total_height: f32,
        key_size: f32,
        spacing: f32,
        scale: f32,
    };
}

/// Configuration options scaling and adjusting the way keys are drawn on screen.
pub const LayoutOptions = struct {
    scale: f32 = 2.0,
    key_size: f32 = 45.0,
    spacing: f32 = 8.0,
    gap: f32 = 80.0,
    thumb_cluster_gap: f32 = 10.0,
};

/// Generates a strict bounding map dynamically adjusting positional offsets for every key
/// based strictly on a provided sequence of `core.Side` elements. Executed cleanly at `comptime`
/// inside `main.zig` to keep runtime memory operations fully optimized.
pub fn generateKeyPositions(
    comptime key_count: usize,
    comptime keys: [key_count]core.Side,
    comptime options: LayoutOptions,
) LayoutMap(key_count) {
    @setEvalBranchQuota(10000);
    const scale = options.scale;
    const key_size = options.key_size * scale;
    const spacing = options.spacing * scale;
    const gap = options.gap * scale;
    const thumb_cluster_gap = options.thumb_cluster_gap * scale;

    var map = LayoutMap(key_count){
        .positions = undefined,
        .total_height = 0,
        .key_size = key_size,
        .spacing = spacing,
        .scale = scale,
    };

    var current_row: f32 = 0;
    var current_col: f32 = 0;
    var last_key: core.Side = keys[0];

    // Pre-Processing Phase: Iterate the entire `sides` mapping of the keymap once to count
    // how many `.L` (Left Side) keys exist on any given row.
    var row_l_counts: [20]f32 = [_]f32{0} ** 20;
    var r: usize = 0;
    for (0..key_count, keys) |i, key| {
        if (key == .L or key == .TL) {
            row_l_counts[r] += 1;
        }

        // We identify the start of a new row when the sequence transits from `.R` back to `.L`
        if (i < key_count - 1 and keys[i] == .R and (keys[i + 1] == .L or keys[i + 1] == .TL)) {
            r += 1;
        }
    }

    var r_idx: usize = 0;
    for (0..key_count, keys) |i, key| {
        if (key == .E) {
            map.positions[i] = .{
                .x_offset = 0,
                .y_offset = 0,
                .row = current_row,
                .col = current_col,
                .side = key,
            };
            current_col += 1;
            continue;
        }

        // Reset coordinates when we observe a transition between physical sides.
        if (key != last_key) {
            if (last_key == .R and (key == .L or key == .TL)) {
                // Transitioning out of a Right Block -> Start a new Row!
                current_row += 1;
                r_idx += 1;
            }
            // reset col on transition
            current_col = 0;
            last_key = key;
        }

        const row_max_cols = row_l_counts[r_idx];

        // Central Offset Logic: Left Keys calculate outwards right-to-left utilizing `row_l_counts`.
        // Right Keys calculate outwards left-to-right based purely on `current_col` incrementations.
        var x_offset: f32 = 0;
        if (key == .L or key == .TL) {
            x_offset = -(gap / 2.0) - (row_max_cols - current_col) * (key_size + spacing);
        } else if (key == .R or key == .TR) {
            x_offset = (gap / 2.0) + current_col * (key_size + spacing);
        }

        var y_offset: f32 = current_row * (key_size + spacing);
        if (key == .TL or key == .TR) {
            y_offset += thumb_cluster_gap;
        }

        map.positions[i] = .{
            .x_offset = x_offset,
            .y_offset = y_offset,
            .row = current_row,
            .col = current_col,
            .side = key,
        };

        current_col += 1;
    }

    map.total_height = (current_row + 1) * key_size + current_row * spacing;
    if (current_row >= 3) {
        map.total_height += thumb_cluster_gap;
    }
    return map;
}

/// Main draw function that draws all keys and the encoder to the screen.
pub fn drawKeysAndEncoder(
    layout: *const LayoutMap(keymap.key_count),
    label_cache: *const cache.LabelCache,
    current_layer: usize,
    active_keys: *[128]bool,
    active_mods: Modifiers,
    maybe_encoder_instance: ?EncoderComponent,
    center_x: f32,
    center_y: f32,
    start_y: f32,
) !void {
    // Draw Keys
    for (0..keymap.key_count) |i| {
        const pos = layout.positions[i];

        if (pos.side == .E) continue; // Skip encoders in the standard grid

        const x = center_x + pos.x_offset;
        const y = start_y + pos.y_offset;

        const content = label_cache.lookup(current_layer, i, active_mods).*;
        const active = active_keys[i];

        try key_comp.drawKey(current_layer, i, x, y, layout.key_size, layout.scale, content, active);
    }

    if (maybe_encoder_instance) |encoder_instance| {
        // Draw Encoder Wheel
        const enc_y = (center_y * 1.1) + 10.0 * layout.scale;
        try encoder_instance.draw(current_layer, label_cache, active_mods, center_x, enc_y, layout.key_size * 1.3, layout.scale);
    }
}

test "generateKeyPositions standard split" {
    // zig fmt: off
    const sides = [_]core.Side{
        .L, .L, .L, .R, .R, .R,
        .L, .L, .L, .R, .R, .R,
        .TL,               .TR
    };
    // zig fmt: on
    const layout = comptime generateKeyPositions(sides.len, sides, .{ .scale = 1.0 });

    try std.testing.expectEqual(@as(f32, 3.0 * 45.0 + 2.0 * 8.0), layout.total_height);
    try std.testing.expectEqual(core.Side.L, layout.positions[0].side);
    try std.testing.expectEqual(@as(f32, 0), layout.positions[0].row);
    try std.testing.expectEqual(@as(f32, 0), layout.positions[0].col);
    try std.testing.expect(layout.positions[0].x_offset < 0);

    try std.testing.expectEqual(core.Side.R, layout.positions[3].side);
    try std.testing.expectEqual(@as(f32, 0), layout.positions[3].row);
    try std.testing.expectEqual(@as(f32, 0), layout.positions[3].col);
    try std.testing.expect(layout.positions[3].x_offset > 0);

    try std.testing.expectEqual(core.Side.TL, layout.positions[12].side);
    try std.testing.expectEqual(@as(f32, 2), layout.positions[12].row);
    try std.testing.expectEqual(@as(f32, 0), layout.positions[12].col);
    // try std.testing.expect(layout.positions[12].x_offset > 0);
}

test "generateKeyPositions with encoder" {
    const sides = [_]core.Side{
        .L, .L, .R, .R,
        .E, .E,
    };
    const layout = comptime generateKeyPositions(sides.len, sides, .{ .scale = 1.0 });

    try std.testing.expectEqual(core.Side.E, layout.positions[4].side);
}

test "generateKeyPositions lopsided" {
    // zig fmt: off
    const sides = [_]core.Side{
        .L, .L, .L, .L, .R, .R,
        .L, .L, .L, .R, .R, .R, .R,
    };
    // zig fmt: on
    const layout = comptime generateKeyPositions(sides.len, sides, .{ .scale = 1.0 });

    try std.testing.expectEqual(@as(f32, 0), layout.positions[0].row);
    try std.testing.expectEqual(@as(f32, 1), layout.positions[6].row);
}
