pub const core = @import("core.zig");
pub const matrix_scanning = @import("matrix_scanning.zig");
pub const processing = @import("processing.zig");
pub const usb = @import("usb_command_executor.zig");
pub const encoder = @import("encoder.zig");

const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

/// Initializes and runs the primary half of the split keyboard (or a unibody keyboard).
/// The `encoder_pins_or_null` parameter optionally defines the two GPIO pins [A, B] for a hardware rotary encoder.
pub fn run_primary(
    comptime dimensions: core.KeymapDimensions,
    comptime pin_cols: []const rp2xxx.gpio.Pin,
    comptime pin_rows: []const rp2xxx.gpio.Pin,
    comptime scanner_settings: matrix_scanning.ScannerSettings,
    comptime combos: []const core.Combo2Def,
    comptime custom_functions: *const core.CustomFunctions,
    comptime pin_mappings: [dimensions.key_count]?[2]usize,
    comptime keymap: *const [dimensions.layer_count][dimensions.key_count]core.KeyDef,
    comptime side_definition: [dimensions.key_count]core.Side,
    uart_or_null: ?rp2xxx.uart.UART,
    encoder_pins_or_null: ?[2]rp2xxx.gpio.Pin,
) !void {
    // Data queues
    var matrix_change_queue = core.MatrixStateChangeQueue.Create();
    var usb_command_queue = core.OutputCommandQueue.Create();

    // Matrix scanning
    const matrix_scanner = matrix_scanning.CreateMatrixScannerType(dimensions, pin_cols, pin_rows, pin_mappings, scanner_settings){};

    // Encoder
    var kb_encoder: ?encoder.Encoder = if (encoder_pins_or_null) |pins| encoder.Encoder.init(pins[0], pins[1]) else null;

    // PRIMARY HALF
    // Processing
    var processor = processing.CreateProcessorType(
        dimensions,
        keymap,
        side_definition,
        combos,
        custom_functions,
    ){
        .input_matrix_changes = &matrix_change_queue,
        .output_usb_commands = &usb_command_queue,
    };

    // Pre-calculate encoder indices at comptime
    const encoder_indices = comptime blk: {
        var cw: ?core.KeyIndex = null;
        var ccw: ?core.KeyIndex = null;
        for (side_definition, 0..) |side, i| {
            if (side == .E) {
                if (cw == null) {
                    cw = @intCast(i);
                } else if (ccw == null) {
                    ccw = @intCast(i);
                    break;
                }
            }
        }
        break :blk .{ .cw = cw, .ccw = ccw };
    };

    // USB events
    const usb_command_executor = usb.CreateAndInitUsbCommandExecutor();
    while (true) {
        const current_time = core.TimeSinceBoot{ .time_since_boot_us = time.get_time_since_boot().to_us() };

        // Scan local matrix changes
        try matrix_scanner.DetectKeyboardChanges(&matrix_change_queue, current_time);

        // Poll encoder hardware and feed rotation events into the main processing pipeline
        if (kb_encoder) |*enc| {
            if (enc.update()) |event| {
                const key_index = if (event.direction == .CW) encoder_indices.cw else encoder_indices.ccw;
                if (key_index) |idx| {
                    try processor.ProcessEncoderEvent(idx, current_time);
                }
            }
        }

        // if uart specified, we are dealing with a primary half of a split keyboard
        if (uart_or_null) |uart| {
            // Receive remote changes as well
            const byte_or_null: ?u8 = uart.read_word() catch blk: {
                uart.clear_errors();
                break :blk null;
            };

            if (byte_or_null) |byte| {
                const uart_message = core.UartMessage.fromByte(byte);
                try matrix_change_queue.enqueue(core.MatrixStateChange{ .pressed = uart_message.pressed, .key_index = uart_message.key_index, .time = current_time });
            }
        }

        // Processing: decide actions
        try processor.Process(current_time);

        // Execute actions: send usb commands to the host
        try usb_command_executor.HouseKeepAndProcessCommands(&usb_command_queue, current_time);

        // todo: put this logic inside usb command executor and make a keycode to trigger it

    }
}

pub fn run_secondary(
    comptime dimensions: core.KeymapDimensions,
    comptime pin_cols: []const rp2xxx.gpio.Pin,
    comptime pin_rows: []const rp2xxx.gpio.Pin,
    comptime scanner_settings: matrix_scanning.ScannerSettings,
    comptime pin_mappings: [dimensions.key_count]?[2]usize,
    uart: rp2xxx.uart.UART,
) !void {

    // Data queues
    var matrix_change_queue = core.MatrixStateChangeQueue.Create();

    // Matrix scanning
    const matrix_scanner = matrix_scanning.CreateMatrixScannerType(dimensions, pin_cols, pin_rows, pin_mappings, scanner_settings){};

    // SECONDARY HALF
    var uart_send_buffer: [1]u8 = .{0};
    while (true) {
        const current_time = core.TimeSinceBoot{ .time_since_boot_us = time.get_time_since_boot().to_us() };
        // Scan local matrix changes
        try matrix_scanner.DetectKeyboardChanges(&matrix_change_queue, current_time);

        if (matrix_change_queue.Count() > 0) {
            const change = try matrix_change_queue.dequeue();
            const msg = core.UartMessage{ .pressed = change.pressed, .key_index = change.key_index };
            uart_send_buffer[0] = msg.toByte();

            // Tries to write one byte with 100ms timeout
            uart.write_blocking(&uart_send_buffer, microzig.drivers.time.Duration.from_ms(100)) catch {
                uart.clear_errors();
            };
        }
    }
}
