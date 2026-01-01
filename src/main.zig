// *--- IMPORTS ---*
const std = @import("std");
const io = @import("io.zig");
const utils = @import("utils.zig");
const CLI = @import("cli.zig");
// --- --- --- --- ---

// *--- ALIAS ---*
const cmp = utils.cmp;
const Args = std.process.ArgIterator;
const help = @import("help.zig").help;
// --- --- --- --- ---

pub fn main() void {
    var iter = std.process.args();
    _ = iter.skip();

    if (iter.next()) |f_arg| {
        if (cmp(f_arg, "run")) file();
        if (cmp(f_arg, "help")) help();
        cli(f_arg, &iter);
    }

    tui();
}

fn cli(f_arg: []const u8, iter: *Args) noreturn {
    var c: CLI = .init(f_arg, iter);

    c.run() catch |err| {
        std.log.err("Failed to run CLI mode.\n{s}\n", .{@errorName(err)});
        std.process.exit(1);
    };

    std.process.exit(0);
}

fn file() noreturn {
    io.print("file");
    io.flush();
    std.process.exit(0);
}

fn tui() noreturn {
    io.print("tui");
    io.flush();
    std.process.exit(0);
}
