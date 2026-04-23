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
pub fn serialize(msg: ProtocolMessage, buffer: *[2]u7) void {
    var message_type: u7 = 0;
    var payload: u7 = 0;
    switch (msg) {
        .KeyPressed => |key_index_released| {
            message_type = 1;
            payload = key_index_released;
        },
        .KeyReleased => |key_index_pressed| {
            message_type = 2;
            payload = key_index_pressed;
        },

        .EncoderValueChanged => |encoder_value| {
            message_type = 3;
            payload = encoder_value;
        },
    }

    buffer[0] = message_type;
    buffer[1] = payload;
}

pub fn deserialize(buffer: *[2]u7) !ProtocolMessage {
    const message_type = buffer[0];
    const payload = buffer[1];
    switch (message_type) {
        1 => return .{ .KeyPressed = payload },
        2 => return .{ .KeyReleased = payload },
        //3 => return .{ .EncoderValueChanged = payload },
        else => return ProtocolMessage{ .KeyPressed = 0 },
    }
}
