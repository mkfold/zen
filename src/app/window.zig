const std = @import("std");
const log = std.log.scoped(.app);
const ig = @import("imgui");

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
        inputs: std.ArrayList(input.Event),
    };

    context: Context,
    window: *glfw.GLFWwindow = undefined,
    is_open: bool = false,
    allocator: std.mem.Allocator,

    var backend_initialized = false;

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

        app.context.inputs = std.ArrayList(input.Event).init(allocator);
        app.is_open = true;
        return app;
    }

    pub fn deinit(self: *Window) void {
        glfw.glfwDestroyWindow(self.window);
        self.context.inputs.deinit();
        _deinit_backend();
    }

    pub fn setup(self: *Window) !void {
        glfw.glfwMakeContextCurrent(self.window);
        glfw.glfwSwapInterval(1);
        var width: c_int = 0;
        var height: c_int = 0;
        glfw.glfwGetWindowSize(self.window, &width, &height);
        gl.glViewport(0, 0, width, height);
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
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
    }

    pub fn end(self: *Window) !void {
        glfw.glfwSwapBuffers(self.window);
        self.context.inputs.clearRetainingCapacity();
        if (!self.is_open) glfw.glfwSetWindowShouldClose(self.window, 1);
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
    glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glfw.GLFW_FALSE);
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
        monitor,
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
    const ctx = _get_window_context(window.?);
    ctx.*.inputs.append(.{ .key = .{
        .key = @intToEnum(input.Key, key),
        .mods = mods,
        .scancode = scancode,
        .action = @intToEnum(input.Action, action),
    } }) catch unreachable;
}

fn _cursor_pos_callback(window: ?*glfw.GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void {
    const ctx = _get_window_context(window.?);
    var io = ig.igGetIO();
    io.*.MousePos = .{ .x = @floatCast(f32, xpos), .y = @floatCast(f32, ypos) };
    ctx.*.inputs.append(.{ .cursor = .{ .xpos = xpos, .ypos = ypos } }) catch unreachable;
}

fn _mouse_button_callback(
    window: ?*glfw.GLFWwindow,
    button: c_int,
    action: c_int,
    mods: c_int,
) callconv(.C) void {
    const ctx = _get_window_context(window.?);
    ctx.*.inputs.append(.{ .mouse = .{
        .button = @intToEnum(input.MouseButton, button),
        .action = @intToEnum(input.Action, action),
        .mods = mods,
    } }) catch unreachable;
}

fn _char_input_callback(window: ?*glfw.GLFWwindow, codepoint: c_uint) callconv(.C) void {
    const ctx = _get_window_context(window.?);
    ctx.*.inputs.append(.{ .char = .{ .codepoint = codepoint } }) catch unreachable;
}

fn _fb_size_callback(window: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    const ctx = _get_window_context(window.?);
    ctx.*.inputs.append(.{ .resize = .{ .width = width, .height = height } }) catch unreachable;
}

fn _scroll_callback(window: ?*glfw.GLFWwindow, xoffs: f64, yoffs: f64) callconv(.C) void {
    const ctx = _get_window_context(window.?);
    ctx.*.inputs.append(.{ .scroll = .{ .xoffs = xoffs, .yoffs = yoffs } }) catch unreachable;
}

/// GLFW error callback function. more robust error handling may follow if necessary.
fn glfw_error_callback(err: c_int, description: [*c]const u8) callconv(.C) void {
    @setCold(true);
    const glfw_log = std.log.scoped(.glfw);
    glfw_log.err("({}) {s}", .{ err, description });
}
