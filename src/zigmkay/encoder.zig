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

pub const Encoder = struct {
    pin_a: rp2xxx.gpio.Pin,
    pin_b: rp2xxx.gpio.Pin,
    state: u2 = 0,

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

    pub fn update(self: *Encoder) ?EncoderEvent {
        const new_state = self.read_state();
        if (new_state == self.state) return null;

        // Basic state machine for quadrature decoding
        // Standard table:
        // 00 -> 01: CW
        // 01 -> 11: CW
        // 11 -> 10: CW
        // 10 -> 00: CW
        // Reverse for CCW

        const old_state = self.state;
        self.state = new_state;

        // We only trigger events on specific transitions to avoid multiple triggers per detent
        // Most encoders have 4 states per detent, often resting at 11 or 00.
        // Common pattern: transition to 00 or 11 (detent positions)

        if (new_state == 0b00 or new_state == 0b11) {
            // Check direction based on previous state
            // For CW (00->01->11->10->00):
            // If new is 00, prev was 10
            // If new is 11, prev was 01
            if ((old_state == 0b10 and new_state == 0b00) or (old_state == 0b01 and new_state == 0b11)) {
                return EncoderEvent{ .direction = .CCW };
            } else if ((old_state == 0b01 and new_state == 0b00) or (old_state == 0b10 and new_state == 0b11)) {
                return EncoderEvent{ .direction = .CW };
            }
        }

        return null;
    }
};
