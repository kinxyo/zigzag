const std = @import("std");
const io = @import("io.zig");
const utils = @import("utils.zig");
const Allocator = std.mem.Allocator;
const Method = std.http.Method;
const Header = std.http.Header;
const Client = std.http.Client;

const CLI = @This();

allocator: std.mem.Allocator,
method: Method = undefined,
port: []const u8 = "8000",
url: []const u8 = undefined,
internal_headers: []const Header = &[1]Header{
    .{ .name = "User-Agent", .value = "zigzag" },
},
headers_json: ?[]const u8 = null,
headers_kv: std.ArrayList([]const u8) = .empty,
body: ?[]const u8 = null,
result: std.http.Status = undefined,
// flags
verbose: bool = false,
dev: bool = false,

const Flags = enum {
    h,
    hj,
    p,
    v,
    d,
};

pub fn start(allocator: std.mem.Allocator, f_arg: []const u8, iter: *std.process.ArgIterator) !void {
    var c: CLI = .{ .allocator = allocator };

    if (utils.lookup(f_arg)) |m| {
        // first arg is METHOD.
        c.method = m;
        c.url = iter.next() orelse "/";
    } else {
        // first arg is URL.
        c.method = .GET;
        c.url = f_arg;

        if (f_arg[0] == '-') {
            std.log.err("Format: <method> <url> <flags>\n", .{});
            return error.MissingMethod;
        }
    }

    while (iter.next()) |arg| {
        switch (arg[0] == '-') { // is arg a flag?
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

    return try c.run();
}

fn run(self: *CLI) !void {
    // Parse URL
    const uri = try utils.parseUrl(self.allocator, self.url, self.port, self.dev);

    // Parse Header
    const headers: []const Header = if (self.headers_json) |h|
        try utils.parseHeaderJson(self.allocator, self.internal_headers, h)
    else if (self.headers_kv.items.len > 0)
        try utils.parseHeaderKV(self.allocator, self.internal_headers, self.headers_kv)
    else
        &[_]Header{};

    // Create Client & Response Writer.
    var client: Client = .{ .allocator = self.allocator };
    var response_writer: std.Io.Writer.Allocating = .init(self.allocator);

    // Make Request
    const result = Client.fetch(&client, .{
        .location = .{ .uri = uri },
        .extra_headers = headers,
        .method = self.method,
        .payload = self.body,
        .response_writer = &response_writer.writer,
    }) catch |err| {
        std.log.err("Request failed: {s}", .{@errorName(err)});
        std.log.err("Could not connect to: {s}", .{self.url});
        return err;
    };

    // Output Result
    self.result = result.status;
    if (self.verbose) self.log();
    io.printf("{s}", .{response_writer.written()});
    io.flush();
}

fn log(self: *const CLI) void {
    defer io.flush_log();

    const code = utils.getStatusCodeColor(self.result);

    io.logf("\x1b[{d}m", .{code});
    io.logf("{s} {s}\n", .{ @tagName(self.method), self.url });
    if (self.body) |b| {
        io.logf("Body:\n{s}\n", .{b});
    }
    io.log("\x1b[0m");
}
