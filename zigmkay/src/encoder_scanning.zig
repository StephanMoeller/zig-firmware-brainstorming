//! Quadrature Encoder Decoder Module
//!
//! This module implements a robust, polling-based software quadrature decoder.
//! It maintains a state machine that reads the A and B pins of a rotary encoder
//! to determine the direction of rotation. It is designed to evaluate specific
//! detent state transitions (e.g., 00 and 11) to avoid multiple phantom events per click.

const std = @import("std");
const core = @import("core.zig");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

pub const EncoderPins = struct {
    pin_a: rp2xxx.gpio.Pin,
    pin_b: rp2xxx.gpio.Pin,
    sensitivity: i8, // lower number get higher sensitivity
};

pub const EncoderState = struct {
    last_detected_state: u2 = 0,
    accumulator: i8 = 0,

    last_change_detected: core.TimeSinceBoot = core.TimeSinceBoot{ .time_since_boot_us = 0 },
    last_announced_change: core.TimeSinceBoot = core.TimeSinceBoot{ .time_since_boot_us = 0 },
};

/// Represents a physical rotary encoder connected to two GPIO pins.
///
pub const EncoderConfig = struct {
    pins: EncoderPins,
    actions: core.EncoderDef,
};

pub fn CreateEncoderScannerType(comptime encoder_configs: []const EncoderConfig) type {
    return struct {
        const Self = @This();
        states: [encoder_configs.len]EncoderState = @splat(.{}),

        pub fn detectEncoderChanges(self: *Self, encoder_event_queue: *core.EncoderEventQueue, current_time: core.TimeSinceBoot) !void {
            comptime var i: usize = 0;
            const config_count = encoder_configs.len;
            inline while (i < config_count) {
                const config = &encoder_configs[i];
                if (update(config, &self.states[i], current_time)) |event| {
                    try encoder_event_queue.enqueue(event);
                }

                i += 1;
            }
        }

        fn read_state(pins: EncoderPins) u2 {
            const a = pins.pin_a.read();
            const b = pins.pin_b.read();
            return (@as(u2, a) << 1) | @as(u2, b);
        }

        fn update(config: *const EncoderConfig, state: *EncoderState, current_time: core.TimeSinceBoot) ?core.EncoderEvent {
            const new_state = read_state(config.pins);

            const transition_table: [4][4]i8 = comptime .{
                // zig fmt: off
            //  new: 00   01   10   11
                     .{ 0,   1,  -1,   0}, // old: 00
                     .{-1,   0,   0,   1}, // old: 01
                      .{1,   0,   0,  -1}, // old: 10
                      .{0,  -1,   1,   0}, // old: 11
            // zig fmt: on
        };

        if (new_state != state.last_detected_state) {
            state.accumulator += transition_table[new_state][state.last_detected_state];
            state.last_change_detected = current_time;
            state.last_detected_state = new_state;
        }

        // Wait for 1 ms of quiet before announcing anything (Jitter handling)
        if (current_time.time_since_boot_us < state.last_change_detected.time_since_boot_us + 1000) {
            return null; // let 1 ms pass before doing anything
        }

        // Don't announce more often than 10ms (debounce handling)
        if (current_time.time_since_boot_us < state.last_announced_change.time_since_boot_us + 10000) {
            return null;
        }

        // If sensitivity threshold exceeded, return an event
        if (state.accumulator >= config.pins.sensitivity) {
            state.accumulator -= config.pins.sensitivity;
            state.last_announced_change = current_time;
            if(config.actions.tap_cw)|tap|{
                return core.EncoderEvent{ .tap = tap };
            } 
        } else if (state.accumulator <= -config.pins.sensitivity) {
            state.accumulator += config.pins.sensitivity;
            state.last_announced_change = current_time;
            if(config.actions.tap_ccw)|tap|{
                return core.EncoderEvent{ .tap = tap };
            }
        }

        // Not enough change to trigger an announcement yet.
        return null;
    }
    };
}


