const std = @import("std");

const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const rollercole_shared_keymap = @import("shared_keymap.zig");
const zigmkay = @import("zigmkay");
const dk = zigmkay.keycodes.dk;
const core = zigmkay.core;
const us = zigmkay.keycodes.us;

// zig fmt: off
pub const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO17 = .{ .name = "led", .direction = .out },

    .GPIO20 = .{ .name = "col0", .direction = .out },
    .GPIO23 = .{ .name = "col1", .direction = .out },
    .GPIO21 = .{ .name = "col2", .direction = .out },
    .GPIO7 = .{ .name = "col3", .direction = .out },
    .GPIO8 = .{ .name = "col4", .direction = .out },

    .GPIO27 = .{ .name = "row0", .direction = .in },
    .GPIO26= .{ .name = "row1", .direction = .in },
    .GPIO22 = .{ .name = "row2", .direction = .in },
    .GPIO4 = .{ .name = "row3", .direction = .in },
    .GPIO5 = .{ .name = "row4", .direction = .in },
    .GPIO6 = .{ .name = "row5", .direction = .in },
};
pub const p = pin_config.pins();

pub const pin_mappings = [rollercole_shared_keymap.key_count]?[2]usize{
  .{0,0}, .{1,0}, .{2,0}, .{3,0}, .{4,0},  .{4,3},.{3,3},.{2,3},.{1,3},.{0,3},
  .{0,1}, .{1,1}, .{2,1}, .{3,1}, .{4,1},    .{4,4},.{3,4},.{2,4},.{1,4},.{0,4},
          .{1,2}, .{2,2}, .{3,2}, .{4,2},    .{4,5},.{3,5},.{2,5},.{1,5},
                                 .{0, 2},   .{0, 5}
};

pub const scanner_settings = zigmkay.matrix_scanning.ScannerSettings{
    .debounce = .{ .ms = 50 },
};

// zig fmt: on
pub const clacky_pin_cols = [_]rp2xxx.gpio.Pin{ p.col0, p.col1, p.col2, p.col3, p.col4 };
pub const clacky_pin_rows = [_]rp2xxx.gpio.Pin{ p.row0, p.row1, p.row2, p.row3, p.row4, p.row5 };

pub fn main() !void {

    // Init pins
    _ = pin_config.apply(); // dont know how this could be done inside the module, but it needs to be done for things to work
    blink_led(1, 300); // Show the user that the keyboard has actually booted up.

    // Mandatory
    comptime var config = zigmkay.loops.GetConfigType(&rollercole_shared_keymap.dimensions).init(
        &rollercole_shared_keymap.keymap,
        &pin_mappings,
        clacky_pin_cols[0..],
        clacky_pin_rows[0..],
    );

    // Optionals
    comptime config.set_combos(rollercole_shared_keymap.combos[0..]);
    comptime config.set_scanner_settings(scanner_settings);
    comptime config.set_custom_functions(&rollercole_shared_keymap.custom_functions);
    comptime config.set_side_definitions(&rollercole_shared_keymap.sides);

    config.run(null) catch {
        blink_led(10000000, 500); // in case of an error, let the keyboard start blinking
    };
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
