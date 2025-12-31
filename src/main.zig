const std = @import("std");
const shared = @import("shared");

const io = shared.io;
const cmp = shared.utils.cmp;

pub fn main() void {
    io.clearScreenNow();

    var iter = std.process.args();
    _ = iter.skip();

    if (iter.next()) |arg| {
        if (cmp(arg, "run")) file() else cli();
    }

    tui();
}

fn cli() noreturn {
    io.print("cli");
    io.flush();
    std.process.exit(0);
}
fn tui() noreturn {
    io.print("tui");
    io.flush();
    std.process.exit(0);
}
fn file() noreturn {
    io.print("file");
    io.flush();
    std.process.exit(0);
}
