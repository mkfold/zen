//! gl buffer objects
//!
//! buffer creation should be done after all mesh assets have been loaded so
//! meshes with the same vertex format can be packed into common buffers.

const c = @import("../c.zig");

pub const GlBuffer = struct {
    vertex_array: u32,
    vertex_buffer: u32,
    index_buffer: u32,
    transform_buffer: u32,
};

pub fn init_buffer(comptime T: type) u32 {
    var buffer_obj: u32 = undefined;
    c.glGenBuffers(1, &buffer_obj);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, buffer_obj);

    const vertex_fields = @typeInfo(T).Struct.fields;
    inline for (vertex_fields) |field, index| {
        const field_info = @typeInfo(field.field_type).Array;

        // TODO: add more types? or just add as needed
        const gl_type = switch (field_info.child) {
            u8 => c.GL_UNSIGNED_BYTE,
            f32 => c.GL_FLOAT,
            else => {
                @compileError("Unsupported vertex type.");
            },
        };

        c.glEnableVertexAttribArray(index);
        c.glVertexAttribPointer(
            index,
            field_info.len,
            gl_type,
            c.GL_FALSE,
            @sizeOf(T),
            @intToPtr(?*c_void, @byteOffsetOf(T, field.name)),
        );
    }

    c.glBindBuffer(c.GL_ARRAY_BUFFER, batcher._vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        vertex_buf_size * @sizeOf(T),
        null,
        c.GL_DYNAMIC_DRAW,
    );

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, batcher._ebo);
    c.glBufferData(
        c.GL_ELEMENT_ARRAY_BUFFER,
        3 * vertex_buf_size * @sizeOf(u32),
        null,
        c.GL_DYNAMIC_DRAW,
    );

    c.glBindVertexArray(0);

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
    c.glGenVertexArrays(1, &bufs.vao);
    c.glGenBuffers(1, &bufs.vbo);
    c.glGenBuffers(1, &bufs.ebo);

    c.glBindVertexArray(bufs.vao);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, bufs.vbo);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @intToPtr(?*c_void, @byteOffsetOf(Vertex, "position")));
    c.glEnableVertexAttribArray(0);

    c.glVertexAttribPointer(1, 4, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @intToPtr(?*c_void, @byteOffsetOf(Vertex, "color")));
    c.glEnableVertexAttribArray(1);

    c.glBufferData(c.GL_ARRAY_BUFFER, num_verts, @as(*c_void, &vertex_buffer), c.GL_STATIC_DRAW);

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, bufs.ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, 3 * num_tris * @sizeOf(u32), null, c.GL_STATIC_DRAW);
    c.glBindVertexArray(0);

    return bufs;
}
