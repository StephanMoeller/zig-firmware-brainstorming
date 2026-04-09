const std = @import("std");
const zigmkay = @import("zigmkay");
const core = zigmkay.core;

const helpers = @import("processing_test_helpers.zig");
const init_test = helpers.init_test;

const a = 0x04;
const b = 0x05;
const c = 0x06;
const d = 0x07;
const e = 0x08;
const f = 0x09;
const g = 0x10;

const dummy_time = core.TimeStamp{ .time_since_boot = 0 };

const key_count = 58;
// test stuff
test "Autofire - case A" {
    const _______ = core.KeyDef.transparent;
    // zig fmt: off
    const keymap = comptime [_][key_count]core.KeyDef{
    .{ 
    t(KC_GRAVE), t(KC_1),  t(KC_2),  t(KC_3),  t(KC_4),  t(KC_5),                        t(KC_6),       t(KC_7),      t(KC_8),       t(KC_9),       t(KC_0),       t(KC_MINUS),
      t(KC_TAB), t(KC_Q),  t(KC_W),  t(KC_F),  t(KC_P),  t(KC_V),                        t(KC_J),       t(KC_L),      t(KC_U),       t(KC_Y),       t(KC_SEMI),    t(KC_BSLH),
    CTL(KC_ESC), t(KC_A),  t(KC_R),  t(KC_S),  t(KC_T),  t(KC_G),                        t(KC_M),       t(KC_N),      t(KC_E),       t(KC_I),       t(KC_O),       t(KC_QUOTE),
     LEFT_SHIFT,     t(KC_Z),  t(KC_X),  t(KC_C),  t(KC_D),  t(KC_B),                        t(KC_K),       t(KC_H),      t(KC_COMMA),   t(KC_DOT),     t(KC_FSLH),    RIGHT_SHIFT,
                             _______,  LEFT_ALT, LEFT_GUI, t(KC_ESC), t(KC_BACKSPACE),        t(KC_ENTER), _______, _______, _______, _______
    }};


    const current_time: core.TimeSinceBoot = .from_absolute_us(100);

    var o = init_test(core.KeymapDimensions{ .key_count = 58, .layer_count = keymap.len }, &keymap){};

    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 0 }); // Press left shift
    try o.matrix_change_queue.enqueue(.{ .time = current_time, .pressed = true, .key_index = 1 }); // Press B

    try o.process(current_time);
}

// zig fmt: on    // zig fmt: on
fn LT(layer_index: core.LayerIndex, keycode_fire: core.KeyCodeFire) core.KeyDef {
    return core.KeyDef{
        .tap_hold = .{
            .tap = .{ .key_press = keycode_fire },
            .hold = .{ .hold_layer = layer_index },
            .tapping_term = .{ .ms = 250 },
        },
    };
}

fn t(keycode: u8) core.KeyDef {
    return core.KeyDef{
        .tap_only = .{ .key_press = .{ .tap_keycode = keycode } },
    };
}

fn CTL(keycode: u8) core.KeyDef {
    return core.KeyDef{
        .tap_hold = .{
            .tap = .{ .key_press = .{ .tap_keycode = keycode } },
            .hold = core.HoldDef{ .hold_modifiers = .{ .left_ctrl = true } },
            .tapping_term = .{.ms = 250},
        },
    };
}

const LEFT_SHIFT: core.KeyDef = core.KeyDef{ .hold_only = .{ .hold_modifiers = .{ .left_shift = true } } };
const LEFT_ALT: core.KeyDef = core.KeyDef{ .hold_only = .{ .hold_modifiers = .{ .left_alt = true } } };
const LEFT_GUI: core.KeyDef = core.KeyDef{ .hold_only = .{ .hold_modifiers = .{ .left_gui = true } } };
const RIGHT_SHIFT: core.KeyDef = core.KeyDef{ .hold_only = .{ .hold_modifiers = .{ .right_shift = true } } };

fn on_event(event: core.ProcessorEvent, layers: *core.LayerActivations, output_queue: *core.OutputCommandQueue) void {
    _ = layers;
    _ = output_queue;
    switch (event) {
        .OnHoldEnterAfter => |data| {
            _ = data;
        },
        .OnHoldExitAfter => |data| {
            _ = data;
        },
        else => {},
    }
}
pub const com_functions = core.ComFunctions{
    .on_event = on_event,
};

// These keycodes are copied from the qmk project under the gpl2 license
pub const KC_BOOT = core.special_keycode_BOOT;
pub const KC_PRINT_STATS = core.special_keycode_PRINT_STATS;
pub const KC_A = 0x0004;
pub const KC_B = 0x0005;
pub const KC_C = 0x0006;
pub const KC_D = 0x0007;
pub const KC_E = 0x0008;
pub const KC_F = 0x0009;
pub const KC_G = 0x000A;
pub const KC_H = 0x000B;
pub const KC_I = 0x000C;
pub const KC_J = 0x000D;
pub const KC_K = 0x000E;
pub const KC_L = 0x000F;
pub const KC_M = 0x0010;
pub const KC_N = 0x0011;
pub const KC_O = 0x0012;
pub const KC_P = 0x0013;
pub const KC_Q = 0x0014;
pub const KC_R = 0x0015;
pub const KC_S = 0x0016;
pub const KC_T = 0x0017;
pub const KC_U = 0x0018;
pub const KC_V = 0x0019;
pub const KC_W = 0x001A;
pub const KC_X = 0x001B;
pub const KC_Y = 0x001C;
pub const KC_Z = 0x001D;
pub const KC_1 = 0x001E;
pub const KC_2 = 0x001F;
pub const KC_3 = 0x0020;
pub const KC_4 = 0x0021;
pub const KC_5 = 0x0022;
pub const KC_6 = 0x0023;
pub const KC_7 = 0x0024;
pub const KC_8 = 0x0025;
pub const KC_9 = 0x0026;
pub const KC_0 = 0x0027;
pub const KC_ENTER = 0x0028;
pub const KC_ESCAPE = 0x0029;
pub const KC_ESC = KC_ESCAPE;
pub const KC_BACKSPACE = 0x002A;
pub const KC_BSPC = KC_BACKSPACE;
pub const KC_TAB = 0x002B;
pub const KC_SPACE = 0x002C;
pub const KC_MINUS = 0x002D;
pub const KC_EQUAL = 0x002E;
pub const KC_LEFT_BRACKET = 0x002F;
pub const KC_RIGHT_BRACKET = 0x0030;
pub const KC_BACKSLASH = 0x0031;
pub const KC_BSLH = KC_BACKSLASH;
pub const KC_NONUS_HASH = 0x0032;
pub const KC_SEMICOLON = 0x0033;
pub const KC_SEMI = KC_SEMICOLON;
pub const KC_QUOTE = 0x0034;
pub const KC_GRAVE = 0x0035;
pub const KC_COMMA = 0x0036;
pub const KC_DOT = 0x0037;
pub const KC_SLASH = 0x0038;
pub const KC_FSLH = KC_SLASH;
pub const KC_CAPS_LOCK = 0x0039;
pub const KC_F1 = 0x003A;
pub const KC_F2 = 0x003B;
pub const KC_F3 = 0x003C;
pub const KC_F4 = 0x003D;
pub const KC_F5 = 0x003E;
pub const KC_F6 = 0x003F;
pub const KC_F7 = 0x0040;
pub const KC_F8 = 0x0041;
pub const KC_F9 = 0x0042;
pub const KC_F10 = 0x0043;
pub const KC_F11 = 0x0044;
pub const KC_F12 = 0x0045;
pub const KC_PRINT_SCREEN = 0x0046;
pub const KC_SCROLL_LOCK = 0x0047;
pub const KC_PAUSE = 0x0048;
pub const KC_INSERT = 0x0049;
pub const KC_HOME = 0x004A;
pub const KC_PAGE_UP = 0x004B;
pub const KC_DELETE = 0x004C;
pub const KC_END = 0x004D;
pub const KC_PAGE_DOWN = 0x004E;
pub const KC_RIGHT = 0x004F;
pub const KC_LEFT = 0x0050;
pub const KC_DOWN = 0x0051;
pub const KC_UP = 0x0052;
pub const KC_NUM_LOCK = 0x0053;
pub const KC_KP_SLASH = 0x0054;
pub const KC_KP_ASTERISK = 0x0055;
pub const KC_KP_MINUS = 0x0056;
pub const KC_KP_PLUS = 0x0057;
pub const KC_KP_ENTER = 0x0058;
pub const KC_KP_1 = 0x0059;
pub const KC_KP_2 = 0x005A;
pub const KC_KP_3 = 0x005B;
pub const KC_KP_4 = 0x005C;
pub const KC_KP_5 = 0x005D;
pub const KC_KP_6 = 0x005E;
pub const KC_KP_7 = 0x005F;
pub const KC_KP_8 = 0x0060;
pub const KC_KP_9 = 0x0061;
pub const KC_KP_0 = 0x0062;
pub const KC_KP_DOT = 0x0063;
pub const KC_NONUS_BACKSLASH = 0x0064;
pub const KC_APPLICATION = 0x0065;
pub const KC_KB_POWER = 0x0066;
pub const KC_KP_EQUAL = 0x0067;
pub const KC_F13 = 0x0068;
pub const KC_F14 = 0x0069;
pub const KC_F15 = 0x006A;
pub const KC_F16 = 0x006B;
pub const KC_F17 = 0x006C;
pub const KC_F18 = 0x006D;
pub const KC_F19 = 0x006E;
pub const KC_F20 = 0x006F;
pub const KC_F21 = 0x0070;
pub const KC_F22 = 0x0071;
pub const KC_F23 = 0x0072;
pub const KC_F24 = 0x0073;

pub const BOOT = core.KeyCodeFire{ .tap_keycode = KC_BOOT };
pub const A = core.KeyCodeFire{ .tap_keycode = KC_A };
pub const B = core.KeyCodeFire{ .tap_keycode = KC_B };
pub const C = core.KeyCodeFire{ .tap_keycode = KC_C };
pub const D = core.KeyCodeFire{ .tap_keycode = KC_D };
pub const E = core.KeyCodeFire{ .tap_keycode = KC_E };
pub const F = core.KeyCodeFire{ .tap_keycode = KC_F };
pub const G = core.KeyCodeFire{ .tap_keycode = KC_G };
pub const H = core.KeyCodeFire{ .tap_keycode = KC_H };
pub const I = core.KeyCodeFire{ .tap_keycode = KC_I };
pub const J = core.KeyCodeFire{ .tap_keycode = KC_J };
pub const K = core.KeyCodeFire{ .tap_keycode = KC_K };
pub const L = core.KeyCodeFire{ .tap_keycode = KC_L };
pub const M = core.KeyCodeFire{ .tap_keycode = KC_M };
pub const N = core.KeyCodeFire{ .tap_keycode = KC_N };
pub const O = core.KeyCodeFire{ .tap_keycode = KC_O };
pub const P = core.KeyCodeFire{ .tap_keycode = KC_P };
pub const Q = core.KeyCodeFire{ .tap_keycode = KC_Q };
pub const R = core.KeyCodeFire{ .tap_keycode = KC_R };
pub const S = core.KeyCodeFire{ .tap_keycode = KC_S };
pub const T = core.KeyCodeFire{ .tap_keycode = KC_T };
pub const U = core.KeyCodeFire{ .tap_keycode = KC_U };
pub const V = core.KeyCodeFire{ .tap_keycode = KC_V };
pub const W = core.KeyCodeFire{ .tap_keycode = KC_W };
pub const X = core.KeyCodeFire{ .tap_keycode = KC_X };
pub const Y = core.KeyCodeFire{ .tap_keycode = KC_Y };
pub const Z = core.KeyCodeFire{ .tap_keycode = KC_Z };
pub const N1 = core.KeyCodeFire{ .tap_keycode = KC_1 };
pub const N2 = core.KeyCodeFire{ .tap_keycode = KC_2 };
pub const N3 = core.KeyCodeFire{ .tap_keycode = KC_3 };
pub const N4 = core.KeyCodeFire{ .tap_keycode = KC_4 };
pub const N5 = core.KeyCodeFire{ .tap_keycode = KC_5 };
pub const N6 = core.KeyCodeFire{ .tap_keycode = KC_6 };
pub const N7 = core.KeyCodeFire{ .tap_keycode = KC_7 };
pub const N8 = core.KeyCodeFire{ .tap_keycode = KC_8 };
pub const N9 = core.KeyCodeFire{ .tap_keycode = KC_9 };
pub const N0 = core.KeyCodeFire{ .tap_keycode = KC_0 };
pub const ENTER = core.KeyCodeFire{ .tap_keycode = KC_ENTER };
pub const ESCAPE = core.KeyCodeFire{ .tap_keycode = KC_ESCAPE };
pub const BACKSPACE = core.KeyCodeFire{ .tap_keycode = KC_BACKSPACE };
pub const TAB = core.KeyCodeFire{ .tap_keycode = KC_TAB };
pub const SPACE = core.KeyCodeFire{ .tap_keycode = KC_SPACE };
pub const MINUS = core.KeyCodeFire{ .tap_keycode = KC_MINUS };
pub const EQUAL = core.KeyCodeFire{ .tap_keycode = KC_EQUAL };
pub const LEFT_BRACKET = core.KeyCodeFire{ .tap_keycode = KC_LEFT_BRACKET };
pub const RIGHT_BRACKET = core.KeyCodeFire{ .tap_keycode = KC_RIGHT_BRACKET };
pub const BACKSLASH = core.KeyCodeFire{ .tap_keycode = KC_BACKSLASH };
pub const NONUS_HASH = core.KeyCodeFire{ .tap_keycode = KC_NONUS_HASH };
pub const SEMICOLON = core.KeyCodeFire{ .tap_keycode = KC_SEMICOLON };
pub const QUOTE = core.KeyCodeFire{ .tap_keycode = KC_QUOTE };
pub const GRAVE = core.KeyCodeFire{ .tap_keycode = KC_GRAVE };
pub const COMMA = core.KeyCodeFire{ .tap_keycode = KC_COMMA };
pub const DOT = core.KeyCodeFire{ .tap_keycode = KC_DOT };
pub const SLASH = core.KeyCodeFire{ .tap_keycode = KC_SLASH };
pub const CAPS_LOCK = core.KeyCodeFire{ .tap_keycode = KC_CAPS_LOCK };
pub const F1 = core.KeyCodeFire{ .tap_keycode = KC_F1 };
pub const F2 = core.KeyCodeFire{ .tap_keycode = KC_F2 };
pub const F3 = core.KeyCodeFire{ .tap_keycode = KC_F3 };
pub const F4 = core.KeyCodeFire{ .tap_keycode = KC_F4 };
pub const F5 = core.KeyCodeFire{ .tap_keycode = KC_F5 };
pub const F6 = core.KeyCodeFire{ .tap_keycode = KC_F6 };
pub const F7 = core.KeyCodeFire{ .tap_keycode = KC_F7 };
pub const F8 = core.KeyCodeFire{ .tap_keycode = KC_F8 };
pub const F9 = core.KeyCodeFire{ .tap_keycode = KC_F9 };
pub const F10 = core.KeyCodeFire{ .tap_keycode = KC_F10 };
pub const F11 = core.KeyCodeFire{ .tap_keycode = KC_F11 };
pub const F12 = core.KeyCodeFire{ .tap_keycode = KC_F12 };
pub const PRINT_SCREEN = core.KeyCodeFire{ .tap_keycode = KC_PRINT_SCREEN };
pub const SCROLL_LOCK = core.KeyCodeFire{ .tap_keycode = KC_SCROLL_LOCK };
pub const PAUSE = core.KeyCodeFire{ .tap_keycode = KC_PAUSE };
pub const INSERT = core.KeyCodeFire{ .tap_keycode = KC_INSERT };
pub const HOME = core.KeyCodeFire{ .tap_keycode = KC_HOME };
pub const PAGE_UP = core.KeyCodeFire{ .tap_keycode = KC_PAGE_UP };
pub const DELETE = core.KeyCodeFire{ .tap_keycode = KC_DELETE };

pub const END = core.KeyCodeFire{ .tap_keycode = KC_END };
pub const PAGE_DOWN = core.KeyCodeFire{ .tap_keycode = KC_PAGE_DOWN };
pub const RIGHT = core.KeyCodeFire{ .tap_keycode = KC_RIGHT };
pub const LEFT = core.KeyCodeFire{ .tap_keycode = KC_LEFT };
pub const DOWN = core.KeyCodeFire{ .tap_keycode = KC_DOWN };
pub const UP = core.KeyCodeFire{ .tap_keycode = KC_UP };
pub const NUM_LOCK = core.KeyCodeFire{ .tap_keycode = KC_NUM_LOCK };
pub const KP_SLASH = core.KeyCodeFire{ .tap_keycode = KC_KP_SLASH };
pub const KP_ASTERISK = core.KeyCodeFire{ .tap_keycode = KC_KP_ASTERISK };
pub const KP_MINUS = core.KeyCodeFire{ .tap_keycode = KC_KP_MINUS };
pub const KP_PLUS = core.KeyCodeFire{ .tap_keycode = KC_KP_PLUS };
pub const KP_ENTER = core.KeyCodeFire{ .tap_keycode = KC_KP_ENTER };
pub const KP_1 = core.KeyCodeFire{ .tap_keycode = KC_KP_1 };
pub const KP_2 = core.KeyCodeFire{ .tap_keycode = KC_KP_2 };
pub const KP_3 = core.KeyCodeFire{ .tap_keycode = KC_KP_3 };
pub const KP_4 = core.KeyCodeFire{ .tap_keycode = KC_KP_4 };
pub const KP_5 = core.KeyCodeFire{ .tap_keycode = KC_KP_5 };
pub const KP_6 = core.KeyCodeFire{ .tap_keycode = KC_KP_6 };
pub const KP_7 = core.KeyCodeFire{ .tap_keycode = KC_KP_7 };
pub const KP_8 = core.KeyCodeFire{ .tap_keycode = KC_KP_8 };
pub const KP_9 = core.KeyCodeFire{ .tap_keycode = KC_KP_9 };
pub const KP_0 = core.KeyCodeFire{ .tap_keycode = KC_KP_0 };
pub const KP_DOT = core.KeyCodeFire{ .tap_keycode = KC_KP_DOT };
pub const NONUS_BACKSLASH = core.KeyCodeFire{ .tap_keycode = KC_NONUS_BACKSLASH };
pub const APPLICATION = core.KeyCodeFire{ .tap_keycode = KC_APPLICATION };
pub const KB_POWER = core.KeyCodeFire{ .tap_keycode = KC_KB_POWER };
pub const KP_EQUAL = core.KeyCodeFire{ .tap_keycode = KC_KP_EQUAL };
pub const F13 = core.KeyCodeFire{ .tap_keycode = KC_F13 };
pub const F14 = core.KeyCodeFire{ .tap_keycode = KC_F14 };
pub const F15 = core.KeyCodeFire{ .tap_keycode = KC_F15 };
pub const F16 = core.KeyCodeFire{ .tap_keycode = KC_F16 };
pub const F17 = core.KeyCodeFire{ .tap_keycode = KC_F17 };
pub const F18 = core.KeyCodeFire{ .tap_keycode = KC_F18 };
pub const F19 = core.KeyCodeFire{ .tap_keycode = KC_F19 };
pub const F20 = core.KeyCodeFire{ .tap_keycode = KC_F20 };
pub const F21 = core.KeyCodeFire{ .tap_keycode = KC_F21 };
pub const F22 = core.KeyCodeFire{ .tap_keycode = KC_F22 };
pub const F23 = core.KeyCodeFire{ .tap_keycode = KC_F23 };
pub const F24 = core.KeyCodeFire{ .tap_keycode = KC_F24 };

pub const ENT = ENTER;
pub const ESC = ESCAPE;
pub const BSPC = BACKSPACE;
pub const BS = BACKSPACE;
pub const SPC = SPACE;
pub const MINS = MINUS;
pub const EQL = EQUAL;
pub const LBRC = LEFT_BRACKET;
pub const RBRC = RIGHT_BRACKET;
pub const BSLS = BACKSLASH;
pub const NUHS = NONUS_HASH;
pub const SCLN = SEMICOLON;
pub const QUOT = QUOTE;
pub const GRV = GRAVE;
pub const COMM = COMMA;
pub const SLSH = SLASH;
pub const CAPS = CAPS_LOCK;
pub const PSCR = PRINT_SCREEN;
pub const SCRL = SCROLL_LOCK;
pub const BRMD = SCROLL_LOCK;
pub const PAUS = PAUSE;
pub const BRK = PAUSE;
pub const BRMU = PAUSE;
pub const INS = INSERT;
pub const PGUP = PAGE_UP;
pub const DEL = DELETE;
pub const PGDN = PAGE_DOWN;
pub const RGHT = RIGHT;
pub const NUM = NUM_LOCK;
pub const PSLS = KP_SLASH;
pub const PAST = KP_ASTERISK;
pub const PMNS = KP_MINUS;
pub const PPLS = KP_PLUS;
pub const PENT = KP_ENTER;
pub const P1 = KP_1;
pub const P2 = KP_2;
pub const P3 = KP_3;
pub const P4 = KP_4;
pub const P5 = KP_5;
pub const P6 = KP_6;
pub const P7 = KP_7;
pub const P8 = KP_8;
pub const P9 = KP_9;
pub const P0 = KP_0;
pub const PDOT = KP_DOT;
pub const NUBS = NONUS_BACKSLASH;
pub const APP = APPLICATION;
