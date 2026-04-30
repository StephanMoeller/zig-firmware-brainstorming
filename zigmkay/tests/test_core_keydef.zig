const zigmkay = @import("zigmkay");
const core = zigmkay.core;

const std = @import("std");

// --- none ---

test "KeyDef.with_tap_mods - none - expect error" {
    const key_def = core.KeyDef{ .none = {} };
    try std.testing.expectEqual(core.ModAddErrors.KeyDefinitionDoesNotContainTapDefinition, key_def.with_tap_mods(.{ .left_ctrl = true }));
}

// --- transparent ---

test "KeyDef.with_tap_mods - transparent - expect error" {
    const key_def = core.KeyDef{ .transparent = {} };
    try std.testing.expectEqual(core.ModAddErrors.KeyDefinitionDoesNotContainTapDefinition, key_def.with_tap_mods(.{ .left_ctrl = true }));
}

// --- hold_only ---

test "KeyDef.with_tap_mods - hold_only - expect error" {
    const key_def = core.KeyDef{ .hold_only = core.HoldDef{ .hold_modifiers = .{ .left_gui = true } } };
    try std.testing.expectEqual(core.ModAddErrors.KeyDefinitionDoesNotContainTapDefinition, key_def.with_tap_mods(.{ .left_ctrl = true }));
}

// --- tap_only ---

test "KeyDef.with_tap_mods - tap_only - with key_press - expect mods added" {
    const key_def = core.KeyDef{
        .tap_only = core.TapDef{
            .key_press = core.KeyCodeFire{
                .tap_keycode = 65,
                .tap_modifiers = .{ .left_shift = true },
            },
            .media_key = .VolumeUp,
        },
    };

    const result = try key_def.with_tap_mods(.{ .right_ctrl = true });

    try std.testing.expectEqual(core.KeyDef{
        .tap_only = core.TapDef{
            .key_press = core.KeyCodeFire{
                .tap_keycode = 65,
                .tap_modifiers = .{ .left_shift = true, .right_ctrl = true },
            },
            .media_key = .VolumeUp,
        },
    }, result);
}

test "KeyDef.with_tap_mods - tap_only - without key_press - expect error" {
    const key_def = core.KeyDef{
        .tap_only = core.TapDef{
            .key_press = null,
            .media_key = .VolumeUp,
        },
    };
    try std.testing.expectEqual(core.ModAddErrors.KeyPressNotDefinedOnTapError, key_def.with_tap_mods(.{ .left_ctrl = true }));
}

// --- tap_hold ---

test "KeyDef.with_tap_mods - tap_hold - with key_press - expect mods added" {
    const key_def = core.KeyDef{
        .tap_hold = core.TapHoldDef{
            .tap = core.TapDef{
                .key_press = core.KeyCodeFire{
                    .tap_keycode = 65,
                    .tap_modifiers = .{ .left_shift = true },
                },
            },
            .hold = core.HoldDef{ .hold_modifiers = .{ .left_ctrl = true } },
            .tapping_term = core.TimeSpan{ .ms = 200 },
        },
    };

    const result = try key_def.with_tap_mods(.{ .right_alt = true });

    try std.testing.expectEqual(core.KeyDef{
        .tap_hold = core.TapHoldDef{
            .tap = core.TapDef{
                .key_press = core.KeyCodeFire{
                    .tap_keycode = 65,
                    .tap_modifiers = .{ .left_shift = true, .right_alt = true },
                },
            },
            .hold = core.HoldDef{ .hold_modifiers = .{ .left_ctrl = true } },
            .tapping_term = core.TimeSpan{ .ms = 200 },
        },
    }, result);
}

test "KeyDef.with_tap_mods - tap_hold - without key_press - expect error" {
    const key_def = core.KeyDef{
        .tap_hold = core.TapHoldDef{
            .tap = core.TapDef{ .key_press = null },
            .hold = core.HoldDef{},
            .tapping_term = core.TimeSpan{ .ms = 200 },
        },
    };
    try std.testing.expectEqual(core.ModAddErrors.KeyPressNotDefinedOnTapError, key_def.with_tap_mods(.{ .left_ctrl = true }));
}

// --- tap_with_autofire ---

test "KeyDef.with_tap_mods - tap_with_autofire - with key_press - expect mods added" {
    const key_def = core.KeyDef{
        .tap_with_autofire = core.AutoFireDef{
            .tap = core.TapDef{
                .key_press = core.KeyCodeFire{
                    .tap_keycode = 65,
                    .tap_modifiers = .{ .left_shift = true },
                },
            },
            .initial_delay = core.TimeSpan{ .ms = 500 },
            .repeat_interval = core.TimeSpan{ .ms = 50 },
        },
    };

    const result = try key_def.with_tap_mods(.{ .right_alt = true });

    try std.testing.expectEqual(core.KeyDef{
        .tap_with_autofire = core.AutoFireDef{
            .tap = core.TapDef{
                .key_press = core.KeyCodeFire{
                    .tap_keycode = 65,
                    .tap_modifiers = .{ .left_shift = true, .right_alt = true },
                },
            },
            .initial_delay = core.TimeSpan{ .ms = 500 },
            .repeat_interval = core.TimeSpan{ .ms = 50 },
        },
    }, result);
}

test "KeyDef.with_tap_mods - tap_with_autofire - without key_press - expect error" {
    const key_def = core.KeyDef{
        .tap_with_autofire = core.AutoFireDef{
            .tap = core.TapDef{ .key_press = null },
            .initial_delay = core.TimeSpan{ .ms = 500 },
            .repeat_interval = core.TimeSpan{ .ms = 50 },
        },
    };
    try std.testing.expectEqual(core.ModAddErrors.KeyPressNotDefinedOnTapError, key_def.with_tap_mods(.{ .left_ctrl = true }));
}
