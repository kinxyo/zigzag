const std = @import("std");
const tui = @import("tuilip");

pub fn run() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cv: tui.Canvas = try .init(allocator);
    defer cv.deinit();

    const text: tui.Text = .{ .value = "Working in progress..." };

    // TODO: add enums for position for tuilip.
    try cv.renderCS(text, .{ .col = @intCast(cv.getCol() - text.value.len), .row = cv.getRow() - 1 }, .draw);
    cv.flush();

    std.Thread.sleep(std.time.ns_per_s * 5);
}
