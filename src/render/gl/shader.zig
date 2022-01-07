//! zen: render/gl/shader.zig
const std = @import("std");
const log = std.log.scoped(.render);

const gl = @import("../c.zig").gl;
const kf = @import("../kf.zig");

const Manager = @import("../asset.zig").Manager;
const math = @import("../math.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat2 = math.Mat2;
const Mat3 = math.Mat3;
const Mat4 = math.Mat4;

pub const Shader = struct {
    const default_vert_shader =
        \\#version 430
        \\layout (location = 0) in vec3 a_pos;
        \\layout (location = 1) in vec2 a_uv;
        \\layout (location = 2) in vec3 a_normal;
        \\layout (location = 4) in vec4 a_color;
        \\layout (location = 5) uniform mat4 mvp;
        \\out vec4 frag_color;
        \\out vec3 frag_pos;
        \\out vec3 normal;
        \\out vec2 uv;
        \\
        \\void main() {
        \\    frag_color = vec4(a_color.xyz, 255);
        \\    frag_pos = a_pos;
        \\    normal = a_normal;
        \\    uv = a_uv;
        \\    // gl_Position = floor(mvp * vec4(a_pos, 1.0f) * 100) / 100;
        \\    gl_Position = mvp * vec4(a_pos, 1.0f);
        \\}
    ;

    const default_frag_shader =
        \\#version 430
        \\out vec4 color;
        \\in vec4 frag_color;
        \\in vec3 frag_pos;
        \\in vec3 normal;
        \\in vec2 uv;
        \\uniform sampler2D texture0;
        \\uniform vec3 light_pos;
        \\
        \\void main() {
        \\    vec3 light_color = vec3(1.0, 1.0, 1.0);
        \\
        \\    vec3 ambient = 0.1 * light_color;
        \\
        \\    vec3 n = normalize(normal);
        \\    vec3 dir = normalize(light_pos - frag_pos);
        \\    float diff = max(dot(n, dir), 0.0);
        \\    vec3 diffuse = diff * light_color;
        \\
        \\    color = vec4(ambient + diffuse, 1.0) * texture(texture0, uv);
        \\}
    ;
    program_id: gl.GLuint,

    pub fn build(vtx_src: [*c]const u8, frag_src: [*c]const u8, geom_src: ?[*c]const u8) !Shader {
        var s: Shader = undefined;
        var status: c_int = undefined;
        var logbuf: [1024]u8 = undefined;

        var vtx_shader_id = gl.glCreateShader(gl.GL_VERTEX_SHADER);
        gl.glShaderSource(vtx_shader_id, 1, &vtx_src, null);
        gl.glCompileShader(vtx_shader_id);

        gl.glGetShaderiv(vtx_shader_id, gl.GL_COMPILE_STATUS, &status);
        if (status == 0) {
            gl.glGetShaderInfoLog(vtx_shader_id, 1024, null, &logbuf[0]);
            log.err("vertex shader failed to compile, reason:\n    {s}", .{logbuf});
            return error.VertShaderCompileError;
        }

        var frag_shader_id = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
        gl.glShaderSource(frag_shader_id, 1, &frag_src, null);
        gl.glCompileShader(frag_shader_id);

        gl.glGetShaderiv(frag_shader_id, gl.GL_COMPILE_STATUS, &status);
        if (status == 0) {
            gl.glGetShaderInfoLog(frag_shader_id, 1024, null, &logbuf[0]);
            log.err("fragment shader failed to compile, reason: \n    {s}", .{logbuf});
            return error.FragShaderCompileError;
        }

        var geom_shader_id = if (geom_src) |src| blk: {
            var _id = gl.glCreateShader(gl.GL_GEOMETRY_SHADER);
            gl.glShaderSource(_id, 1, &src, null);
            gl.glCompileShader(_id);

            gl.glGetShaderiv(_id, gl.GL_COMPILE_STATUS, &status);
            if (status == 0) {
                gl.glGetShaderInfoLog(_id, 1024, null, &logbuf[0]);
                log.err("geometry shader failed to compile, reason: \n    {s}", .{logbuf});
                return error.GeomShaderCompileError;
            }
            break :blk _id;
        } else null;

        // link shaders
        s.program_id = gl.glCreateProgram();
        gl.glBindFragDataLocation(s.program_id, 0, "color");
        gl.glAttachShader(s.program_id, vtx_shader_id);
        gl.glAttachShader(s.program_id, frag_shader_id);
        if (geom_shader_id) |_id| gl.glAttachShader(s.program_id, _id);
        gl.glLinkProgram(s.program_id);

        gl.glGetProgramiv(s.program_id, gl.GL_LINK_STATUS, &status);
        if (status == 0) {
            gl.glGetProgramInfoLog(frag_shader_id, 1024, null, &logbuf[0]);
            log.err("shader program linking failed, reason:\n    {s}", .{logbuf});
            return error.ShaderLinkError;
        }
        if (geom_shader_id) |_id| gl.glDeleteShader(_id);
        gl.glDeleteShader(frag_shader_id);
        gl.glDeleteShader(vtx_shader_id);

        return s;
    }

    pub fn load_default() !Shader {
        return Shader.build(default_vert_shader, default_frag_shader, null);
    }

    pub inline fn bind(self: *Shader) void {
        gl.glUseProgram(self.program_id);
    }

    pub inline fn set_uniform_mat2(self: *Shader, name: []const u8, mat: []Mat2) void {
        const id = gl.glGetUniformLocation(self.program_id, @ptrCast([*c]const u8, name));
        gl.glUniformMatrix2fv(id, mat.len, true, @ptrCast([*c]gl.GLfloat, mat.ptr));
    }

    pub inline fn set_uniform_mat3(self: *Shader, name: []const u8, mat: []Mat3) void {
        const id = gl.glGetUniformLocation(self.program_id, @ptrCast([*c]const u8, name));
        gl.glUniformMatrix3fv(id, mat.len, true, @ptrCast([*c]gl.GLfloat, mat.ptr));
    }

    pub inline fn set_uniform_mat4(self: *Shader, name: []const u8, mat: []Mat4) void {
        const id = gl.glGetUniformLocation(self.program_id, @ptrCast([*c]const u8, name));
        gl.glUniformMatrix4fv(id, @intCast(c_int, mat.len), gl.GL_TRUE, @ptrCast([*c]gl.GLfloat, mat.ptr));
    }

    pub inline fn set_uniform_vec2(self: *Shader, name: []const u8, vec: []Vec2) void {
        const id = gl.glGetUniformLocation(self.program_id, @ptrCast([*c]const u8, name));
        gl.glUniform2fv(id, @intCast(c_int, vec.len), @ptrCast([*c]gl.GLfloat, vec.ptr));
    }

    pub inline fn set_uniform_vec3(self: *Shader, name: []const u8, vec: []Vec3) void {
        const id = gl.glGetUniformLocation(self.program_id, @ptrCast([*c]const u8, name));
        gl.glUniform3fv(id, @intCast(c_int, vec.len), @ptrCast([*c]gl.GLfloat, vec.ptr));
    }

    pub inline fn set_uniform_vec4(self: *Shader, name: []const u8, vec: []Vec4) void {
        const id = gl.glGetUniformLocation(self.program_id, @ptrCast([*c]const u8, name));
        gl.glUniform4fv(id, @intCast(c_int, vec.len), @ptrCast([*c]gl.GLfloat, vec.ptr));
    }
};

fn load(allocator: std.mem.Allocator, fname: []const u8) !Shader {
    const bufsize: usize = 2048;
    var file_with_ext = [1]u8{0} ** bufsize;
    for (fname) |c, i| {
        if (i >= bufsize - 5) return error.NameTooLong;
        file_with_ext[i] = c;
    }

    file_with_ext[fname.len .. fname.len + 5].* = ".frag";
    const frag_src = try kf.load_text_file(allocator, file_with_ext);
    defer allocator.free(frag_src);

    file_with_ext[fname.len .. fname.len + 5].* = ".vert";
    const vtx_src = try kf.load_text_file(allocator, file_with_ext);
    defer allocator.free(vtx_src);

    file_with_ext[fname.len .. fname.len + 5].* = ".geom";
    const geom_src = kf.load_text_file(allocator, file_with_ext) catch |e| blk: {
        if (e != .FileNotFound) return e;
        break :blk null;
    };
    defer if (geom_src != null) allocator.free(geom_src.?);

    return Shader.build(vtx_src, frag_src, geom_src);
}

fn unload(shader: Shader) void {
    gl.glDeleteProgram(shader.program_id);
}

pub const ShaderManager = Manager(Shader, load, unload);
