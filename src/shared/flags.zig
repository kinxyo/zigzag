const std = @import("std");
const fmt = @import("fmt.zig");
const eql = std.mem.eql;

pub const Options = struct {
    verbose_all: bool = false,
    headers: ?[]const u8 = null,

    pub fn enableFlags(self: *Options, arg: []const u8) bool {
        if (arg[1] == 'v') {
            self.verbose_all = true;
            return true;
        }
        return false;
    }

    pub fn addHeader(self: *Options, arg: ?[]const u8, headers: ?[]const u8) void {
        if (arg == null) return;
        if (arg.?[1] != 'h') return;
        if (self.headers != null) return; // header already set.
        if (headers) |h| {
            if (h.len <= 2) {
                fmt.fatal("No headers provided.", .{});
                return;
            }

            if (h[0] == '{' and h[h.len - 1] == '}') {
                self.headers = h;
                return;
            }
        }
    }

    pub fn log(self: *const Options) void {
        std.log.info("verbose: {any}\n", .{self.verbose_all});
        if (self.headers) |h| {
            std.log.info("headers: {s}\n", .{h});
        }
    }
};
