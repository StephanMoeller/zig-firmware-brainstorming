const keymap = @import("zigmkay_keymap");
const core = @import("core.zig");

pub const basic = keymap.keycodes.basic;
pub const system = keymap.keycodes.system;
pub const modifiers = keymap.keycodes.modifiers;
pub const mouse = keymap.keycodes.mouse;
pub const media = keymap.keycodes.media;

pub const internal = struct {
    pub const KC_NO = keymap.keycodes.internal.KC_NO;
    pub const XXXXXXX = keymap.keycodes.internal.XXXXXXX;
    pub const KC_TRANSPARENT = keymap.keycodes.internal.KC_TRANSPARENT;
    pub const _______ = keymap.keycodes.internal._______;
    pub const KC_TRNS = keymap.keycodes.internal.KC_TRNS;

    // Firmware-specific special keycodes
    pub const KC_BOOT = core.special_keycode_BOOT;
    pub const KC_PRINT_STATS = core.special_keycode_PRINT_STATS;
    pub const KC_COMPANION = core.special_keycode_COMPANION;
    pub const KC_SHUTDOWN_COMPANION = core.special_keycode_SHUTDOWN_COMPANION;
};

// Language-specific keymaps
pub const ger = keymap.ger;
pub const ger_mac_iso = keymap.ger_mac_iso;
pub const us_intl = keymap.us_intl;
