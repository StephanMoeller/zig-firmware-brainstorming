const std = @import("std");

const microzig = @import("microzig");

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
        "src/tests/core.test.zig",
        "src/tests/generic_queue.test.zig",
        "src/tests/grazkb.test.zig",
        "src/tests/output_command_queue.test.zig",
        "src/tests/processing.test.autofire.zig",
        "src/tests/processing.test.basics.hold_only.zig",
        "src/tests/processing.test.basics.multitap_same_keycode.zig",
        "src/tests/processing.test.basics.tap_only.zig",
        "src/tests/processing.test.basics.trans_none.zig",
        "src/tests/processing.test.boot_key.zig",
        "src/tests/processing.test.combos_single.zig",
        "src/tests/processing.test.custom_functions.zig",
        "src/tests/processing.test.known_bugs.zig",
        "src/tests/processing.test.one_shot.zig",
        "src/tests/processing.test.permissive_hold.zig",
        "src/tests/processing.test.permissive_hold_and_combos.zig",
        "src/tests/processing.test.retrotapping.zig",
        "src/tests/processing.test.rolling_keys.zig",
        "src/tests/processing.test.sides.zig",
        "src/tests/processing.test.struct_sizes.zig",
        "src/tests/processing.test.tap_hold.all_cases.zig",
        "src/tests/processing.test.tap_hold.zig",
    };

    const test_step = b.step("test", "Run unit tests");
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
        const run = b.addRunArtifact(test_exe);
        test_step.dependOn(&run.step);
    }
}
