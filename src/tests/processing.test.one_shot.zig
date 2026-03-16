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
const TestObjects = struct {
    matrix_change_queue: core.MatrixStateChangeQueue,
    actions_queue: core.OutputCommandQueue,
    processor: zigmkay.processing.Processor,
};

test "Simple one-shot" {
    // multiple mod hold presses at the same time

    const current_time: core.TimeSinceBoot = .from_absolute_us(100);
    const one_shot_shift = comptime helpers.ONE_SHOT_MOD(core.Modifiers{ .left_shift = true });
    const base_layer = comptime [_]core.KeyDef{ A, one_shot_shift, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};

    var o = init_test(core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len }, &keymap){};
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 0 }); // Press A
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 0 }); // Release A
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 1 }); // Press OneShot
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 1 }); // Release OneShot
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 2 }); // Press C
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 2 }); // Release C
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 2 }); // Press C
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 2 }); // Release C

    try o.process(current_time);

    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = a }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = a }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{ .left_shift = true } }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = c }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = c }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{} }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = c }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = c }, try o.dequeue());

    try std.testing.expectEqual(0, o.count_non_key_events());
    try std.testing.expectEqual(0, o.matrix_change_queue.Count());
}

test "one-shot in a rolling manner" {
    // multiple mod hold presses at the same time

    const current_time: core.TimeSinceBoot = .from_absolute_us(100);
    const one_shot_shift = comptime helpers.ONE_SHOT_MOD(core.Modifiers{ .left_shift = true });
    const base_layer = comptime [_]core.KeyDef{ A, B, one_shot_shift, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};

    var o = init_test(core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len }, &keymap){};
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 0 }); // Press A
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 1 }); // Press B
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 0 }); // Release A
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 2 }); // Press OneShot
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 1 }); // Release B
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 3 }); // Press C
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 2 }); // Release OneShot
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 4 }); // Press D
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 3 }); // Release C
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 4 }); // Release D

    // Expect one_shot to sourround the c press and nothing else
    try o.process(current_time);

    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = a }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = b }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = a }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = b }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{ .left_shift = true } }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = c }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{} }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = d }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = c }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = d }, try o.dequeue());

    try std.testing.expectEqual(0, o.count_non_key_events());
    try std.testing.expectEqual(0, o.matrix_change_queue.Count());
}
