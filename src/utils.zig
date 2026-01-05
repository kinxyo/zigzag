const std = @import("std");

pub fn trimlower(buf: []u8, s: []const u8) []const u8 {
    return std.ascii.lowerString(
        buf,
        std.mem.trim(
            u8,
            s,
            &std.ascii.whitespace,
        ),
    );
}

pub fn cmp(a: []const u8, comptime b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
