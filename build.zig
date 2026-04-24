const std = @import("std");

const build_utils = @import("zigmkay/build_utils.zig");
pub const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const zigmkay_mod = b.addModule("zigmkay", .{
        .root_source_file = .{
            .src_path = .{ .owner = b, .sub_path = "zigmkay/src/root.zig" },
        },
    });

    const test_run_step = b.step("test", "Run unit tests");
    build_utils.add_test_steps(b, zigmkay_mod, test_run_step, "zigmkay/tests");
}
