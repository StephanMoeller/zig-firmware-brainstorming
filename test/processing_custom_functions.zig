const std = @import("std");
const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const generic_queue = @import("zigmkay").generic_queue;
const helpers = @import("processing_test_helpers.zig");

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

const no_combos: [0]core.Combo2Def = [0]core.Combo2Def{};

test "custom code - tap events" {
    const MyFunctions = struct {
        var events_received: generic_queue.GenericQueue(core.ProcessorEvent, 100) = .Create();
        pub fn on_event(event: core.ProcessorEvent, layers: *core.LayerActivations, output_queue: *core.OutputCommandQueue) void {
            _ = layers;
            if (event != .OnMatrixChanged) events_received.enqueue(event) catch @panic("error should not happen here");
            switch (event) {
                .Tick => {},
                .OnMatrixChanged => {},
                .OnTapEnterBefore => |data| {
                    // ensure c press will happen before the a
                    output_queue.press_key(core.KeyCodeFire{ .tap_keycode = b }) catch @panic("error should not happen here");
                    _ = data;
                },
                .OnTapEnterAfter => |data| {
                    // ensure c press will happen before the a
                    output_queue.press_key(core.KeyCodeFire{ .tap_keycode = c }) catch @panic("error should not happen here");
                    _ = data;
                },
                .OnTapExitBefore => |data| {
                    // ensure c press will happen before the a
                    output_queue.press_key(core.KeyCodeFire{ .tap_keycode = d }) catch @panic("error should not happen here");
                    _ = data;
                },
                .OnTapExitAfter => |data| {
                    // ensure c press will happen before the a
                    output_queue.press_key(core.KeyCodeFire{ .tap_keycode = e }) catch @panic("error should not happen here");
                    _ = data;
                },
                else => {
                    if (event != .OnMatrixChanged) @panic("did not expect this event here");
                },
            }
        }
        pub fn get_event_count() usize {
            return events_received.Count();
        }
        pub fn dequeue_next_event() !core.ProcessorEvent {
            return try events_received.dequeue();
        }
    };

    const custom_functions = core.CustomFunctions{
        .on_event = MyFunctions.on_event,
    };

    const a_with_shift_hold = core.KeyDef{ .tap_hold = .{
        .tap = .{ .key_press = .{ .tap_keycode = a } },
        .hold = .{ .hold_modifiers = .{ .left_shift = true } },
        .tapping_term = core.TimeSpan{ .ms = 250 },
    } };
    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const base_layer = comptime [_]core.KeyDef{ a_with_shift_hold, B, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = helpers.init_test_full(
        core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len },
        &keymap,
        &[_]core.Combo2Def{},
        &custom_functions,
        @splat(.L),
    ){};

    // press B in the matrix
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 0 });
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 0 });

    try o.process(current_time);

    // ensure all events are fired and in the correct order
    try std.testing.expectEqual(5, MyFunctions.get_event_count());

    try std.testing.expectEqual(core.ProcessorEvent.Tick, MyFunctions.dequeue_next_event());

    try std.testing.expectEqual(core.ProcessorEvent{ .OnTapEnterBefore = .{ .tap = .{ .key_press = .{ .tap_keycode = a } } } }, MyFunctions.dequeue_next_event());
    try std.testing.expectEqual(core.ProcessorEvent{ .OnTapEnterAfter = .{ .tap = .{ .key_press = .{ .tap_keycode = a } } } }, MyFunctions.dequeue_next_event());
    try std.testing.expectEqual(core.ProcessorEvent{ .OnTapExitBefore = .{ .tap = .{ .key_press = .{ .tap_keycode = a } } } }, MyFunctions.dequeue_next_event());
    try std.testing.expectEqual(core.ProcessorEvent{ .OnTapExitAfter = .{ .tap = .{ .key_press = .{ .tap_keycode = a } } } }, MyFunctions.dequeue_next_event());

    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = b }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = a }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = c }, try o.dequeue());

    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = d }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodeRelease = a }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = e }, try o.dequeue());

    try std.testing.expectEqual(0, o.count_non_key_events());
}

test "custom code - hold events" {
    const MyFunctions = struct {
        var events_received: generic_queue.GenericQueue(core.ProcessorEvent, 100) = .Create();
        pub fn on_event(event: core.ProcessorEvent, layers: *core.LayerActivations, output_queue: *core.OutputCommandQueue) void {
            _ = layers;
            if (event != .OnMatrixChanged) events_received.enqueue(event) catch @panic("error should not happen here");
            switch (event) {
                .Tick => {},
                .OnMatrixChanged => {},
                .OnHoldEnterBefore => |data| {
                    // ensure c press will happen before the a
                    output_queue.press_key(core.KeyCodeFire{ .tap_keycode = b }) catch @panic("error should not happen here");
                    _ = data;
                },
                .OnHoldEnterAfter => |data| {
                    // ensure c press will happen before the a
                    output_queue.press_key(core.KeyCodeFire{ .tap_keycode = c }) catch @panic("error should not happen here");
                    _ = data;
                },
                .OnHoldExitBefore => |data| {
                    // ensure c press will happen before the a
                    output_queue.press_key(core.KeyCodeFire{ .tap_keycode = d }) catch @panic("error should not happen here");
                    _ = data;
                },
                .OnHoldExitAfter => |data| {
                    // ensure c press will happen before the a
                    output_queue.press_key(core.KeyCodeFire{ .tap_keycode = e }) catch @panic("error should not happen here");
                    _ = data;
                },
                else => {
                    @panic("did not expect this event here");
                },
            }
        }
        pub fn get_event_count() usize {
            return events_received.Count();
        }
        pub fn dequeue_next_event() !core.ProcessorEvent {
            return try events_received.dequeue();
        }
    };

    const custom_functions = core.CustomFunctions{
        .on_event = MyFunctions.on_event,
    };

    const a_with_shift_hold = core.KeyDef{ .tap_hold = .{
        .tap = .{ .key_press = .{ .tap_keycode = a } },
        .hold = .{ .hold_modifiers = .{ .left_shift = true } },
        .tapping_term = core.TimeSpan{ .ms = 250 },
    } };
    var current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const base_layer = comptime [_]core.KeyDef{ a_with_shift_hold, B, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = helpers.init_test_full(
        core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len },
        &keymap,
        &[_]core.Combo2Def{},
        &custom_functions,
        @splat(.L),
    ){};

    // press B in the matrix
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 0 });
    current_time = current_time.add_ms(500); // should trigger holding
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = false, .key_index = 0 });
    try o.process(current_time);

    // ensure all events are fired and in the correct order
    try std.testing.expectEqual(5, MyFunctions.get_event_count());

    try std.testing.expectEqual(core.ProcessorEvent.Tick, MyFunctions.dequeue_next_event());

    try std.testing.expectEqual(core.ProcessorEvent{ .OnHoldEnterBefore = .{ .hold = .{ .hold_modifiers = .{ .left_shift = true } } } }, MyFunctions.dequeue_next_event());
    try std.testing.expectEqual(core.ProcessorEvent{ .OnHoldEnterAfter = .{ .hold = .{ .hold_modifiers = .{ .left_shift = true } } } }, MyFunctions.dequeue_next_event());
    try std.testing.expectEqual(core.ProcessorEvent{ .OnHoldExitBefore = .{ .hold = .{ .hold_modifiers = .{ .left_shift = true } } } }, MyFunctions.dequeue_next_event());
    try std.testing.expectEqual(core.ProcessorEvent{ .OnHoldExitAfter = .{ .hold = .{ .hold_modifiers = .{ .left_shift = true } } } }, MyFunctions.dequeue_next_event());

    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = b }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{ .left_shift = true } }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = c }, try o.dequeue());

    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = d }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .ModifiersChanged = .{} }, try o.dequeue());
    try std.testing.expectEqual(core.OutputCommand{ .KeyCodePress = e }, try o.dequeue());

    try std.testing.expectEqual(0, o.count_non_key_events());
}

test "custom code - ensure tick event" {
    const MyFunctions = struct {
        var events_received: generic_queue.GenericQueue(core.ProcessorEvent, 100) = .Create();
        pub fn on_event(event: core.ProcessorEvent, layers: *core.LayerActivations, output_queue: *core.OutputCommandQueue) void {
            _ = output_queue;
            _ = layers;
            if (event != .OnMatrixChanged) events_received.enqueue(event) catch @panic("error should not happen here");
            switch (event) {
                .Tick => {},
                .OnMatrixChanged => {},
                else => {
                    @panic("did not expect this event here");
                },
            }
        }
        pub fn get_event_count() usize {
            return events_received.Count();
        }
        pub fn dequeue_next_event() !core.ProcessorEvent {
            return try events_received.dequeue();
        }
    };

    const custom_functions = core.CustomFunctions{
        .on_event = MyFunctions.on_event,
    };

    const a_with_shift_hold = core.KeyDef{ .tap_hold = .{
        .tap = .{ .key_press = .{ .tap_keycode = a } },
        .hold = .{ .hold_modifiers = .{ .left_shift = true } },
        .tapping_term = core.TimeSpan{ .ms = 250 },
    } };
    const current_time: core.TimeSinceBoot = core.TimeSinceBoot.from_absolute_us(100);
    const base_layer = comptime [_]core.KeyDef{ a_with_shift_hold, B, C, D };
    const keymap = comptime [_][base_layer.len]core.KeyDef{base_layer};
    var o = helpers.init_test_full(
        core.KeymapDimensions{ .key_count = base_layer.len, .layer_count = keymap.len },
        &keymap,
        &[_]core.Combo2Def{},
        &custom_functions,
        @splat(.L),
    ){};
    try o.process(current_time);

    // ensure all 4 tap events are fired and in the correct order
    try std.testing.expectEqual(1, MyFunctions.get_event_count());

    try std.testing.expectEqual(core.ProcessorEvent.Tick, MyFunctions.dequeue_next_event());
    try std.testing.expectEqual(0, o.count_non_key_events());
}
