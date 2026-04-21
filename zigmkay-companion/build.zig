const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigmkay_dep = b.dependency("zigmkay", .{});
    const zigmkay_mod = zigmkay_dep.module("zigmkay");

    const keymap_molekula_mod = b.addModule("sample_keymap", .{
        .root_source_file = b.path("src/sample_keymap_molekula.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigmkay", .module = zigmkay_mod },
        },
    });
    addCompanionExecutable(
        b,
        b,
        keymap_molekula_mod,
        zigmkay_mod,
        target,
        optimize,
        .{ .step_name = "run-molekula" },
    );

    const keymap_clackychan_mod = b.addModule("sample_keymap", .{
        .root_source_file = b.path("src/sample_keymap_clackychan.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigmkay", .module = zigmkay_mod },
        },
    });
    addCompanionExecutable(
        b,
        b,
        keymap_clackychan_mod,
        zigmkay_mod,
        target,
        optimize,
        .{ .step_name = "run-clacky" },
    );

    const zkeymap_dep = b.dependency("zkeymap", .{ .target = target, .optimize = optimize });
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/components/layout.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("zigmkay", zigmkay_mod);
    tests.root_module.addImport("zkeymap", zkeymap_dep.module("zkeymap"));

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run component tests");
    test_step.dependOn(&run_tests.step);
}

pub const CompanionOptions = struct {
    exe_name: []const u8 = "zigmkay_companion",
    step_name: []const u8 = "run-companion",
};

pub fn addCompanionExecutable(
    b_host: *std.Build,
    b_companion: *std.Build,
    keymap_mod: *std.Build.Module,
    zigmkay_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: CompanionOptions,
) void {
    const exe = b_host.addExecutable(.{
        .name = options.exe_name,
        .root_module = b_host.createModule(.{
            .root_source_file = b_companion.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b_host.installArtifact(exe);

    const run_step = b_host.step(options.step_name, "Run the app");

    const run_cmd = b_host.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b_host.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b_host.args) |args| {
        run_cmd.addArgs(args);
    }

    const dvui_dep = b_companion.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .sdl3 });
    exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
    exe.root_module.addImport("sdl-backend", dvui_dep.module("sdl3"));

    exe.root_module.addImport("keymap", keymap_mod);
    exe.root_module.addImport("zigmkay", zigmkay_mod);

    const zkeymap_dep = b_companion.dependency("zkeymap", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zkeymap", zkeymap_dep.module("zkeymap"));

    const icon_dep = b_companion.dependency("icons", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("icons", icon_dep.module("icons"));
}
