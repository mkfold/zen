const std = @import("std");
const log = std.log.scoped(.app);

const input = @import("./input.zig");
const Event = input.Event;

const c = @import("../c.zig");
const gl = c.gl;
const glfw = c.glfw;

const Error = error{
    GlfwError,
    GlfwInitFailed,
    GladInitFailed,
    GlfwWindowCreationFailed,
    BackendUninitialized,
};

pub const GraphicsBackend = enum { opengl, vulkan };

pub const Window = struct {
    pub const Context = struct {
        inputs: std.ArrayList(Event),
        _key_fns: std.ArrayList(fn (Event.Keyboard) void),
        _mouse_fns: std.ArrayList(fn (Event.Mouse) void),
        _cur_fns: std.ArrayList(fn (Event.Cursor) void),
        _char_fns: std.ArrayList(fn (Event.CharInput) void),
        _resize_fns: std.ArrayList(fn (Event.Resize) void),
        _scroll_fns: std.ArrayList(fn (Event.Scroll) void),
        width: i32,
        height: i32,
        cursor_xpos: f32,
        cursor_ypos: f32,
    };

    context: Context,
    window: *glfw.GLFWwindow = undefined,
    is_open: bool = false,
    allocator: std.mem.Allocator,

    var backend_initialized = false;

    pub fn add_key_callback(self: *Window, func: fn (Event.Keyboard) void) !void {
        try self.context._key_fns.append(func);
    }

    pub fn add_mouse_callback(self: *Window, func: fn (Event.Mouse) void) !void {
        try self.context._mouse_fns.append(func);
    }

    pub fn add_cursor_callback(self: *Window, func: fn (Event.Cursor) void) !void {
        try self.context._cur_fns.append(func);
    }

    pub fn add_char_input_callback(self: *Window, func: fn (Event.CharInput) void) !void {
        try self.context._char_fns.append(func);
    }

    pub fn add_resize_callback(self: *Window, func: fn (Event.Resize) void) !void {
        try self.context._resize_fns.append(func);
    }

    pub fn add_scroll_callback(self: *Window, func: fn (Event.Scroll) void) !void {
        try self.context._scroll_fns.append(func);
    }

    pub fn reset_callbacks(self: *Window) !void {
        try self.context._key_fns.resize(0);
        try self.context._mouse_fns.resize(0);
        try self.context._cur_fns.resize(0);
        try self.context._char_fns.resize(0);
        try self.context._resize_fns.resize(0);
        try self.context._scroll_fns.resize(0);
    }

    fn _init_backend() !void {
        _ = glfw.glfwSetErrorCallback(glfw_error_callback);
        if (glfw.glfwInit() == glfw.GLFW_FALSE) {
            log.err("GLFW failed to initialize", .{});
            return Error.GlfwInitFailed;
        }
        log.info("GLFW initialized", .{});
        backend_initialized = true;
    }

    fn _deinit_backend() void {
        if (backend_initialized) glfw.glfwTerminate();
        backend_initialized = false;
    }

    pub fn init(allocator: std.mem.Allocator) !Window {
        if (!backend_initialized) try _init_backend();

        var app: Window = undefined;
        app.window = try create_window(.opengl);
        errdefer glfw.glfwDestroyWindow(app.window);

        app.context.inputs = std.ArrayList(Event).init(allocator);
        app.context._key_fns = std.ArrayList(fn (Event.Keyboard) void).init(allocator);
        app.context._mouse_fns = std.ArrayList(fn (Event.Mouse) void).init(allocator);
        app.context._cur_fns = std.ArrayList(fn (Event.Cursor) void).init(allocator);
        app.context._char_fns = std.ArrayList(fn (Event.CharInput) void).init(allocator);
        app.context._resize_fns = std.ArrayList(fn (Event.Resize) void).init(allocator);
        app.context._scroll_fns = std.ArrayList(fn (Event.Scroll) void).init(allocator);
        app.is_open = true;
        return app;
    }

    pub fn deinit(self: *Window) void {
        glfw.glfwDestroyWindow(self.window);
        self.context.inputs.deinit();
        self.context._key_fns.deinit();
        self.context._mouse_fns.deinit();
        self.context._cur_fns.deinit();
        self.context._char_fns.deinit();
        self.context._resize_fns.deinit();
        self.context._scroll_fns.deinit();
        _deinit_backend();
    }

    pub fn setup(self: *Window) !void {
        glfw.glfwMakeContextCurrent(self.window);
        glfw.glfwSwapInterval(1);
        var width: c_int = 0;
        var height: c_int = 0;
        glfw.glfwGetWindowSize(self.window, &width, &height);
        self.context.width = @intCast(i32, width);
        self.context.height = @intCast(i32, height);
        _ = glfw.glfwSetWindowUserPointer(self.window, &self.context);
        _ = glfw.glfwSetKeyCallback(self.window, _key_callback);
        _ = glfw.glfwSetMouseButtonCallback(self.window, _mouse_button_callback);
        _ = glfw.glfwSetScrollCallback(self.window, _scroll_callback);
        _ = glfw.glfwSetCharCallback(self.window, _char_input_callback);
        _ = glfw.glfwSetCursorPosCallback(self.window, _cursor_pos_callback);
        _ = glfw.glfwSetFramebufferSizeCallback(self.window, _fb_size_callback);
    }

    pub fn poll(_: Window) void {
        glfw.glfwPollEvents();
    }

    pub fn begin(self: *Window) !void {
        if (glfw.glfwWindowShouldClose(self.window) != 0) {
            self.is_open = false;
            return;
        }
    }

    pub fn end(self: *Window) !void {
        glfw.glfwSwapBuffers(self.window);
        self.context.inputs.clearRetainingCapacity();
        if (!self.is_open) glfw.glfwSetWindowShouldClose(self.window, 1);
    }

    pub fn set_mouse_capture(self: *Window, enabled: bool) void {
        glfw.glfwSetInputMode(
            self.window,
            glfw.GLFW_CURSOR,
            if (enabled) glfw.GLFW_CURSOR_NORMAL else glfw.GLFW_CURSOR_DISABLED,
        );
    }
};

fn create_window(backend: GraphicsBackend) !*glfw.GLFWwindow {
    switch (backend) {
        .opengl => {
            glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4);
            glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
            glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
        },
        .vulkan => {
            log.info("Vulkan support: {}", .{glfw.glfwVulkanSupported() == glfw.GLFW_TRUE});
            glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
        },
    }
    glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glfw.GLFW_TRUE);
    glfw.glfwWindowHint(glfw.GLFW_DOUBLEBUFFER, glfw.GLFW_TRUE);

    // obtain the dimensions of the primary display to create "windowed fullscreen" context
    // TODO: may want to allow changes to the monitor in use? not really necessary
    const monitor = glfw.glfwGetPrimaryMonitor();
    const mode = glfw.glfwGetVideoMode(monitor);

    glfw.glfwWindowHint(glfw.GLFW_RED_BITS, mode.*.redBits);
    glfw.glfwWindowHint(glfw.GLFW_GREEN_BITS, mode.*.greenBits);
    glfw.glfwWindowHint(glfw.GLFW_BLUE_BITS, mode.*.blueBits);
    glfw.glfwWindowHint(glfw.GLFW_REFRESH_RATE, mode.*.refreshRate);

    return glfw.glfwCreateWindow(
        mode.*.width,
        mode.*.height,
        "zen",
        null, // monitor,
        null,
    ) orelse Error.GlfwWindowCreationFailed;
}

//
// input handling
//

/// helper for getting window context
fn _get_window_context(window: *glfw.GLFWwindow) *Window.Context {
    return @ptrCast(*Window.Context, @alignCast(
        @alignOf(*Window.Context),
        glfw.glfwGetWindowUserPointer(window),
    ));
}

fn _key_callback(
    window: ?*glfw.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mods: c_int,
) callconv(.C) void {
    if (key == -1 or window == null) return;
    const e = Event.Keyboard{
        .key = @intToEnum(input.Key, key),
        .mods = mods,
        .scancode = scancode,
        .action = @intToEnum(input.Action, action),
    };
    const ctx = _get_window_context(window.?);

    for (ctx.*._key_fns.items) |func| func(e);
}

fn _cursor_pos_callback(window: ?*glfw.GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void {
    const ctx = _get_window_context(window.?);
    const new_xpos = @floatCast(f32, xpos);
    const new_ypos = @floatCast(f32, ypos);

    const e = Event.Cursor{
        .xpos = new_xpos,
        .ypos = new_ypos,
        .dx = ctx.*.cursor_xpos - new_xpos,
        .dy = ctx.*.cursor_ypos - new_ypos,
    };

    for (ctx.*._cur_fns.items) |func| func(e);

    ctx.*.cursor_xpos = new_xpos;
    ctx.*.cursor_ypos = new_ypos;
}

fn _mouse_button_callback(
    window: ?*glfw.GLFWwindow,
    button: c_int,
    action: c_int,
    mods: c_int,
) callconv(.C) void {
    const e = Event.Mouse{
        .button = @intToEnum(input.MouseButton, button),
        .action = @intToEnum(input.Action, action),
        .mods = mods,
    };
    const ctx = _get_window_context(window.?);
    for (ctx.*._mouse_fns.items) |func| func(e);
}

fn _char_input_callback(window: ?*glfw.GLFWwindow, codepoint: c_uint) callconv(.C) void {
    const e = Event.CharInput{ .codepoint = codepoint };
    const ctx = _get_window_context(window.?);
    for (ctx.*._char_fns.items) |func| func(e);
}

fn _fb_size_callback(window: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    const ctx = _get_window_context(window.?);
    ctx.*.width = @intCast(i32, width);
    ctx.*.height = @intCast(i32, height);
    const e = Event.Resize{ .width = width, .height = height };
    for (ctx.*._resize_fns.items) |func| func(e);
}

fn _scroll_callback(window: ?*glfw.GLFWwindow, xoffs: f64, yoffs: f64) callconv(.C) void {
    const ctx = _get_window_context(window.?);
    const e = Event.Scroll{ .xoffs = xoffs, .yoffs = yoffs };
    for (ctx.*._scroll_fns.items) |func| func(e);
}

/// GLFW error callback function. more robust error handling may follow if necessary.
fn glfw_error_callback(err: c_int, description: [*c]const u8) callconv(.C) void {
    @setCold(true);
    const glfw_log = std.log.scoped(.glfw);
    glfw_log.err("({}) {s}", .{ err, description });
}
