const std = @import("std");
const core = @import("core.zig");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;
pub const ScannerSettings = struct {
    debounce: core.TimeSpan,
    pin_raise_wait_us: u64 = 30,
    activated_value: u1 = 1,
};

const PinAndIndex = struct {
    col_index: usize,
    row_index: usize,
    key_index: core.KeyIndex,
};

pub fn CreateMatrixScannerType(
    comptime keymap_dimensions: core.KeymapDimensions,
    comptime pin_cols: []const rp2xxx.gpio.Pin,
    comptime pin_rows: []const rp2xxx.gpio.Pin,
    comptime pins_to_keys_mapping: [keymap_dimensions.key_count]?[2]usize,
    comptime settings: ScannerSettings,
) type {
    comptime var row_col_to_keyindex: [pin_cols.len][pin_rows.len]?core.KeyIndex = @splat(@splat(null));
    for (pins_to_keys_mapping, 0..) |pins_or_null, key_index| {
        if (pins_or_null) |pins| {
            const col_idx = pins[0];
            const row_idx = pins[1];
            row_col_to_keyindex[col_idx][row_idx] = key_index;
        }
    }
    return struct {
        // current_states should be a packed struct
        var current_states: [pins_to_keys_mapping.len]bool = [1]bool{false} ** (pins_to_keys_mapping.len);
        var current_states_last_changed: [pins_to_keys_mapping.len]u64 = [1]u64{0} ** (pins_to_keys_mapping.len);

        // map col+row coordinates to keymap positions

        const Self = @This();
        pub fn DetectKeyboardChanges(_: *const Self, output_queue: *core.MatrixStateChangeQueue, current_time: core.TimeSinceBoot) !void {
            for (pin_cols, 0..) |col, col_idx| {
                col.put(settings.activated_value);
                time.sleep_us(settings.pin_raise_wait_us);

                for (pin_rows, 0..) |row, row_idx| {
                    // find the key index for this combination
                    const key_index_or_null = row_col_to_keyindex[col_idx][row_idx];
                    if (key_index_or_null) |key_index| {
                        const pressed = row.read() == settings.activated_value;

                        if (pressed != current_states[key_index]) {
                            // DEBOUNCE HANDLING
                            // This state has changed. If this happened last time very recently, this could be a debounce.
                            // Then let it be for now. In a future tick this will be picked up and handled correctly if it is still at the current state by then.
                            const last_changed_time = current_states_last_changed[key_index];

                            if (current_time.time_since_boot_us - last_changed_time > settings.debounce.ms * 1000) {
                                current_states[key_index] = pressed;
                                current_states_last_changed[key_index] = current_time.time_since_boot_us;

                                const key_index_with_type: core.KeyIndex = @intCast(key_index);
                                try output_queue.enqueue(.{ .pressed = pressed, .key_index = key_index_with_type, .time = current_time });
                                //p.led_red.put(read_value);
                                //p.led_green.put(1 - read_value);
                                //p.led_blue.put(1);
                            }
                        }
                    }
                }

                col.put(1 - settings.activated_value);
            }
            // zig fmt: off
     }
    };
}

