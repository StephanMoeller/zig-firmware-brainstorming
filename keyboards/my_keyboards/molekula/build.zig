const api = @import("../../build_api.zig");

/// Registers Molekula keyboard firmware steps.
pub fn register(builder: *api.KeyboardBuilder) void {
    const target = builder.mb.ports.rp2xxx.boards.raspberrypi.pico.*;

    const firmware = builder.mb.add_firmware(.{
        .name = "molekula_firmware",
        .target = &target,
        .optimize = builder.optimize,
        .root_source_file = builder.b.path("my_keyboards/molekula/main.zig"),
    });

    firmware.add_app_import("zigmkay", builder.zigmkay_mod, .{ .depend_on_microzig = true });
    firmware.add_app_import("zkeycodes", builder.zkeycodes_mod, .{ .depend_on_microzig = true });

    builder.publishFirmware("molekula", firmware);
}
