//! Quadrature Encoder Decoder Module
//!
//! This module implements a robust, polling-based software quadrature decoder.
//! It maintains a state machine that reads the A and B pins of a rotary encoder
//! to determine the direction of rotation. It is designed to evaluate specific
//! detent state transitions (e.g., 00 and 11) to avoid multiple phantom events per click.

const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;

pub const EncoderDirection = enum(u8) {
    CW = 1,
    CCW = 2,
};

pub const EncoderEvent = struct {
    direction: EncoderDirection,
};

/// Represents a physical rotary encoder connected to two GPIO pins.
pub const Encoder = struct {
    pin_a: rp2xxx.gpio.Pin,
    pin_b: rp2xxx.gpio.Pin,
    state: u2 = 0,
    accumulator: i8 = 0,

    /// Initializes a new Encoder instance, setting the given pins as input with pull-ups enabled.
    /// Reads the initial internal state of the pins.
    pub fn init(pin_a: rp2xxx.gpio.Pin, pin_b: rp2xxx.gpio.Pin) Encoder {
        pin_a.set_function(.sio);
        pin_b.set_function(.sio);
        pin_a.set_direction(.in);
        pin_b.set_direction(.in);
        pin_a.set_pull(.up);
        pin_b.set_pull(.up);

        var self = Encoder{
            .pin_a = pin_a,
            .pin_b = pin_b,
        };
        self.state = self.read_state();
        return self;
    }

    fn read_state(self: Encoder) u2 {
        const a = self.pin_a.read();
        const b = self.pin_b.read();
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
    pub fn update(self: *Encoder) ?EncoderEvent {
        // Transition vote table indexed by (old_state << 2 | new_state).
        // CW sequence:  00->01->11->10->00  => +1 per step
        // CCW sequence: 00->10->11->01->00  => -1 per step
        // Two-bit jumps and no-change transitions: 0 (ignored)
        const transition_table: [16]i8 = comptime .{
            // zig fmt: off
            //  new: 00   01   10   11
                      0,   1,  -1,   0, // old: 00
                     -1,   0,   0,   1, // old: 01
                      1,   0,   0,  -1, // old: 10
                      0,  -1,   1,   0, // old: 11
            // zig fmt: on
        };

        const new_state = self.read_state();
        if (new_state == self.state) return null;

        const old_state = self.state;
        self.state = new_state;

        const idx: u4 = (@as(u4, old_state) << 2) | @as(u4, new_state);
        self.accumulator +|= transition_table[idx]; // saturating add

        // Reset the accumulator at every detent so stale votes from one
        // half-step never bleed into the next. Only the 00 detent emits events.
        if (new_state == 0b11) {
            self.accumulator = 0;
        } else if (new_state == 0b00) {
            defer self.accumulator = 0;
            if (self.accumulator >= 2) {
                return EncoderEvent{ .direction = .CCW };
            } else if (self.accumulator <= -2) {
                return EncoderEvent{ .direction = .CW };
            }
        }

        return null;
    }
};
