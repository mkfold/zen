//! gl buffer objects
//!
const gl = @import("../c.zig").gl;

pub const MeshHandle = packed struct {
    num_verts: u32,
    offs_verts: u32,
    num_index: u32,
    offs_index: u32,
};

pub fn VertexArray(comptime T: type) type {
    return struct {
        const initial_size: u32 = 2048;
        pub const Self = @This();

        vao: u32,
        vbo: u32,
        ebo: u32,

        vbuf_size: u32 = 0,
        vbuf_used: u32 = 0,

        ibuf_size: u32 = 0,
        ibuf_used: u32 = 0,

        pub fn init() Self {
            var bufs = Self{
                .vao = undefined,
                .vbo = undefined,
                .ebo = undefined,
                .vbuf_size = Self.initial_size,
                .ibuf_size = Self.initial_size * 3,
            };

            gl.glGenVertexArrays(1, &bufs.vao);
            gl.glGenBuffers(1, &bufs.vbo);
            gl.glGenBuffers(1, &bufs.ebo);

            gl.glBindVertexArray(bufs.vao);
            gl.glBindVertexBuffer(0, bufs.vbo, 0, @sizeOf(T));
            const vertex_fields = @typeInfo(T).Struct.fields;
            inline for (vertex_fields) |field, index| {
                const field_info = @typeInfo(field.field_type).Array;

                // TODO: add more types? or just add as needed
                const gl_type = switch (field_info.child) {
                    u8 => gl.GL_UNSIGNED_BYTE,
                    u16 => gl.GL_UNSIGNED_SHORT,
                    u32 => gl.GL_UNSIGNED_INT,
                    i8 => gl.GL_BYTE,
                    i16 => gl.GL_SHORT,
                    i32 => gl.GL_INT,
                    f32 => gl.GL_FLOAT,
                    f64 => gl.GL_DOUBLE,
                    else => @compileError("Unsupported vertex type."),
                };

                gl.glEnableVertexAttribArray(index);
                const offs = @intCast(c_uint, @offsetOf(T, field.name));
                gl.glVertexAttribFormat(index, field_info.len, gl_type, gl.GL_FALSE, offs);
                gl.glVertexAttribBinding(index, 0);
            }

            gl.glBufferData(
                gl.GL_ARRAY_BUFFER,
                @intCast(c_long, bufs.vbuf_size * @sizeOf(T)),
                null,
                gl.GL_STATIC_DRAW,
            );

            gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, bufs.ebo);
            gl.glBufferData(
                gl.GL_ELEMENT_ARRAY_BUFFER,
                @intCast(c_long, bufs.ibuf_size * @sizeOf(u32)),
                null,
                gl.GL_STATIC_DRAW,
            );

            gl.glBindVertexArray(0);

            return bufs;
        }

        pub fn buffer(self: *VertexArray, vertices: []const T, indices: []const u32) MeshHandle {
            const h = MeshHandle{
                .num_verts = @intCast(u32, vertices.len),
                .offs_verts = self.vbuf_used,
                .num_index = @intCast(u32, indices.len),
                .offs_index = self.ibuf_used,
            };
            gl.glBindVertexArray(self.vao);
            const new_vbuf_used = @intCast(usize, self.vbuf_used) + vertices.len;
            if (new_vbuf_used > @intCast(usize, self.vbuf_size)) {
                var new_vbo: u32 = undefined;
                gl.glGenBuffers(1, &new_vbo);
                gl.glBindVertexBuffer(0, new_vbo, 0, @sizeOf(T));
                gl.glBufferData(
                    gl.GL_ARRAY_BUFFER,
                    @intCast(c_long, 2 * self.vbuf_size * @sizeOf(T)),
                    null,
                    gl.GL_STATIC_DRAW,
                );
                gl.glBindVertexBuffer(0, 0, 0, 0);
                gl.glBindBuffer(gl.GL_COPY_WRITE_BUFFER, new_vbo);
                gl.glBindBuffer(gl.GL_COPY_READ_BUFFER, self.vbo);
                gl.glCopyBufferSubData(
                    gl.GL_COPY_READ_BUFFER,
                    gl.GL_COPY_WRITE_BUFFER,
                    0,
                    0,
                    @intCast(c_long, self.vbuf_used * @sizeOf(T)),
                );
                gl.glBindBuffer(gl.GL_COPY_READ_BUFFER, 0);
                gl.glBindBuffer(gl.GL_COPY_WRITE_BUFFER, 0);
                gl.glDeleteBuffers(1, &self.vbo);
                self.vbo = new_vbo;
                self.vbuf_size = 2 * self.vbuf_size;
            }

            const new_ibuf_used = @intCast(usize, self.ibuf_used) + indices.len;
            if (new_ibuf_used > @intCast(usize, self.ibuf_size)) {
                var new_ebo: u32 = undefined;
                gl.glGenBuffers(1, &new_ebo);
                gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, new_ebo);
                gl.glBufferData(
                    gl.GL_ELEMENT_ARRAY_BUFFER,
                    @intCast(c_long, 2 * self.ibuf_size * @sizeOf(T)),
                    null,
                    gl.GL_STATIC_DRAW,
                );
                gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
                gl.glBindBuffer(gl.GL_COPY_WRITE_BUFFER, new_ebo);
                gl.glBindBuffer(gl.GL_COPY_READ_BUFFER, self.ebo);
                gl.glCopyBufferSubData(
                    gl.GL_COPY_READ_BUFFER,
                    gl.GL_COPY_WRITE_BUFFER,
                    0,
                    0,
                    @intCast(c_long, self.ibuf_used * @sizeOf(u32)),
                );
                gl.glBindBuffer(gl.GL_COPY_READ_BUFFER, 0);
                gl.glBindBuffer(gl.GL_COPY_WRITE_BUFFER, 0);
                gl.glDeleteBuffers(1, &self.ebo);
                self.ebo = new_ebo;
                self.ibuf_size = 2 * self.ibuf_size;
            }

            gl.glBindVertexBuffer(0, self.vbo, 0, @sizeOf(T));
            gl.glBufferSubData(
                gl.GL_ARRAY_BUFFER,
                @intCast(c_long, self.vbuf_used * @sizeOf(T)),
                @intCast(c_long, vertices.len * @sizeOf(T)),
                @ptrCast(*const anyopaque, vertices.ptr),
            );
            gl.glBindVertexBuffer(0, 0, 0, 0);
            self.vbuf_used += @intCast(u32, vertices.len);

            gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.ebo);
            gl.glBufferSubData(
                gl.GL_ELEMENT_ARRAY_BUFFER,
                @intCast(c_long, self.ibuf_used * @sizeOf(u32)),
                @intCast(c_long, indices.len * @sizeOf(u32)),
                @ptrCast(*const anyopaque, indices.ptr),
            );
            gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
            self.ibuf_used += @intCast(u32, vertices.len);
            gl.glBindVertexArray(0);

            return h;
        }
    };
}
