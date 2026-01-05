//! Creating wrapper for IO operation because API keeps changing
//! but also don't wanna handle errors for it.
const std = @import("std");

const SIZE = 4 * 1024;

var buffer_r: [SIZE]u8 = undefined;
var reader = std.fs.File.stdin().reader(&buffer_r);

var buffer_w: [SIZE]u8 = undefined;
var writer = std.fs.File.stdout().writer(&buffer_w);
const stdout = &writer.interface;

var buffer_e: [SIZE]u8 = undefined;
var writer_err = std.fs.File.stderr().writer(&buffer_e);
const stderr = &writer_err.interface;

// ======== Primitives =========================|

/// return the stdin instance.
pub fn getStdIn() *std.Io.Reader {
    return &reader.interface;
}

/// flush stdout buffer.
pub fn flush() void {
    stdout.flush() catch {};
}

///  write bytes to stdout buffer.
pub fn print(bytes: []const u8) void {
    stdout.writeAll(bytes) catch {};
}

///  write bytes to stdout buffer with formatting.
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    stdout.print(fmt, args) catch {};
}

///  write bytes to stdout buffer with formatting and color.
pub fn printfc(color: Color, comptime fmt: []const u8, args: anytype) void {
    stdout.print("\x1b[{d}m", .{color}) catch {};
    stdout.print(fmt, args) catch {};
    stdout.writeAll("\x1b[{d}m") catch {};
}

/// flush stderr buffer.
pub fn flush_log() void {
    stderr.flush() catch {};
}

///  write bytes to stderr buffer.
pub fn log(bytes: []const u8) void {
    stderr.writeAll(bytes) catch {};
}

///  write bytes to stderr buffer with formatting.
pub fn logf(comptime fmt: []const u8, args: anytype) void {
    stderr.print(fmt, args) catch {};
}

///  write bytes to stderr buffer with formatting and color.
pub fn logfc(color: Color, comptime fmt: []const u8, args: anytype) void {
    stderr.print("\x1b[{d}m", .{color}) catch {};
    stderr.print(fmt, args) catch {};
    stderr.writeAll("\x1b[0m") catch {};
}

// ======== Wrapper =========================|

/// Clear screen and reset cursor
pub fn clearScreen() void {
    print("\x1b[2J\x1b[H");
}

/// Flush after clearing screen and resetting cursor.
pub fn clearScreenNow() void {
    clearScreen();
    flush();
}

/// For colored error output.
pub fn err(comptime msg: []const u8) void {
    logfc(.red, msg, .{});
    flush_log();
}

/// For colored error output with format.
pub fn errf(comptime fmt: []const u8, args: anytype) void {
    logfc(.red, fmt, args);
    flush_log();
}

// ======== Color Section =========================|

pub const Color = enum(u8) {
    reset = 0,
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,

    default = 39,

    bright_black = 90,
    bright_red = 91,
    bright_green = 92,
    bright_yellow = 93,
    bright_blue = 94,
    bright_magenta = 95,
    bright_cyan = 96,
    bright_white = 97,
};

// ======== ... =========================|
