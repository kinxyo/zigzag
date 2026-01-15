const std = @import("std");
const tui = @import("tuilip");

pub fn run() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cv: tui.Canvas = try .init(allocator);
    defer cv.deinit();

    const text: tui.Text = .{ .value = "Working in progress..." };

    _ = try cv.renderAlign(text, .right, .bottom);
    cv.flush();

    std.Thread.sleep(std.time.ns_per_s * 5);
}
