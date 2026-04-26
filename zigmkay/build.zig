const std = @import("std");

pub const microzig = @import("microzig");
const build_utils = @import("build_utils.zig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub const PublishOptions = struct {
    module_name: []const u8 = "zigmkay",
    module_root_source_file: []const u8 = "src/root.zig",
    shared_module_name: []const u8 = "zigmkay_shared",
    shared_module_root_source_file: []const u8 = "src/shared_types.zig",
    test_step_name: []const u8 = "test",
    test_dir: []const u8 = "tests",
    target: ?std.Build.ResolvedTarget = null,
};

/// publish shared types in addition to the rest of zigmkay for cleaner imports
pub const Published = struct {
    zigmkay_module: *std.Build.Module,
    zigmkay_shared_module: *std.Build.Module,
    test_step: *std.Build.Step,
};

pub fn publish(b: *std.Build, options: PublishOptions) Published {
    const target = options.target orelse b.standardTargetOptions(.{});

    const zigmkay_shared_mod = b.addModule(options.shared_module_name, .{
        .root_source_file = .{
            .src_path = .{ .owner = b, .sub_path = options.shared_module_root_source_file },
        },
    });

    const zigmkay_mod = b.addModule(options.module_name, .{
        .root_source_file = .{
            .src_path = .{ .owner = b, .sub_path = options.module_root_source_file },
        },
    });
    zigmkay_mod.addImport(options.shared_module_name, zigmkay_shared_mod);

    const test_run_step = b.step(options.test_step_name, "Run zigmkay unit tests");
    build_utils.add_test_steps(b, zigmkay_mod, test_run_step, target, options.test_dir);

    return .{
        .zigmkay_module = zigmkay_mod,
        .zigmkay_shared_module = zigmkay_shared_mod,
        .test_step = test_run_step,
    };
}

pub fn build(b: *std.Build) void {
    _ = publish(b, .{});
}
