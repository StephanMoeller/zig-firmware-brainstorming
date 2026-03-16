const std = @import("std");
const zigmkay = @import("zigmkay");
const core = zigmkay.core;

const helpers = @import("processing.test_helpers.zig");
const init_test = helpers.init_test;

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
test "TAP - single key press" {
    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const base_layer = comptime [_]core.KeyDef{ A, B, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = init_test(core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len }, &keymap){};
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 1 });

    try o.process(current_time);

    // expect B to be fired as press
    try std.testing.expectEqual(1, o.count_non_key_events());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = b }, try o.dequeue());

    // expect event removed from input_events
    try std.testing.expectEqual(0, o.count_non_key_events());
    try std.testing.expectEqual(0, o.matrix_change_queue.Count());
}

test "TAP - single key release - expect nothing as key is not held" {
    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const base_layer = comptime [_]core.KeyDef{ A, B, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = init_test(core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len }, &keymap){};
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 1 });

    try o.process(current_time);

    try std.testing.expectEqual(0, o.count_non_key_events()); // expect B to be fired as press
}

test "TAP - multiple simple tap events" {
    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const base_layer = comptime [_]core.KeyDef{ A, B, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = init_test(core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len }, &keymap){};
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 1 });
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 1 });
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 2 });
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 0 });
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 0 });

    try o.process(current_time);

    // expect B to be fired as press
    try std.testing.expectEqual(5, o.count_non_key_events());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = b }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = b }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = c }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = a }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = a }, try o.dequeue());

    // expect event removed from input_events
    try std.testing.expectEqual(0, o.count_non_key_events());
    try std.testing.expectEqual(0, o.matrix_change_queue.Count());
}

test "TAP_WITH_MOD - single key press" {
    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const shiftedA = comptime helpers.TAP_WITH_MOD(0x04, .{ .left_shift = true });
    const base_layer = comptime [_]core.KeyDef{ shiftedA, B, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = init_test(core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len }, &keymap){};
    // define some input events
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 0 });
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 0 });

    try o.process(current_time);

    // expect B to be fired as press
    try std.testing.expectEqual(4, o.count_non_key_events());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{ .left_shift = true } }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = 0x04 }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = 0x04 }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{} }, try o.dequeue());

    // expect event removed from input_events
    try std.testing.expectEqual(0, o.count_non_key_events());
    try std.testing.expectEqual(0, o.matrix_change_queue.Count());
}

test "TAP_WITH_MOD - with other keys" {
    // with other keys pressed between press and release
    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const shiftedA = comptime helpers.TAP_WITH_MOD(0x04, .{ .left_shift = true });
    const normalB = comptime helpers.TAP(0x05);
    const base_layer = comptime [_]core.KeyDef{ shiftedA, normalB, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = init_test(core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len }, &keymap){};
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 0 }); // Press A + shift
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 1 }); // Press B
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 0 }); // Release A + shift
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 1 }); // Release B

    try o.process(current_time);

    // expect B to be fired as press
    try std.testing.expectEqual(6, o.count_non_key_events());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{ .left_shift = true } }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = a }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = a }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{} }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = b }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = b }, try o.dequeue());

    // expect event removed from input_events
    try std.testing.expectEqual(0, o.count_non_key_events());
    try std.testing.expectEqual(0, o.matrix_change_queue.Count());
}
