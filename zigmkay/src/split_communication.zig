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

pub const UartClient = union(enum) {
    uart: rp2xxx.uart.UART,
    pub fn send_blocking(self: *const UartClient, data: u8) !void {
        const uart_send_buffer = [1]u8{data};
        self.uart.write_blocking(&uart_send_buffer, microzig.drivers.time.Deadline{ .timeout = microzig.drivers.time.Absolute.from_us(100 * 1000) }) catch |e| {
            self.uart.clear_errors();
            return e;
        };
    }
    pub fn receive_byte_or_null(self: *const UartClient) ?u8 {
        if (self.uart.read_word() catch {
            self.uart.clear_errors();
            return null;
        }) |byte| {
            return byte;
        } else {
            return null;
        }
    }
};
