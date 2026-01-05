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

pub fn main() !void {
    var iter = std.process.args();
    _ = iter.skip();

    if (iter.next()) |f_arg| {
        if (cmp(f_arg, "run")) return file();
        if (cmp(f_arg, "help")) return help();
        return cli(f_arg, &iter);
    }

    return tui();
}

fn cli(f_arg: []const u8, iter: *Args) !void {
    errdefer std.log.err("Failed to run CLI mode.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    defer arena.deinit();

    return try CLI.start(arena.allocator(), f_arg, iter);
}

fn file() !void {
    io.print("file");
    io.flush();
}

fn tui() !void {
    io.print("tui");
    io.flush();
}
