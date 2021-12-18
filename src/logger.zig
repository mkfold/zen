const std = @import("std");

var _arena: std.heap.ArenaAllocator = undefined;
var num_logs: u32 = 0;

pub fn init() void {
    _arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
}

pub fn deinit() void {
    _arena.deinit();
}

pub const log_level: std.log.Level = .warn;

pub fn log(comptime level: std.log.Level, comptime scope: @TypeOf(.EnumLiteral), comptime fmt: []const u8, args: anytype) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ @tagName(level) ++ "] " ++ scope_prefix;

    const msg = std.fmt.allocPrint(&_arena.allocator, prefix ++ fmt ++ "\n", args) catch return;

    // Print the message to stderr, silently ignoring any errors
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.writeAll(msg) catch return;
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
