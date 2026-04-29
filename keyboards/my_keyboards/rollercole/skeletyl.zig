const std = @import("std");

const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const rollercole_shared_keymap = @import("shared_keymap.zig");
const zigmkay = @import("zigmkay");
const zkeycodes = @import("zkeycodes");
const keymap = @import("skeletyl_keymap.zig");

// uart
const uart_rx_pin = gpio.num(1);
// zig fmt: off

pub const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO17 = .{ .name = "led", .direction = .out },
    .GPIO19 = .{ .name = "usb_detection", .direction = .in, .pull = .down },

    .GPIO28 = .{ .name = "col0", .direction = .in },
    .GPIO21 = .{ .name = "col1", .direction = .in },
    .GPIO6 = .{ .name = "col2", .direction = .in },
    .GPIO7 = .{ .name = "col3", .direction = .in },
    .GPIO8 = .{ .name = "col4", .direction = .in },

    .GPIO26 = .{ .name = "row0", .direction = .out },
    .GPIO5 = .{ .name = "row1", .direction = .out },
    .GPIO4 = .{ .name = "row2", .direction = .out },
    .GPIO9 = .{ .name = "row3", .direction = .out },
};
pub const p = blk: {
    @setEvalBranchQuota(10_000);
    break :blk pin_config.pins();
};

pub const pin_mappings_right = [keymap.key_count]?[2]usize{
   null, null, null, null, null,  .{4,0},.{3,0},.{2,0},.{1,0},.{0,0},
   null, null, null, null, null,  .{4,1},.{3,1},.{2,1},.{1,1},.{0,1},
   null, null, null, null, null,  .{4,2},.{3,2},.{2,2},.{1,2},.{0,2},
               null, null, null,  .{4,3},.{3,3},.{2,3}
};

pub const pin_mappings_left = [keymap.key_count]?[2]usize{
     .{0,0},.{1,0},.{2,0},.{3,0},.{4,0},        null, null, null, null, null,
     .{0,1},.{1,1},.{2,1},.{3,1},.{4,1},        null, null, null, null, null,
     .{0,2},.{1,2},.{2,2},.{3,2},.{4,2},        null, null, null, null, null,
                   .{0,3},.{1,3},.{2,3},        null, null, null,
};



// zig fmt: on
pub const pin_cols = [_]rp2xxx.gpio.Pin{ p.col0, p.col1, p.col2, p.col3, p.col4 };
pub const pin_rows = [_]rp2xxx.gpio.Pin{ p.row0, p.row1, p.row2, p.row3 };

pub fn main() !void {
    _ = pin_config.apply();

    const primary = check_is_primary_side();

    if (primary) {
        blink_led(3, 200); // Show the user that the keyboard has actually booted up.
        var uart = init_uart();
        comptime var config = zigmkay.loops.GetPrimarySideConfigType(&keymap.dimensions){
            .config = .{
                .keymap = &keymap.keymap,
                .scanner_settings = &.{
                    .matrix = .{
                        .debounce = .{ .ms = 50 },
                        .pin_cols = pin_cols[0..],
                        .pin_rows = pin_rows[0..],
                        .pins_to_keys_mapping = &pin_mappings_right,
                        .direction = .row2col,
                    },
                },
            },
        };

        comptime var runner = config.build();
        runner.run_primary(&uart) catch {
            blink_led(10000000, 500); // in case of an error, let the keyboard start blinking
        };
    } else {
        blink_led(1, 1000); // Show the user that the keyboard has actually booted up.
        var uart = init_pio_uart();
        comptime var config = zigmkay.loops.GetSecondarySideConfigType(&keymap.dimensions){
            .config = .{
                .scanner_settings = &.{
                    .matrix = .{
                        .debounce = .{ .ms = 50 },
                        .pin_cols = pin_cols[0..],
                        .pin_rows = pin_rows[0..],
                        .pins_to_keys_mapping = &pin_mappings_left,
                        .direction = .row2col,
                    },
                },
            },
        };

        comptime var runner = config.build();
        runner.run_secondary(&uart) catch {
            blink_led(10000000, 500); // in case of an error, let the keyboard start blinking
        };
    }
}
pub fn check_is_primary_side() bool {
    const usb_detect_pin = gpio.num(19);
    usb_detect_pin.set_function(.sio);
    usb_detect_pin.set_direction(.in);
    usb_detect_pin.set_pull(.down);
    time.sleep_ms(1);
    const primary = usb_detect_pin.read() == 1;
    return primary;
}

pub fn init_uart() zigmkay.split_communication.UartClient {
    // Primary side: GPIO1 is UART0 RX only (hardwired in RP2040 silicon)
    uart_rx_pin.set_function(.uart);
    const uart = rp2xxx.uart.instance.num(0);
    uart.apply(.{ .clock_config = rp2xxx.clock_config, .baud_rate = 9600 });
    return zigmkay.split_communication.UartClient{ .uart = uart };
}

pub fn init_pio_uart() zigmkay.split_communication.UartClient {
    // Secondary side: PIO TX on GPIO1 (hardware UART cannot TX on GPIO1)
    const pio_tx = zigmkay.split_communication.init_pio_uart_tx(gpio.num(0), 9600);
    return zigmkay.split_communication.UartClient{ .pio_uart_tx = pio_tx };
}

pub fn blink_led(blink_count: u32, interval_ms: u32) void {
    var counter = blink_count;
    while (counter > 0) : (counter -= 1) {
        p.led.put(1);
        time.sleep_us(interval_ms * 1000);
        p.led.put(0);
        time.sleep_us(interval_ms * 1000);
    }
}
