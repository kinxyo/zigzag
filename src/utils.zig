const std = @import("std");
const start = std.mem.startsWith;
const Allocator = std.mem.Allocator;
const Method = std.http.Method;
const Header = std.http.Header;
const Client = std.http.Client;
const Uri = std.Uri;

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

pub fn parseHeaderKV(allocator: Allocator, header: []const u8) ![]const Header {
    _ = allocator;
    _ = header;
    return &.{};
}

pub fn parseHeaderJSON(allocator: Allocator, header: []const u8) ![]const Header {
    var list: std.ArrayList(Header) = .empty;

    const parsed: std.json.Parsed(std.json.Value) = try std.json.parseFromSlice(std.json.Value, allocator, header, .{});
    var iter = parsed.value.object.iterator();

    while (iter.next()) |entry| {
        // TODO: may need to dupe the strings.

        const key = try allocator.dupe(u8, entry.key_ptr.*);
        const value = try allocator.dupe(u8, entry.value_ptr.string);
        try list.append(allocator, .{ .name = key, .value = value });
    }

    return try list.toOwnedSlice(allocator);
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
