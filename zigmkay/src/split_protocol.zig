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
                const payload: u7 = u8_to_u7(byte) catch {
                    return null;
                };
                var buffer: [2]u7 = @splat(2);
                buffer[0] = self.cached_message_id;
                buffer[1] = payload;
                const msg = deserialize(&buffer) catch return null;
                return msg;
            },
        }

        unreachable;
    }
};

pub const UartSendHelper = struct {
    byte_queue: ByteQueue = ByteQueue.Create(),
    pub fn sendMessage(self: *UartSendHelper, msg: ProtocolMessage) !void {
        var data_u7: [2]u7 = .{ 0, 0 };
        serialize(msg, &data_u7);
        try self.byte_queue.enqueue(DELIMITER);
        try self.byte_queue.enqueue(data_u7[0]);
        try self.byte_queue.enqueue(data_u7[1]);
    }
};

fn u8_to_u7(val: u8) DeserializeError!u7 {
    if (val > 127) {
        return DeserializeError.U8notConvertibleToU7;
    }
    return @intCast(val);
}

//pub fn sendMessage(uart_write_word: fn (word: u8) void, msg: ProtocolMessage) void {}

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
    U8notConvertibleToU7,
    UnknownMessageType,
};
