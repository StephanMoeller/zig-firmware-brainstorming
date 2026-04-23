const std = @import("std");
const core = @import("core.zig");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;

pub const ProtocolMessage = union(enum) {
    KeyPressed: core.KeyIndex,
    KeyReleased: core.KeyIndex,
    EncoderValueChanged: u2,
};

pub const UartClient = struct {
    uart: rp2xxx.uart.UART,
    buffer: [2]u7 = @splat(u7),
    pub fn send(self: *UartClient, message: ProtocolMessage) !void {
        serialize(message, self.buffer);
        try sendData(self.uart, self.buffer);
    }

    pub fn receiveNext(self: *UartClient) !?ProtocolMessage {
        if (readData(self.uart, self.buffer)) {
            const message = try deserialize(self.buffer);
            return message;
        } else {
            return null;
        }
    }
};

pub fn readData(_: rp2xxx.uart.UART, _: *[2]u7) bool {} // <= error handling and message discarding will happen here
pub fn sendData(_: rp2xxx.uart.UART, _: [2]u7) !void {}
pub fn serialize(_: ProtocolMessage, _: *[2]u7) void {}
pub fn deserialize(_: *[2]u7) ProtocolMessage {
    return .{ .KeyPressed = 14 };
}
