const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const p = zigmkay.split_protocol;

const std = @import("std");
test "Serialize and deserialize: KeyPress" {
    const msg = p.ProtocolMessage{ .KeyPressed = 102 };
    var data: [2]u7 = [2]u7{ 0, 0 };
    p.serialize(msg, &data);
    const other_msg = try p.deserialize(&data);

    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 102 }, other_msg);
}

test "Serialize and deserialize: KeyReleased" {
    const msg = p.ProtocolMessage{ .KeyReleased = 47 };
    var data: [2]u7 = [2]u7{ 0, 0 };
    p.serialize(msg, &data);

    // sanity checking
    try std.testing.expectEqual(2, data[0]);

    const other_msg = try p.deserialize(&data);

    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 47 }, other_msg);
}

test "Serialize and deserialize: EncoderValueChanged" {
    const msg = p.ProtocolMessage{ .EncoderValueChanged = 3 };
    var data: [2]u7 = [2]u7{ 0, 0 };
    p.serialize(msg, &data);
    const other_msg = try p.deserialize(&data);

    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 3 }, other_msg);
}
