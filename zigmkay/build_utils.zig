const std = @import("std");

pub fn add_test_steps(
    b: *std.Build,
    zigmkay_module: *std.Build.Module,
    test_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    test_dir: []const u8,
) void {
    // START: Create test file iterator
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
            const current_test_run = b.addRunArtifact(current_test_exe);
            test_step.dependOn(&current_test_run.step);
        }
    }
}
