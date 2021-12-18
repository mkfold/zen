const std = @import("std");
const log = std.log.scoped(.render);
const panic = std.debug.panic;

const c = @import("../c.zig");
const cc = @import("../cc.zig");

fn gl_debug_callback(
    source: c.GLenum,
    _type: c.GLenum,
    id: c.GLuint,
    severity: c.GLenum,
    length: c.GLsizei,
    message: [*c]const c.GLchar,
    userParam: ?*const c_void,
) callconv(.C) void {
    std.debug.warn("gl debug: {}\n", .{@ptrCast([*:0]const u8, message)});
}

/// initialize renderer: load default shaders, placeholder assets, etc.
pub fn init() void {
    // TODO: enable debug output for debug builds only
    c.glEnable(c.GL_DEBUG_OUTPUT);
    c.glDebugMessageCallback(gl_debug_callback, null);

    c.glEnable(GL_DEPTH_TEST);
    c.glDepthFunc(GL_LESS);
    c.glEnable(c.GL_CULL_FACE);
    c.glCullFace(c.GL_BACK);
}

pub fn deinit() void {
    // TODO:
    //  - destroy texture objects
    //  - destroy shaders
    //  - clear vertex buffers
    //  - free any memory
    //  - etc
}

//!
//! drawing!
//!

/// Sets clear values for framebuffer.
pub fn set_clear_color() void {
    c.glClearColor(0, 0, 0, 1);
}

/// Clears back framebuffer for new frame.
pub fn clear_framebuffer() void {
    c.glClear(c.GL_COLOR_BUFFER_BIT);
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

pub fn draw__(bufs: GlBuffer, max_tris: u32) void {
    var cmds: [100000]c.DrawElementsIndirectCommand = undefined;
    var i: u32 = 0;
    while (i < 100000) : (i += 1) {
        cmds[i].count = 3;
        cmds[i].instanceCount = 1;
        cmds[i].firstIndex = @mod(r.random.int(u32), 10000) * 3;
        cmds[i].baseVertex = cmds[i].firstIndex;
        //std.debug.warn("{}\n", .{cmds[i].firstIndex});
        cmds[i].baseInstance = 0;
    }
    c.glBindVertexArray(bufs.vao);

    c.glMultiDrawElementsIndirect(
        c.GL_TRIANGLES,
        c.GL_UNSIGNED_INT,
        @as(*c_void, &cmds),
        100000,
        0,
    );
    c.glBindVertexArray(0);
}

pub fn draw(bufs: GlBuffer, max_tris: u32) void {
    var counts: [400000]u32 = undefined;
    var inds: [400000]*c.GLvoid = undefined;
    var bases: [400000]u32 = undefined;
    var i: u32 = 0;
    var t = cc.gettime();
    while (i < 400000) : (i += 1) {
        counts[i] = 3;
        bases[i] = @mod(r.random.int(u32), 10000) * 3;
        inds[i] = @intToPtr(*c.GLvoid, bases[i] * 4);
        //std.debug.warn("{}\n", .{cmds[i].firstIndex});
    }
    var dt = cc.gettime() - t;
    std.debug.warn("    {:.4}\n", .{dt});
    c.glBindVertexArray(bufs.vao);
    c.glMultiDrawElementsBaseVertex(
        c.GL_TRIANGLES,
        @ptrCast(*c.GLsizei, &counts),
        c.GL_UNSIGNED_INT,
        @ptrCast([*c]const *c.GLvoid, &inds),
        400000,
        @ptrCast(*c_int, &bases),
    );
    c.glBindVertexArray(0);
}

//!
//! shaders!
//!

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
    vtx_shader_id: c.GLuint,
    frag_shader_id: c.GLuint,
    program_id: c.GLuint,

    pub fn build(vtx_src: [*c]const u8, frag_src: [*c]const u8) !Shader {
        var s: Shader = undefined;
        var status: c_int = undefined;
        var logbuf: [1024]u8 = undefined;

        s.vtx_shader_id = c.glCreateShader(c.GL_VERTEX_SHADER);
        c.glShaderSource(s.vtx_shader_id, 1, &vtx_src, null);
        c.glCompileShader(s.vtx_shader_id);

        c.glGetShaderiv(s.vtx_shader_id, c.GL_COMPILE_STATUS, &status);
        if (status == 0) {
            c.glGetShaderInfoLog(s.vtx_shader_id, 1024, null, &logbuf[0]);
            log.err("vertex shader failed to compile, reason:\n    {}", .{logbuf});
            return error.VertShaderCompileError;
        }

        s.frag_shader_id = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        c.glShaderSource(s.frag_shader_id, 1, &frag_src, null);
        c.glCompileShader(s.frag_shader_id);

        c.glGetShaderiv(s.frag_shader_id, c.GL_COMPILE_STATUS, &status);
        if (status == 0) {
            c.glGetShaderInfoLog(s.frag_shader_id, 1024, null, &logbuf[0]);
            log.err("fragment shader failed to compile, reason: \n    {}", .{logbuf});
            return error.FragShaderCompileError;
        }

        // link shaders
        s.program_id = c.glCreateProgram();
        c.glBindFragDataLocation(s.program_id, 0, "color");
        c.glAttachShader(s.program_id, s.vtx_shader_id);
        c.glAttachShader(s.program_id, s.frag_shader_id);
        c.glLinkProgram(s.program_id);

        c.glGetProgramiv(s.program_id, c.GL_LINK_STATUS, &status);
        if (status == 0) {
            c.glGetProgramInfoLog(s.frag_shader_id, 1024, null, &logbuf[0]);
            log.err("shader program linking failed, reason:\n    {}", .{logbuf});
            return error.ShaderLinkError;
        }
        c.glDeleteShader(s.frag_shader_id);
        c.glDeleteShader(s.vtx_shader_id);

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
