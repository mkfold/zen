const std = @import("std");
const app = @import("./app.zig");
const logger = @import("./logger.zig");
pub const log = logger.log;

pub fn main() !void {
    try app.init();
    defer app.deinit();
    app.loop() catch |err| log.err("exited with error {}", .{err});
}
