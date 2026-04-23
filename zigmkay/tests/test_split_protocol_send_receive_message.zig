const zigmkay = @import("zigmkay");
const core = zigmkay.core;
const p = zigmkay.split_protocol;

const std = @import("std");

test "receiveMessage - no data" {
    var input_data = p.ByteQueue.Create();

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(null, msg);
}

test "receiveMessage - non-delimiters and then no new message" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(40);
    try input_data.enqueue(41);
    try input_data.enqueue(42);

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - delimiter, then no more data" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - delimiter, then one more delimiter" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(p.DELIMITER);

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - delimiter, then message_type, then no more data" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(1);

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - delimiter, then message_type, then delimiter again" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(1);
    try input_data.enqueue(p.DELIMITER);

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - KeyPressed example" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(1); // key pressed message type
    try input_data.enqueue(54);

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 54 }, msg);
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - KeyReleased example" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(2); // key released message type
    try input_data.enqueue(54);

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 54 }, msg);
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - EncoderValueChanged example" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(3); // key released message type
    try input_data.enqueue(2); // encoder value

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 2 }, msg);
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - EncoderValueChanged example, payload exceeding a u2" {
    var input_data = p.ByteQueue.Create();
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(3); // key released message type
    try input_data.enqueue(5); // invalid encoder value

    var uart_helper = p.UartHelper{};
    const msg = uart_helper.receiveMessage(&input_data);
    try std.testing.expectEqual(null, msg);
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - Mixed data" {
    var input_data = p.ByteQueue.Create();

    // key pressed
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(1); // key pressed
    try input_data.enqueue(111); // key index

    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(2); // key released
    try input_data.enqueue(112); // key index
    //
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(3); // encoder val changed
    try input_data.enqueue(1); // value

    var uart_helper = p.UartHelper{};

    try std.testing.expectEqual(9, input_data.Count());
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 111 }, uart_helper.receiveMessage(&input_data));
    try std.testing.expectEqual(6, input_data.Count());
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 112 }, uart_helper.receiveMessage(&input_data));
    try std.testing.expectEqual(3, input_data.Count());
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 1 }, uart_helper.receiveMessage(&input_data));
    try std.testing.expectEqual(0, input_data.Count());
}

test "receiveMessage - Mixed data - with errors in it" {
    var input_data = p.ByteQueue.Create();

    // VALID
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(1); // key pressed
    try input_data.enqueue(111); // key index

    // INVALID
    try input_data.enqueue(111); // key index
    try input_data.enqueue(p.DELIMITER);

    // VALID
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(2); // key released
    try input_data.enqueue(112); // key index

    // INVALID
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(112);

    // VALID
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(3); // encoder val changed
    try input_data.enqueue(1); // value
    var uart_helper = p.UartHelper{};
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 111 }, uart_helper.receiveMessage(&input_data));
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 112 }, uart_helper.receiveMessage(&input_data));
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 1 }, uart_helper.receiveMessage(&input_data));
    try std.testing.expectEqual(0, input_data.Count());
}

test "sendMessage/receive - KeyPressed example" {
    var queue = p.ByteQueue.Create();

    var uart_helper = p.UartHelper{};
    try uart_helper.sendMessage(&queue, p.ProtocolMessage{ .KeyPressed = 54 });
    const msg = uart_helper.receiveMessage(&queue);
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 54 }, msg);
}

test "sendMessage/receive - KeyReleased example" {
    var queue = p.ByteQueue.Create();
    var uart_helper = p.UartHelper{};
    try uart_helper.sendMessage(&queue, p.ProtocolMessage{ .KeyReleased = 54 });
    const msg = uart_helper.receiveMessage(&queue);
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 54 }, msg);
}

test "sendMessage/receive - EncoderValueChanged example" {
    var queue = p.ByteQueue.Create();
    var uart_helper = p.UartHelper{};
    try uart_helper.sendMessage(&queue, p.ProtocolMessage{ .EncoderValueChanged = 2 });
    const msg = uart_helper.receiveMessage(&queue);
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 2 }, msg);
}

test "sendMessage/receive - multiple values example" {
    var queue = p.ByteQueue.Create();

    var uart_helper = p.UartHelper{};
    try uart_helper.sendMessage(&queue, p.ProtocolMessage{ .KeyPressed = 20 });
    try uart_helper.sendMessage(&queue, p.ProtocolMessage{ .KeyReleased = 100 });
    try queue.enqueue(p.DELIMITER); // add some noise!
    try uart_helper.sendMessage(&queue, p.ProtocolMessage{ .EncoderValueChanged = 2 });
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 20 }, uart_helper.receiveMessage(&queue));
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyReleased = 100 }, uart_helper.receiveMessage(&queue));
    try std.testing.expectEqual(p.ProtocolMessage{ .EncoderValueChanged = 2 }, uart_helper.receiveMessage(&queue));
    try std.testing.expectEqual(null, uart_helper.receiveMessage(&queue));
}

test "sendMessage/receive - reading mid-message - expect resumed at next read call" {
    var input_data = p.ByteQueue.Create();
    var uart_helper = p.UartHelper{};
    try input_data.enqueue(p.DELIMITER);
    try input_data.enqueue(1); // key pressed
    try std.testing.expectEqual(null, uart_helper.receiveMessage(&input_data));

    try input_data.enqueue(111); // key index
    try std.testing.expectEqual(p.ProtocolMessage{ .KeyPressed = 111 }, uart_helper.receiveMessage(&input_data));
}
