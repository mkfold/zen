const std = @import("std");
const panic = std.debug.panic;
const log = std.log.scoped(.app);

const input = @import("./app/input.zig");
const Key = input.Key;
const KeyMod = input.KeyMod;
const KeyMods = input.KeyMods;

const gl = @import("gl");
const glfw = @import("glfw");

const Error = error{
    GlfwError,
    GlfwInitFailed,
    GladInitFailed,
    GlfwWindowCreationFailed,
    BackendUninitialized,
};

var backend_initialized: bool = false;

pub const Window = struct {
    pub const Context = struct {
        inputs: std.ArrayList(input.Event),
    };

    context: Context,
    window: *glfw.GLFWwindow = undefined,
    is_open: bool = false,
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) !Window {
        if (!backend_initialized) return Error.BackendUninitialized;

        var app: Window = undefined;
        app.window = try create_window(.opengl);
        errdefer glfw.glfwDestroyWindow(app.window);

        app.context.inputs = std.ArrayList(input.Event).init(allocator);
        app.is_open = true;
        return app;
    }

    pub fn setup(self: *Window) !void {
        _ = glfw.glfwSetWindowUserPointer(self.window, &self.context);
        _ = glfw.glfwSetKeyCallback(self.window, _key_callback);
        _ = glfw.glfwSetMouseButtonCallback(self.window, _mouse_button_callback);
        _ = glfw.glfwSetCursorPosCallback(self.window, _cursor_pos_callback);
        glfw.glfwMakeContextCurrent(self.window);
        glfw.glfwSwapInterval(1);
    }

    pub fn begin(self: *Window) !void {
        if (glfw.glfwWindowShouldClose(self.window) != 0) {
            self.is_open = false;
            return;
        }
        glfw.glfwPollEvents();
    }

    pub fn end(self: *Window) !void {
        glfw.glfwSwapBuffers(self.window);
        self.context.inputs.clearRetainingCapacity();
        if (!self.is_open) glfw.glfwSetWindowShouldClose(self.window, 1);
    }

    pub fn deinit(self: *Window) void {
        glfw.glfwDestroyWindow(self.window);
        self.context.inputs.deinit();
    }
};

pub const GraphicsBackend = enum {
    opengl,
    vulkan,
};

pub fn init() !void {
    _ = glfw.glfwSetErrorCallback(glfw_error_callback);
    if (glfw.glfwInit() == glfw.GLFW_FALSE) {
        log.crit("GLFW failed to initialize", .{});
        return Error.GlfwInitFailed;
    }
    log.info("GLFW initialized", .{});
    errdefer glfw.glfwTerminate();

    if (gl.gladLoadGL() < 0) return Error.GladInitFailed;

    backend_initialized = true;
}

pub fn deinit() void {
    glfw.glfwTerminate();
    backend_initialized = false;
}

pub fn create_window(backend: GraphicsBackend) !*glfw.GLFWwindow {
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

fn _key_callback(
    window: ?*glfw.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mods: c_int,
) callconv(.C) void {
    const context = @ptrCast(
        *Window.Context,
        @alignCast(@alignOf(*Window.Context), glfw.glfwGetWindowUserPointer(window.?)),
    );
    context.*.inputs.append(input.Event{
        .key = .{
            .key = @intToEnum(Key, key),
            .mods = mods,
            .scancode = scancode,
            .action = @intToEnum(input.Action, action),
        },
    }) catch unreachable;
}

fn _cursor_pos_callback(
    window: ?*glfw.GLFWwindow,
    xpos: f64,
    ypos: f64,
) callconv(.C) void {
    const context = @ptrCast(
        *Window.Context,
        @alignCast(@alignOf(*Window.Context), glfw.glfwGetWindowUserPointer(window.?)),
    );
    context.*.inputs.append(
        input.Event{ .cursor = .{ .xpos = xpos, .ypos = ypos } },
    ) catch unreachable;
}

fn _mouse_button_callback(
    window: ?*glfw.GLFWwindow,
    button: c_int,
    action: c_int,
    mods: c_int,
) callconv(.C) void {
    const context = @ptrCast(
        *Window.Context,
        @alignCast(@alignOf(*Window.Context), glfw.glfwGetWindowUserPointer(window.?)),
    );
    context.*.inputs.append(input.Event{
        .mouse = .{
            .button = @intToEnum(input.MouseButton, button),
            .action = @intToEnum(input.Action, action),
            .mods = mods,
        },
    }) catch unreachable;
}

fn _char_input_callback(
    window: ?*glfw.GLFWwindow,
    codepoint: c_int,
) callconv(.C) void {
    const context = @ptrCast(*Window.Context, glfw.glfwGetWindowUserPointer(window.?));
    context.*.inputs.append(input.CharEvent{ .codepoint = codepoint }) catch unreachable;
}

/// GLFW error callback function. more robust error handling may follow if necessary.
fn glfw_error_callback(err: c_int, description: [*c]const u8) callconv(.C) void {
    @setCold(true);
    const glfw_log = std.log.scoped(.glfw);
    glfw_log.err("({}) {s}", .{ err, description });
}
