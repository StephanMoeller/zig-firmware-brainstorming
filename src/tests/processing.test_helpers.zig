const zigmkay = @import("zigmkay");
const core = zigmkay.core;

const no_combos: [0]core.Combo2Def = [0]core.Combo2Def{};
fn on_event(e: core.ProcessorEvent, layers: *core.LayerActivations, output_queue: *core.OutputCommandQueue) void {
    _ = e;
    _ = layers;
    _ = output_queue;
}

const no_functions: core.CustomFunctions = .{ .on_event = on_event };
pub fn init_test_full(
    comptime keymap_dimensions: core.KeymapDimensions,
    comptime keymap: *const [keymap_dimensions.layer_count][keymap_dimensions.key_count]core.KeyDef,
    comptime combos: []const core.Combo2Def,
    comptime custom_functions: *const core.CustomFunctions,
    comptime sides: [keymap_dimensions.key_count]core.Side,
) type {
    const ProcessorType = zigmkay.processing.CreateProcessorType(
        keymap_dimensions,
        keymap,
        sides,
        combos,
        custom_functions,
    );
    return struct {
        const Self = @This();
        matrix_change_queue: zigmkay.core.MatrixStateChangeQueue = zigmkay.core.MatrixStateChangeQueue.Create(),
        actions_queue: zigmkay.core.OutputCommandQueue = zigmkay.core.OutputCommandQueue.Create(),
        _inner_processor: ?ProcessorType = null,
        pub fn press_key(self: *Self, key_index: zigmkay.core.KeyIndex, time: core.TimeSinceBoot) !void {
            if (self._inner_processor == null)
                self._inner_processor = ProcessorType{ .input_matrix_changes = &self.matrix_change_queue, .output_usb_commands = &self.actions_queue };
            try self.matrix_change_queue.enqueue(.{ .time = time, .pressed = true, .key_index = key_index });
        }
        pub fn release_key(self: *Self, key_index: zigmkay.core.KeyIndex, time: core.TimeSinceBoot) !void {
            if (self._inner_processor == null)
                self._inner_processor = ProcessorType{ .input_matrix_changes = &self.matrix_change_queue, .output_usb_commands = &self.actions_queue };
            try self.matrix_change_queue.enqueue(.{ .time = time, .pressed = false, .key_index = key_index });
        }
        pub fn process(self: *Self, time: core.TimeSinceBoot) !void {
            if (self._inner_processor == null)
                self._inner_processor = ProcessorType{ .input_matrix_changes = &self.matrix_change_queue, .output_usb_commands = &self.actions_queue };
            try self._inner_processor.?.Process(time);
        }

        /// Dequeues the next output command, automatically skipping any
        /// RAWHID_SIGNAL_KEY_EVENT signals that are emitted unconditionally
        /// by the processing pipeline for companion app telemetry.
        /// Use this in tests that only care about USB key/modifier output.
        pub fn dequeue(self: *Self) !core.OutputCommand {
            while (true) {
                const cmd = try self.actions_queue.dequeue();
                switch (cmd) {
                    .RawHidSignal => |sig| {
                        if (sig.signal_id == core.RAWHID_SIGNAL_KEY_EVENT) continue;
                        return cmd;
                    },
                    else => return cmd,
                }
            }
        }

        /// Returns the number of queued output commands, excluding
        /// RAWHID_SIGNAL_KEY_EVENT telemetry signals.
        pub fn count_non_key_events(self: *Self) usize {
            var count: usize = 0;
            const all = self.actions_queue.queue.peek_all();
            for (all) |cmd| {
                switch (cmd) {
                    .RawHidSignal => |sig| {
                        if (sig.signal_id != core.RAWHID_SIGNAL_KEY_EVENT) count += 1;
                    },
                    else => count += 1,
                }
            }
            return count;
        }
    };
}
pub fn init_test_with_combos(
    comptime keymap_dimensions: core.KeymapDimensions,
    comptime keymap: *const [keymap_dimensions.layer_count][keymap_dimensions.key_count]core.KeyDef,
    comptime combos: []const core.Combo2Def,
) type {
    return init_test_full(keymap_dimensions, keymap, combos, &no_functions, @splat(.L));
}
pub fn init_test(
    comptime keymap_dimensions: core.KeymapDimensions,
    comptime keymap: *const [keymap_dimensions.layer_count][keymap_dimensions.key_count]core.KeyDef,
) type {
    return init_test_full(keymap_dimensions, keymap, no_combos[0..], &no_functions, @splat(.L));
}

pub fn init_test_with_sides(
    comptime keymap_dimensions: core.KeymapDimensions,
    comptime keymap: *const [keymap_dimensions.layer_count][keymap_dimensions.key_count]core.KeyDef,
    comptime sides: [keymap_dimensions.key_count]core.Side,
) type {
    return init_test_full(keymap_dimensions, keymap, no_combos[0..], &no_functions, sides);
}

pub fn ONE_SHOT_LAYER(layer: u8) core.TapDef {
    return core.TapDef{ .one_shot = .{ .layer = layer } };
}
pub fn ONE_SHOT_MOD(mod: core.Modifiers) core.KeyDef {
    return core.KeyDef{ .tap_only = .{ .one_shot = .{ .hold_modifiers = mod } } };
}
pub fn TAP(keycode: u8) core.KeyDef {
    return core.KeyDef{ .tap_only = .{ .key_press = .{ .tap_keycode = keycode } } };
}
pub fn TAP_WITH_MOD(keycode: u8, modifiers: core.Modifiers) core.KeyDef {
    return core.KeyDef{ .tap_only = .{ .key_press = .{ .tap_keycode = keycode, .tap_modifiers = modifiers } } };
}
pub fn HOLD_MOD(modifiers: core.Modifiers) core.KeyDef {
    return core.KeyDef{ .hold_only = .{ .hold_modifiers = modifiers } };
}
pub fn MO(layer: core.LayerIndex) core.KeyDef {
    return core.KeyDef{ .hold_only = .{ .hold_layer = layer } };
}
pub fn LT(layer: core.LayerIndex, tap_keycode: u8, tap_modifiers: core.Modifiers, tapping_term: core.TimeSpan) core.KeyDef {
    return core.KeyDef{ .tap_hold = .{
        .tap = .{ .key_press = .{ .tap_keycode = tap_keycode, .tap_modifiers = tap_modifiers } },
        .hold = .{ .hold_layer = layer },
        .tapping_term = tapping_term,
        .retro_tapping = false,
    } };
}
pub fn MT(tap: core.TapDef, hold_mods: core.Modifiers, tapping_term: core.TimeSpan) core.KeyDef {
    return core.KeyDef{ .tap_hold = .{
        .tap = tap,
        .hold = core.HoldDef{ .hold_modifiers = hold_mods },
        .tapping_term = tapping_term,
        .retro_tapping = false,
    } };
}
pub fn NONE() core.KeyDef {
    return core.KeyDef.none;
}
pub fn TRANSPARENT() core.KeyDef {
    return core.KeyDef.transparent;
}
