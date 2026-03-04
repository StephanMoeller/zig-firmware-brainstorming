const std = @import("std");
const zigmkay = @import("zigmkay");
const keycodes = zigmkay.keycodes;
const core = zigmkay.core;

test "basic keycodes have correct hex values" {
    try std.testing.expectEqual(@as(comptime_int, 0x0004), keycodes.basic.KC_A);
    try std.testing.expectEqual(@as(comptime_int, 0x0005), keycodes.basic.KC_B);
    try std.testing.expectEqual(@as(comptime_int, 0x001D), keycodes.basic.KC_Z);
    try std.testing.expectEqual(@as(comptime_int, 0x0028), keycodes.basic.KC_ENTER);
    try std.testing.expectEqual(@as(comptime_int, 0x002C), keycodes.basic.KC_SPACE);
}

test "basic keycode aliases resolve correctly" {
    try std.testing.expectEqual(keycodes.basic.KC_ENTER, keycodes.basic.KC_ENT);
    try std.testing.expectEqual(keycodes.basic.KC_ESCAPE, keycodes.basic.KC_ESC);
    try std.testing.expectEqual(keycodes.basic.KC_BACKSPACE, keycodes.basic.KC_BSPC);
    try std.testing.expectEqual(keycodes.basic.KC_SPACE, keycodes.basic.KC_SPC);
}

test "firmware special keycodes are accessible via internal" {
    try std.testing.expectEqual(@as(u8, 0xFC), keycodes.internal.KC_BOOT);
    try std.testing.expectEqual(@as(u8, 0xFD), keycodes.internal.KC_PRINT_STATS);
    try std.testing.expectEqual(@as(u8, 0xFE), keycodes.internal.KC_COMPANION);
    try std.testing.expectEqual(@as(u8, 0xFF), keycodes.internal.KC_SHUTDOWN_COMPANION);
}

test "special keycodes match core definitions" {
    try std.testing.expectEqual(core.special_keycode_BOOT, keycodes.internal.KC_BOOT);
    try std.testing.expectEqual(core.special_keycode_PRINT_STATS, keycodes.internal.KC_PRINT_STATS);
}

test "modifier keycodes exist" {
    try std.testing.expectEqual(@as(comptime_int, 0x00E0), keycodes.modifiers.KC_LEFT_CTRL);
    try std.testing.expectEqual(@as(comptime_int, 0x00E1), keycodes.modifiers.KC_LEFT_SHIFT);
    try std.testing.expectEqual(@as(comptime_int, 0x00E6), keycodes.modifiers.KC_RIGHT_ALT);
    try std.testing.expectEqual(keycodes.modifiers.KC_RIGHT_ALT, keycodes.modifiers.KC_ALGR);
}

test "media keycodes exist" {
    try std.testing.expectEqual(@as(comptime_int, 0x00A8), keycodes.media.KC_AUDIO_MUTE);
    try std.testing.expectEqual(keycodes.media.KC_AUDIO_MUTE, keycodes.media.KC_MUTE);
}

test "system keycodes exist" {
    try std.testing.expectEqual(@as(comptime_int, 0x00A5), keycodes.system.KC_SYSTEM_POWER);
    try std.testing.expectEqual(keycodes.system.KC_SYSTEM_POWER, keycodes.system.KC_PWR);
}

test "mouse keycodes exist" {
    try std.testing.expectEqual(@as(comptime_int, 0x00D1), keycodes.mouse.KC_MS_BTN1);
    try std.testing.expectEqual(keycodes.mouse.KC_MS_BTN1, keycodes.mouse.KC_BTN1);
}

test "internal keycodes accessible" {
    try std.testing.expectEqual(@as(comptime_int, 0x0000), keycodes.internal.KC_NO);
    try std.testing.expectEqual(@as(comptime_int, 0x0001), keycodes.internal.KC_TRANSPARENT);
}

test "german keymap aliases accessible" {
    // DE_Z should map to KC_Y (QWERTZ layout)
    try std.testing.expectEqual(keycodes.basic.KC_Y, keycodes.ger.DE_Z);
    // DE_Y should map to KC_Z
    try std.testing.expectEqual(keycodes.basic.KC_Z, keycodes.ger.DE_Y);
}
