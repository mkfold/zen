const std = @import("std");

const logger = @import("./logger.zig");
const render = @import("./gl.zig");
const ui = @import("./ui.zig");

const math = @import("./math.zig");
const Vec3 = math.Vec3;

const Editor = @import("./editor.zig").Editor;
const Event = @import("./app/input.zig").Event;
const Window = @import("./app/window.zig").Window;

const asset = @import("./asset.zig");

var window: Window = undefined;
var arena: std.heap.ArenaAllocator = undefined;

pub const State = struct {
    menu_open: bool = true,
    console_open: bool = true,
    metrics_open: bool = true,
    options_open: bool = false,

    // TODO: move this to the renderer
    camera_ypr: Vec3 = math.vec3(90, 45, 0),
    camera_pos: Vec3 = math.vec3(0, 10, 8),
    camera_front: Vec3 = math.vec3(0, 0, -1),
    // camera_dir: Vec3 = math.vec3(0, 0, 0),

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
    try window.add_key_callback(handle_key);
    try window.add_key_callback(ui.handle_key);
    try window.add_mouse_callback(ui.handle_mouse);
    try window.add_cursor_callback(handle_cursor);
    try window.add_cursor_callback(ui.handle_cursor);
    try window.add_resize_callback(handle_resize);
    try window.add_resize_callback(ui.handle_resize);
    try window.add_scroll_callback(ui.handle_scroll);
    try window.add_char_input_callback(ui.handle_char);

    render.init();
    errdefer render.deinit();

    ui.init();
    errdefer ui.deinit();

    ui.register_cmd("editor", _init_editor) catch unreachable;

    try asset.load_assets("assets/");
}

fn _init_editor(_: [][]const u8) void {
    if (state.editor != null) return;
    state.editor = Editor.init(arena.allocator(), arena.allocator());
}

fn handle_key(k: Event.Keyboard) void {
    if (k.action == .press) switch (k.key) {
        .grave_accent => {
            state.console_open = !state.console_open or !state.menu_open;
            state.menu_open = true;
        },
        .escape => {
            state.menu_open = !state.menu_open;
        },
        .right_bracket => {
            state.metrics_open = !state.metrics_open;
        },
        else => {},
    };
    if (!state.menu_open) {
        if (k.action == .press or k.action == .repeat) {
            if (k.key == .w) {
                state.camera_pos.sub_(state.camera_front.muls(0.05));
            }
            if (k.key == .s) {
                state.camera_pos.add_(state.camera_front.muls(0.05));
            }
            if (k.key == .a) {
                const right = math.cross(state.camera_front, math.vec3(0, 1, 0)).muls(0.05);
                state.camera_pos.add_(right);
            }
            if (k.key == .d) {
                const right = math.cross(state.camera_front, math.vec3(0, 1, 0)).muls(0.05);
                state.camera_pos.sub_(right);
            }
        }
    }
}

fn handle_cursor(c: Event.Cursor) void {
    if (!state.menu_open) {
        var ypr = &state.camera_ypr.data;
        var dx: f32 = c.dx * 0.1;
        var dy: f32 = c.dy * 0.1;
        ypr[0] -= dx;
        ypr[0] = if (ypr[0] > 360) ypr[0] - 360 else ypr[0];
        ypr[0] = if (ypr[0] < 0) 360 - ypr[0] else ypr[0];
        ypr[1] -= dy;
        ypr[1] = std.math.max(-89, std.math.min(ypr[1], 89));

        const sin = std.math.sin;
        const cos = std.math.cos;
        const yr = math.to_radians(ypr[0]);
        const pr = math.to_radians(ypr[1]);
        state.camera_front = math.vec3(cos(yr) * cos(pr), sin(pr), sin(yr) * cos(pr)).normalize();
    }
}

fn handle_resize(r: Event.Resize) void {
    render.set_viewport(0, 0, r.width, r.height);
}

const ig = @import("imgui");

/// the main application loop <3
pub fn loop() !void {
    window.poll();
    while (window.is_open) {
        try window.begin();
        window.poll();

        render.draw_renderable_batch(state.camera_pos, state.camera_front);

        // TODO:
        ui.begin();
        if (state.menu_open) {
            if (state.editor != null)
                ui.show_editor(&state)
            else
                ui.show_menu(&state);
            if (state.console_open)
                ui.show_console(&state);
        }
        ui.show_metrics(&state);
        ui.render();

        window.set_mouse_capture(state.menu_open);

        try window.end();
    }
}

pub fn deinit() void {
    ui.deinit();
    render.deinit();
    window.deinit();
    arena.deinit();
    // asset.free_all();
}
