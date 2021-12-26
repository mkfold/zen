//! gl buffer objects
//!
//! buffer creation should be done after all mesh assets have been loaded so
//! meshes with the same vertex format can be packed into common buffers.

const gl = @import("gl");

pub const GlBuffer = struct {
    vao: u32,
    vbo: u32,
    ebo: u32,

    pub fn init() !GlBuffer {
        
    }
};

pub fn init_buffer(comptime T: type) u32 {
    const vertex_fields = @typeInfo(T).Struct.fields;
    inline for (vertex_fields) |field, index| {
        const field_info = @typeInfo(field.field_type).Array;

        // TODO: add more types? or just add as needed
        const gl_type = switch (field_info.child) {
            u8 => gl.GL_UNSIGNED_BYTE,
            f32 => gl.GL_FLOAT,
            else => @compileError("Unsupported vertex type."),
        };

        gl.glEnableVertexAttribArray(index);
        gl.glVertexAttribPointer(
            index,
            field_info.len,
            gl_type,
            gl.GL_FALSE,
            @sizeOf(T),
            @intToPtr(?*c_void, @offsetOf(T, field.name)),
        );
    }

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, batcher._vbo);
    gl.glBufferData(
        gl.GL_ARRAY_BUFFER,
        vertex_buf_size * @sizeOf(T),
        null,
        gl.GL_DYNAMIC_DRAW,
    );

    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, batcher._ebo);
    gl.glBufferData(
        gl.GL_ELEMENT_ARRAY_BUFFER,
        3 * vertex_buf_size * @sizeOf(u32),
        null,
        gl.GL_DYNAMIC_DRAW,
    );

    gl.glBindVertexArray(0);

    batcher.vertex_buf_size = vertex_buf_size;
    batcher.index_buf_size = vertex_buf_size * 3;

    return batcher;
}

pub fn gen_buffer_from_data(
    comptime T: type,
    buffer: []T,
) u32 {
    const num_verts = @sizeOf(Vertex) * 3 * num_tris;
    var bufs: GlBuffer = undefined;
    gl.glGenVertexArrays(1, &bufs.vao);
    gl.glGenBuffers(1, &bufs.vbo);
    gl.glGenBuffers(1, &bufs.ebo);

    gl.glBindVertexArray(bufs.vao);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, bufs.vbo);

    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(Vertex), @intToPtr(?*c_void, @byteOffsetOf(Vertex, "position")));
    gl.glEnableVertexAttribArray(0);

    gl.glVertexAttribPointer(1, 4, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(Vertex), @intToPtr(?*c_void, @byteOffsetOf(Vertex, "color")));
    gl.glEnableVertexAttribArray(1);

    gl.glBufferData(gl.GL_ARRAY_BUFFER, num_verts, @as(*c_void, &vertex_buffer), gl.GL_STATIC_DRAW);

    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, bufs.ebo);
    gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, 3 * num_tris * @sizeOf(u32), null, gl.GL_STATIC_DRAW);
    gl.glBindVertexArray(0);

    return bufs;
}
