const std = @import("std");
const shared = @import("shared");

const fmt = shared.fmt;
const Options = shared.Options;
const Http = shared.Http;

const ParsedArgs = struct {
    method: []const u8 = undefined,
    path: []const u8 = undefined,
    body: ?[]const u8 = null,
    options: Options = .{},
};

// Combinations:
// zz / -v
// zz get / -v
// zz post /msg "{...}" -h "{...}"
// zz get / -h "{...}"
fn parseArguments(first_arg: []const u8, iter: *std.process.ArgIterator) ParsedArgs {
    var pa: ParsedArgs = .{};

    var direct_path: bool = true;

    while (iter.next()) |arg| {
        if (arg[0] == '-') {
            if (pa.options.enableFlags(arg)) {
                pa.options.addHeader(iter.next(), iter.next());
            } else {
                pa.options.addHeader(arg, iter.next());
            }
            break;
        } else {
            direct_path = false;
            pa.method = first_arg;
            pa.path = arg;
            pa.body = iter.next();
        }
    }

    if (direct_path) {
        pa.method = "get";
        pa.path = first_arg;
        pa.body = iter.next();
    }

    return pa;
}

pub fn run(first_arg: []const u8, iter: *std.process.ArgIterator) void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const child_allocator = gpa.allocator();

    var arena: std.heap.ArenaAllocator = .init(child_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const pa = parseArguments(first_arg, iter);

    const method = Http.parseMethod(allocator, pa.method) catch |err| switch (err) {
        error.InvalidMethod => {
            fmt.fatal("Wrong Method: use \"get\",\"post\",\"put\",\"delete\"\n", .{});
            return;
        },
        else => {
            fmt.fatal("Failed to parse method: {any}\n", .{err});
            return;
        },
    };

    const url = Http.parseUrl(allocator, pa.path, null) catch |err| {
        fmt.fatal("Failed to prepare path: {any}\n", .{err});
        return;
    };

    const header: []const std.http.Header = Http.parseHeader(allocator, pa.options.headers) catch |err| {
        fmt.fatal("Parsing header failed: {s}\n", .{@errorName(err)});
        return;
    };

    const res_status = Http.curl(allocator, method, url, pa.body, header);

    if (pa.options.verbose_all) {
        fmt.logColored("\n{s} {s}\n", .{ @tagName(method), url }, .bold);
        if (res_status == .accepted or res_status == .created or res_status == .ok) {
            fmt.logColored("{s}\n", .{@tagName(res_status)}, .green);
        } else {
            fmt.logColored("{s}\n", .{@tagName(res_status)}, .red);
        }

        fmt.logFlush();
    }

    std.process.exit(0);
}
