const std = @import("std");

pub fn build(_: *std.Build) void {
    std.debug.print("Navigate into the keyboards/ folder, and run: zig build -Dkeyboard=path_to_my_main.zig", .{});
    return;
}
