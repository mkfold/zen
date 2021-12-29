const std = @import("std");

pub const LogItem = struct {
    pub const Type = enum(u4) { err, warn, info, debug, editor, none };

    data: [:0]const u8,
    tag: Type,
    time: i64,
};

var _arena: std.heap.ArenaAllocator = undefined;
var log_items: std.ArrayList(LogItem) = undefined;
var log_mutex = std.Thread.Mutex{};

pub fn init() void {
    _arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = _arena.allocator();
    log_items = std.ArrayList(LogItem).init(alloc);
}

pub fn deinit() void {
    log_items.deinit();
    _arena.deinit();
}

pub const log_level: std.log.Level = .warn;

pub fn get_logs() []LogItem {
    return log_items.items;
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime fmt: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ @tagName(level) ++ "] " ++ scope_prefix;

    const msg = std.fmt.allocPrintZ(_arena.allocator(), prefix ++ fmt ++ "\n", args) catch return;

    // Print the message to stderr, silently ignoring any errors
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    log_mutex.lock();
    defer log_mutex.unlock();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.writeAll(msg) catch return;
    nosuspend log_items.append(.{
        .data = msg,
        .tag = switch (level) {
            .err => .err,
            .warn => .warn,
            .info => .info,
            .debug => .debug,
        },
        .time = std.time.milliTimestamp(),
    }) catch return;
}

// pub fn err(comptime scope: @Type(.EnumLiteral), comptime fmt: []const u8, args: anytype) void {
//     std.log.err(scope, fmt, args);
// }

// pub fn warn(comptime scope: @Type(.EnumLiteral), comptime fmt: []const u8, args: anytype) void {
//     std.log.warn(scope, fmt, args);
// }

// pub fn info(comptime scope: @Type(.EnumLiteral), comptime fmt: []const u8, args: anytype) void {
//     std.log.info(scope, fmt, args);
// }
