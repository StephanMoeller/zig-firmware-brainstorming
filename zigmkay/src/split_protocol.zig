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

pub const UartMock = struct {
    pointer: usize = 0,
    data: []const u8,
    pub fn read_next_mocked_value(self: *UartMock) ?u8 {
        if (self.pointer < self.data.len) {
            self.pointer += 1;
            return self.data[self.pointer - 1];
        } else {
            return null;
        }
    }
};
pub const UartWrapper = struct {
    uart: ?rp2xxx.uart.UART,
    mock: ?UartMock,
    pub fn create(uart: rp2xxx.uart.UART) UartWrapper {
        return UartWrapper{ .uart = uart, .mock = null };
    }
    pub fn create_mock(mock: UartMock) UartWrapper {
        return UartWrapper{ .uart = null, .mock = mock };
    }
    const UartUtils = struct {
        pub fn read_word(self: *const UartWrapper) ?u8 {
            if (self.uart) |uart| {
                const byte_or_null: ?u8 = uart.read_word() catch {
                    uart.clear_errors();
                    return null;
                };

                return byte_or_null;
            } else if (self.mock) |mock| {
                return mock.read_next_mocked_value();
            }
        }
    };
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
            payload = u2_to_u7(encoder_value);
        },
    }

    buffer[0] = message_type;
    buffer[1] = payload;
}

pub fn deserialize(buffer: *[2]u7) DeserializeError!ProtocolMessage {
    const message_type = buffer[0];
    const payload = buffer[1];
    switch (message_type) {
        1 => return .{ .KeyPressed = payload },
        2 => return .{ .KeyReleased = payload },
        3 => return .{ .EncoderValueChanged = try u7_to_u2(payload) },
        else => return DeserializeError.UnknownMessageType,
    }
}

pub fn u2_to_u7(input: u2) u7 {
    return input;
}

pub fn u7_to_u2(input: u7) DeserializeError!u2 {
    if (input > 3) {
        return DeserializeError.U7notConvertibleToU2;
    }
    return @intCast(input);
}

pub const DeserializeError = error{
    U7notConvertibleToU2,
    UnknownMessageType,
};
