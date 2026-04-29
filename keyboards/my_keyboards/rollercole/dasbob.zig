const std = @import("std");

const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const rollercole_shared_keymap = @import("shared_keymap.zig");
const zigmkay = @import("zigmkay");
const zkeycodes = @import("zkeycodes");

// uart
const uart_tx_pin = gpio.num(0);
const uart_rx_pin = gpio.num(1);

// zig fmt: off
pub const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO17 = .{ .name = "led", .direction = .out },

    .GPIO13 = .{ .name = "GP13", .direction = .in, .pull = .up},
    .GPIO28 = .{ .name = "GP28", .direction = .in, .pull = .up},
    .GPIO12 = .{ .name = "GP12", .direction = .in, .pull = .up},
    .GPIO29 = .{ .name = "GP29", .direction = .in, .pull = .up},
    .GPIO0 = .{ .name = "GP0", .direction = .in, .pull = .up},

    .GPIO22 = .{ .name = "GP22", .direction = .in, .pull = .up},
    .GPIO14 = .{ .name = "GP14", .direction = .in, .pull = .up},
    .GPIO26 = .{ .name = "GP26", .direction = .in, .pull = .up},
    .GPIO4 = .{ .name = "GP4", .direction = .in, .pull = .up},
    .GPIO27 = .{ .name = "GP27", .direction = .in, .pull = .up},

    //.GPIO21 = .{ .name = "GP21", .direction = .in, .pull = .up},
    .GPIO23 = .{ .name = "GP23", .direction = .in, .pull = .up},
    .GPIO7 = .{ .name = "GP7", .direction = .in, .pull = .up},
    .GPIO20 = .{ .name = "GP20", .direction = .in, .pull = .up},
    .GPIO6 = .{ .name = "GP6", .direction = .in, .pull = .up},

    //.GPIO16 = .{ .name = "GP16", .direction = .in, .pull = .up},
    .GPIO9 = .{ .name = "GP9", .direction = .in, .pull = .up},
    //.GPIO8 = .{ .name = "GP8", .direction = .in, .pull = .up},
};
pub const p = pin_config.pins();
pub const pin_mappings_right = [rollercole_shared_keymap.key_count]?[2]usize{
   null, null, null, null, null,  .{0,13},.{0,12},.{0,11},.{0,10},.{0,5},
   null, null, null, null, null,   .{0,9},.{0,8},.{0,7},.{0,6},.{0,0},
         null, null, null, null,   .{0,4},.{0,3},.{0,2},.{0,1},
                           null,   .{0, 14}
};

pub const pin_mappings_left = [rollercole_shared_keymap.key_count]?usize{
    0, 1, 2, 3, 4,     null, null, null, null, null,
    5, 6, 7, 8, 9,     null, null, null, null, null,
      10,11,12,13,     null, null, null, null, 
               14,     null,
};

pub const scanner_settings = zigmkay.matrix_scanning.ScannerSettings{
};

pub const switch_pins = [_]rp2xxx.gpio.Pin{
    p.GP13, p.GP28, p.GP12, p.GP29, p.GP0,
    p.GP22, p.GP14, p.GP26, p.GP4,  p.GP27,
            p.GP23, p.GP7,  p.GP20, p.GP6,  
    p.GP9,
};
// zig fmt: on

const primary = true;

pub fn main() !void {
    _ = pin_config.apply();
    blink_led(1, 300); // Show the user that the keyboard has actually booted up.
    const uart = init_uart();

    if (primary) {
        comptime var config = zigmkay.loops.GetPrimarySideConfigType(&rollercole_shared_keymap.dimensions){
            .config = .{
                .keymap = &rollercole_shared_keymap.keymap,
                .scanner_settings = &.{
                    .direct_wiring = .{
                        .debounce = .{ .ms = 50 },
                        .switch_pins = &switch_pins,
                        .pins_to_keys_mapping = &pin_mappings_left,
                    },
                },
                .combos = rollercole_shared_keymap.combos[0..],
                .custom_functions = &rollercole_shared_keymap.custom_functions,
                .side_definition = &rollercole_shared_keymap.sides,
            },
        };

        comptime var runner = config.build();
        runner.run_primary(uart) catch {
            blink_led(10000000, 500); // in case of an error, let the keyboard start blinking
        };
    } else {}
}

pub fn init_uart() rp2xxx.uart.UART {
    // uart init
    uart_tx_pin.set_function(.uart);
    uart_rx_pin.set_function(.uart);
    const uart = rp2xxx.uart.instance.num(0);
    uart.apply(.{ .clock_config = rp2xxx.clock_config, .baud_rate = 9600 });
    return uart;
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
