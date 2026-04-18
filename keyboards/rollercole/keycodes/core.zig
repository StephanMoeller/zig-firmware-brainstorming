const zigmkay = @import("zigmkay");
const core = zigmkay.core;

/// helper to add Left Control modifier to a KeyCodeFire.
pub fn L_CTL(fire: core.KeyCodeFire) core.KeyCodeFire {
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
pub fn R_CTL(fire: core.KeyCodeFire) core.KeyCodeFire {
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
pub fn L_SFT(fire: core.KeyCodeFire) core.KeyCodeFire {
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
pub fn R_SFT(fire: core.KeyCodeFire) core.KeyCodeFire {
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
pub fn L_GUI(fire: core.KeyCodeFire) core.KeyCodeFire {
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
pub fn R_GUI(fire: core.KeyCodeFire) core.KeyCodeFire {
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
pub fn L_ALT(fire: core.KeyCodeFire) core.KeyCodeFire {
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
pub fn R_ALT(fire: core.KeyCodeFire) core.KeyCodeFire {
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
pub fn DEAD(fire: core.KeyCodeFire) core.KeyCodeFire {
    var copy = fire;
    copy.dead = true;
    return copy;
}

pub const LabelEntry = struct {
    value: core.KeyCodeFire,
    label: []const u8,
    short_label: []const u8,
};

/// Looks up `keycode` in `table` by matching both `tap_keycode` and `tap_modifiers`.
/// This distinguishes e.g. `S(KC_1)` ("EXLM") from plain `KC_1` ("1").
pub fn getLabel(table: []const LabelEntry, keycode: core.KeyCodeFire, shortest: bool) ?[]const u8 {
    const key_mods: u8 = if (keycode.tap_modifiers) |m| m.toByte() else 0;
    for (table) |entry| {
        const entry_mods: u8 = if (entry.value.tap_modifiers) |m| m.toByte() else 0;
        if (entry.value.tap_keycode == keycode.tap_keycode and entry_mods == key_mods) {
            return if (shortest) entry.short_label else entry.label;
        }
    }
    return null;
}
