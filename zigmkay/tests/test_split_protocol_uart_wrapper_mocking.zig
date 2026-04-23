const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const p = zigmkay.split_protocol;

const std = @import("std");
test "UartMock - with data" {
    var mock = p.UartWrapper.create_mock(&[_]u8{ 1, 0, 7 });
    try std.testing.expectEqual(1, mock.read_word());
    try std.testing.expectEqual(0, mock.read_word());
    try std.testing.expectEqual(7, mock.read_word());
    try std.testing.expectEqual(null, mock.read_word());
    try std.testing.expectEqual(null, mock.read_word());
}

test "UartMock - no data" {
    var mock = p.UartWrapper.create_mock(&[_]u8{});

    try std.testing.expectEqual(null, mock.read_word());
    try std.testing.expectEqual(null, mock.read_word());
}
