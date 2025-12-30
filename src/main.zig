const std = @import("std");
const shared = @import("shared");

const fmt = shared.fmt;
const Options = shared.Options;
const Http = shared.Http;

const CLI = @import("cli/run.zig");
const TUI = @import("tui/run.zig");
const FILE = @import("files/run.zig");

//  ========================================================================================
//
//            /$$
//           |__/
//  /$$$$$$$$ /$$  /$$$$$$  /$$$$$$$$  /$$$$$$   /$$$$$$
// |____ /$$/| $$ /$$__  $$|____ /$$/ |____  $$ /$$__  $$
//    /$$$$/ | $$| $$  \ $$   /$$$$/   /$$$$$$$| $$  \ $$
//   /$$__/  | $$| $$  | $$  /$$__/   /$$__  $$| $$  | $$
//  /$$$$$$$$| $$|  $$$$$$$ /$$$$$$$$|  $$$$$$$|  $$$$$$$
// |________/|__/ \____  $$|________/ \_______/ \____  $$
//                /$$  \ $$                     /$$  \ $$
//               |  $$$$$$/                    |  $$$$$$/
//                \______/                      \______/
//
//
//        ⚡Version 0.8 ⚡
//
//  ========================================================================================

const SIZE = 1024 * 8;

pub fn main() void {
    var iter: std.process.ArgIterator = std.process.args();
    _ = iter.skip();

    const first: ?[]const u8 = iter.next();

    if (first == null) TUI.run();
    // if (std.mem.eql(u8, first, "run")) FILE.run(iter.next());

    CLI.run(first.?, &iter);
}
