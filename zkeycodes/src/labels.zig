const core = @import("zigmkay_shared");

pub const LabelEntry = struct {
    value: core.KeyCodeFire,
    label: []const u8,
    short_label: []const u8,
};

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
