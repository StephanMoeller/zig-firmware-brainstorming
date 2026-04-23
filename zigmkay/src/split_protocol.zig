const std = @import("std");
const core = @import("core.zig");
const generic_queue = @import("generic_queue.zig");

pub const ProtocolMessage = union(enum) {
    KeyPressed: core.KeyIndex,
    KeyReleased: core.KeyIndex,
    EncoderValueChanged: u2,
};

pub const ByteQueue = generic_queue.GenericQueue(u8, 250);

pub const DELIMITER: u8 = 0b11111111;

pub const UartReceiveHelper = struct {
    pub const ExpectedData = enum { Delimiter, MessageId, Payload };
    pointer: usize = 0,
    cached_message_id: u7 = undefined,
    expected_next: ExpectedData = ExpectedData.Delimiter,
    pub fn receiveByte(self: *UartReceiveHelper, byte: u8) ?ProtocolMessage {
        // read until delimiter + 2x non-delimiters received or null received
        switch (self.expected_next) {
            .Delimiter => {
                if (byte == DELIMITER) {
                    self.expected_next = .MessageId;
                }
                return null;
            },
            .MessageId => {
                if (byte == DELIMITER) {
                    // Let the expected next stay at message id
                    return null;
                }
                self.cached_message_id = u8_to_u7(byte) catch {
                    self.expected_next = .Delimiter; // Reset
                    return null;
                };

                self.expected_next = .Payload;
                return null;
            },
            .Payload => {
                if (byte == DELIMITER) {
                    self.expected_next = .MessageId;
                    return null;
                }

                self.expected_next = .Delimiter; // Reset no matter what

                var buffer: [2]u8 = @splat(2);
                buffer[0] = self.cached_message_id;
                buffer[1] = byte;
                const msg = deserialize(buffer) catch return null;
                return msg;
            },
        }

        unreachable;
    }
};

pub const UartSendHelper = struct {
    byte_queue: ByteQueue = ByteQueue.Create(),
    pub fn sendMessage(self: *UartSendHelper, msg: ProtocolMessage) !void {
        const data: [2]u8 = serialize(msg);
        try self.byte_queue.enqueue(DELIMITER);
        try self.byte_queue.enqueue(data[0]);
        try self.byte_queue.enqueue(data[1]);
    }
};

fn u8_to_u7(val: u8) DeserializeError!u7 {
    if (val > 127) {
        return DeserializeError.U8notConvertibleToU7;
    }
    return @intCast(val);
}

//pub fn sendMessage(uart_write_word: fn (word: u8) void, msg: ProtocolMessage) void {}

pub fn serialize(msg: ProtocolMessage) [2]u8 {
    switch (msg) {
        .KeyPressed => |key_index_pressed| {
            return .{ 1, key_index_pressed };
        },
        .KeyReleased => |key_index_released| {
            return .{ 2, key_index_released };
        },
        .EncoderValueChanged => |encoder_value| {
            return .{ 3, encoder_value };
        },
    }
}

pub fn deserialize(buffer: [2]u8) DeserializeError!ProtocolMessage {
    const message_type = buffer[0];
    const payload = buffer[1];
    switch (message_type) {
        1 => return .{ .KeyPressed = try u8_to_u7(payload) },
        2 => return .{ .KeyReleased = try u8_to_u7(payload) },
        3 => return .{ .EncoderValueChanged = try u8_to_u2(payload) },
        else => return DeserializeError.UnknownMessageType,
    }
}

pub fn u8_to_u2(input: u8) DeserializeError!u2 {
    if (input > 3) {
        return DeserializeError.U7notConvertibleToU2;
    }
    return @intCast(input);
}

pub const DeserializeError = error{
    U7notConvertibleToU2,
    U8notConvertibleToU7,
    UnknownMessageType,
};
