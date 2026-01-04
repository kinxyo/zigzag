const std = @import("std");
const io = @import("io.zig");
const utils = @import("utils.zig");
const cmp = utils.cmp;
const has = std.mem.containsAtLeast;
const Allocator = std.mem.Allocator;
const Method = std.http.Method;
const Header = std.http.Header;
const Client = std.http.Client;

const CLI = @This();

allocator: std.mem.Allocator,
method: Method = undefined,
port: []const u8 = "8000",
url: []const u8 = undefined,
default_header: []const Header = &[1]Header{
    .{ .name = "User-Agent", .value = "zigzag" },
},
header: ?[]const u8 = null,
header_strings: std.ArrayList([]const u8) = .empty,
body: ?[]const u8 = null,
result: std.http.Status = undefined,
// flags
verbose: bool = false,
dev: bool = false,

pub fn init(allocator: std.mem.Allocator, f_arg: []const u8, iter: *std.process.ArgIterator) CLI {
    var c: CLI = .{ .allocator = allocator };

    if (utils.lookup(f_arg)) |m| {
        // first arg is METHOD.
        c.method = m;
        c.url = iter.next() orelse "/";
    } else {
        // first arg is URL.
        c.method = .GET;
        c.url = f_arg;

        if (f_arg[0] == '-') io.panic("Missing: <method> <url>", .{});
    }

    var is_header_json: bool = false;
    var is_header_kv: bool = false;

    while (iter.next()) |arg| {
        if (cmp(arg, "-hj")) {
            if (is_header_kv) return io.panic("Can use only one header format (json/kv).", .{});
            c.header = iter.next() orelse break;
            is_header_json = true;
        } else if (cmp(arg, "-h")) {
            if (is_header_json) return io.panic("Can use only one header format (json/kv).", .{});
            const h = iter.next() orelse break;
            c.header_strings.append(allocator, h) catch @panic("Out of memory");
            is_header_kv = true;
        } else if (cmp(arg, "-p")) {
            c.port = iter.next() orelse break;
        } else if (cmp(arg, "-v")) {
            c.verbose = true;
        } else if (cmp(arg, "-d")) {
            c.dev = true;
        } else {
            if (arg[0] == '-') {
                std.log.warn("Unknown flag: `{s}`", .{arg});
            } else {
                c.body = arg;
            }
        }
    }

    return c;
}

// Examples:
// zz httpbin.org/get -v
// zz get httpbin.org/json
// zz /api -d -v  # Should hit http://localhost/api
pub fn run(self: *CLI) !void {
    if (true) return error.MyError;

    var response_writer: std.Io.Writer.Allocating = .init(self.allocator);

    const uri = try utils.parseUrl(self.allocator, self.url, self.port, self.dev);

    var headers: ?[]const Header = null;

    if (self.header) |h| {
        if (h[0] != '{' or h[h.len - 1] != '}') return error.InvalidHeaderFormat;
        headers = try utils.parseHeaderJson(self.allocator, self.default_header, h);
    } else {
        headers = self.allocator.alloc(Header, self.default_header.len + self.header_strings.items.len) catch @panic("Out of memory"); // TODO: try to not panic here.
        @memcpy(headers.?[0..self.default_header.len], self.default_header);
        var i: usize = self.default_header.len;
        for (self.header_strings.items) |h| {
            const trim = std.mem.trim(u8, h, ": ");
            if (trim.len > 2) {
                return std.log.warn("Failed to parse `{s}` header: `{s}`\n", .{ h, @errorName(error.InvalidHeaderFormat) });
            }
            headers.?[i] = h;
            i += 1;
        }
    }

    var client: Client = .{ .allocator = self.allocator };

    const result = Client.fetch(&client, .{
        .location = .{ .uri = uri },
        .extra_headers = headers orelse &[_]Header{},
        .method = self.method,
        .payload = self.body,
        .response_writer = &response_writer.writer,
    }) catch |err| {
        std.log.err("Request failed: {s}", .{@errorName(err)});
        std.log.err("Could not connect to: {s}", .{self.url});
        return err;
    };

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
