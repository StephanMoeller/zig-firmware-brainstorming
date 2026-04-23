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
pub fn receiveMessage(input_byte_queue: *ByteQueue) ?ProtocolMessage {
    // read until delimiter + 2x non-delimiters received or null received
    var pointer: usize = 0;
    var data: [2]u8 = @splat(2);
    while (true) {
        const byte = input_byte_queue.dequeue() catch return null;
        if (pointer == 0 and byte != DELIMITER) {
            pointer = 0; // Reset, starting with a delimiter
            continue; // non delimiter received, reset pointer
        }

        if (pointer > 0 and byte == DELIMITER) {
            pointer = 1; // received a delimiter, now expect the next to be the first byte in the message
            continue;
        }

        if (pointer > 0) {
            data[pointer - 1] = byte;
        }

        pointer += 1;
        if (pointer > 2) {
            var buffer: [2]u7 = @splat(2);
            buffer[0] = u8_to_u7(data[0]) catch return null;
            buffer[1] = u8_to_u7(data[1]) catch return null;
            const msg = deserialize(&buffer) catch return null;
            return msg;
        }
    }
}

pub fn sendMessage(output_byte_queue: *ByteQueue, msg: ProtocolMessage) void {
    var data_u7: [2]u7 = .{ 0, 0 };
    serialize(msg, &data_u7);
    output_byte_queue.enqueue(DELIMITER) catch return;
    output_byte_queue.enqueue(data_u7[0]) catch return;
    output_byte_queue.enqueue(data_u7[1]) catch return;
}

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
