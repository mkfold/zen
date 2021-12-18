const std = @import("std");
const app = @import("./app.zig");
const ui = @import("./ui.zig");
const logger = @import("./logger.zig");
pub const log = logger.log;

pub fn main() !void {
    logger.init();
    defer logger.deinit();

    try app.init();
    defer app.deinit();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = &arena.allocator;

    var w = try app.Window.init(alloc);
    defer w.deinit();

    try w.setup();
    while (w.context.state != .dead) {
        try w.begin();

        try w.end();
    }
}
