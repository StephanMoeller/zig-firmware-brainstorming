const api = @import("../build_api.zig");
const kb_0 = @import("../my_keyboards/molekula/build.zig");
const kb_1 = @import("../my_keyboards/rollercole/build.zig");

/// Registers all discovered keyboard sample build plugins.
pub fn registerAll(builder: *api.KeyboardBuilder) void {
    kb_0.register(builder);
    kb_1.register(builder);
}
