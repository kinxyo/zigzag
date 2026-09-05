# zigzag: porting from Zig 0.15.2 to 0.16.0

Every "after" snippet below was compiled and run against the installed 0.16.0 std
before being written down. Nothing here is guessed.

## The one idea behind all of it

In 0.15 you already pass an `Allocator` into anything that heap-allocates.
0.16 does the same thing for I/O: anything that can *block* or is
*nondeterministic* (files, sockets, sleeping, spawning) now takes an `Io`.

```zig
// 0.15 mental model
fn foo(gpa: Allocator) !void

// 0.16 mental model
fn foo(gpa: Allocator, io: Io) !void
```

`Io` is a vtable + context, exactly like `Allocator`. std ships several
implementations. `Io.Threaded` is the finished one (blocking syscalls, a thread
pool for `async`). `Io.Evented` (stackful coroutines over io_uring / kqueue /
GCD) is experimental and has no networking yet.

Why bother? Because it makes async colorless. Your function signature does not
say whether it runs on threads or coroutines. The caller picks that once, at the
top of the program, by choosing which `Io` to hand down. There is no `async` or
`await` keyword anymore and there will not be one. Async is std's concern, not
the compiler's.

The practical consequence for zigzag: an `Io` has to reach every place that
touches stdin/stdout, reads a file, or opens a socket. That is `io.zig`,
`file.zig`, and `http.zig`. And `main` is where the `Io` comes from.

Everything else in the language changed less than it looks. `ArrayList`,
`Io.Writer.Allocating`, `std.json`, `StaticStringMap`, `std.log`, `std.Uri`,
`process.exit`, and your `build.zig` all still work as written.

---

## 1. `main` and where `Io` comes from

### Before (`src/main.zig`)

```zig
pub fn main() !void {
    var iter = std.process.args();
    _ = iter.skip();
    ...
}
```

### After

```zig
pub fn main(init: std.process.Init) !void {
    const io = init.io;              // the Io for the whole program
    const gpa = init.gpa;            // general purpose, leak-checked in Debug
    const arena = init.arena.allocator(); // process-lifetime arena, freed at exit

    var iter = init.minimal.args.iterate();
    _ = iter.skip();
    ...
}
```

`main` can now take one parameter of type `std.process.Init`. `start.zig`
inspects the signature at comptime and, if it sees `Init`, builds all of this
for you before calling `main`:

| field           | what it is                                                     |
|-----------------|----------------------------------------------------------------|
| `io`            | a ready `Io.Threaded` (or the right default for the target)    |
| `gpa`           | `DebugAllocator` in Debug, `smp_allocator` / `c_allocator` otherwise |
| `arena`         | `*ArenaAllocator` living for the whole process                 |
| `minimal.args`  | argv, as an `Args` value                                       |
| `minimal.environ` | environment block                                            |
| `environ_map`   | parsed env map                                                 |

Zero-parameter `main` still works. `Init.Minimal` also works as the parameter
if you want args and environ but want to build your own `Io` and allocators.

What Zig is enforcing: there is no global `Io`, so there is no way to do I/O
without someone handing you one. `Init` is the sanctioned root of that chain.

### Args

`std.process.ArgIterator` and `std.process.args()` are gone. Args are a value
(`std.process.Args`) inside `Init.minimal`. You get an iterator from it:

```zig
// before
const ArgIterator = std.process.ArgIterator;
var iter = std.process.args();

// after
const ArgIterator = std.process.Args.Iterator;
var iter = init.minimal.args.iterate();
```

`iter.next()` and `iter.skip()` are unchanged. `next()` still returns
`?[:0]const u8`. On Windows and WASI use `iterateAllocator(gpa)` and `deinit()`
instead, since those platforms need to decode argv. Linux does not.

`cli.run` and `file.run` take `*ArgIterator`; only the type alias changes.

---

## 2. Allocators: stop building your own

### Before (`src/cli.zig`, `src/file.zig`)

```zig
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
defer _ = gpa.deinit();
var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
defer arena.deinit();
const allocator = arena.allocator();
```

### After

`std.heap.GeneralPurposeAllocator` no longer exists as a name. The type it
aliased is `std.heap.DebugAllocator`. But you do not need it: `Init` already
made one and hands it to you as `init.gpa`, with leak detection in Debug.

Cleanest shape for zigzag: `main` passes what each mode needs.

```zig
// main.zig
if (cmp(f_arg, "run")) return file.run(init, &iter);
return cli.run(init, f_arg, &iter);

// cli.zig
pub fn run(init: std.process.Init, first_arg: []const u8, iter: *ArgIterator) !void {
    const allocator = init.arena.allocator();
    var c: Http = .{ .allocator = allocator, .io = init.io };
    ...
}
```

If you prefer a fresh arena per run so it frees before exit, keep
`ArenaAllocator.init(init.gpa)` locally. Both are fine; the process arena is
just less code.

---

## 3. stdio and the `io.zig` wrapper

This is the one place the port is a design change rather than a rename.

### Before (`src/io.zig`)

```zig
var buffer_w: [SIZE]u8 = undefined;
var writer = std.fs.File.stdout().writer(&buffer_w);
const stdout = &writer.interface;
```

### After

`std.fs.File` is gone. It is now `std.Io.File`, and `writer` takes an `Io`:

```zig
pub fn writer(file: File, io: Io, buffer: []u8) Writer   // Io.File.Writer
pub fn reader(file: File, io: Io, buffer: []u8) Reader   // Io.File.Reader
```

The problem: a container-level `var` initialiser runs at comptime, and there is
no `Io` at comptime. So the globals cannot be initialised inline anymore. The
wrapper needs an explicit init step that receives the `Io`:

```zig
const std = @import("std");
const Io = std.Io;

const SIZE = 4 * 1024;

var buffer_r: [SIZE]u8 = undefined;
var reader: Io.File.Reader = undefined;

var buffer_w: [SIZE]u8 = undefined;
var writer: Io.File.Writer = undefined;
var stdout: *Io.Writer = undefined;

var buffer_e: [SIZE]u8 = undefined;
var writer_err: Io.File.Writer = undefined;
var stderr: *Io.Writer = undefined;

/// Call once from main before any other io.* function.
pub fn init(io: Io) void {
    reader = Io.File.stdin().reader(io, &buffer_r);
    writer = Io.File.stdout().writer(io, &buffer_w);
    writer_err = Io.File.stderr().writer(io, &buffer_e);
    stdout = &writer.interface;
    stderr = &writer_err.interface;
}
```

Then in `main`, first line: `io.init(init.io);`

Note `stdout` and `stderr` went from `const` to `var` because they are now
assigned at runtime. The `.interface` field name is unchanged, and it is still an
`*std.Io.Writer`, so `print`, `writeAll`, `flush`, and the whole rest of
`io.zig` compile untouched. Your `getStdIn()` still returns `*std.Io.Reader`.

What Zig is enforcing: the file handle alone is not enough to do I/O. The
handle says *which* fd; the `Io` says *how* to block on it.

Alternative if you dislike hidden global state: make `io.zig` a struct you
construct in `main` and pass around. More plumbing, no init-order footgun.
Given `io.zig` is already a global wrapper by design, `init(io)` is the smaller
change.

---

## 4. Reading a file

### Before (`src/file.zig`)

```zig
const content = try std.fs.cwd().readFileAlloc(allocator, file_path, MAX_SIZE);
```

### After

```zig
const content = try Io.Dir.cwd().readFileAlloc(io, file_path, allocator, .limited(MAX_SIZE));
```

Three things moved:

- `std.fs.Dir` is now `std.Io.Dir`. `cwd()` is still there.
- `io` is the first argument after `dir`, and the allocator moved after the path.
- The size cap is an `Io.Limit`, an enum over `usize` with `.unlimited` and
  `.limited(n)`. This exists so "no limit" is a named thing instead of
  `maxInt(usize)` by convention.

Full signature for reference:

```zig
pub fn readFileAlloc(dir: Dir, io: Io, sub_path: []const u8, gpa: Allocator, limit: Io.Limit) ReadFileAllocError![]u8
```

`execute` in `file.zig` therefore needs an `io` parameter, or take `Init`.

---

## 5. HTTP client

### Before (`src/http.zig`)

```zig
allocator: Allocator,
...
var client: Client = .{ .allocator = self.allocator };
```

### After

`std.http.Client` grew an `io` field, used for opening TCP connections. Add
`io: Io` to your `Http` struct and forward it:

```zig
allocator: Allocator,
io: Io,
...
var client: Client = .{ .allocator = self.allocator, .io = self.io };
defer client.deinit();
```

`Client.fetch`, `FetchOptions`, `.location = .{ .uri = ... }`, `.extra_headers`,
`.payload`, `.response_writer`, `result.status`, and
`Method.requestHasBody` are all unchanged. `Io.Writer.Allocating.init(gpa)` and
`.written()` are unchanged.

Callers (`cli.zig`, `file.zig`) now write `.{ .allocator = allocator, .io = io }`.

---

## 6. What this unlocks: the concurrent-requests TODO

`http.zig` has `// TODO: Fn for concurrent requests.` This is now a few lines
and needs no threads code of your own. Two primitives, both verified:

```zig
// Fire many, wait once. Tasks share one lifetime.
var group: Io.Group = .init;
for (requests) |*r| group.async(io, Http.fetch, .{r});
try group.await(io);

// One task, one result.
var fut = io.async(Http.fetch, .{&req});
const result = fut.await(io);
```

`io.async` means "this may run concurrently, or the implementation may just run
it inline". It cannot fail. `io.concurrent` means "this *must* run
concurrently" and can return `error.ConcurrencyUnavailable`. For a batch of
HTTP requests where you only care that they all finish, `async` is the right
one.

Cancellation is built in: `fut.cancel(io)` or `group.cancel(io)`. Under
`Io.Threaded` that signals the thread so the blocking syscall returns `EINTR`,
and the operation surfaces `error.Canceled`.

The fetch function's signature does not mention any of this. That is the
"colorless" part. The same `Http.fetch` runs sequentially in `cli.zig` and
concurrently in `file.zig` with no change to `http.zig`.

---

## 7. Things that did NOT change (so you don't go hunting)

- `std.ArrayList(T)` with `.empty` and `append(allocator, item)`. Still unmanaged
  by default; `ArrayListUnmanaged` is now just an alias.
- `std.Io.Writer.Allocating`, `.init(gpa)`, `.written()`, `.writer`.
- `std.Io.Reader` / `std.Io.Writer` and the `.interface` field on file readers.
- `std.json.parseFromSlice`, `std.json.Parsed`, `std.json.Stringify.valueAlloc`.
- `std.StaticStringMap.initComptime`.
- `std.log`. It locks stderr internally through `std.debug`, so it needs no `Io`
  from you.
- `std.process.exit`.
- `std.Uri.parse`, `std.mem.startsWith`, `std.meta.stringToEnum`.
- `build.zig` as written. Nothing in yours touches a changed API.

## 8. Language-level changes that do not affect zigzag but you should know

- `@Type` is gone, replaced by `@Int`, `@Struct`, `@Enum`, `@Union`,
  `@Pointer`, `@Fn`, `@Tuple`, `@EnumLiteral`. Matters for tuilip if it
  builds types at comptime.
- Returning the address of a local is now a compile error, not UB.
- Runtime indexing into a `@Vector` is a compile error; coerce to an array first.
- `*align(N) T` and `*T` are distinct types even when N is the natural
  alignment.
- Packed unions must have all fields the same `@bitSizeOf`, and pointers are
  banned inside packed structs and unions.
- `@cImport` is deprecated in favour of `addTranslateC` in `build.zig`.
- `std.posix` is gone. Direct syscalls live under `std.os.linux` etc., but the
  intended path is `Io`.
- `Thread.Pool`, `Thread.WaitGroup`, `Thread.ResetEvent`, `std.once`, and
  `heap.ThreadSafeAllocator` are gone. Their replacements are `Io.Group`,
  `Io.Mutex`, `Io.Condition`, `Io.Event`, and `ArenaAllocator` (now thread-safe).

---

## Checklist, file by file

- [ ] `build.zig.zon`: `.minimum_zig_version = "0.16.0"`.
- [ ] `main.zig`: `main(init: std.process.Init)`, call `io.init(init.io)`,
      `init.minimal.args.iterate()`, pass `init` into `cli.run` / `file.run`.
- [ ] `io.zig`: globals become `undefined` + `pub fn init(io: Io)`;
      `std.fs.File` becomes `Io.File`; `stdout`/`stderr` become `var`.
- [ ] `cli.zig`: drop GPA/arena boilerplate, take `init`, use
      `std.process.Args.Iterator`, set `.io` on `Http`.
- [ ] `file.zig`: same as cli, plus `Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(MAX_SIZE))`.
- [ ] `http.zig`: add `io: Io` field, forward to `Client`, `defer client.deinit()`.
- [ ] Optional: replace the concurrency TODO with `Io.Group`.
