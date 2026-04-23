const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const p = zigmkay.split_protocol;

const std = @import("std");
test "UartMock - with data" {
    var mock = p.UartMock{ .data = &[_]u8{ 1, 0, 7 } };
    try std.testing.expectEqual(1, mock.read_next_mocked_value());
    try std.testing.expectEqual(0, mock.read_next_mocked_value());
    try std.testing.expectEqual(7, mock.read_next_mocked_value());
    try std.testing.expectEqual(null, mock.read_next_mocked_value());
    try std.testing.expectEqual(null, mock.read_next_mocked_value());
}

test "UartMock - no data" {
    var mock = p.UartMock{ .data = &[_]u8{} };

    try std.testing.expectEqual(null, mock.read_next_mocked_value());
    try std.testing.expectEqual(null, mock.read_next_mocked_value());
}
