const std = @import("std");
const start = std.mem.startsWith;
const Allocator = std.mem.Allocator;
const Method = std.http.Method;
const Header = std.http.Header;
const Client = std.http.Client;
const Uri = std.Uri;
const Value = std.json.Value;
const Parsed = std.json.Parsed;

pub const MethodStrings: std.StaticStringMap(Method) = .initComptime(.{
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

pub fn lookup(method_string: []const u8) ?Method {
    if (method_string.len > 7) return null;
    var buf: [8]u8 = undefined;
    const t = std.mem.trim(u8, method_string, &std.ascii.whitespace);
    const l = lower(&buf, t);
    return MethodStrings.get(l);
}

pub fn lower(buf: []u8, s: []const u8) []const u8 {
    return std.ascii.lowerString(buf, s);
}

pub fn cmp(a: []const u8, comptime b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn parseUrl(allocator: Allocator, url_string: []const u8, port: []const u8, dev: bool) !Uri {
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

pub fn parseHeaderJson(allocator: Allocator, default_headers: []const Header, headers: []const u8) ![]const Header {
    const parse = std.json.parseFromSlice;
    const parsed: Parsed(Value) = try parse(Value, allocator, headers, .{});
    const map = parsed.value.object;

    const result = try allocator.alloc(Header, default_headers.len + map.count());

    @memcpy(result[0..default_headers.len], default_headers);

    var iter = map.iterator();

    var i: usize = default_headers.len;
    while (iter.next()) |entry| {
        const key = try allocator.dupe(u8, entry.key_ptr.*);
        const value = try allocator.dupe(u8, entry.value_ptr.string);
        result[i] = .{ .name = key, .value = value };
        i += 1;
    }

    return result;
}

pub fn getStatusCodeColor(result_status: std.http.Status) usize {
    return switch (result_status) {
        .accepted => 32,
        .@"continue" => 32,
        .created => 32,
        .found => 32,
        .ok => 32,
        else => 31,
    };
}
