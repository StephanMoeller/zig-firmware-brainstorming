const std = @import("std");
const core = @import("core.zig");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

pub fn CreateScannerConfig(comptime keymap_dimensions: *const core.KeymapDimensions) type {
    const DirectWiredWithGroundAsOutput = struct {
        input_pins: []const rp2xxx.gpio.Pin,
        pins_to_keys_mapping: *const [keymap_dimensions.key_count]?usize,
    };

    const Matrix = struct {
        pin_cols: []const rp2xxx.gpio.Pin,
        pin_rows: []const rp2xxx.gpio.Pin,
        pin_raise_wait_us: u64 = 30,
        pins_to_keys_mapping: *const [keymap_dimensions.key_count]?[2]usize,
    };

    const ScannerPinSettings = union(enum) {
        direct_wiring: DirectWiredWithGroundAsOutput,
        matrix: Matrix,
    };

    return struct {
        debounce: core.TimeSpan = .{ .ms = 50 },
        pin_settings: ScannerPinSettings,
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
    switch (settings.pin_settings) {
        .matrix => |pins| {
            comptime var row_col_to_keyindex: [pins.pin_cols.len][pins.pin_rows.len]?core.KeyIndex = @splat(@splat(null));
            comptime for (pins.pins_to_keys_mapping, 0..) |pins_coordinates_or_null, key_index| {
                if (pins_coordinates_or_null) |pin_coordinates| {
                    const col_idx = pin_coordinates[0];
                    const row_idx = pin_coordinates[1];

                    if (col_idx >= pin_coordinates.len) {
                        @compileError(std.fmt.comptimePrint("A col index {d} exceeds the total number of pin_cols provided ({d}).", .{ col_idx, pin_coordinates.len }));
                    }
                    if (row_idx >= pin_coordinates.len) {
                        @compileError(std.fmt.comptimePrint("A row index {d} exceeds the total number of pin_rows provided ({d}).", .{ row_idx, pin_coordinates.len }));
                    }

                    row_col_to_keyindex[col_idx][row_idx] = key_index;
                }
            };
            return struct {
                // current_states should be a packed struct
                var current_states: [pins.pins_to_keys_mapping.len]bool = [1]bool{false} ** (pins.pins_to_keys_mapping.len);
                var current_states_last_changed: [pins.pins_to_keys_mapping.len]u64 = [1]u64{0} ** (pins.pins_to_keys_mapping.len);

                // map col+row coordinates to keymap positions

                const Self = @This();
                pub fn DetectKeyboardChanges(_: *const Self, output_queue: *core.MatrixStateChangeQueue, current_time: core.TimeSinceBoot) !void {
                    for (pins.pin_cols, 0..) |col, col_idx| {
                        col.put(settings.activated_value);
                        time.sleep_us(settings.pin_raise_wait_us);

                        for (pins.pin_rows, 0..) |row, row_idx| {
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
        },
        else => @panic("unsupported pin settings")
    }
    
}

