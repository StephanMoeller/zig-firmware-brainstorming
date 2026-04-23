const std = @import("std");

pub const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const zigmkay_mod = b.addModule("zigmkay", .{
        .root_source_file = .{
            .src_path = .{ .owner = b, .sub_path = "src/root.zig" },
        },
    });
    add_test_steps(b, zigmkay_mod);
}
pub fn add_test_steps(b: *std.Build, zigmkay_module: *std.Build.Module) void {
    const global_test_compile_step = b.step("test_compile_only", "Compile unit tests");
    const global_test_run_step = b.step("test", "Run unit tests");
    const target = b.standardTargetOptions(.{});

    // START: Create test file iterator
    const test_dir = "zigmkay/tests";
    var src_dir = b.build_root.handle.openDir(test_dir, .{ .iterate = true }) catch |err|
        std.debug.panic("Failed to open '{s}': {}", .{ test_dir, err });
    defer src_dir.close();

    var walker = src_dir.walk(b.allocator) catch |err|
        std.debug.panic("Failed to walk '{s}': {}", .{ test_dir, err });
    defer walker.deinit();
    // END: Create test file iterator

    while (walker.next() catch |err| std.debug.panic("Failed to iterate '{s}': {}", .{ test_dir, err })) |entry| {
        if (entry.kind == .file and std.mem.indexOf(u8, entry.basename, "test_") != null) {
            const current_test_file_path = std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ test_dir, entry.path }) catch unreachable;

            // to ensure your test file is actually being loaded, remove the comments on the following line:
            //std.debug.print("{s}\n", .{current_test_file_path});

            const current_test_file_module = b.createModule(.{
                .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = current_test_file_path } },
                .target = target,
            });
            current_test_file_module.addImport("zigmkay", zigmkay_module);

            const current_test_exe = b.addTest(.{ .root_module = current_test_file_module });
            global_test_compile_step.dependOn(&current_test_exe.step);

            const current_test_run = b.addRunArtifact(current_test_exe);
            global_test_run_step.dependOn(&current_test_run.step);
        }
    }
}
