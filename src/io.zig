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

// return the stdin instance.
pub fn getStdIn() *std.Io.Reader {
    return &reader.interface;
}

// flush stdout buffer.
pub fn flush() void {
    stdout.flush() catch {};
}

//  write bytes to stdout buffer.
pub fn print(bytes: []const u8) void {
    stdout.writeAll(bytes) catch {};
}

//  write bytes to stdout buffer.
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    stdout.print(fmt, args) catch {};
}

// flush stderr buffer.
pub fn flushl() void {
    stderr.flush() catch {};
}

//  write bytes to stderr buffer.
pub fn printl(bytes: []const u8) void {
    stderr.writeAll(bytes) catch {};
}

//  write bytes to stderr buffer.
pub fn printfl(comptime fmt: []const u8, args: anytype) void {
    stderr.print(fmt, args) catch {};
}

pub fn clearScreen() void {
    print("\x1b[2J\x1b[H");
}

pub fn clearScreenNow() void {
    clearScreen();
    flush();
}
