const std = @import("std");
const io = @import("io.zig");
const utils = @import("utils.zig");
const start = std.mem.startsWith;
const Allocator = std.mem.Allocator;
const Method = std.http.Method;
const Header = std.http.Header;
const Client = std.http.Client;
const Status = std.http.Status;
const Uri = std.Uri;
const Value = std.json.Value;
const Parsed = std.json.Parsed;

const Http = @This();

allocator: Allocator,
method: Method = undefined,
port: []const u8 = "8000",
url: []const u8 = undefined,
headers_json: ?[]const u8 = null,
headers_kv: std.ArrayList([]const u8) = .empty,
internal_headers: []const Header = &[_]Header{
    .{ .name = "User-Agent", .value = "zigzag" },
},
body: ?[]const u8 = null,
result: Status = undefined,
// flags
verbose: bool = false,
dev: bool = false,

// TODO: Fn for concurrent requests.

/// Make one-shot request.
pub fn fetch(self: *Http) !void {
    // Parse URL
    const uri = try parseUrl(self.allocator, self.url, self.port, self.dev);

    // Parse Header
    const headers: []const Header = if (self.headers_json) |h|
        try parseHeaderJson(self.allocator, self.internal_headers, h)
    else if (self.headers_kv.items.len > 0)
        try parseHeaderKV(self.allocator, self.internal_headers, self.headers_kv)
    else
        &[_]Header{};

    // Create Client & Response Writer.
    var client: Client = .{ .allocator = self.allocator };
    var response_writer: std.Io.Writer.Allocating = .init(self.allocator);

    if (self.method.requestHasBody() and self.body == null) return error.NoPayload;

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

/// Logs http struct.
pub fn log(self: *const Http) void {
    defer io.flush_log();

    const code = statusColor(self.result);

    io.logf("\x1b[{d}m", .{code});
    io.logf("{s} {s}\n", .{ @tagName(self.method), self.url });
    if (self.body) |b| {
        io.logfc(.bright_white, "Body:\n{s}\n", .{b});
    }
    io.log("\x1b[0m");
}

/// Returns method enum if input string is defined.
pub fn isMethod(input_string: []const u8) ?Method {
    if (input_string.len > 7) return null;
    var buf: [8]u8 = undefined;
    return MethodStrings.get(
        utils.trimlower(&buf, input_string),
    );
}

// === Private Fns ===================

const MethodStrings: std.StaticStringMap(Method) = .initComptime(.{
    .{ "get", .GET },
    .{ "g", .GET },
    .{ "post", .POST },
    .{ "p", .POST },
    .{ "put", .PUT },
    .{ "pu", .PUT },
    .{ "patch", .PATCH },
    .{ "pat", .PATCH },
    .{ "pa", .PATCH },
    .{ "delete", .DELETE },
    .{ "del", .DELETE },
    .{ "de", .DELETE },
    .{ "d", .DELETE },
});

fn parseUrl(allocator: Allocator, url_string: []const u8, port: []const u8, dev: bool) !Uri {
    var url = url_string;

    const h = "http://";
    const hs = "https://";

    if (url_string[0] == '/') {
        url = try std.fmt.allocPrint(allocator, "http://localhost:{s}{s}", .{ port, url_string });
    } else if (!start(u8, url_string, hs) and !start(u8, url_string, h)) {
        url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ if (dev) h else hs, url_string });
    }

    return try Uri.parse(url);
}

fn parseHeaderKV(allocator: Allocator, internal_headers: []const Header, external_headers: std.ArrayList([]const u8)) ![]const Header {
    const result = try allocator.alloc(Header, internal_headers.len + external_headers.items.len);

    @memcpy(result[0..internal_headers.len], internal_headers);

    var i: usize = internal_headers.len;
    for (external_headers.items) |h| {
        var t = std.mem.splitSequence(u8, h, ": ");

        const key = t.next() orelse return error.InvalidHeaderFormat;
        const value = t.next() orelse return error.InvalidHeaderFormat;

        result[i] = .{ .name = key, .value = value };
        i += 1;
    }

    return result;
}

fn parseHeaderJson(allocator: Allocator, internal_headers: []const Header, external_header: []const u8) ![]const Header {
    if (external_header[0] != '{' or external_header[external_header.len - 1] != '}') return error.InvalidHeaderFormat;

    const parse = std.json.parseFromSlice;
    const parsed: Parsed(Value) = try parse(Value, allocator, external_header, .{});
    const map = parsed.value.object;

    const result = try allocator.alloc(Header, internal_headers.len + map.count());

    @memcpy(result[0..internal_headers.len], internal_headers);

    var iter = map.iterator();

    var i: usize = internal_headers.len;
    while (iter.next()) |entry| {
        const key = try allocator.dupe(u8, entry.key_ptr.*);
        const value = try allocator.dupe(u8, entry.value_ptr.string);
        result[i] = .{ .name = key, .value = value };
        i += 1;
    }

    return result;
}

fn statusColor(result_status: Status) usize {
    return switch (result_status) {
        .accepted => 32,
        .@"continue" => 32,
        .created => 32,
        .found => 32,
        .ok => 32,
        else => 31,
    };
}
