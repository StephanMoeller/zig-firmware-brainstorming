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
pub const EncoderEvent = struct {
    direction: enum(u8) {
        CW = 1,
        CCW = 2,
    },
};

pub const EncoderPins = struct {
    pin_a: rp2xxx.gpio.Pin,
    pin_b: rp2xxx.gpio.Pin,
};

pub const EncoderState = struct {
    last_detected_state: u2 = 0,
    accumulator: i8 = 0,

    last_change_detected: core.TimeSinceBoot,
    last_announced_change: core.TimeSinceBoot,
    sensitivity: i8, // lower number get higher sensitivity
};

/// Represents a physical rotary encoder connected to two GPIO pins.
///
pub const Encoder = struct {
    pins: EncoderPins,
    config: core.EncoderDef,
    state: EncoderState,

    /// Initializes a new Encoder instance, setting the given pins as input with pull-ups enabled.
    /// Reads the initial internal state of the pins.
    pub fn init(pin_a: rp2xxx.gpio.Pin, pin_b: rp2xxx.gpio.Pin, sensitivity: i8, current_time: core.TimeSinceBoot) Encoder {
        pin_a.set_function(.sio);
        pin_b.set_function(.sio);
        pin_a.set_direction(.in);
        pin_b.set_direction(.in);
        pin_a.set_pull(.up);
        pin_b.set_pull(.up);

        var self = Encoder{
            .pins = .{
                .pin_a = pin_a,
                .pin_b = pin_b,
            },
            .state = .{
                .sensitivity = sensitivity,
                .last_announced_change = current_time,
                .last_change_detected = current_time,
            },
            .config = .{},
        };
        self.state.last_detected_state = read_state(self.pins);

        return self;
    }

    fn read_state(pins: EncoderPins) u2 {
        const a = pins.pin_a.read();
        const b = pins.pin_b.read();
        return (@as(u2, a) << 1) | @as(u2, b);
    }

    /// Polls the current encoder state and computes any rotation events.
    /// Should be called repeatedly within the matrix scanning loop.
    ///
    /// Uses a direction accumulator to suppress jitter: each quadrature transition
    /// votes +1 (CW) or -1 (CCW). An event is only emitted when the encoder reaches
    /// the resting detent (state 00) with an accumulated vote of ±2 or more.
    /// The accumulator is not reset at intermediate states (e.g. 11), so a full step
    /// (00→01→11→10→00) accumulates +4 before firing. A single jitter bounce
    /// (e.g. 00→01→00) nets zero and is discarded.
    pub fn update(self: *Encoder, current_time: core.TimeSinceBoot) ?EncoderEvent {
        const new_state = read_state(self.pins);

        const transition_table: [4][4]i8 = comptime .{
            // zig fmt: off
            //  new: 00   01   10   11
                     .{ 0,   1,  -1,   0}, // old: 00
                     .{-1,   0,   0,   1}, // old: 01
                      .{1,   0,   0,  -1}, // old: 10
                      .{0,  -1,   1,   0}, // old: 11
            // zig fmt: on
        };

        var state = &self.state;

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
        if (state.accumulator >= state.sensitivity) {
            state.accumulator -= state.sensitivity;
            state.last_announced_change = current_time;
            return EncoderEvent{ .direction = .CW };
        } else if (state.accumulator <= -state.sensitivity) {
            state.accumulator += state.sensitivity;
            state.last_announced_change = current_time;
            return EncoderEvent{ .direction = .CCW };
        }

        // Not enough change to trigger an announcement yet.
        return null;
    }
};
