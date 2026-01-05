const std = @import("std");
const io = @import("io.zig");
const Http = @import("http.zig");

const Allocator = std.mem.Allocator;
const Parsed = std.json.Parsed;
const ArgIterator = std.process.ArgIterator;

const DEFAULT_FILE_PATH = "test.json";
const MAX_SIZE = 1024 * 1024 * 1;

const API = struct {
    method: []const u8,
    path: []const u8,
    headers: ?std.json.Value = null,
    body: ?std.json.Value = null,
};

const Collection = struct {
    name: []const u8,
    baseUrl: []const u8,
    apis: []API,

    pub fn log(self: *const Collection) void {
        defer io.flush();

        io.printf("{s}\n", .{self.name});
        io.printf("{s}\n", .{self.baseUrl});

        for (self.apis) |api| {
            io.printf("{s} ", .{api.method});
            io.printf("{s}\n", .{api.path});
            if (api.headers) |h| io.printf("{any}\n", .{h});
            if (api.body) |b| io.printf("{any}\n", .{b});
        }
    }
};

pub fn run(args: *ArgIterator) !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    try execute(allocator, args.next() orelse DEFAULT_FILE_PATH);

    while (args.next()) |file_path| {
        try execute(allocator, file_path);
    }
}

fn execute(allocator: Allocator, file_path: []const u8) !void {
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, MAX_SIZE);

    const parsed: Parsed(Collection) = try std.json.parseFromSlice(Collection, allocator, content, .{});
    const c = parsed.value;

    // c.log();

    for (c.apis) |api| {
        var h: Http = .{ .allocator = allocator };
        h.method = Http.isMethod(api.method) orelse return error.InvalidMethod;
        h.url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ c.baseUrl, api.path });
        if (api.headers) |map| {
            h.headers_json = try std.json.Stringify.valueAlloc(allocator, map, .{ .whitespace = .indent_2 });
        }
        if (api.body) |map| {
            h.body = try std.json.Stringify.valueAlloc(allocator, map, .{ .whitespace = .indent_2 });
        }
        h.verbose = true;
        try h.fetch();
        io.print("\n");
        io.flush();
    }
}
