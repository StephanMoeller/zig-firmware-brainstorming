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

test "Serialize and deserialize: Invalid message type - 0" {
    var data: [2]u7 = [2]u7{ 0, 127 };
    const err = p.deserialize(&data);

    try std.testing.expectEqual(err, p.DeserializeError.UnknownMessageType);
}

test "Serialize and deserialize: Invalid message type - 4" {
    var data: [2]u7 = [2]u7{ 4, 127 };
    const err = p.deserialize(&data);

    try std.testing.expectEqual(err, p.DeserializeError.UnknownMessageType);
}

test "Serialize and deserialize: EncoderValueChanged (invalid u2 value) - 4" {
    const msg = p.ProtocolMessage{ .EncoderValueChanged = 3 };
    var data: [2]u7 = [2]u7{ 0, 0 };
    p.serialize(msg, &data);
    try std.testing.expectEqual(3, data[1]); // sanity checking that the actual value is currently at this position

    // now make the data invalid
    data[1] = 4;

    const err = p.deserialize(&data);

    try std.testing.expectEqual(err, p.DeserializeError.U7notConvertibleToU2);
}

test "Serialize and deserialize: EncoderValueChanged (invalid u2 value) - 127" {
    const msg = p.ProtocolMessage{ .EncoderValueChanged = 3 };
    var data: [2]u7 = [2]u7{ 0, 0 };
    p.serialize(msg, &data);
    try std.testing.expectEqual(3, data[1]); // sanity checking that the actual value is currently at this position

    // now make the data invalid
    data[1] = 127;

    const err = p.deserialize(&data);

    try std.testing.expectEqual(err, p.DeserializeError.U7notConvertibleToU2);
}
