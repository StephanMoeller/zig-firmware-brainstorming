const std = @import("std");

const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const keyboard = b.option([]const u8, "keyboard", "Keyboard name (e.g. clackychan)") orelse @panic("Please specify a -Dkeyboard parameter, eg zig build -Dkeyboard=my_keyboard_name where 'my_keyboard_name' is the name of the folder container the main.zig for the keyboard configuration");

    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const target = mb.ports.rp2xxx.boards.raspberrypi.pico.*; //  b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe; //b.standardOptimizeOption(.{});

    const zigmkay_dep = b.dependency("zigmkay", .{});
    const zigmkay_mod = zigmkay_dep.module("zigmkay");

    std.debug.print("building keyboard '{s}'\n", .{keyboard});
    const root_source_file = std.fmt.allocPrint(b.allocator, "{s}", .{keyboard}) catch @panic("Keyboard folder not found");
    const firmware = mb.add_firmware(.{
        .name = "zigmkay",
        .target = &target,
        .optimize = optimize,
        .root_source_file = b.path(root_source_file),
    });

    firmware.add_app_import("zigmkay", zigmkay_mod, .{ .depend_on_microzig = true });

    // We call this twice to demonstrate that the default binary output for
    // RP2040 is UF2, but we can also output other formats easily
    mb.install_firmware(firmware, .{});
}
