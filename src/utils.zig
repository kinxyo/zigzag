const std = @import("std");
const start = std.mem.startsWith;

pub const MethodStrings: std.StaticStringMap(std.http.Method) = .initComptime(.{
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

pub fn lookup(METHOD_STRING: []const u8) ?std.http.Method {
    if (METHOD_STRING.len > 7) return null;
    var buf: [8]u8 = undefined;
    const METHOD = std.mem.trim(u8, METHOD_STRING, &std.ascii.whitespace);
    const method = lower(&buf, METHOD);
    return MethodStrings.get(method);
}

pub fn lower(buf: []u8, s: []const u8) []const u8 {
    return std.ascii.lowerString(buf, s);
}

pub fn cmp(a: []const u8, comptime b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn parseUri(allocator: std.mem.Allocator, url_string: []const u8, port: []const u8, dev: bool) !std.Uri {
    var url = url_string;

    const h = "http://";
    const hs = "https://";

    if (url_string[0] == '/') {
        url = try std.fmt.allocPrint(allocator, "http://localhost:{s}{s}", .{ port, url_string });
    } else if (!start(u8, url_string, hs) and !start(u8, url_string, h)) {
        url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ if (dev) h else hs, url_string });
    }

    return try std.Uri.parse(url);
}
