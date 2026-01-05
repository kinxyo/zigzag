// *--- IMPORTS ---*
const std = @import("std");
const io = @import("io.zig");
const cmp = @import("utils.zig").cmp;
// --- --- --- --- ---

// *--- MODES ---*
const cli = @import("cli.zig");
const tui = @import("tui.zig");
const file = @import("file.zig");
const help = @import("help.zig");
// --- --- --- --- ---

pub fn main() !void {
    var iter = std.process.args();
    _ = iter.skip();

    if (iter.next()) |f_arg| {
        if (cmp(f_arg, "help")) return help.run();
        if (cmp(f_arg, "run")) return file.run(&iter);
        return cli.run(f_arg, &iter);
    }

    return tui.run();
}
