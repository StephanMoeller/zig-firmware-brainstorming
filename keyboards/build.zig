const std = @import("std");

const microzig = @import("microzig");
const flash = @import("zig_flash");
const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

const KeyboardSample = struct {
    name: []const u8,
    root_source_file: []const u8,
};

const keyboard_samples = [_]KeyboardSample{
    .{ .name = "clacky_chan", .root_source_file = "my_keyboards/rollercole/clacky_chan.zig" },
    .{ .name = "lk1", .root_source_file = "my_keyboards/rollercole/leonardo_keycaprio_0_1.zig" },
    .{ .name = "lk2", .root_source_file = "my_keyboards/rollercole/leonardo_keycaprio_0_2.zig" },
    .{ .name = "lk6", .root_source_file = "my_keyboards/rollercole/leonardo_keycaprio_0_6.zig" },
    .{ .name = "encoder_demo", .root_source_file = "my_keyboards/rollercole/encoder_demo.zig" },
    .{ .name = "dasbob", .root_source_file = "examples/dasbob/main.zig" },
    .{ .name = "tuckytwotimes", .root_source_file = "my_keyboards/rollercole/tuckytwotimes.zig" },
    .{ .name = "molekula", .root_source_file = "my_keyboards/molekula/main.zig" },
};

pub fn build(b: *std.Build) void {
    const selected_keyboard = b.option([]const u8, "keyboard", keyboardOptionDescription(b)) orelse keyboard_samples[0].name;

    if (shouldPrintSamplesForListSteps(b)) {
        printAvailableSamples();
    }

    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const target = mb.ports.rp2xxx.boards.raspberrypi.pico.*; //  b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe; //b.standardOptimizeOption(.{});

    const zigmkay_dep = b.dependency("zigmkay", .{});
    const zigmkay_mod = zigmkay_dep.module("zigmkay");

    const zkeycodes_dep = b.dependency("zkeycodes", .{});
    const zkeycodes_mod = zkeycodes_dep.module("zkeycodes");

    const sample = findSample(selected_keyboard) orelse {
        printAvailableSamples();
        std.debug.panic("Unknown keyboard sample: '{s}'", .{selected_keyboard});
    };

    const firmware = mb.add_firmware(.{
        .name = "zigmkay_firmware",
        .target = &target,
        .optimize = optimize,
        .root_source_file = b.path(sample.root_source_file),
    });

    firmware.add_app_import("zigmkay", zigmkay_mod, .{ .depend_on_microzig = true });
    firmware.add_app_import("zkeycodes", zkeycodes_mod, .{ .depend_on_microzig = true });
    mb.install_firmware(firmware, .{});

    const flash_dep = b.dependency("zig_flash", .{});
    const flash_exe = flash_dep.artifact("zig_flash");

    _ = flash.addFlashStep(b, flash_exe, .{ .input_name = "zigmkay_firmware.uf2" });
}

fn keyboardOptionDescription(b: *std.Build) []const u8 {
    var sample_names: [keyboard_samples.len][]const u8 = undefined;
    inline for (keyboard_samples, 0..) |sample, idx| {
        sample_names[idx] = sample.name;
    }

    const joined_samples = std.mem.join(b.allocator, ", ", sample_names[0..]) catch @panic("Failed to build keyboard sample list");
    return std.fmt.allocPrint(
        b.allocator,
        "Keyboard sample to build/flash (use: zig build -Dkeyboard=<name>, flash: zig build flash -Dkeyboard=<name>, available: {s})",
        .{joined_samples},
    ) catch @panic("Failed to build keyboard option description");
}

fn findSample(name: []const u8) ?KeyboardSample {
    inline for (keyboard_samples) |sample| {
        if (std.mem.eql(u8, sample.name, name)) return sample;
    }
    return null;
}

fn printAvailableSamples() void {
    std.debug.print("Available keyboard samples:\n", .{});
    inline for (keyboard_samples) |sample| {
        std.debug.print("  - {s}\n", .{sample.name});
    }
    std.debug.print("zig build -Dkeyboard=<name>\t\tBuild the Firmware\n", .{});
    std.debug.print("zig build flash -Dkeyboard=<name>\tBuild & Flash the Firmware \n\n", .{});
}

fn shouldPrintSamplesForListSteps(b: *std.Build) bool {
    const args = std.process.argsAlloc(b.allocator) catch return false;
    defer std.process.argsFree(b.allocator, args);

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--list-steps")) {
            return true;
        }
    }

    return false;
}
