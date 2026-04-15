const std = @import("std");

pub const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const zkeycodes_dep = b.dependency("zkeycodes", .{});
    const zkeycodes_mod = zkeycodes_dep.module("zkeycodes");

    const zigmkay_mod = b.addModule("zigmkay", .{
        .root_source_file = .{
            .src_path = .{ .owner = b, .sub_path = "src/root.zig" },
        },
    });

    const zigmkay_internal_mod = b.createModule(.{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/root.zig" } },
    });
    zigmkay_internal_mod.addImport("zkeycodes", zkeycodes_mod);

    zigmkay_mod.addImport("zkeycodes", zkeycodes_mod);

    const test_files = &[_][]const u8{
        "test/core.zig",
        "test/generic_queue.zig",
        "test/grazkb.zig",
        "test/output_command_queue.zig",
        "test/processing_autofire.zig",
        "test/processing_basics_hold_only.zig",
        "test/processing_basics_multitap_same_keycode.zig",
        "test/processing_basics_tap_only.zig",
        "test/processing_basics_trans_none.zig",
        "test/processing_boot_key.zig",
        "test/processing_combos_single.zig",
        "test/processing_custom_functions.zig",
        "test/processing_known_bugs.zig",
        "test/processing_one_shot.zig",
        "test/processing_permissive_hold.zig",
        "test/processing_permissive_hold_and_combos.zig",
        "test/processing_retrotapping.zig",
        "test/processing_rolling_keys.zig",
        "test/processing_sides.zig",
        "test/processing_struct_sizes.zig",
        "test/processing_tap_hold.all_cases.zig",
        "test/processing_tap_hold.zig",
    };

    // compile tests only: zig build test_compile
    // compile and run tests: zig build test_compile_run
    const test_compile_step = b.step("test_compile", "Compile unit tests");
    const test_run_step = b.step("test_compile_run", "Run unit tests");

    const target = b.standardTargetOptions(.{});
    for (test_files) |path| {
        const test_file_module = b.createModule(.{
            .root_source_file = .{
                .src_path = .{ .owner = b, .sub_path = path },
            },
            .target = target,
        });
        test_file_module.addImport("zigmkay", zigmkay_internal_mod);

        const test_exe = b.addTest(.{ .root_module = test_file_module });
        const test_compile = b.addTest(.{ .root_module = test_file_module });

        const test_run = b.addRunArtifact(test_exe);
        test_run_step.dependOn(&test_run.step);
        test_compile_step.dependOn(&test_compile.step);
    }
}
