//! gl buffer objects
//!
//! buffer creation should be done after all mesh assets have been loaded so
//! meshes with the same vertex format can be packed into common buffers.

const gl = @import("../c.zig").gl;

pub const GlBuffer = struct {
    vao: u32,
    vbo: u32,
    ebo: u32,

    pub fn init(comptime T: type) GlBuffer {
        var bufs: GlBuffer = undefined;
        gl.glGenVertexArrays(1, &bufs.vao);
        gl.glGenBuffers(1, &bufs.vbo);
        gl.glGenBuffers(1, &bufs.ebo);

        gl.glBindVertexArray(bufs.vao);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, bufs.vbo);

        const vertex_fields = @typeInfo(T).Struct.fields;
        inline for (vertex_fields) |field, index| {
            const field_info = @typeInfo(field.field_type).Array;

            // TODO: add more types? or just add as needed
            const gl_type = switch (field_info.child) {
                u8 => gl.GL_UNSIGNED_BYTE,
                f32 => gl.GL_FLOAT,
                else => @compileError("Unsupported vertex type."),
            };

            gl.glVertexAttribPointer(
                index,
                field_info.len,
                gl_type,
                gl.GL_FALSE,
                @sizeOf(T),
                @intToPtr(?*anyopaque, @offsetOf(T, field.name)),
            );
            gl.glEnableVertexAttribArray(index);
        }

        gl.glBindBuffer(0);
        gl.glBindVertexArray(0);

        return bufs;
    }

    pub fn from_data(
        comptime T: type,
        vertices: []T,
        indices: []u32,
    ) GlBuffer {
        var bufs = GlBuffer.init(T);

        gl.glBindVertexArray(bufs.vao);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, bufs.vbo);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, vertices.len * @sizeOf(T), @as(*anyopaque, &vertices.ptr), gl.GL_STATIC_DRAW);

        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, bufs.ebo);
        gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), @as(*anyopaque, &indices.ptr), gl.GL_STATIC_DRAW);
        gl.glBindBuffer(0);
        gl.glBindVertexArray(0);

        return bufs;
    }
};
