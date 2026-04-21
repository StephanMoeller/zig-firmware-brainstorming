const std = @import("std");
const microzig = @import("microzig");

/// Shared MicroZig build type used by keyboard plugins.
pub const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

/// Runtime options for publishing firmware steps.
pub const KeyboardBuilder = struct {
    b: *std.Build,
    mb: *MicroBuild,
    zigmkay_mod: *std.Build.Module,
    zkeycodes_mod: *std.Build.Module,
    flash_exe: *std.Build.Step.Compile,
    optimize: std.builtin.OptimizeMode,
    all_keyboards_step: *std.Build.Step,
    flash_step: *std.Build.Step,
    flash_targets: *std.StringHashMap(*std.Build.Step),
    keyboard_names: *std.ArrayList([]const u8),

    /// Publishes one keyboard firmware build step and its flash dependency step.
    pub fn publishFirmware(builder: *KeyboardBuilder, name: []const u8, firmware: *MicroBuild.Firmware) void {
        ensureUniqueKeyboardName(builder, name);

        const install_step = builder.mb.add_install_firmware(firmware, .{});

        const build_step = builder.b.step(name, builder.b.fmt("Build {s} keyboard firmware", .{name}));
        build_step.dependOn(&install_step.step);
        builder.all_keyboards_step.dependOn(&install_step.step);

        const run_flash = builder.b.addRunArtifact(builder.flash_exe);
        run_flash.addFileArg(firmware.get_emitted_bin(.{ .uf2 = .{} }));
        run_flash.step.dependOn(&install_step.step);

        builder.flash_targets.put(name, &run_flash.step) catch @panic("Failed to register flash step");
        builder.keyboard_names.append(builder.b.allocator, name) catch @panic("Failed to register keyboard name");
    }
};

/// Fails the build when the same keyboard name is registered twice.
fn ensureUniqueKeyboardName(builder: *KeyboardBuilder, name: []const u8) void {
    for (builder.keyboard_names.items) |existing| {
        if (std.mem.eql(u8, existing, name)) {
            std.debug.panic("Duplicate keyboard target name: {s}", .{name});
        }
    }
}
