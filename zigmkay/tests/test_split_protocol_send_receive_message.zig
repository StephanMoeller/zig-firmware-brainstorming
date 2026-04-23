const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const p = zigmkay.split_protocol;

const std = @import("std");

test "receiveMessage - no data" {
    var uart_helper = p.UartReceiveHelper{};
    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(null, msg);
}

test "receiveMessage - non-delimiters and then no new message" {
    var uart_helper = p.UartReceiveHelper{};
    try uart_helper.byte_queue.enqueue(40);
    try uart_helper.byte_queue.enqueue(41);
    try uart_helper.byte_queue.enqueue(42);

    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - delimiter, then no more data" {
    var uart_helper = p.UartReceiveHelper{};
    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - delimiter, then one more delimiter" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(p.DELIMITER);

    var uart_helper = p.UartReceiveHelper{};
    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - delimiter, then message_type, then no more data" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(1);

    var uart_helper = p.UartReceiveHelper{};
    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - delimiter, then message_type, then delimiter again" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(1);
    try input_data.enqueue(p.DELIMITER);

    var uart_helper = p.UartReceiveHelper{};
    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - KeyPressed example" {
    var uart_helper = p.UartReceiveHelper{};
    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(1); // key pressed message type
    try uart_helper.byte_queue.enqueue(54);

    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 54 }, msg);
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - KeyReleased example" {
    var uart_helper = p.UartReceiveHelper{};

    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(2); // key released message type
    try uart_helper.byte_queue.enqueue(54);

    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 54 }, msg);
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - EncoderValueChanged example" {
    var uart_helper = p.UartReceiveHelper{};

    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(3); // key released message type
    try uart_helper.byte_queue.enqueue(2); // encoder value

    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 2 }, msg);
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - EncoderValueChanged example, payload exceeding a u2" {
    var uart_helper = p.UartReceiveHelper{};

    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(3); // key released message type
    try uart_helper.byte_queue.enqueue(5); // invalid encoder value

    const msg = uart_helper.receiveMessage();
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - Mixed data" {
    var uart_helper = p.UartReceiveHelper{};
    // key pressed
    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(1); // key pressed
    try uart_helper.byte_queue.enqueue(111); // key index

    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(2); // key released
    try uart_helper.byte_queue.enqueue(112); // key index
    //
    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(3); // encoder val changed
    try uart_helper.byte_queue.enqueue(1); // value

    try std.testing.expectEqual(9, uart_helper.byte_queue.Count());
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 111 }, uart_helper.receiveMessage());
    try std.testing.expectEqual(6, uart_helper.byte_queue.Count());
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 112 }, uart_helper.receiveMessage());
    try std.testing.expectEqual(3, uart_helper.byte_queue.Count());
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 1 }, uart_helper.receiveMessage());
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "receiveMessage - Mixed data - with errors in it" {
    var uart_helper = p.UartReceiveHelper{};
    // VALID
    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(1); // key pressed
    try uart_helper.byte_queue.enqueue(111); // key index

    // INVALID
    try uart_helper.byte_queue.enqueue(111); // key index
    try uart_helper.byte_queue.enqueue(p.DELIMITER);

    // VALID
    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(2); // key released
    try uart_helper.byte_queue.enqueue(112); // key index

    // INVALID
    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(112);

    // VALID
    try uart_helper.byte_queue.enqueue(p.DELIMITER);
    try uart_helper.byte_queue.enqueue(3); // encoder val changed
    try uart_helper.byte_queue.enqueue(1); // value
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 111 }, uart_helper.receiveMessage());
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 112 }, uart_helper.receiveMessage());
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 1 }, uart_helper.receiveMessage());
    try std.testing.expectEqual(0, uart_helper.byte_queue.Count());
}

test "sendMessage/receive - KeyPressed example" {
    var uart_receiver = p.UartReceiveHelper{};
    var uart_sender = p.UartSendHelper{};

    try uart_sender.sendMessage(p.ProtocolMessage{ .KeyPressed = 54 });
    try move_from_to(&uart_sender.byte_queue, &uart_receiver.byte_queue);
    const msg = uart_receiver.receiveMessage();
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 54 }, msg);
}

test "sendMessage/receive - KeyReleased example" {
    var uart_receiver = p.UartReceiveHelper{};
    var uart_sender = p.UartSendHelper{};
    try uart_sender.sendMessage(p.ProtocolMessage{ .KeyReleased = 54 });
    try move_from_to(&uart_sender.byte_queue, &uart_receiver.byte_queue);

    const msg = uart_receiver.receiveMessage();
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 54 }, msg);
}

test "sendMessage/receive - EncoderValueChanged example" {
    var uart_receiver = p.UartReceiveHelper{};
    var uart_sender = p.UartSendHelper{};
    try uart_sender.sendMessage(p.ProtocolMessage{ .EncoderValueChanged = 2 });
    try move_from_to(&uart_sender.byte_queue, &uart_receiver.byte_queue);
    const msg = uart_receiver.receiveMessage();
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 2 }, msg);
}

test "sendMessage/receive - multiple values example" {
    var uart_receiver = p.UartReceiveHelper{};
    var uart_sender = p.UartSendHelper{};
    try uart_sender.sendMessage(p.ProtocolMessage{ .KeyPressed = 20 });
    try uart_sender.sendMessage(p.ProtocolMessage{ .KeyReleased = 100 });
    try uart_sender.byte_queue.enqueue(p.DELIMITER); // add some noise!
    try uart_sender.sendMessage(p.ProtocolMessage{ .EncoderValueChanged = 2 });

    try move_from_to(&uart_sender.byte_queue, &uart_receiver.byte_queue);

    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 20 }, uart_receiver.receiveMessage());
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 100 }, uart_receiver.receiveMessage());
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 2 }, uart_receiver.receiveMessage());
    try std.testing.expectEqual(null, uart_receiver.receiveMessage());
}

test "sendMessage/receive - reading mid-message - expect resumed at next read call" {
    var uart_receiver = p.UartReceiveHelper{};
    var uart_sender = p.UartSendHelper{};

    try uart_sender.byte_queue.enqueue(p.DELIMITER);
    try uart_sender.byte_queue.enqueue(1); // key pressed

    try move_from_to(&uart_sender.byte_queue, &uart_receiver.byte_queue);
    try std.testing.expectEqual(null, uart_receiver.receiveMessage());

    try uart_sender.byte_queue.enqueue(111); // key index
    try move_from_to(&uart_sender.byte_queue, &uart_receiver.byte_queue);

    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 111 }, uart_receiver.receiveMessage());
}

fn move_from_to(from: *p.ByteQueue, to: *p.ByteQueue) !void {
    while (true) {
        const val: u8 = from.dequeue() catch return;
        try to.enqueue(val);
    }
}
