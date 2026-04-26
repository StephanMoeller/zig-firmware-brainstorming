const std = @import("std");
const zigmkay_build = @import("zigmkay/build.zig");
const zkeycodes_build = @import("zkeycodes/build.zig");
const keyboards_build = @import("keyboards/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigmkay = zigmkay_build.publish(b, .{
        .module_name = "zigmkay",
        .module_root_source_file = "zigmkay/src/root.zig",
        .shared_module_root_source_file = "zigmkay/src/shared_types.zig",
        .test_step_name = "zigmkay-test",
        .test_dir = "zigmkay/tests",
        .target = target,
    });

    const zkeycodes = zkeycodes_build.publish(b, .{
        .zigmkay_shared_module = zigmkay.zigmkay_shared_module,
        .module_name = "zkeycodes",
        .project_root = "zkeycodes",
        .test_step_name = "zkeycodes-test",
        .convert_step_name = "zkeycodes-convert",
        .convert_all_step_name = "zkeycodes-convert-all",
        .target = target,
        .optimize = optimize,
    });

    _ = keyboards_build.publish(b, .{
        .sample_path_prefix = "keyboards",
        .build_step_name = "keyboards-build",
        .flash_step_name = "keyboards-flash",
        .zigmkay_module = zigmkay.zigmkay_module,
        .zkeycodes_module = zkeycodes.zkeycodes_module,
    });

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(zigmkay.test_step);
    test_step.dependOn(zkeycodes.test_step);
}
