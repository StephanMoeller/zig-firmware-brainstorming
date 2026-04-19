const std = @import("std");

pub fn build(_: *std.Build) void {
    std.debug.print("Navigate into the my_keyboards folder, and run: zig build -Dkeyboard=path_to_my_main.zig", .{});
    return;
}
