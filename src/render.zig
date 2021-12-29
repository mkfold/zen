const std = @import("std");
const log = std.log.scoped(.render);
const panic = std.debug.panic;

const cc = @import("./cc.zig");

const gl = @import("./c.zig").gl;
pub const vertex = @import("render/vertex.zig");
const GlBuffer = @import("render/buffer.zig").GlBuffer;

fn _debug_callback(
    source: gl.GLenum,
    _type: gl.GLenum,
    id: gl.GLuint,
    severity: gl.GLenum,
    length: gl.GLsizei,
    message: [*c]const gl.GLchar,
    userParam: ?*const anyopaque,
) callconv(.C) void {
    _ = source;
    _ = _type;
    _ = id;
    _ = severity;
    _ = length;
    _ = userParam;
    std.debug.warn("gl debug: {}\n", .{@ptrCast([*:0]const u8, message)});
}

/// initialize renderer: load default shaders, placeholder assets, etc.
pub fn init() void {
    // TODO: enable debug output for debug builds only
    // gl.glEnable(gl.GL_DEBUG_OUTPUT);
    // gl.glDebugMessageCallback(_debug_callback, null);

    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LESS);
    gl.glEnable(gl.GL_CULL_FACE);
    gl.glCullFace(gl.GL_BACK);
}

pub fn deinit() void {
    // TODO:
    //  - destroy texture objects
    //  - destroy shaders
    //  - clear vertex buffers
    //  - free any memory
    //  - etc
}

//
// drawing!
//

/// Sets clear values for framebuffer.
pub fn set_clear_color() void {
    gl.glClearColor(0, 0, 0, 1);
}

/// Clears back framebuffer for new frame.
pub fn clear_framebuffer() void {
    gl.glClear(gl.GL_COLOR_BUFFER_BIT);
}

const Drawable = struct {
    buffer_obj: c_uint,
    shader_id: c_uint,
    texture_id: c_uint,
};

/// TODO: implement this
pub fn draw_renderable_batch() void {
    // find visible renderables
    // sort renderables by shader
    // for each shader, draw renderables
}

pub fn draw__(
    bufs: GlBuffer,
) void {
    var cmds: [100000]gl.DrawElementsIndirectCommand = undefined;
    var i: u32 = 0;
    var rng = std.rand.DefaultPrng.init();
    const r = rng.random();
    while (i < 100000) : (i += 1) {
        cmds[i].count = 3;
        cmds[i].instanceCount = 1;
        cmds[i].firstIndex = @mod(r.random.int(u32), 10000) * 3;
        cmds[i].baseVertex = cmds[i].firstIndex;
        //std.debug.warn("{}\n", .{cmds[i].firstIndex});
        cmds[i].baseInstance = 0;
    }
    gl.glBindVertexArray(bufs.vao);

    gl.glMultiDrawElementsIndirect(
        gl.GL_TRIANGLES,
        gl.GL_UNSIGNED_INT,
        @as(*anyopaque, &cmds),
        100000,
        0,
    );
    gl.glBindVertexArray(0);
}

pub fn draw(
    bufs: GlBuffer,
) void {
    var counts: [100000]u32 = undefined;
    var inds: [100000]*gl.GLvoid = undefined;
    var bases: [100000]u32 = undefined;

    var rng = std.rand.DefaultPrng.init();
    const r = rng.random();

    var t = cc.gettime();
    var i: u32 = 0;
    while (i < 100000) : (i += 1) {
        counts[i] = 3;
        bases[i] = @mod(r.random.int(u32), 10000) * 3;
        inds[i] = @intToPtr(*gl.GLvoid, bases[i] * 4);
        //std.debug.warn("{}\n", .{cmds[i].firstIndex});
    }
    var dt = cc.gettime() - t;
    std.debug.warn("    {:.4}\n", .{dt});
    gl.glBindVertexArray(bufs.vao);
    gl.glMultiDrawElementsBaseVertex(
        gl.GL_TRIANGLES,
        @ptrCast(*gl.GLsizei, &counts),
        gl.GL_UNSIGNED_INT,
        @ptrCast([*c]const *gl.GLvoid, &inds),
        100000,
        @ptrCast(*c_int, &bases),
    );
    gl.glBindVertexArray(0);
}

//
// shaders!
//

const default_vert_shader =
    \\#version 420 core
    \\layout (location = 0) in vec3 a_pos;
    \\layout (location = 1) in vec4 a_color;
    \\out vec4 frag_color;
    \\void main() {
    \\    frag_color = a_color;
    \\    gl_Position = vec4(a_pos, 1.0f);
    \\}
;

const default_frag_shader =
    \\#version 420 core
    \\out vec4 color;
    \\in vec4 frag_color;
    \\void main() {
    \\    color = frag_color;
    \\}
;

pub const Shader = struct {
    program_id: gl.GLuint,

    pub fn build(vtx_src: [*c]const u8, frag_src: [*c]const u8) !Shader {
        var s: Shader = undefined;
        var status: c_int = undefined;
        var logbuf: [1024]u8 = undefined;

        var vtx_shader_id = gl.glCreateShader(gl.GL_VERTEX_SHADER);
        gl.glShaderSource(vtx_shader_id, 1, &vtx_src, null);
        gl.glCompileShader(vtx_shader_id);

        gl.glGetShaderiv(vtx_shader_id, gl.GL_COMPILE_STATUS, &status);
        if (status == 0) {
            gl.glGetShaderInfoLog(vtx_shader_id, 1024, null, &logbuf[0]);
            log.err("vertex shader failed to compile, reason:\n    {}", .{logbuf});
            return error.VertShaderCompileError;
        }

        var frag_shader_id = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
        gl.glShaderSource(frag_shader_id, 1, &frag_src, null);
        gl.glCompileShader(frag_shader_id);

        gl.glGetShaderiv(frag_shader_id, gl.GL_COMPILE_STATUS, &status);
        if (status == 0) {
            gl.glGetShaderInfoLog(frag_shader_id, 1024, null, &logbuf[0]);
            log.err("fragment shader failed to compile, reason: \n    {}", .{logbuf});
            return error.FragShaderCompileError;
        }

        // link shaders
        s.program_id = gl.glCreateProgram();
        gl.glBindFragDataLocation(s.program_id, 0, "color");
        gl.glAttachShader(s.program_id, s.vtx_shader_id);
        gl.glAttachShader(s.program_id, s.frag_shader_id);
        gl.glLinkProgram(s.program_id);

        gl.glGetProgramiv(s.program_id, gl.GL_LINK_STATUS, &status);
        if (status == 0) {
            gl.glGetProgramInfoLog(frag_shader_id, 1024, null, &logbuf[0]);
            log.err("shader program linking failed, reason:\n    {}", .{logbuf});
            return error.ShaderLinkError;
        }
        gl.glDeleteShader(frag_shader_id);
        gl.glDeleteShader(vtx_shader_id);

        return s;
    }

    pub fn load(frag_fname: []const u8, vtx_fname: []const u8) !Shader {
        const allocator = std.heap.page_allocator;

        const frag_src = try cc.load_text_file(allocator, frag_fname);
        defer allocator.free(frag_src);

        const vtx_src = try cc.load_text_file(allocator, vtx_fname);
        defer allocator.free(vtx_src);

        return Shader.build(vtx_src, frag_src);
    }
};

pub fn load_default_shader() !Shader {
    return Shader.build(default_vert_shader, default_frag_shader);
}
