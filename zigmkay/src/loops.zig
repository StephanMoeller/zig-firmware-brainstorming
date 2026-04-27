pub const split_protocol = @import("split_protocol.zig");
pub const generic_queue = @import("generic_queue.zig");
pub const core = @import("core.zig");
pub const processing = @import("processing.zig");
pub const usb = @import("usb_command_executor.zig");

pub const matrix_scanning = @import("matrix_scanning.zig");
pub const encoder_scanning = @import("encoder_scanning.zig");

const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

pub fn GetPrimarySideConfigType(comptime dimensions: *const core.KeymapDimensions) type {
    return struct {
        const Self = @This();

        dimensions: *const core.KeymapDimensions = dimensions,

        // Mandatory
        keymap: *const [dimensions.layer_count][dimensions.key_count]core.KeyDef,
        pin_mappings: *const [dimensions.key_count]?[2]usize,
        pin_cols: []const rp2xxx.gpio.Pin,
        pin_rows: []const rp2xxx.gpio.Pin,

        // Extras (both sides)
        scanner_settings: *const matrix_scanning.ScannerSettings = &.{},

        // Extras (primary side only)
        combos: []const core.Combo2Def = &.{},
        custom_functions: *const core.CustomFunctions = &core.CustomFunctions{
            .on_event = null,
        },
        side_definition: *const [dimensions.key_count]core.Side = &[_]core.Side{core.Side.X} ** dimensions.key_count,
        encoder_configs: []encoder_scanning.EncoderConfig = &.{},

        pub fn build(comptime self: Self) Runner {
            return Runner{ .config = self };
        }

        pub const Runner = struct {
            config: Self,
            pub fn run_unibody(comptime self: Runner) !void {
                try self.run_primary_internal(null);
            }

            pub fn run_primary(comptime self: Runner, uart: rp2xxx.uart.UART) !void {
                try self.run_primary_internal(uart);
            }

            fn run_primary_internal(
                comptime self: Runner,
                uart_or_null: ?rp2xxx.uart.UART,
            ) !void {
                const config = self.config;

                // Data queues
                var matrix_change_queue = core.MatrixStateChangeQueue.Create();
                var encoder_change_queue = core.EncoderEventQueue.Create();
                var usb_command_queue = core.OutputCommandQueue.Create();

                // Input scanning
                const matrix_scanner = comptime matrix_scanning.CreateMatrixScannerType(dimensions, config.pin_cols, config.pin_rows, config.pin_mappings, config.scanner_settings){};
                var encoder_scanner = comptime encoder_scanning.CreateEncoderScannerType(config.encoder_configs){};

                // Processing
                var processor = processing.CreateProcessorType(dimensions, config.keymap, config.side_definition, config.combos, config.custom_functions){
                    .input_matrix_changes = &matrix_change_queue,
                    .output_usb_commands = &usb_command_queue,
                    .encoder_event_changes = &encoder_change_queue,
                };

                // uart byte queue
                var uart_receiver = split_protocol.UartReceiveHelper{};

                // USB events
                const usb_command_executor = usb.CreateAndInitUsbCommandExecutor();
                while (true) {
                    // Detect local changes
                    const current_time = core.TimeSinceBoot{ .time_since_boot_us = time.get_time_since_boot().to_us() };
                    try matrix_scanner.DetectKeyboardChanges(&matrix_change_queue, current_time); // Scan local matrix changes
                    try encoder_scanner.detectEncoderChanges(&encoder_change_queue, current_time);

                    // Receive from remote side
                    if (uart_or_null) |uart| {
                        try receive_from_uart_to_queue(&uart, &uart_receiver, &matrix_change_queue, current_time);
                    }

                    // Processing: decide actions
                    try processor.Process(current_time);

                    // Execute actions: send usb commands to the host
                    try usb_command_executor.HouseKeepAndProcessCommands(&usb_command_queue, current_time);
                }
            }
        };
    };
}

pub fn GetSecondarySideConfigType(comptime dimensions: *const core.KeymapDimensions) type {
    return struct {
        const Self = @This();

        dimensions: *const core.KeymapDimensions = dimensions,

        // Mandatory
        keymap: *const [dimensions.layer_count][dimensions.key_count]core.KeyDef,
        pin_mappings: *const [dimensions.key_count]?[2]usize,
        pin_cols: []const rp2xxx.gpio.Pin,
        pin_rows: []const rp2xxx.gpio.Pin,

        // Extras (both sides)
        scanner_settings: *const matrix_scanning.ScannerSettings = &.{},

        pub fn build(comptime self: Self) Runner {
            return Runner{ .config = self };
        }

        pub const Runner = struct {
            config: Self,

            pub fn run_secondary(comptime self: Runner, uart: rp2xxx.uart.UART) !void {
                try self.run_secondary_internal(uart);
            }

            fn run_secondary_internal(
                comptime self: Runner,
                uart: rp2xxx.uart.UART,
            ) !void {
                const config = self.config;
                var matrix_change_queue = core.MatrixStateChangeQueue.Create();
                const matrix_scanner = comptime matrix_scanning.CreateMatrixScannerType(dimensions, config.pin_cols, config.pin_rows, config.pin_mappings, config.scanner_settings){};

                var uart_sender = split_protocol.UartSendHelper{};
                while (true) {
                    const current_time = core.TimeSinceBoot{ .time_since_boot_us = time.get_time_since_boot().to_us() };

                    // Detect local changes
                    try matrix_scanner.DetectKeyboardChanges(&matrix_change_queue, current_time);

                    // Send to primary side
                    try send_from_queue_to_uart(&uart, &uart_sender, &matrix_change_queue);
                }
            }
        };
    };
}

pub fn receive_from_uart_to_queue(uart: *const rp2xxx.uart.UART, receiver: *split_protocol.UartReceiveHelper, matrix_change_queue: *core.MatrixStateChangeQueue, current_time: core.TimeSinceBoot) !void {
    while (uart.read_word() catch {
        uart.clear_errors();
        return;
    }) |byte| {
        if (receiver.receiveByte(byte)) |msg| {
            switch (msg) {
                .MatrixStateChange => |e| {
                    try matrix_change_queue.enqueue(.{ .key_index = e.key_index, .pressed = e.pressed, .time = current_time });
                },
                .EncoderValueChanged => {},
            }
        }
    }
}

pub fn send_from_queue_to_uart(uart: *const rp2xxx.uart.UART, uart_sender: *split_protocol.UartSendHelper, matrix_change_queue: *core.MatrixStateChangeQueue) !void {
    while (matrix_change_queue.dequeue()) |matrix_change| {
        try uart_sender.sendMessage(.{ .MatrixStateChange = .{ .key_index = matrix_change.key_index, .pressed = matrix_change.pressed } });

        while (uart_sender.byte_queue.dequeue()) |msg| {
            const uart_send_buffer = [1]u8{msg};
            uart.write_blocking(&uart_send_buffer, microzig.drivers.time.Deadline{ .timeout = microzig.drivers.time.Absolute.from_us(100 * 1000) }) catch {
                uart.clear_errors();
            };
        }
    }
}
