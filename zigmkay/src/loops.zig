pub const split_protocol = @import("split_protocol.zig");
pub const generic_queue = @import("generic_queue.zig");
pub const core = @import("core.zig");
pub const matrix_scanning = @import("matrix_scanning.zig");
pub const processing = @import("processing.zig");
pub const usb = @import("usb_command_executor.zig");
pub const encoder = @import("encoder.zig");

const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

pub fn GetConfigType(comptime dimensions: *const core.KeymapDimensions) type {
    return struct {
        const Self = @This();

        _keymap_defined: bool = false,
        _pins_defined: bool = false,

        dimensions: *const core.KeymapDimensions,

        keymap: *const [dimensions.layer_count][dimensions.key_count]core.KeyDef = undefined,
        pin_mappings: *const [dimensions.key_count]?[2]usize = undefined,
        pin_cols: []const rp2xxx.gpio.Pin = undefined,
        pin_rows: []const rp2xxx.gpio.Pin = undefined,

        combos: []const core.Combo2Def = &.{},
        scanner_settings: *const matrix_scanning.ScannerSettings = &.{},
        custom_functions: *const core.CustomFunctions = &core.CustomFunctions{
            .on_event = null,
        },
        side_definition: *const [dimensions.key_count]core.Side = &[_]core.Side{core.Side.X} ** dimensions.key_count,
        pub fn init() Self {
            return .{
                .dimensions = dimensions,
            };
        }

        pub fn set_pins(comptime self: *Self, pin_cols: []const rp2xxx.gpio.Pin, pin_rows: []const rp2xxx.gpio.Pin, pin_mappings: *const [dimensions.key_count]?[2]usize) void {
            self.pin_cols = pin_cols;
            self.pin_rows = pin_rows;
            self.pin_mappings = pin_mappings;
            self._pins_defined = true;
        }

        pub fn set_keymap(comptime self: *Self, keymap: *const [dimensions.layer_count][dimensions.key_count]core.KeyDef) void {
            self.keymap = keymap;
            self._keymap_defined = true;
        }

        pub fn set_combos(comptime self: *Self, combos: []const core.Combo2Def) void {
            self.combos = combos;
        }

        pub fn set_scanner_settings(comptime self: *Self, scanner_settings: *const matrix_scanning.ScannerSettings) void {
            self.scanner_settings = scanner_settings;
        }

        pub fn set_custom_functions(comptime self: *Self, custom_functions: *const core.CustomFunctions) void {
            self.custom_functions = custom_functions;
        }
        pub fn set_side_definitions(comptime self: *Self, side_definition: *const [dimensions.key_count]core.Side) void {
            self.side_definition = side_definition;
        }

        pub fn build(comptime self: Self) Runner {
            if (self._keymap_defined == false) {
                @compileError(std.fmt.comptimePrint("set_keymap must be calld on the config prior to calling run", .{}));
            }
            if (self._pins_defined == false) {
                @compileError(std.fmt.comptimePrint("set_pins must be calld on the config prior to calling run", .{}));
            }

            return Runner{ .config = self };
        }

        pub const Runner = struct {
            config: Self,
            pub fn run_unibody(comptime self: Runner) !void {
                try run_primary_internal(self.config.dimensions, self.config, null);
            }

            pub fn run_primary(comptime self: Runner, uart: rp2xxx.uart.UART) !void {
                try run_primary_internal(self.config.dimensions, self.config, uart);
            }

            pub fn run_secondary(comptime self: Runner, uart: rp2xxx.uart.UART) !void {
                try run_secondary_internal(self.config.dimensions, self.config, uart);
            }
        };
    };
}

pub fn run_primary_internal(
    comptime dimensions: *const core.KeymapDimensions,
    comptime config: GetConfigType(dimensions),
    uart_or_null: ?rp2xxx.uart.UART,
) !void {
    // Data queues
    var matrix_change_queue = core.MatrixStateChangeQueue.Create();
    var usb_command_queue = core.OutputCommandQueue.Create();

    // Matrix scanning
    const matrix_scanner = comptime matrix_scanning.CreateMatrixScannerType(dimensions, config.pin_cols, config.pin_rows, config.pin_mappings, config.scanner_settings){};

    // Processing
    var processor = processing.CreateProcessorType(dimensions, config.keymap, config.side_definition, config.combos, config.custom_functions){
        .input_matrix_changes = &matrix_change_queue,
        .output_usb_commands = &usb_command_queue,
    };

    // uart byte queue
    var uart_receiver = split_protocol.UartReceiveHelper{};

    // USB events
    const usb_command_executor = usb.CreateAndInitUsbCommandExecutor();
    while (true) {
        // Detect local changes
        const current_time = core.TimeSinceBoot{ .time_since_boot_us = time.get_time_since_boot().to_us() };
        try matrix_scanner.DetectKeyboardChanges(&matrix_change_queue, current_time); // Scan local matrix changes

        // Receive from remote side
        if (uart_or_null) |uart| {
            try receive_from_uart_to_queue(&uart, &uart_receiver.byte_queue);
            if (uart_receiver.receiveMessage(&uart_receiver.byte_queue)) |msg| {
                switch (msg) {
                    .KeyPressed => |key_index| {
                        try matrix_change_queue.enqueue(.{ .key_index = key_index, .pressed = true, .time = current_time });
                    },
                    .KeyReleased => |key_index| {
                        try matrix_change_queue.enqueue(.{ .key_index = key_index, .pressed = false, .time = current_time });
                    },
                    .EncoderValueChanged => {},
                }
            }
        }

        // Processing: decide actions
        try processor.Process(current_time);

        // Execute actions: send usb commands to the host
        try usb_command_executor.HouseKeepAndProcessCommands(&usb_command_queue, current_time);
    }
}

pub fn run_secondary_internal(
    comptime dimensions: *const core.KeymapDimensions,
    comptime config: GetConfigType(dimensions),
    uart: rp2xxx.uart.UART,
) !void {
    var matrix_change_queue = core.MatrixStateChangeQueue.Create();
    const matrix_scanner = comptime matrix_scanning.CreateMatrixScannerType(dimensions, config.pin_cols, config.pin_rows, config.pin_mappings, config.scanner_settings){};

    var uart_sender = split_protocol.UartSendHelper{};
    while (true) {
        const current_time = core.TimeSinceBoot{ .time_since_boot_us = time.get_time_since_boot().to_us() };

        // Detect local changes
        try matrix_scanner.DetectKeyboardChanges(&matrix_change_queue, current_time);

        // Send to primary side
        while (matrix_change_queue.Count() > 0) {
            const matrix_change = try matrix_change_queue.dequeue();
            if (matrix_change.pressed) {
                try uart_sender.sendMessage(&uart_sender.byte_queue, .{ .KeyPressed = matrix_change.key_index });
            } else {
                try uart_sender.sendMessage(&uart_sender.byte_queue, .{ .KeyReleased = matrix_change.key_index });
            }

            try send_from_queue_to_uart(&uart, &uart_sender.byte_queue);
        }
    }
}

pub fn receive_from_uart_to_queue(uart: *const rp2xxx.uart.UART, buffer: *split_protocol.ByteQueue) !void {
    while (uart.read_word() catch {
        uart.clear_errors();
        return;
    }) |byte| {
        try buffer.enqueue(byte);
    }
}

pub fn send_from_queue_to_uart(uart: *const rp2xxx.uart.UART, buffer: *split_protocol.ByteQueue) !void {
    while (buffer.Count() > 0) {
        const uart_send_buffer = [1]u8{try buffer.dequeue()};
        uart.write_blocking(&uart_send_buffer, microzig.drivers.time.Deadline{ .timeout = microzig.drivers.time.Absolute.from_us(100 * 1000) }) catch {
            uart.clear_errors();
        };
    }
}
