const std = @import("std");

const zigmkay = @import("zigmkay");
const core = zigmkay.core;

const keycodes = @import("zkeycodes");
const dk = keycodes.layouts.danish;
const us = keycodes.layouts.keycodes.kcf;

// zig fmt: off
pub const key_count = 36;
pub const ________ = core.KeyDef.none;

pub const BASE_LAYER = 0;
pub const NUMBER_LAYER = 1;
pub const ARROW_KEYS_LAYER = 1;

pub const keymap = [_][key_count]zigmkay.core.KeyDef{
    // BASE_LAYER 
    .{
         T(dk.Q), T(dk.W), T(dk.E), T(dk.R), T(dk.T),                  T(dk.Y), T(dk.U), T(dk.I),    T(dk.O),  T(dk.P),
         T(dk.A), T(dk.S), T(dk.D), T(dk.F), T(dk.G),                  T(dk.H), T(dk.J), T(dk.K),    T(dk.L),  T(dk.SCLN),
         T(dk.Z), T(dk.X), T(dk.C), T(dk.V), T(dk.B),                  T(dk.N), T(dk.M), T(dk.COMM), T(dk.DOT),T(dk.SLSH),
                           T(dk.A), T(us.ENTER), T(dk.B),           T(dk.T), T(us.SPACE), T(dk.C)
    }, 
    // NUMBER_LAYER
    .{
         ________, ________, ________, ________, ________,                  ________, T(dk.N7), T(dk.N8), T(dk.N9), ________,
         ________, ________, ________, ________, ________,                  ________, T(dk.N4), T(dk.N5), T(dk.N6), ________,
         ________, ________, ________, ________, ________,                  ________, T(dk.N1), T(dk.N2), T(dk.N3), ________,
                             ________, ________, ________,                  ________,   ________,   ________,
    },
    // ARROW_KEYS_LAYER
    .{
         ________, ________, ________, ________, ________,                  ________, T(us.HOME),   T(us.UP),   T(us.END), ________,
         ________, ________, ________, ________, ________,                  ________, T(us.LEFT), T(us.DOWN), T(us.RIGHT), ________,
         ________, ________, ________, ________, ________,                  ________,   ________,   ________,    ________, ________,
                             ________, ________, ________,                  ________,   ________,   ________,
    },
};
// zig fmt: on

pub const dimensions = core.KeymapDimensions{
    .key_count = key_count,
    .layer_count = keymap.len,
};

fn T(keycode_fire: core.KeyCodeFire) core.KeyDef {
    return core.KeyDef{
        .tap_only = .{ .key_press = keycode_fire },
    };
}
