const std = @import("std");
const log = std.log.scoped(.render);
const panic = std.debug.panic;

const gl = @import("../c.zig").gl;
const asset = @import("../asset.zig");
const model = @import("../asset/model.zig");
pub const vertex = @import("vertex.zig");
const GlBuffer = @import("gl/buffer.zig").GlBuffer;
const RenderQueue = @import("gl/queue.zig").RenderQueue;

const shader = @import("gl/shader.zig");
const Shader = shader.Shader;
const ShaderManager = shader.ShaderManager;

const TexManager = @import("gl/texture.zig").TexManager;

const math = @import("../math.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat2 = math.Mat2;
const Mat3 = math.Mat3;
const Mat4 = math.Mat4;

const SkinVBuf = GlBuffer(vertex.MeshVertex);
const StaticVBuf = GlBuffer(vertex.StaticMeshVertex);
const GuiVBuf = GlBuffer(vertex.GuiVertex);

var ctx: struct {
    shaders: ShaderManager = undefined,
    textures: TexManager = undefined,
    skin_geom_buf: SkinVBuf = undefined,
    static_geom_buf: StaticVBuf = undefined,
    gui_geom_buf: GuiVBuf = undefined,
    scene: model.Model = undefined,
    scene_texture_handle: u32 = undefined,
} = .{};

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
    log.warn("gl debug: {s}", .{@ptrCast([*:0]const u8, message)});
}

/// initialize renderer: load default shaders, placeholder assets, etc.
pub fn init() void {
    // TODO: enable debug output for debug builds only
    gl.glEnable(gl.GL_DEBUG_OUTPUT);
    gl.glDebugMessageCallback(_debug_callback, null);

    ctx.default_shader = Shader.load_default() catch panic("shader load failed", .{});
    ctx.scene = asset.load_model("assets/models/cube.iqm") catch panic("scene load failed", .{});
    ctx.skin_geom_buf = SkinVBuf.init_data(ctx.scene.vertices, ctx.scene.indices);
    gl.glGenTextures(1, &ctx.scene_texture_handle);
    gl.glBindTexture(gl.GL_TEXTURE_2D, ctx.scene_texture_handle);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR_MIPMAP_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_REPEAT);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_REPEAT);
    const st = ctx.scene.meshes[0].material.?;
    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        gl.GL_RGB,
        @intCast(c_int, st.*.width),
        @intCast(c_int, st.*.height),
        0,
        gl.GL_RGB,
        gl.GL_UNSIGNED_BYTE,
        @ptrCast(*const anyopaque, st.*.data.ptr),
    );
    gl.glGenerateMipmap(gl.GL_TEXTURE_2D);
}

pub fn deinit() void {
    // TODO:
    //  - destroy texture objects
    //  - destroy shaders
    //  - clear vertex buffers
    //  - free any memory
    //  - etc
    // static_geom_buf.deinit();
}

pub fn set_viewport(xpos: i32, ypos: i32, width: i32, height: i32) void {
    gl.glViewport(xpos, ypos, width, height);
}

/// Sets clear values for framebuffer.
pub fn set_clear_color() void {
    gl.glClearColor(0, 0, 0, 1);
}

/// Clears back framebuffer for new frame.
pub fn clear_framebuffer() void {
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
}

/// TODO: implement this
pub fn draw_renderable_batch(camera_pos: Vec3, camera_front: Vec3) void {
    // find visible renderables
    // sort renderables by shader
    // for each shader, draw renderables
    // right now this is just bunch of crep

    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LEQUAL);
    gl.glEnable(gl.GL_CULL_FACE);
    gl.glCullFace(gl.GL_BACK);
    gl.glFrontFace(gl.GL_CCW);
    clear_framebuffer();
    gl.glUseProgram(ctx.default_shader.program_id);
    ctx.default_shader.set_uniform_mat4("mvp", &[1]Mat4{Mat4.matmul(
        math.perspective(math.to_radians(100.0), 16.0 / 9.0, 0.1, 100.0),
        math.lookat(camera_pos, camera_pos.add(camera_front), math.vec3(0, 1, 0)),
    )});
    ctx.default_shader.set_uniform_vec3("light_pos", &[1]Vec3{math.vec3(1.2, 1, 2).muls(4)});

    gl.glBindVertexArray(ctx.skin_geom_buf.vao);
    gl.glBindVertexBuffer(0, ctx.skin_geom_buf.vbo, 0, @sizeOf(vertex.MeshVertex));
    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ctx.skin_geom_buf.ebo);

    var s: i32 = undefined;
    var counts: [100]gl.GLsizei = undefined;
    var inds = [1]?*gl.GLvoid{null} ** 100;
    var bases: [100]c_int = undefined;

    // std.debug.print("{}\n", .{scene.indices.len});
    for (ctx.scene.meshes) |mesh, i| {
        counts[i] = @intCast(gl.GLsizei, mesh.indices.len);
        //inds[i] = @ptrCast(*gl.GLvoid, mesh.indices.ptr);
        bases[i] = 0; // if (i > 0) (bases[i - 1] + @intCast(c_int, counts[i - 1])) else 0;
        // std.debug.print("{}, {}\n", .{ bases[i], counts[i] });
    }
    gl.glGetBufferParameteriv(gl.GL_ELEMENT_ARRAY_BUFFER, gl.GL_BUFFER_SIZE, &s);
    // gl.glDrawElements(gl.GL_TRIANGLES, @divTrunc(s, @sizeOf(u32)), gl.GL_UNSIGNED_INT, null);
    // gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE);
    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, ctx.scene_texture_handle);
    gl.glMultiDrawElementsBaseVertex(
        gl.GL_TRIANGLES,
        &counts,
        gl.GL_UNSIGNED_INT,
        @ptrCast([*c]const *gl.GLvoid, &inds),
        @intCast(c_int, ctx.scene.meshes.len),
        &bases,
    );
    // gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL);
}

// pub fn draw__(
//     bufs: GlBuffer,
// ) void {
//     var cmds: [100000]gl.DrawElementsIndirectCommand = undefined;
//     var i: u32 = 0;
//     var rng = std.rand.DefaultPrng.init();
//     const r = rng.random();
//     while (i < 100000) : (i += 1) {
//         cmds[i].count = 3;
//         cmds[i].instanceCount = 1;
//         cmds[i].firstIndex = @mod(r.random.int(u32), 10000) * 3;
//         cmds[i].baseVertex = cmds[i].firstIndex;
//         //std.debug.warn("{}\n", .{cmds[i].firstIndex});
//         cmds[i].baseInstance = 0;
//     }
//     gl.glBindVertexArray(bufs.vao);
//
//     gl.glMultiDrawElementsIndirect(
//         gl.GL_TRIANGLES,
//         gl.GL_UNSIGNED_INT,
//         @as(*anyopaque, &cmds),
//         100000,
//         0,
//     );
//     gl.glBindVertexArray(0);
// }
