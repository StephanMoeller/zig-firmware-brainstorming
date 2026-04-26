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
    .{ .name = "leonardo_keycaprio", .root_source_file = "my_keyboards/rollercole/leonardo_keycaprio.zig" },
    .{ .name = "molekula", .root_source_file = "my_keyboards/molekula/main.zig" },
};

pub const PublishOptions = struct {
    sample_path_prefix: []const u8 = "",
    build_step_name: []const u8 = "build",
    flash_step_name: []const u8 = "flash",
    zigmkay_module: *std.Build.Module,
    zkeycodes_module: *std.Build.Module,
};

pub const Published = struct {
    build_step: *std.Build.Step,
    flash_step: *std.Build.Step,
};

pub fn publish(b: *std.Build, options: PublishOptions) Published {
    const selected_keyboard = b.option([]const u8, "keyboard", keyboardOptionDescription(b)) orelse keyboard_samples[0].name;

    if (shouldPrintSamplesForListSteps(b)) {
        printAvailableSamples();
    }

    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse @panic("Failed to initialize MicroBuild");

    const target = mb.ports.rp2xxx.boards.raspberrypi.pico.*; //  b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe; //b.standardOptimizeOption(.{});

    const zigmkay_mod = options.zigmkay_module;

    const zkeycodes_mod = options.zkeycodes_module;

    const sample = findSample(selected_keyboard) orelse {
        printAvailableSamples();
        std.debug.panic("Unknown keyboard sample: '{s}'", .{selected_keyboard});
    };

    const sample_path = withPrefix(b, options.sample_path_prefix, sample.root_source_file);
    const firmware = mb.add_firmware(.{
        .name = "zigmkay_firmware",
        .target = &target,
        .optimize = optimize,
        .root_source_file = b.path(sample_path),
    });

    firmware.add_app_import("zigmkay", zigmkay_mod, .{ .depend_on_microzig = true });
    firmware.add_app_import("zkeycodes", zkeycodes_mod, .{ .depend_on_microzig = true });
    mb.install_firmware(firmware, .{});

    const flash_dep = b.dependency("zig_flash", .{});
    const flash_exe = flash_dep.artifact("zig_flash");

    const flash_step = flash.addFlashStep(b, flash_exe, .{
        .step_name = options.flash_step_name,
        .input_name = "zigmkay_firmware.uf2",
    });

    const build_step = b.step(options.build_step_name, "Build keyboard firmware");
    build_step.dependOn(b.getInstallStep());

    return .{
        .build_step = build_step,
        .flash_step = flash_step,
    };
}

fn withPrefix(b: *std.Build, prefix: []const u8, sub_path: []const u8) []const u8 {
    if (prefix.len == 0) return sub_path;
    return b.pathJoin(&.{ prefix, sub_path });
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
    std.debug.print("zig build keyboards-build -Dkeyboard=<name>\tBuild the Firmware\n", .{});
    std.debug.print("zig build keyboards-flash -Dkeyboard=<name>\tBuild & Flash the Firmware \n\n", .{});
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
