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

method: Method = undefined,
port: []const u8 = "8000",
url: []const u8 = undefined,
header: ?[]const u8 = null, // TODO: create method to load default headers.
body: ?[]const u8 = null,
// flags
verbose: bool = false,
dev: bool = false,

pub fn init(f_arg: []const u8, iter: *std.process.ArgIterator) CLI {
    var c: CLI = .{};

    if (utils.lookup(f_arg)) |m| {
        // first arg is METHOD.
        c.method = m;
        c.url = iter.next() orelse "/";
    } else {
        // first arg is URL.
        c.method = .GET;
        c.url = f_arg;
    }

    while (iter.next()) |arg| {
        if (cmp(arg, "-h")) {
            c.header = iter.next() orelse break;
        } else if (cmp(arg, "-p")) {
            c.port = iter.next() orelse break;
        } else if (cmp(arg, "-v")) {
            c.verbose = true;
        } else if (cmp(arg, "-d")) {
            c.dev = true;
        } else {
            if (arg[0] == '-') {
                std.log.warn("Unknown flag: `{s}`", .{arg});
                // std.process.exit(1);
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
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const child_allocator = gpa.allocator();

    var arena: std.heap.ArenaAllocator = .init(child_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var response_writer: std.Io.Writer.Allocating = .init(allocator);

    const uri = try utils.parseUrl(allocator, self.url, self.port, self.dev);

    var headers: ?[]const Header = null;

    if (self.header) |h| {
        if (h[0] == '{') {
            if (h[h.len - 1] == '}') {
                headers = try utils.parseHeaderJSON(allocator, h);
            } else {
                return error.InvalidHeaderFormat;
            }
        } else {
            headers = try utils.parseHeaderKV(allocator, h);
        }
    }
    var client: Client = .{ .allocator = allocator };

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

    if (self.verbose) self.log(utils.getStatusCodeColor(result.status));

    io.printf("{s}", .{response_writer.written()});
    io.print("\x1b[0m");
    io.flush();
}

fn log(self: *const CLI, code: usize) void {
    defer io.flushl();

    io.printfl("\x1b[{d}m", .{code});
    io.printfl("{s} {s}\n", .{ @tagName(self.method), self.url });
    if (self.body) |b| {
        io.printfl("Body:\n{s}\n", .{b});
    }
    io.printl("\x1b[0m");
}
