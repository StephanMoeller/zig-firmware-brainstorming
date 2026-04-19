pub const KeyCodeFire = struct {
    tap_keycode: u8 = 0,
    tap_modifiers: ?Modifiers = null,
    dead: bool = false,
};

pub const Modifiers = packed struct {
    left_ctrl: bool = false,
    left_shift: bool = false,
    left_alt: bool = false,
    left_gui: bool = false,
    right_ctrl: bool = false,
    right_shift: bool = false,
    right_alt: bool = false,
    right_gui: bool = false, // TODO: do we want to ad numlock and capslock here too?

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

/// helper to add Left Control modifier to a KeyCodeFire.
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

/// helper to add Right Control modifier to a KeyCodeFire.
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

/// helper to add Left Shift modifier to a KeyCodeFire.
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

/// helper to add Right Shift modifier to a KeyCodeFire.
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

/// helper to add Left GUI (Windows/Command) modifier to a KeyCodeFire.
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

/// helper to add Right GUI (Windows/Command) modifier to a KeyCodeFire.
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

/// helper to add Left Alt modifier to a KeyCodeFire.
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

/// helper to add Right Alt modifier to a KeyCodeFire.
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

/// Sets the dead key flag on a KeyCodeFire. Dead keys send the keycode followed by a
/// spacebar press to cancel the dead key combination.
pub fn DEAD(fire: KeyCodeFire) KeyCodeFire {
    var copy = fire;
    copy.dead = true;
    return copy;
}

pub const LabelEntry = struct {
    value: KeyCodeFire,
    label: []const u8,
    short_label: []const u8,
};

/// Looks up `keycode` in `table` by matching both `tap_keycode` and `tap_modifiers`.
/// This distinguishes e.g. `S(KC_1)` ("EXLM") from plain `KC_1` ("1").
pub fn getLabel(table: []const LabelEntry, keycode: KeyCodeFire, shortest: bool) ?[]const u8 {
    const key_mods: u8 = if (keycode.tap_modifiers) |m| m.toByte() else 0;
    for (table) |entry| {
        const entry_mods: u8 = if (entry.value.tap_modifiers) |m| m.toByte() else 0;
        if (entry.value.tap_keycode == keycode.tap_keycode and entry_mods == key_mods) {
            return if (shortest) entry.short_label else entry.label;
        }
    }
    return null;
}
