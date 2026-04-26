const generic_queue = @import("generic_queue.zig");
const std = @import("std");
const string_printing = @import("string_printing.zig");
const shared = @import("zigmkay_shared");

// reimport shared types for now so zigmkay logic does not break
pub const shared_types = shared;
pub const special_keycode_BOOT = shared.special_keycode_BOOT;
pub const special_keycode_PRINT_STATS = shared.special_keycode_PRINT_STATS;
pub const special_keycode_COMPANION = shared.special_keycode_COMPANION;
pub const special_keycode_SHUTDOWN_COMPANION = shared.special_keycode_SHUTDOWN_COMPANION;
pub const CUSTOM_ID_COMPANION_LOG_TOGGLE = shared.CUSTOM_ID_COMPANION_LOG_TOGGLE;
pub const CUSTOM_ID_COMPANION_SHUTDOWN = shared.CUSTOM_ID_COMPANION_SHUTDOWN;
pub const CUSTOM_ID_COMPANION_TOGGLE = shared.CUSTOM_ID_COMPANION_TOGGLE;
pub const KC_BOOT = shared.KC_BOOT;
pub const KC_PRINT_STATS = shared.KC_PRINT_STATS;
pub const KC_COMPANION = shared.KC_COMPANION;
pub const KC_SHUTDOWN_COMPANION = shared.KC_SHUTDOWN_COMPANION;
pub const KeyCodeFire = shared.KeyCodeFire;
pub const Modifiers = shared.Modifiers;
pub const KeyIndex = shared.KeyIndex;
pub const LayerIndex = shared.LayerIndex;
pub const TimeSpan = shared.TimeSpan;
pub const KeymapDimensions = shared.KeymapDimensions;
pub const MouseAction = shared.MouseAction;
pub const MediaCode = shared.MediaCode;
pub const HoldDef = shared.HoldDef;
pub const TapDef = shared.TapDef;
pub const TapHoldDef = shared.TapHoldDef;
pub const AutoFireDef = shared.AutoFireDef;
pub const KeyDef = shared.KeyDef;
pub const Side = shared.Side;
pub const Combo2Def = shared.Combo2Def;
pub const L_CTL = shared.L_CTL;
pub const R_CTL = shared.R_CTL;
pub const L_SFT = shared.L_SFT;
pub const R_SFT = shared.R_SFT;
pub const L_GUI = shared.L_GUI;
pub const R_GUI = shared.R_GUI;
pub const L_ALT = shared.L_ALT;
pub const R_ALT = shared.R_ALT;
pub const DEAD = shared.DEAD;

const queue_capacities = 250;

// Matrix events: switch press/release,
pub const UartMessage = packed struct {
    pressed: bool,
    key_index: u7,
    pub fn toByte(self: UartMessage) u8 {
        return @bitCast(self);
    }
    pub fn fromByte(byte_val: u8) UartMessage {
        return @bitCast(byte_val);
    }
};

pub const LogMessage = extern struct {
    pressed: bool,
    key_index: u8,
    layer: u8,
    modifiers: Modifiers,
    pub fn toBytes(self: LogMessage) [4]u8 {
        return @bitCast(self);
    }
    pub fn fromBytes(bytes: [4]u8) LogMessage {
        return @bitCast(bytes);
    }
};
pub const MatrixStateChange = struct { pressed: bool, key_index: KeyIndex, time: TimeSinceBoot };
pub const MatrixStateChangeQueue = generic_queue.GenericQueue(MatrixStateChange, queue_capacities);

// Media Key Codes (Consumer Page)
pub const MEDIA_VOLUME_UP: u16 = 0xE9;
pub const MEDIA_VOLUME_DOWN: u16 = 0xEA;
pub const MEDIA_MUTE: u16 = 0xE2;
pub const MEDIA_PLAY_PAUSE: u16 = 0xCD;
pub const MEDIA_NEXT_TRACK: u16 = 0xB5;
pub const MEDIA_PREV_TRACK: u16 = 0xB6;

// USB output
pub const OutputCommand = union(enum) {
    KeyCodePress: u8,
    KeyCodeRelease: u8,
    ModifiersChanged: Modifiers,
    ActivateBootMode,
    RawHidSignal: struct { signal_id: u8, data: [8]u8, len: u8 },
    ConsumerKeyPressed: MediaCode,
    ConsumerKeyReleased: MediaCode,
    MouseCommandPressed: MouseAction,
    MouseCommandReleased: MouseAction,
};
pub const OutputCommandQueue = struct {
    const QueueType = generic_queue.GenericQueue(OutputCommand, queue_capacities);
    currently_pressed_keycodes: [256]bool = [1]bool{false} ** 256,
    queue: QueueType = QueueType.Create(),
    current_mods: Modifiers = .{}, // holds the latest submitted
    pub fn Create() OutputCommandQueue {
        return OutputCommandQueue{};
    }
    pub fn dequeue(self: *OutputCommandQueue) !OutputCommand {
        return try self.queue.dequeue();
    }
    pub fn Count(self: *OutputCommandQueue) usize {
        return self.queue.Count();
    }
    pub fn has_events(self: *OutputCommandQueue) bool {
        return self.queue.Count() > 0;
    }
    pub fn go_to_boot_mode(self: *OutputCommandQueue) !void {
        try self.queue.enqueue(OutputCommand.ActivateBootMode);
    }

    pub fn tap_key(self: *OutputCommandQueue, tap: KeyCodeFire) !void {
        try press_key(self, tap);
        try release_key(self, tap);
    }
    pub fn press_key(self: *OutputCommandQueue, tap: KeyCodeFire) !void {
        if (self.currently_pressed_keycodes[tap.tap_keycode]) {
            try self.queue.enqueue(.{ .KeyCodeRelease = tap.tap_keycode });
            self.currently_pressed_keycodes[tap.tap_keycode] = false;
        }

        if (tap.tap_modifiers) |mod| {
            const temp_mods = self.current_mods.add(mod);
            try self.queue.enqueue(.{ .ModifiersChanged = temp_mods });

            try self.queue.enqueue(.{ .KeyCodePress = tap.tap_keycode });
            try self.queue.enqueue(.{ .KeyCodeRelease = tap.tap_keycode });

            try self.queue.enqueue(.{ .ModifiersChanged = self.current_mods });
        } else {
            self.currently_pressed_keycodes[tap.tap_keycode] = true;
            try self.queue.enqueue(.{ .KeyCodePress = tap.tap_keycode });
        }
    }
    pub fn release_key(self: *OutputCommandQueue, tap: KeyCodeFire) !void {
        if (tap.tap_modifiers != null) {
            return; // if modifiers exist, release has already been fire
        }
        if (self.currently_pressed_keycodes[tap.tap_keycode] == false) {
            return; // release has already been fired per #CASE 1
        }
        try self.queue.enqueue(.{ .KeyCodeRelease = tap.tap_keycode });
        self.currently_pressed_keycodes[tap.tap_keycode] = false;
    }
    pub fn get_current_modifiers(self: *OutputCommandQueue) Modifiers {
        return self.current_mods;
    }
    pub fn set_mods(self: *OutputCommandQueue, modifiers: Modifiers) !void {
        if (self.current_mods.toByte() != modifiers.toByte()) {}
        self.current_mods = modifiers;
        try self.queue.enqueue(.{ .ModifiersChanged = modifiers });
    }

    pub fn send_raw_hid_signal(self: *OutputCommandQueue, signal_id: u8, data: []const u8) !void {
        var buf: [8]u8 = [_]u8{0} ** 8;
        const len = @min(data.len, 8);
        @memcpy(buf[0..len], data[0..len]);
        try self.queue.enqueue(.{ .RawHidSignal = .{ .signal_id = signal_id, .data = buf, .len = @intCast(len) } });
    }

    pub fn print_string(self: *OutputCommandQueue, string: []u8) !void {
        try string_printing.print_string(string, self);
    }
};
pub const TimeSinceBoot = struct {
    time_since_boot_us: u64,
    pub fn from_absolute_us(time_us: u64) TimeSinceBoot {
        return .{ .time_since_boot_us = time_us };
    }
    pub fn add_us(self: *const TimeSinceBoot, delta_us: u64) TimeSinceBoot {
        return .{ .time_since_boot_us = self.time_since_boot_us + delta_us };
    }
    pub fn add_ms(self: *const TimeSinceBoot, delta_ms: u64) TimeSinceBoot {
        return .{ .time_since_boot_us = self.time_since_boot_us + delta_ms * 1000 };
    }
    pub fn add(self: *const TimeSinceBoot, delta: TimeSpan) TimeSinceBoot {
        return self.add_ms(delta.ms);
    }
    pub fn diff_us(self: *const TimeSinceBoot, other: *const TimeSinceBoot) DiffError!u64 {
        if (self.time_since_boot_us < other.time_since_boot_us) {
            return DiffError.CurrentIsEarlierThanInput;
        }
        return self.time_since_boot_us - other.time_since_boot_us;
    }
    pub fn diff_ms(self: *const TimeSinceBoot, other: *const TimeSinceBoot) DiffError!u64 {
        return try self.diff_us(other) * 1000;
    }
    pub fn up_til_ms(self: *const TimeSinceBoot, other: *const TimeSinceBoot) DiffError!u64 {
        if (self.time_since_boot_us > other.time_since_boot_us) {
            return DiffError.CurrentIsLaterThanInput;
        }
        return (other.time_since_boot_us - self.time_since_boot_us) / 1000;
    }
};

pub const DiffError = error{ CurrentIsEarlierThanInput, CurrentIsLaterThanInput };

pub const LayerActivations = struct {
    layers: [32]bool = [_]bool{false} ** 32,
    top_most_active_layer: LayerIndex = 0,
    const Self = @This();
    pub fn activate(self: *Self, layer_index: LayerIndex) void {
        if (layer_index == 0)
            return;
        self.layers[layer_index] = true;
        if (layer_index > self.top_most_active_layer) {
            self.top_most_active_layer = layer_index;
        }
    }

    pub fn deactivate(self: *Self, layer_index: LayerIndex) void {
        if (layer_index == 0)
            return;
        self.layers[layer_index] = false;
        if (layer_index == self.top_most_active_layer) {
            // now find the next top most active layer
            var counter = self.top_most_active_layer - 1;
            while (self.layers[counter] == false and counter > 0) {
                counter -= 1;
            }
            if (self.top_most_active_layer != counter) {
                self.top_most_active_layer = counter;
            }
        }
    }

    pub fn set_layer_state(self: *Self, layer_index: LayerIndex, state: bool) void {
        switch (state) {
            true => activate(self, layer_index),
            false => deactivate(self, layer_index),
        }
    }

    pub fn is_layer_active(self: *const Self, layer_index: LayerIndex) bool {
        if (layer_index == 0)
            return true;
        return self.layers[layer_index];
    }
    pub fn get_top_most_active_layer(self: *const Self) LayerIndex {
        return self.top_most_active_layer;
    }
};

/// Plugin interface for injecting keymap-specific logic into the processing pipeline.
///
/// zigmkay handles a set of built-in behaviors automatically without requiring a
/// custom handler (see processing.zig for the full list). Only define `on_event`
/// when your keymap needs logic that goes beyond the built-ins — for example,
/// activating a custom layer, chaining multiple keys, or reacting to hold events
/// in a keyboard-specific way.
///
/// A keymap with no custom logic can simply use the zero value:
///   `pub const custom_functions = core.CustomFunctions{};`
pub const CustomFunctions = struct {
    /// Optional callback invoked by the processor on every firmware event.
    /// Receives the event, a pointer to the current layer state, and the output
    /// command queue so that custom actions can enqueue USB output.
    /// Set to null (the default) when no custom logic is needed.
    on_event: ?*const fn (event: ProcessorEvent, layers: *LayerActivations, output_queue: *OutputCommandQueue) void = null,
};
pub const ProcessorEvent = union(enum) {
    Tick,
    OnMatrixChanged: struct { event: MatrixStateChange, layer: LayerIndex, modifiers: Modifiers },
    OnTapEnterBefore: struct { tap: TapDef },
    OnTapEnterAfter: struct { tap: TapDef },
    OnTapExitBefore: struct { tap: TapDef },
    OnTapExitAfter: struct { tap: TapDef },
    OnHoldEnterBefore: struct { hold: HoldDef },
    OnHoldEnterAfter: struct { hold: HoldDef },
    OnHoldExitBefore: struct { hold: HoldDef },
    OnHoldExitAfter: struct { hold: HoldDef },
};
