const std = @import("std");

pub const PublishOptions = struct {
    zigmkay_shared_module: *std.Build.Module,
    module_name: []const u8 = "zkeycodes",
    project_root: []const u8 = ".",
    test_step_name: []const u8 = "test",
    convert_step_name: []const u8 = "convert",
    convert_all_step_name: []const u8 = "convert-all",
    target: ?std.Build.ResolvedTarget = null,
    optimize: ?std.builtin.OptimizeMode = null,
};

pub const Published = struct {
    zkeycodes_module: *std.Build.Module,
    test_step: *std.Build.Step,
    convert_step: *std.Build.Step,
    convert_all_step: *std.Build.Step,
};

pub fn publish(b: *std.Build, options: PublishOptions) Published {
    const target = options.target orelse b.standardTargetOptions(.{});
    const optimize = options.optimize orelse b.standardOptimizeOption(.{});

    const module_root_path = joinProjectPath(b, options.project_root, "root.zig");
    const labels_root_path = joinProjectPath(b, options.project_root, "src/labels.zig");

    const labels_mod = b.createModule(.{
        .root_source_file = b.path(labels_root_path),
        .target = target,
        .imports = &.{
            .{ .name = "zigmkay_shared", .module = options.zigmkay_shared_module },
        },
    });

    const mod = b.addModule(options.module_name, .{
        .root_source_file = b.path(module_root_path),
        .target = target,
    });
    mod.addImport("zigmkay_shared", options.zigmkay_shared_module);
    mod.addImport("zkeycodes_labels", labels_mod);

    const exe_root_path = joinProjectPath(b, options.project_root, "src/main.zig");

    const exe = b.addExecutable(.{
        .name = "zkeycodes",
        .root_module = b.createModule(.{
            .root_source_file = b.path(exe_root_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = options.module_name, .module = mod },
                .{ .name = "zigmkay_shared", .module = options.zigmkay_shared_module },
                .{ .name = "zkeycodes_labels", .module = labels_mod },
            },
        }),
    });

    b.installArtifact(exe);

    // Convert Step
    const convert_step = b.step(options.convert_step_name, "Convert a QMK hjson keymap to a Zig keymap file");
    const infile_opt = b.option([]const u8, "infile", "Input hjson file to convert") orelse "";
    const outfile_opt = b.option([]const u8, "outfile", "Output Zig keymap file") orelse "";

    const run_convert_cmd = b.addRunArtifact(exe);
    if (infile_opt.len > 0 and outfile_opt.len > 0) {
        run_convert_cmd.addArg(infile_opt);
        run_convert_cmd.addArg(outfile_opt);
    } else if (b.args) |args| {
        run_convert_cmd.addArgs(args);
    }

    convert_step.dependOn(&run_convert_cmd.step);

    // convert-all: read every .hjson from input/ and write the result to keycodes/.
    // Also generates keycodes/all.zig — a re-export file listing every generated layout.
    // If input/ does not exist the step is registered but does nothing.
    const convert_all_step = b.step(options.convert_all_step_name, "Convert all HJSON files in qmk_imports/ to Zig files in keycodes/");
    convert_all: {
        const input_dir_path = joinProjectPath(b, options.project_root, "qmk_imports");
        const keycodes_dir_path = joinProjectPath(b, options.project_root, "keycodes");
        var input_dir = std.fs.cwd().openDir(input_dir_path, .{ .iterate = true }) catch break :convert_all;
        defer input_dir.close();

        // Collect output filenames so we can write the all.zig export file afterward.
        var out_names = std.ArrayList([]const u8){};
        defer out_names.deinit(b.allocator);

        var iter = input_dir.iterate();
        while (iter.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".hjson")) continue;

            // Derive output filename using the same convention as extractLanguageAndVersion:
            //   keycodes_0.0.1_basic.hjson             → keycodes/keycodes.zig
            //   keycodes_german_0.0.1.hjson             → keycodes/german.zig
            //   keycodes_us_international_0.0.1.hjson  → keycodes/us_international.zig
            const out_name: []const u8 = blk: {
                if (std.mem.indexOf(u8, entry.name, "basic") != null) break :blk "keycodes.zig";
                const after = if (std.mem.startsWith(u8, entry.name, "keycodes_"))
                    entry.name["keycodes_".len..]
                else
                    entry.name;
                var lang_end: usize = after.len;
                for (after, 0..) |c, i| {
                    if (c == '.' or (c == '_' and i + 1 < after.len and std.ascii.isDigit(after[i + 1]))) {
                        lang_end = i;
                        break;
                    }
                }
                const lang = after[0..lang_end];
                if (lang.len == 0) break :blk "keycodes.zig";
                break :blk b.fmt("{s}.zig", .{lang});
            };

            const cmd = b.addRunArtifact(exe);
            cmd.addArg(b.fmt("{s}/{s}", .{ input_dir_path, entry.name }));
            cmd.addArg(b.fmt("{s}/{s}", .{ keycodes_dir_path, out_name }));
            convert_all_step.dependOn(&cmd.step);

            out_names.append(b.allocator, out_name) catch {};
        }

        // Write keycodes/all.zig — a single-import re-export of every generated layout.
        // This file is written at build-graph-construction time (i.e. when `zig build
        // convert-all` is evaluated), which is the right moment since we know all names.
        // Sort all the out_names consistently to not rely of the order of the files provided by the current environment
        const ordered_names = out_names.toOwnedSlice(b.allocator) catch @panic("error in toOwnedSlice");
        sortStringSlice(ordered_names);

        // Write keycodes/all.zig — a single-import re-export of every generated layout.
        // This file is written at build-graph-construction time (i.e. when `zig build
        // convert-all` is evaluated), which is the right moment since we know all names.
        if (ordered_names.len > 0) {
            const all_file_path = joinProjectPath(b, options.project_root, "keycodes/all.zig");
            var all_file = std.fs.cwd().createFile(all_file_path, .{}) catch break :convert_all;
            defer all_file.close();
            all_file.writeAll("// Auto-generated by zkeycodes (zig build convert-all). Do not edit by hand.\n") catch {};
            for (ordered_names) |name| {
                // Derive the module identifier from the filename stem (strip ".zig").
                const stem = if (std.mem.endsWith(u8, name, ".zig")) name[0 .. name.len - 4] else name;
                var line_buf: [256]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "pub const {s} = @import(\"{s}\");\n", .{ stem, name }) catch continue;
                all_file.writeAll(line) catch {};
            }
        } else {
            @panic("ordered_names was empty which is unexpected.");
        }
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    // Conversion generation tests
    const test_keycodes_cmd = b.addRunArtifact(exe);

    const test_us_cmd = b.addRunArtifact(exe);

    const test_ger_mac_iso_cmd = b.addRunArtifact(exe);
    test_ger_mac_iso_cmd.addArgs(&.{
        joinProjectPath(b, options.project_root, "test_data/keycodes_german_mac_iso_0.0.1.hjson"),
        joinProjectPath(b, options.project_root, "test_data/german_mac_iso.zig"),
    });

    const test_keycodes_hjson = joinProjectPath(b, options.project_root, "test_data/keycodes_0.0.1_basic.hjson");
    const test_keycodes_out = joinProjectPath(b, options.project_root, "test_data/keycodes.zig");
    const test_us_hjson = joinProjectPath(b, options.project_root, "test_data/keycodes_us_international_0.0.1.hjson");
    const test_us_out = joinProjectPath(b, options.project_root, "test_data/us_international.zig");

    test_keycodes_cmd.addArgs(&.{ test_keycodes_hjson, test_keycodes_out });
    test_us_cmd.addArgs(&.{ test_us_hjson, test_us_out });

    const gen_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(joinProjectPath(b, options.project_root, "test_generation.zig")),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigmkay_shared", .module = options.zigmkay_shared_module },
                .{ .name = "zkeycodes_labels", .module = labels_mod },
            },
        }),
    });

    gen_tests.step.dependOn(&test_keycodes_cmd.step);
    gen_tests.step.dependOn(&test_us_cmd.step);
    gen_tests.step.dependOn(&test_ger_mac_iso_cmd.step);

    const label_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(joinProjectPath(b, options.project_root, "test_labels.zig")),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigmkay_shared", .module = options.zigmkay_shared_module },
                .{ .name = "zkeycodes_labels", .module = labels_mod },
            },
        }),
    });
    label_tests.step.dependOn(&test_keycodes_cmd.step);
    label_tests.step.dependOn(&test_us_cmd.step);
    label_tests.step.dependOn(&test_ger_mac_iso_cmd.step);

    const run_gen_tests = b.addRunArtifact(gen_tests);
    const run_label_tests = b.addRunArtifact(label_tests);
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests.
    const test_step = b.step(options.test_step_name, "Run tests");
    test_step.dependOn(convert_all_step);
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_gen_tests.step);
    test_step.dependOn(&run_label_tests.step);

    return .{
        .zkeycodes_module = mod,
        .test_step = test_step,
        .convert_step = convert_step,
        .convert_all_step = convert_all_step,
    };
}

pub fn build(b: *std.Build) void {
    const zigmkay_dep = b.dependency("zigmkay", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zigmkay_shared_mod = b.createModule(.{
        .root_source_file = zigmkay_dep.path("src/shared_types.zig"),
        .target = target,
    });
    _ = publish(b, .{
        .zigmkay_shared_module = zigmkay_shared_mod,
        .target = target,
        .optimize = optimize,
    });
}

fn joinProjectPath(b: *std.Build, project_root: []const u8, sub_path: []const u8) []const u8 {
    if (project_root.len == 0 or std.mem.eql(u8, project_root, ".")) {
        return sub_path;
    }
    return b.pathJoin(&.{ project_root, sub_path });
}

// these two wer found here: https://stackoverflow.com/questions/79012210/sorting-array-of-strings-alphabetically-in-ascendending-order-in-zig
fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

fn sortStringSlice(slice: [][]const u8) void {
    std.mem.sort([]const u8, slice, {}, lessThan);
}
