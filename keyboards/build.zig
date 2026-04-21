const std = @import("std");
const registry = @import("generated/keyboard_registry.zig");
const api = @import("build_api.zig");

const MicroBuild = api.MicroBuild;

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe;

    addGenerateRegistryStep(b);

    const flash_dep = b.dependency("zig_flash", .{});
    const flash_exe = flash_dep.artifact("zig_flash");
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const zigmkay_dep = b.dependency("zigmkay", .{});
    const zigmkay_mod = zigmkay_dep.module("zigmkay");

    const zkeycodes_dep = b.dependency("zkeycodes", .{});
    const zkeycodes_mod = zkeycodes_dep.module("zkeycodes");

    const flash_step = b.step("flash", "Build and flash one or more keyboard firmwares");
    const all_keyboards_step = b.step("all", "Build all keyboard firmwares");

    var flash_targets = std.StringHashMap(*std.Build.Step).init(b.allocator);
    var keyboard_names = std.ArrayList([]const u8).empty;

    var builder = api.KeyboardBuilder{
        .b = b,
        .mb = mb,
        .zigmkay_mod = zigmkay_mod,
        .zkeycodes_mod = zkeycodes_mod,
        .flash_exe = flash_exe,
        .optimize = optimize,
        .all_keyboards_step = all_keyboards_step,
        .flash_step = flash_step,
        .flash_targets = &flash_targets,
        .keyboard_names = &keyboard_names,
    };

    registry.registerAll(&builder);
    configureFlashStep(&builder);
}

/// Adds a build step that regenerates the keyboard plugin registry.
fn addGenerateRegistryStep(b: *std.Build) void {
    const registry_tool = b.addExecutable(.{
        .name = "generate_keyboard_registry",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_registry.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });

    const generate_registry_step = b.step("generate-registry", "Generate keyboards/generated/keyboard_registry.zig");
    const run_registry_tool = b.addRunArtifact(registry_tool);
    generate_registry_step.dependOn(&run_registry_tool.step);

    if (b.args) |args| {
        run_registry_tool.addArgs(args);
    }
}

/// Configures `flash` to depend on requested keyboard flash steps.
fn configureFlashStep(builder: *api.KeyboardBuilder) void {
    if (!containsArg(builder.b, "flash")) return;

    var has_target = false;
    for (builder.keyboard_names.items) |name| {
        if (!containsArg(builder.b, name)) continue;
        const flash_target = builder.flash_targets.get(name) orelse continue;
        builder.flash_step.dependOn(flash_target);
        has_target = true;
    }

    if (!has_target) {
        const names = std.mem.join(builder.b.allocator, ", ", builder.keyboard_names.items) catch @panic("OOM");
        const error_message = std.fmt.allocPrint(
            builder.b.allocator,
            "No keyboard target passed to flash. Use: zig build flash <name>\nAvailable keyboard targets: {s}\nExamples:\n  zig build molekula\n  zig build flash molekula",
            .{names},
        ) catch @panic("OOM");

        const fail_step = builder.b.addFail(error_message);
        builder.flash_step.dependOn(&fail_step.step);
    }
}

/// Returns true when a command-line argument exists.
fn containsArg(b: *std.Build, value: []const u8) bool {
    const args = std.process.argsAlloc(b.allocator) catch return false;
    defer std.process.argsFree(b.allocator, args);

    for (args) |arg| {
        if (std.mem.eql(u8, arg, value)) return true;
    }
    return false;
}
