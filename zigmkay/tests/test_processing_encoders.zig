const std = @import("std");
const zigmkay = @import("zigmkay");
const core = zigmkay.core;

const helpers = @import("test_processing_helpers.zig");
const init_with_config = helpers.init_with_config;

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
test "Encoders" {
    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const base_layer = comptime [_]core.KeyDef{ A, B, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = init_with_config(.{ .key_count = base_layer.len, .layer_count = keymap.len }, .{ .keymap = &keymap }){};
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 1 });

    try o.process(current_time);

    // expect B to be fired as press
    try std.testing.expectEqual(1, o.actions_queue.Count());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = b }, o.actions_queue.dequeue());

    // expect event removed from input_events
    try std.testing.expectEqual(0, o.actions_queue.Count());
    try std.testing.expectEqual(0, o.matrix_change_queue.Count());
}
