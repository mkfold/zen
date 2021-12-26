const std = @import("std");
const app = @import("./app.zig");
const ui = @import("./ui.zig");
const render = @import("./render.zig");
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
    try render.init();

    while (w.is_open) {
        try w.begin();

        for (w.context.inputs.items) |e| {
            switch (e) {
                .key => |k| {
                    if (k.key == .escape and k.action == .press) w.is_open = false;
                },
                else => {},
            }
        }

        try w.end();
    }
}
