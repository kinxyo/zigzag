const std = @import("std");
const io = @import("io.zig");

pub fn run() noreturn {
    io.clearScreen();
    io.print("\n");
    io.print(logo);
    io.print("\n\n");
    io.print("  ━━━ Usage ━━━\n");
    io.print("  1. TUI\n");
    io.printf("\t{u} Opens up UI to get a fully features API testing tool.\n", .{bullet});
    io.printf("\t{u} No arg needed.\n", .{bullet});
    io.print("  2. FILE\n");
    io.printf("\t{u} Run the API collections defined in `.json` directly.\n", .{bullet});
    io.printf("\t{u} `run` arg needed.\n", .{bullet});
    io.print("  3. CLI\n");
    io.printf("\t{u} Case sensitive method (eg- get or GET).\n", .{bullet});
    io.printf("\t{u} Flags appear at the end.\n", .{bullet});
    io.print("\n");
    io.print(examples);
    io.print("\n");

    io.flush();
    std.process.exit(0);
}

const bullet = '⚉';

// Examples:
// zz httpbin.org/get -v
// zz get httpbin.org/json
// zz /api -d -v  # Should hit http://localhost/api
const examples =
    // ┌─┐│└┘
    \\ ┌────────────EXAMPLES─────────────┐
    \\ │ zz / -v                         │
    \\ │ zz get / -v                     │ 
    \\ │ zz post /msg "{...}" -h "{...}" │
    \\ │ zz get / -h "{...}"             │
    \\ └─────────────────────────────────┘
;
const logo =
    \\            /$$
    \\           |__/
    \\  /$$$$$$$$ /$$  /$$$$$$  /$$$$$$$$  /$$$$$$   /$$$$$$
    \\ |____ /$$/| $$ /$$__  $$|____ /$$/ |____  $$ /$$__  $$
    \\    /$$$$/ | $$| $$  \ $$   /$$$$/   /$$$$$$$| $$  \ $$
    \\   /$$__/  | $$| $$  | $$  /$$__/   /$$__  $$| $$  | $$
    \\  /$$$$$$$$| $$|  $$$$$$$ /$$$$$$$$|  $$$$$$$|  $$$$$$$
    \\ |________/|__/ \____  $$|________/ \_______/ \____  $$
    \\                /$$  \ $$                     /$$  \ $$
    \\               |  $$$$$$/                    |  $$$$$$/
    \\                \______/                      \______/
    \\
    \\
    \\        ⚡ Version 0.8 ⚡
;
