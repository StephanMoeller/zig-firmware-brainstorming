const core = @import("zigmkay").core;
const std = @import("std");
test "TimeSinceBoot creation" {
    try std.testing.expectEqual(789, core.TimeSinceBoot.from_absolute_us(789).time_since_boot_us);
}

test "TimeSinceBoot add_us" {
    var time = core.TimeSinceBoot{ .time_since_boot_us = 100 };
    time = time.add_us(20);
    try std.testing.expectEqual(120, time.time_since_boot_us);
}

test "TimeSinceBoot add_ms" {
    var time = core.TimeSinceBoot{ .time_since_boot_us = 100 };
    time = time.add_ms(20);
    try std.testing.expectEqual(20100, time.time_since_boot_us);
}

test "TimeSinceBoot add" {
    var time = core.TimeSinceBoot{ .time_since_boot_us = 100 };
    const diff = core.TimeSpan{ .ms = 30 };
    time = time.add(diff);
    try std.testing.expectEqual(30100, time.time_since_boot_us);
}

test "TimeSinceBoot diff_us" {
    const time1 = core.TimeSinceBoot{ .time_since_boot_us = 100 };
    const time2 = core.TimeSinceBoot{ .time_since_boot_us = 2000 };
    try std.testing.expectEqual(1900, time2.diff_us(&time1));
    const res = time1.diff_us(&time2);
    try std.testing.expectEqual(core.DiffError.CurrentIsEarlierThanInput, res);
}

test "Modifiers.add" {
    var mod = core.Modifiers{ .left_shift = true, .left_ctrl = true, .left_gui = true };
    const mod1 = core.Modifiers{ .left_alt = true, .left_ctrl = true };
    const result = mod.add(mod1);

    try std.testing.expectEqual(core.Modifiers{ .left_ctrl = true, .left_alt = true, .left_gui = true, .left_shift = true }, result);
}

test "Modifiers.remove" {
    var mod = core.Modifiers{ .left_shift = true, .left_ctrl = true, .left_gui = true };
    const mod1 = core.Modifiers{ .left_alt = true, .left_ctrl = true };
    const result = mod.remove(mod1);

    try std.testing.expectEqual(core.Modifiers{ .left_gui = true, .left_shift = true }, result);
}

test "LayerActivations" {
    var layers = core.LayerActivations{};
    var q = core.OutputCommandQueue.Create();
    try std.testing.expectEqual(true, layers.is_layer_active(0)); // base is always active
    try std.testing.expectEqual(false, layers.is_layer_active(1)); // base is always active
    try std.testing.expectEqual(false, layers.is_layer_active(6)); // base is always active
    try std.testing.expectEqual(false, layers.is_layer_active(4)); // base is always active
    try std.testing.expectEqual(false, layers.is_layer_active(7)); // base is always active

    layers.activate(6, &q);

    layers.activate(4, &q);
    layers.activate(4, &q);

    layers.activate(7, &q);
    layers.activate(7, &q);
    layers.deactivate(7, &q);

    try std.testing.expectEqual(true, layers.is_layer_active(0)); // base is always active
    try std.testing.expectEqual(false, layers.is_layer_active(1)); // base is always active
    try std.testing.expectEqual(true, layers.is_layer_active(6)); // base is always active
    try std.testing.expectEqual(true, layers.is_layer_active(4)); // base is always active
    try std.testing.expectEqual(false, layers.is_layer_active(7)); // base is always active
}

test "LayerActivations is_top_most_active_layer - test 1" {
    var layers = core.LayerActivations{};
    var q = core.OutputCommandQueue.Create();
    try std.testing.expectEqual(0, layers.get_top_most_active_layer());
    layers.activate(3, &q);
    try std.testing.expectEqual(3, layers.get_top_most_active_layer());
    layers.deactivate(3, &q);
    try std.testing.expectEqual(0, layers.get_top_most_active_layer());
}

test "LayerActivations is_top_most_active_layer - test 2" {
    var layers = core.LayerActivations{};
    var q = core.OutputCommandQueue.Create();
    try std.testing.expectEqual(0, layers.get_top_most_active_layer());
    layers.activate(3, &q);
    layers.deactivate(3, &q);
    layers.activate(4, &q);
    layers.activate(5, &q);
    layers.activate(6, &q);
    layers.deactivate(5, &q);

    try std.testing.expectEqual(6, layers.get_top_most_active_layer());

    layers.deactivate(5, &q);

    try std.testing.expectEqual(6, layers.get_top_most_active_layer());

    layers.deactivate(6, &q);

    try std.testing.expectEqual(4, layers.get_top_most_active_layer());
}
test "Uart message" {
    var uart = core.UartMessage{ .pressed = true, .key_index = 112 };
    const byte = uart.toByte();
    uart = core.UartMessage.fromByte(byte);
    try std.testing.expectEqual(true, uart.pressed);
    try std.testing.expectEqual(112, uart.key_index);
}
