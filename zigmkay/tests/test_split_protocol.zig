const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const p = zigmkay.split_protocol;

const std = @import("std");
test "Serialize and deserialize: KeyPress" {
    const msg = p.ProtocolMessage{ .KeyPressed = 102 };
    var data: [2]u7 = [2]u7{ 0, 0 };
    p.serialize(msg, &data);
    const msg_again = p.deserialize(&data);

    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 102 }, msg_again);
}
