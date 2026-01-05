const std = @import("std");
const io = @import("io.zig");
const Http = @import("http.zig");
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

const Flags = enum { h, hj, p, v, d };

pub fn run(first_arg: []const u8, iter: *ArgIterator) !void {
    errdefer io.err("Failed to run CLI mode.");

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    var c: Http = .{ .allocator = allocator };

    if (Http.isMethod(first_arg)) |m| {
        c.method = m;
        c.url = iter.next() orelse "/";
    } else {
        c.method = .GET;
        c.url = first_arg;

        if (first_arg[0] == '-') {
            std.log.err("Format: <method> <url> <flags>\n", .{});
            return error.MissingMethod;
        }
    }

    while (iter.next()) |arg| {
        // is arg a flag?
        switch (arg[0] == '-') {
            false => c.body = arg,
            true => {
                if (std.meta.stringToEnum(Flags, arg[1..])) |flag| {
                    switch (flag) {
                        .h => {
                            const h = iter.next() orelse break;
                            c.headers_kv.append(allocator, h) catch @panic("Out of memory");
                        },
                        .hj => c.headers_json = iter.next() orelse break,
                        .p => c.port = iter.next() orelse break,
                        .v => c.verbose = true,
                        .d => c.dev = true,
                    }
                } else {
                    std.log.warn("Unknown flag: `{s}`", .{arg});
                    continue;
                }
            },
        }
    }

    return try c.fetch();
}
