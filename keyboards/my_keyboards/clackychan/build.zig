const api = @import("../../build_api.zig");

/// Registers clackychan keyboard firmware steps.
pub fn register(builder: *api.KeyboardBuilder) void {
    registerVariant(builder, "clackychan", "my_keyboards/clackychan/main.zig");
    registerVariant(builder, "clackychan2", "my_keyboards/clackychan/clackychan2.zig");
}

/// Registers a single clackychan firmware variant.
fn registerVariant(builder: *api.KeyboardBuilder, name: []const u8, root_source_file: []const u8) void {
    const target = builder.mb.ports.rp2xxx.boards.raspberrypi.pico.*;

    const firmware = builder.mb.add_firmware(.{
        .name = builder.b.fmt("{s}_firmware", .{name}),
        .target = &target,
        .optimize = builder.optimize,
        .root_source_file = builder.b.path(root_source_file),
    });

    firmware.add_app_import("zigmkay", builder.zigmkay_mod, .{ .depend_on_microzig = true });
    firmware.add_app_import("zkeycodes", builder.zkeycodes_mod, .{ .depend_on_microzig = true });

    builder.publishFirmware(name, firmware);
}
