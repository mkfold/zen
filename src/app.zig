const std = @import("std");

const logger = @import("./logger.zig");
const render = @import("./render.zig");
const ui = @import("./ui.zig");

const Editor = @import("./editor.zig").Editor;
const Event = @import("./app/input.zig").Event;
const Window = @import("./app/window.zig").Window;

var window: Window = undefined;
var arena: std.heap.ArenaAllocator = undefined;

pub const State = struct {
    menu_open: bool = true,
    console_open: bool = true,
    metrics_open: bool = true,
    options_open: bool = false,
    game: struct {} = undefined,
    editor: ?Editor = null,
};
var state = State{};

pub fn init() !void {
    logger.init();
    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    errdefer arena.deinit();

    window = try Window.init(arena.allocator());
    errdefer window.deinit();

    try window.setup();
    render.init();
    errdefer render.deinit();

    ui.init();
    errdefer ui.deinit();

    ui.register_cmd("editor", _init_editor) catch unreachable;
}

fn _init_editor(_: [][]const u8) void {
    if (state.editor != null) return;
    state.editor = Editor.init(arena.allocator(), arena.allocator());
}

fn handle_events(inputs: []Event) !void {
    ui.handle_events(inputs);

    for (inputs) |e| {
        switch (e) {
            .key => |k| {
                if (k.action == .press) switch (k.key) {
                    .grave_accent => {
                        state.console_open = !state.console_open or !state.menu_open;
                        state.menu_open = true;
                    },
                    .escape => {
                        state.menu_open = !state.menu_open;
                    },
                    else => {},
                };
            },
            .mouse => |m| {
                _ = m;
            },
            .cursor => |c| {
                _ = c;
            },
            .char => |c| {
                _ = c;
            },
            .scroll => |s| {
                _ = s;
            },
            else => {},
        }
    }
}

/// the main application loop <3
pub fn loop() !void {
    while (window.is_open) {
        window.poll();
        const inputs = window.context.inputs.items;
        try handle_events(inputs);
        try window.begin();

        // TODO:
        ui.begin();
        ui.show_editor(&state);
        ui.show_menu(&state);
        ui.render();

        try window.end();
    }
}

pub fn deinit() void {
    ui.deinit();
    render.deinit();
    window.deinit();
    arena.deinit();
}
