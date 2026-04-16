const std = @import("std");
const zigmkay = @import("zigmkay");
const core = zigmkay.core;

const helpers = @import("test_processing_helpers.zig");
const init_test = helpers.init_test;

const KC_SPACE = 0x2C;

const a = 0x04;
const b = 0x05;
const c = 0x06;
const d = 0x07;
const e = 0x08;
const f = 0x09;
const g = 0x10;

const A = helpers.TAP(a);
const B = helpers.TAP(b);
const C = helpers.TAP(c);
const D = helpers.TAP(d);
const E = helpers.TAP(e);
const F = helpers.TAP(f);
const G = helpers.TAP(g);
// test stuff
test "Mouse actions - left mouse press" {
    const key_tap = core.KeyDef{ .tap_only = .{ .key_press = .{ .tap_keycode = a, .dead = true } } };
    const mouse_left_click = core.KeyDef{ .tap_only = .{ .mouse_action = .LeftClick } };

    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const base_layer = comptime [_]core.KeyDef{ key_tap, mouse_left_click };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = init_test(core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len }, &keymap){};

    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 1 }); // press mouse down

    try o.process(current_time);

    // expect B to be fired as press
    try std.testing.expectEqual(1, o.count_non_key_events());
    try std.testing.expectEqual(core.OutputCommand{ .MouseCommand = .{ .action = .LeftClick, .pressed = true } }, try o.dequeue());

    // expect event removed from input_events
    try std.testing.expectEqual(0, o.count_non_key_events());
    try std.testing.expectEqual(0, o.matrix_change_queue.Count());
}

test "Mouse actions - left mouse press and release" {
    const key_tap = core.KeyDef{ .tap_only = .{ .key_press = .{ .tap_keycode = a, .dead = true } } };
    const mouse_left_click = core.KeyDef{ .tap_only = .{ .mouse_action = .LeftClick } };

    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const base_layer = comptime [_]core.KeyDef{ key_tap, mouse_left_click };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = init_test(core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len }, &keymap){};

    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 1 }); // press mouse down
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 1 }); // press mouse down

    try o.process(current_time);

    // expect B to be fired as press
    try std.testing.expectEqual(2, o.count_non_key_events());
    try std.testing.expectEqual(core.OutputCommand{ .MouseCommand = .{ .action = .LeftClick, .pressed = true } }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .MouseCommand = .{ .action = .LeftClick, .pressed = false } }, try o.dequeue());

    // expect event removed from input_events
    try std.testing.expectEqual(0, o.count_non_key_events());
    try std.testing.expectEqual(0, o.matrix_change_queue.Count());
}
