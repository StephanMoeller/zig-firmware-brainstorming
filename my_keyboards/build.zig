const std = @import("std");

const microzig = @import("microzig");
const flash = @import("zig_flash");
const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const keyboard = b.option([]const u8, "keyboard", "Keyboard name (e.g. clackychan)") orelse "rollercole/clackychan.zig";

    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const target = mb.ports.rp2xxx.boards.raspberrypi.pico.*; //  b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe; //b.standardOptimizeOption(.{});

    const zigmkay_dep = b.dependency("zigmkay", .{});
    const zigmkay_mod = zigmkay_dep.module("zigmkay");

    const zkeycodes_dep = b.dependency("zkeycodes", .{});
    const zkeycodes_mod = zkeycodes_dep.module("zkeycodes");

    std.debug.print("building keyboard '{s}'\n", .{keyboard});
    const root_source_file = std.fmt.allocPrint(b.allocator, "{s}", .{keyboard}) catch @panic("Keyboard folder not found");
    const firmware = mb.add_firmware(.{
        .name = "zigmkay_firmware",
        .target = &target,
        .optimize = optimize,
        .root_source_file = b.path(root_source_file),
    });

    firmware.add_app_import("zigmkay", zigmkay_mod, .{ .depend_on_microzig = true });
    firmware.add_app_import("zkeycodes", zkeycodes_mod, .{ .depend_on_microzig = true });
    mb.install_firmware(firmware, .{});

    const flash_dep = b.dependency("zig_flash", .{});
    const flash_exe = flash_dep.artifact("zig_flash");

    _ = flash.addFlashStep(b, flash_exe, .{ .input_name = "zigmkay_firmware.uf2" });
}
