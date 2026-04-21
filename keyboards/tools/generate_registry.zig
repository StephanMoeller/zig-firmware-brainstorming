const std = @import("std");

/// Entry point for keyboard registry generation and validation.
pub fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const allocator = gpa_impl.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const check_only = hasCheckFlag(args);
    const build_files = try discoverKeyboardBuildFiles(allocator);
    defer freeStringList(allocator, build_files);

    const rendered = try renderRegistryFile(allocator, build_files);
    defer allocator.free(rendered);

    try std.fs.cwd().makePath("generated");
    const output_path = "generated/keyboard_registry.zig";
    const existing = readFileIfPresent(allocator, output_path) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    defer if (existing) |content| allocator.free(content);

    if (check_only) {
        if (existing) |content| {
            if (!std.mem.eql(u8, content, rendered)) {
                std.debug.print("Registry is outdated. Run: zig run tools/generate_registry.zig\n", .{});
                std.process.exit(1);
            }
            return;
        }
        std.debug.print("Registry is missing. Run: zig run tools/generate_registry.zig\n", .{});
        std.process.exit(1);
    }

    if (existing) |content| {
        if (std.mem.eql(u8, content, rendered)) {
            std.debug.print("Registry is already up to date.\n", .{});
            return;
        }
    }

    try writeFile(output_path, rendered);
    std.debug.print("Updated {s}\n", .{output_path});
}

/// Returns true when the command includes `--check`.
fn hasCheckFlag(args: []const []const u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--check")) return true;
    }
    return false;
}

/// Discovers keyboard plugin files under `my_keyboards`.
fn discoverKeyboardBuildFiles(allocator: std.mem.Allocator) ![][]const u8 {
    var result = std.ArrayList([]const u8).empty;

    var root_dir = try std.fs.cwd().openDir("my_keyboards", .{ .iterate = true });
    defer root_dir.close();

    var walker = try root_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.eql(u8, entry.basename, "build.zig")) continue;

        const rel_path = try std.fmt.allocPrint(allocator, "my_keyboards/{s}", .{entry.path});
        normalizePathSeparators(rel_path);
        try result.append(allocator, rel_path);
    }

    std.mem.sort([]const u8, result.items, {}, lessThanString);
    return result.toOwnedSlice(allocator);
}

/// Converts Windows separators to forward slashes.
fn normalizePathSeparators(path: []u8) void {
    for (path) |*ch| {
        if (ch.* == '\\') ch.* = '/';
    }
}

/// Compares two strings for stable sorting.
fn lessThanString(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}

/// Renders the generated Zig registry source.
fn renderRegistryFile(allocator: std.mem.Allocator, build_files: []const []const u8) ![]u8 {
    var output = std.ArrayList(u8).empty;
    const writer = output.writer(allocator);

    try writer.writeAll("const api = @import(\"../build_api.zig\");\n");
    for (build_files, 0..) |path, idx| {
        try writer.print("const kb_{d} = @import(\"../{s}\");\n", .{ idx, path });
    }

    try writer.writeAll("\n/// Registers all discovered keyboard sample build plugins.\n");
    try writer.writeAll("pub fn registerAll(builder: *api.KeyboardBuilder) void {\n");
    for (build_files, 0..) |_, idx| {
        try writer.print("    kb_{d}.register(builder);\n", .{idx});
    }
    try writer.writeAll("}\n");

    return output.toOwnedSlice(allocator);
}

/// Reads a whole file if it exists.
fn readFileIfPresent(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
}

/// Writes a file atomically in the current working directory.
fn writeFile(path: []const u8, content: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(content);
}

/// Releases allocated strings from a list.
fn freeStringList(allocator: std.mem.Allocator, list: [][]const u8) void {
    for (list) |item| allocator.free(item);
    allocator.free(list);
}
