const std = @import("std");

const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const gpio = rp2xxx.gpio;
const zigmkay = @import("zigmkay");
const dk = zigmkay.keycodes.dk;
const core = zigmkay.core;
const us = zigmkay.keycodes.us;
const time = rp2xxx.time;

const usb = zigmkay.usb;
const encoder_scanning = zigmkay.encoder_scanning;

// zig fmt: off
pub const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO17 = .{ .name = "led", .direction = .out },

    .GPIO0 = .{ .name = "col", .direction = .out },
    .GPIO1 = .{ .name = "row", .direction = .in },
    .GPIO23 = .{ .name = "data1", .direction = .in, .pull = .up, .function = .SIO },
    .GPIO21 = .{ .name = "data2", .direction = .in, .pull = .up , .function = .SIO},
    .GPIO8 = .{ .name = "click", .direction = .in, .pull = .up, .function = .SIO },
};
pub const p = pin_config.pins();

const dimensions = core.KeymapDimensions{
    .key_count = 1,
    .layer_count = 1
};
pub const no_pin_mappings = [dimensions.key_count]?[2]usize{ .{0,0} };
pub const keymap = [dimensions.layer_count][dimensions.key_count]core.KeyDef{.{core.KeyDef{.tap_only = .{.key_press = .{ .tap_keycode = 10 }}}}};

pub const scanner_settings = zigmkay.matrix_scanning.ScannerSettings{
    .debounce = .{ .ms = 50 },
};

// zig fmt: on
pub const pins_cols = [_]rp2xxx.gpio.Pin{p.col};
pub const pins_rows = [_]rp2xxx.gpio.Pin{p.row};

pub fn main() !void {
    run() catch {
        p.led.put(1);
    };
}
var encoder_configs = [_]encoder_scanning.EncoderConfig{encoder_scanning.EncoderConfig{
    .pins = .{
        .pin_a = p.data1,
        .pin_b = p.data2,
        .sensitivity = 4,
    },
    .actions = .{
        .tap_cw = core.TapDef{ .media_key = .VolumeUp },
        .tap_ccw = core.TapDef{ .media_key = .VolumeDown },
    },
}};
pub fn run() !void {
    _ = pin_config.apply();
    blink_led(1, 300); // Show the user that the keyboard has actually booted up.

    // Mandatory
    comptime var config = zigmkay.loops.GetUnibodyConfigType(&dimensions){
        .config = .{
            .keymap = &keymap,
            .pin_cols = pins_cols[0..],
            .pin_rows = pins_rows[0..],
            .pin_mappings = &no_pin_mappings,
            .encoder_configs = encoder_configs[0..],
        },
    };

    comptime var runner = config.build();
    runner.run_unibody() catch {
        blink_led(10000000, 500); // in case of an error, let the keyboard start blinking
    };
}

fn get_current_time() core.TimeSinceBoot {
    return core.TimeSinceBoot{
        .time_since_boot_us = time.get_time_since_boot().to_us(),
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
