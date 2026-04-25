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

pub fn run() !void {
    _ = pin_config.apply();
    blink_led(1, 300); // Show the user that the keyboard has actually booted up.

    // Mandatory
    //comptime var config = zigmkay.loops.GetConfigType(&dimensions).init();
    //comptime config.set_keymap(&keymap);
    //comptime config.set_pins(pins_cols[0..], pins_rows[0..], &no_pin_mappings);

    var usb_command_queue = core.OutputCommandQueue.Create();
    const usb_command_executor = usb.CreateAndInitUsbCommandExecutor();

    var current_time = get_current_time();
    var encoder = encoder_scanning.Encoder.init(
        p.data1,
        p.data2,
        4,
        current_time,
    );
    const max_len = 2000;
    var buf: [max_len]u8 = undefined;

    p.click.set_function(.sio);
    p.click.set_direction(.in);
    p.click.set_pull(.up);

    while (true) {
        current_time = get_current_time();
        try usb_command_executor.HouseKeepAndProcessCommands(&usb_command_queue, current_time);

        const event = encoder.update(current_time);
        if (event) |e| {
            switch (e.direction) {
                .CW => {
                    try usb_command_queue.queue.enqueue(.{ .ConsumerKeyPressed = .VolumeUp });
                    try usb_command_queue.queue.enqueue(.{ .ConsumerKeyReleased = .VolumeUp });

                    const numAsString = try std.fmt.bufPrint(&buf, "{}", .{1});
                    try usb_command_queue.print_string(numAsString);

                    //p.led.put(1);
                },
                .CCW => {
                    try usb_command_queue.queue.enqueue(.{ .ConsumerKeyPressed = .VolumeDown });
                    try usb_command_queue.queue.enqueue(.{ .ConsumerKeyReleased = .VolumeDown });
                    const numAsString = try std.fmt.bufPrint(&buf, "{}", .{0});
                    try usb_command_queue.print_string(numAsString);
                    //p.led.put(0);
                },
            }
        }

        p.led.put(p.click.read());
        //runner.run_unibody() catch {
        //    blink_led(10000000, 500); // in case of an error, let the keyboard start blinking
        //};

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
