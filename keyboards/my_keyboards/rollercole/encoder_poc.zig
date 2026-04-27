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
    .GPIO23 = .{ .name = "data1", .direction = .in },
    .GPIO21 = .{ .name = "data2", .direction = .in },
    .GPIO8 = .{ .name = "click", .direction = .in },
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
const enc_config = encoder_scanning.EncoderConfig{
    .pins = .{
        .pin_a = p.data1,
        .pin_b = p.data2,
        .sensitivity = 4,
    },
    .actions = .{
        .tap_cw = core.TapDef{ .media_key = .VolumeUp },
        .tap_ccw = core.TapDef{ .media_key = .VolumeDown },
    },
};
const configs: [1]encoder_scanning.EncoderConfig = .{enc_config};
pub fn run() !void {
    _ = pin_config.apply();
    blink_led(1, 300); // Show the user that the keyboard has actually booted up.

    const configs_slice: []const encoder_scanning.EncoderConfig = configs[0..];
    // Mandatory
    //comptime var config = zigmkay.loops.GetConfigType(&dimensions).init();
    //comptime config.set_keymap(&keymap);
    //comptime config.set_pins(pins_cols[0..], pins_rows[0..], &no_pin_mappings);

    var usb_command_queue = core.OutputCommandQueue.Create();
    const usb_command_executor = usb.CreateAndInitUsbCommandExecutor();

    var current_time = get_current_time();

    var encoder_change_queue = core.EncoderEventQueue.Create();
    var encoder_scanner = comptime encoder_scanning.CreateEncoderScannerType(configs_slice){
        .configs = configs_slice,
    };
    while (true) {
        current_time = get_current_time();
        try usb_command_executor.HouseKeepAndProcessCommands(&usb_command_queue, current_time);
        try encoder_scanner.detectEncoderChanges(&encoder_change_queue, current_time);

        while (encoder_change_queue.dequeue()) |e| {
            try usb_command_queue.queue.enqueue(.{ .ConsumerKeyPressed = e.tap.media_key.? });
            try usb_command_queue.queue.enqueue(.{ .ConsumerKeyReleased = e.tap.media_key.? });
        }
    }
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
