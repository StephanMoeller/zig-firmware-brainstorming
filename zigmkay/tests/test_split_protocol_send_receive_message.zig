const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const p = zigmkay.split_protocol;

const std = @import("std");

test "receiveMessage - non-delimiters and then no new message" {
    var uart_helper = p.UartReceiveHelper{};
    try std.testing.expectEqual(null, uart_helper.receiveByte(40));
    try std.testing.expectEqual(null, uart_helper.receiveByte(41));
    try std.testing.expectEqual(null, uart_helper.receiveByte(42));
}

test "receiveMessage - delimiter, then no more data" {
    var uart_helper = p.UartReceiveHelper{};
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
}

test "receiveMessage - delimiter, then one more delimiter" {
    var uart_helper = p.UartReceiveHelper{};
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
}

test "receiveMessage - KeyPressed example" {
    var uart_helper = p.UartReceiveHelper{};
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(1)); // key pressed message type
    const msg = uart_helper.receiveByte(54);
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 54 }, msg);
}

test "receiveMessage - KeyReleased example" {
    var uart_helper = p.UartReceiveHelper{};
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER)); // key released message type
    try std.testing.expectEqual(null, uart_helper.receiveByte(2));
    const msg = uart_helper.receiveByte(54);
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 54 }, msg);
}

test "receiveMessage - EncoderValueChanged example" {
    var uart_helper = p.UartReceiveHelper{};
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER)); // EncoderValueChanged message type
    try std.testing.expectEqual(null, uart_helper.receiveByte(3));
    const msg = uart_helper.receiveByte(2);
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 2 }, msg);
}

test "receiveMessage - EncoderValueChanged example, payload exceeding a u2" {
    var uart_helper = p.UartReceiveHelper{};

    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(3)); // key released message type
    try std.testing.expectEqual(null, uart_helper.receiveByte(5)); // invalid encoder value
}

test "receiveMessage - Mixed data" {
    var uart_helper = p.UartReceiveHelper{};

    // key pressed
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(1)); // key pressed
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 111 }, uart_helper.receiveByte(111));

    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(2)); // key released
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 112 }, uart_helper.receiveByte(112));

    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(3)); // encoder val changed
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 1 }, uart_helper.receiveByte(1)); // key index
}

test "receiveMessage - Mixed data - with errors in it" {
    var uart_helper = p.UartReceiveHelper{};
    // VALID
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(1)); // key pressed
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 111 }, uart_helper.receiveByte(111));

    // INVALID
    try std.testing.expectEqual(null, uart_helper.receiveByte(111)); // key index
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));

    // VALID
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(2)); // key released
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 112 }, uart_helper.receiveByte(112));

    // INVALID
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(112));

    // VALID
    try std.testing.expectEqual(null, uart_helper.receiveByte(p.DELIMITER));
    try std.testing.expectEqual(null, uart_helper.receiveByte(3)); // encoder val changed
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 1 }, uart_helper.receiveByte(1));
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
