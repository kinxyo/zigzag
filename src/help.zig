const std = @import("std");
const io = @import("io.zig");

pub fn run() noreturn {
    io.clearScreen();
    io.print("\n");
    io.print(logo);
    io.print("\n\n");

    io.print("  DESCRIPTION\n");
    io.print("    A fast and elegant HTTP client for API testing and development.\n");
    io.print("\n");

    io.print("  USAGE\n");
    io.print("    zz [METHOD] [URL] [OPTIONS]\n");
    io.print("    zz [COMMAND]\n");
    io.print("\n");

    io.print("  COMMANDS\n");
    io.printf("    {u} (no args)          Launch interactive TUI mode\n", .{bullet});
    io.printf("    {u} run <file.json>    Execute API collection from file\n", .{bullet});
    io.printf("    {u} help, -h, --help   Show this help message\n", .{bullet});
    io.print("\n");

    io.print("  METHODS\n");
    io.print("    get, post, put, patch, delete, head, options\n");
    io.print("    (Case insensitive. Defaults to GET if omitted)\n");
    io.print("\n");

    io.print("  OPTIONS\n");
    io.printf("    {u} -v, --verbose      Show request/response details\n", .{bullet});
    io.printf("    {u} -d, --dev          Development mode (use localhost)\n", .{bullet});
    io.printf("    {u} -h <json>          Set request headers as JSON object\n", .{bullet});
    io.printf("    {u} -b <json>          Set request body as JSON object\n", .{bullet});
    io.printf("    {u} -p <port>          Specify port (default: 8000)\n", .{bullet});
    io.print("\n");

    io.print("  EXAMPLES\n");
    io.print("    Basic requests:\n");
    io.print("      zz httpbin.org/get\n");
    io.print("      zz get https://api.github.com/users/octocat -v\n");
    io.print("\n");
    io.print("    With headers:\n");
    io.print("      zz get /api -h '{\"Authorization\":\"Bearer token\"}' -v\n");
    io.print("\n");
    io.print("    POST with body:\n");
    io.print("      zz post /msg '{\"message\":\"Hello!\"}' -v\n");
    io.print("      zz post /users -b '{\"name\":\"Alice\"}' -h '{\"Content-Type\":\"application/json\"}'\n");
    io.print("\n");
    io.print("    Development mode:\n");
    io.print("      zz /api -d -v              # Hits http://localhost:8000/api\n");
    io.print("      zz post /data '{}' -d -p 3000\n");
    io.print("\n");
    io.print("    Run collection:\n");
    io.print("      zz run tests.json\n");
    io.print("\n");

    io.print("  NOTES\n");
    io.printf("    {u} URLs without scheme default to http://\n", .{bullet});
    io.printf("    {u} Relative paths in -d mode use http://localhost:<port>\n", .{bullet});
    io.printf("    {u} JSON strings must be properly quoted in shell\n", .{bullet});
    io.print("\n");

    io.print("  MORE INFO\n");
    io.print("    Repository: https://github.com/kinxyo/zigzap\n");
    io.print("    Issues:     https://github.com/kinxyo/zigzap/issues\n");
    io.print("\n");

    io.flush();
    std.process.exit(0);
}

const bullet = '⚉';

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
    \\        ⚡ A blazing fast HTTP client built with Zig ⚡
    \\                      Version 0.8
;
