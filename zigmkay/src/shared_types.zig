pub const special_keycode_BOOT: u8 = 0xFC;
pub const special_keycode_PRINT_STATS: u8 = 0xFD;
pub const special_keycode_COMPANION: u8 = 0xFE;
pub const special_keycode_SHUTDOWN_COMPANION: u8 = 0xFF;

pub const CUSTOM_ID_COMPANION_LOG_TOGGLE: u8 = 0xFD;
pub const CUSTOM_ID_COMPANION_SHUTDOWN: u8 = 0xFE;
pub const CUSTOM_ID_COMPANION_TOGGLE: u8 = 0xFF;

pub const KeyCodeFire = struct {
    tap_keycode: u8 = 0,
    tap_modifiers: ?Modifiers = null,
    dead: bool = false,
};

pub const KC_BOOT = KeyCodeFire{ .tap_keycode = special_keycode_BOOT };
pub const KC_PRINT_STATS = KeyCodeFire{ .tap_keycode = special_keycode_PRINT_STATS };
pub const KC_COMPANION = KeyCodeFire{ .tap_keycode = special_keycode_COMPANION };
pub const KC_SHUTDOWN_COMPANION = KeyCodeFire{ .tap_keycode = special_keycode_SHUTDOWN_COMPANION };

pub const Modifiers = packed struct {
    left_ctrl: bool = false,
    left_shift: bool = false,
    left_alt: bool = false,
    left_gui: bool = false,
    right_ctrl: bool = false,
    right_shift: bool = false,
    right_alt: bool = false,
    right_gui: bool = false,

    pub fn add(self: *const Modifiers, other: Modifiers) Modifiers {
        const self_bytes = self.toByte();
        const other_bytes = other.toByte();
        return Modifiers.fromByte(self_bytes | other_bytes);
    }

    pub fn remove(self: *const Modifiers, other: Modifiers) Modifiers {
        const self_bytes = self.toByte();
        const other_bytes = other.toByte();
        return Modifiers.fromByte(self_bytes & ~other_bytes);
    }

    pub fn toByte(self: Modifiers) u8 {
        return @bitCast(self);
    }

    pub fn fromByte(byte_val: u8) Modifiers {
        return @bitCast(byte_val);
    }
};

pub const KeyIndex = u7;
pub const LayerIndex = u4;

pub const TimeSpan = struct {
    ms: u16 = 0,
};

pub const KeymapDimensions = struct {
    key_count: KeyIndex,
    layer_count: LayerIndex,
};

pub const MouseAction = enum(u8) {
    LeftButton,
    RightButton,
    MiddleButton,
    Button4,
    Button5,
    WheelUp,
    WheelDown,
    WheelLeft,
    WheelRight,
};

pub const MediaCode = enum(u16) {
    VolumeMute = 0x00e8,
    VolumeUp = 0x00e9,
    VolumeDown = 0x00ea,
};

pub const HoldDef = struct {
    hold_modifiers: ?Modifiers = null,
    hold_layer: ?LayerIndex = null,
    custom: ?u8 = null,
};

pub const TapDef = struct {
    key_press: ?KeyCodeFire = null,
    one_shot: ?HoldDef = null,
    custom: ?u8 = null,
    media_key: ?MediaCode = null,
    mouse_action: ?MouseAction = null,
};

pub const TapHoldDef = struct {
    tap: TapDef,
    hold: HoldDef,
    tapping_term: TimeSpan,
    retro_tapping: bool = false,
};

pub const AutoFireDef = struct {
    tap: TapDef,
    initial_delay: TimeSpan,
    repeat_interval: TimeSpan,
};

pub const KeyDef = union(enum) {
    none,
    transparent,
    tap_only: TapDef,
    hold_only: HoldDef,
    tap_hold: TapHoldDef,
    tap_with_autofire: AutoFireDef,
};

pub const Side = enum {
    L,
    R,
    X,
};

pub const Combo2Def = struct {
    key_indexes: [2]KeyIndex,
    timeout: TimeSpan,
    layer: LayerIndex,
    key_def: KeyDef,
};

pub fn L_CTL(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = false;
    if (copy.tap_modifiers) |mods| {
        copy.tap_modifiers = mods.add(.{ .left_ctrl = true });
    } else {
        copy.tap_modifiers = .{ .left_ctrl = true };
    }
    return copy;
}

pub fn R_CTL(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = false;
    if (copy.tap_modifiers) |mods| {
        copy.tap_modifiers = mods.add(.{ .right_ctrl = true });
    } else {
        copy.tap_modifiers = .{ .right_ctrl = true };
    }
    return copy;
}

pub fn L_SFT(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = false;
    if (copy.tap_modifiers) |mods| {
        copy.tap_modifiers = mods.add(.{ .left_shift = true });
    } else {
        copy.tap_modifiers = .{ .left_shift = true };
    }
    return copy;
}

pub fn R_SFT(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = false;
    if (copy.tap_modifiers) |mods| {
        copy.tap_modifiers = mods.add(.{ .right_shift = true });
    } else {
        copy.tap_modifiers = .{ .right_shift = true };
    }
    return copy;
}

pub fn L_GUI(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = false;
    if (copy.tap_modifiers) |mods| {
        copy.tap_modifiers = mods.add(.{ .left_gui = true });
    } else {
        copy.tap_modifiers = .{ .left_gui = true };
    }
    return copy;
}

pub fn R_GUI(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = false;
    if (copy.tap_modifiers) |mods| {
        copy.tap_modifiers = mods.add(.{ .right_gui = true });
    } else {
        copy.tap_modifiers = .{ .right_gui = true };
    }
    return copy;
}

pub fn L_ALT(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = false;
    if (copy.tap_modifiers) |mods| {
        copy.tap_modifiers = mods.add(.{ .left_alt = true });
    } else {
        copy.tap_modifiers = .{ .left_alt = true };
    }
    return copy;
}

pub fn R_ALT(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = false;
    if (copy.tap_modifiers) |mods| {
        copy.tap_modifiers = mods.add(.{ .right_alt = true });
    } else {
        copy.tap_modifiers = .{ .right_alt = true };
    }
    return copy;
}

pub fn DEAD(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = true;
    return copy;
}
