const std = @import("std");
const io = @import("io.zig");
const utils = @import("utils.zig");
const cmp = utils.cmp;
const has = std.mem.containsAtLeast;

const CLI = @This();

method: std.http.Method = undefined,
port: []const u8 = "8000",
url: []const u8 = undefined,
header: []const u8 = undefined, // TODO: create method to load default headers.
body: ?[]const u8 = null,
// flags
verbose: bool = false,
dev: bool = false,

/// Panics on wrong userinputs.
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
    if (self.verbose) self.log();

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const child_allocator = gpa.allocator();

    var arena: std.heap.ArenaAllocator = .init(child_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var response_writer: std.Io.Writer.Allocating = .init(allocator);

    const uri = try utils.parseUri(allocator, self.url, self.port, self.dev);

    var client: std.http.Client = .{ .allocator = allocator };

    _ = std.http.Client.fetch(&client, .{
        .location = .{ .uri = uri },
        .method = self.method,
        .payload = self.body,
        .response_writer = &response_writer.writer,
    }) catch |err| {
        std.log.err("Request failed: {s}", .{@errorName(err)});
        std.log.err("Could not connect to: {s}", .{self.url});
        return err;
    };

    io.printf("\n{s}\n", .{response_writer.written()});
    io.flush();
}

fn log(self: *const CLI) void {
    defer io.flushl();

    io.printl("\x1b[97m");
    io.printfl("{s} {s}\n", .{ @tagName(self.method), self.url });
    if (self.body) |b| {
        io.printfl("Body:\n{s}\n", .{b});
    }
    io.printl("\x1b[0m");

    io.printl("\x1b[2m");
    io.printfl("\nverbose:{any}\n", .{self.verbose});
    io.printl("\x1b[0m");
}
