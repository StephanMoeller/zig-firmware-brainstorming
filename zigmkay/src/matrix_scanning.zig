const std = @import("std");
const core = @import("core.zig");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

pub fn CreateScannerConfig(comptime keymap_dimensions: *const core.KeymapDimensions) type {
    const DirectWiredWithGroundAsOutput = struct {
        debounce: core.TimeSpan = .{ .ms = 50 },
        switch_pins: []const rp2xxx.gpio.Pin,
        pins_to_keys_mapping: *const [keymap_dimensions.key_count]?usize,
    };

    const Matrix = struct {
        debounce: core.TimeSpan = .{ .ms = 50 },
        pin_cols: []const rp2xxx.gpio.Pin,
        pin_rows: []const rp2xxx.gpio.Pin,
        pin_raise_wait_us: u64 = 30,
        pins_to_keys_mapping: *const [keymap_dimensions.key_count]?[2]usize,
    };

    return union(enum) {
        direct_wiring: DirectWiredWithGroundAsOutput,
        matrix: Matrix,
    };
}

const PinAndIndex = struct {
    col_index: usize,
    row_index: usize,
    key_index: core.KeyIndex,
};

pub fn CreateMatrixScannerType(
    comptime keymap_dimensions: *const core.KeymapDimensions,
    comptime settings: *const CreateScannerConfig(keymap_dimensions),
) type {
    switch (settings.*) {
        .matrix => |matrix_settings| {
            comptime var row_col_to_keyindex: [matrix_settings.pin_cols.len][matrix_settings.pin_rows.len]?core.KeyIndex = @splat(@splat(null));
            comptime for (matrix_settings.pins_to_keys_mapping, 0..) |pins_coordinates_or_null, key_index| {
                if (pins_coordinates_or_null) |pin_coordinates| {
                    const col_idx = pin_coordinates[0];
                    const row_idx = pin_coordinates[1];

                    if (col_idx >= matrix_settings.pin_cols.len) {
                        @compileError(std.fmt.comptimePrint("A col index {d} exceeds the total number of pin_cols provided ({d}).", .{ col_idx, matrix_settings.pin_cols.len }));
                    }
                    if (row_idx >= matrix_settings.pin_rows.len) {
                        @compileError(std.fmt.comptimePrint("A row index {d} exceeds the total number of pin_rows provided ({d}).", .{ row_idx, matrix_settings.pin_rows.len }));
                    }

                    row_col_to_keyindex[col_idx][row_idx] = key_index;
                }
            };
            return struct {
                // current_states should be a packed struct
                var current_states: [matrix_settings.pins_to_keys_mapping.len]bool = [1]bool{false} ** (matrix_settings.pins_to_keys_mapping.len);
                var current_states_last_changed: [matrix_settings.pins_to_keys_mapping.len]u64 = [1]u64{0} ** (matrix_settings.pins_to_keys_mapping.len);

                // map col+row coordinates to keymap positions

                const Self = @This();
                pub fn DetectKeyboardChanges(_: *const Self, output_queue: *core.MatrixStateChangeQueue, current_time: core.TimeSinceBoot) !void {
                    for (matrix_settings.pin_cols, 0..) |col, col_idx| {
                        col.put(1);
                        time.sleep_us(matrix_settings.pin_raise_wait_us);

                        for (matrix_settings.pin_rows, 0..) |row, row_idx| {
                            // find the key index for this combination
                            const key_index_or_null = row_col_to_keyindex[col_idx][row_idx];
                            if (key_index_or_null) |key_index| {
                                const pressed = row.read() == 1;

                                if (pressed != current_states[key_index]) {
                                    // DEBOUNCE HANDLING
                                    // This state has changed. If this happened last time very recently, this could be a debounce.
                                    // Then let it be for now. In a future tick this will be picked up and handled correctly if it is still at the current state by then.
                                    const last_changed_time = current_states_last_changed[key_index];

                                    if (current_time.time_since_boot_us - last_changed_time > matrix_settings.debounce.ms * 1000) {
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

                        col.put(0);
                    }
                    // zig fmt: off
     }
    };
        },
        else => @panic("unsupported pin settings")
    }
    
}

