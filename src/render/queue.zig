//! zng: batch.zig
//! batched rendering implementation

const std = @import("std");

usingnamespace @import("./vertex.zig");
const c = @import("../c.zig");

/// creates a vertex batcher. initializes a vao, ebo, and a vbo with attributes
/// for vertex struct members.
pub fn Batcher(comptime T: type) type {
    return struct {
        const Self = @This();

        _vao: u32,
        _vbo: u32,
        _ebo: u32,

        vertex_buf_size: u32,
        index_buf_size: u32,

        pub fn init(allocator: *std.mem.Allocator, vertex_buf_size: u32) !Batcher(T) {
            var batcher: Batcher(T) = undefined;

            c.glGenVertexArrays(1, &batcher._vao);
            c.glGenBuffers(1, &batcher._vbo);
            c.glGenBuffers(1, &batcher._ebo);

            c.glBindVertexArray(batcher._vao);
            c.glBindBuffer(c.GL_ARRAY_BUFFER, batcher._vbo);

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

        pub inline fn bind(self: Self) void {
            c.glBindVertexArray(self._vao);
        }

        pub fn add(self: Self, vertices: []T, indices: []u32, vertex_offset: u32, index_offset: u32) !void {
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self._vbo);
            c.glBufferSubData(c.GL_ARRAY_BUFFER, vertex_offset, vertices.len, vertices.ptr);

            c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self._ebo);
            c.glBufferSubData(c.GL_ELEMENT_ARRAY_BUFFER, index_offset, indices.len, indices.ptr);
        }
    };
}

pub const GuiBatcher = Batcher(GuiVertex);
pub const StaticMeshBatcher = Batcher(StaticMeshVertex);
pub const MeshBatcher = Batcher(MeshVertex);

pub const Drawable = struct {
    mesh: u32,
    mesh_type: MeshType,
    material: ?u32,
    shader: u32,
};

//! queued batched rendering procedure:
//! 1) for everything but gui, determine geometry visible from current view
//! 2) queue visible geometry
//! 3) sort queue by texture, shader, vbo, etc.
//! 4) set uniforms for camera, etc.
//! 5) split into batches and draw

pub fn RenderQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        queue: []T,
        // batcher: Batcher(...),
        allocator: *Allocator,

        pub fn init(allocator: *Allocator) RenderQueue(T) {
            return Self{ .queue = std.ArrayList(T).init(allocator) };
        }

        pub fn deinit(self: Self) void {
            queue.deinit();
        }

        pub fn push(self: Self, mesh: T) !void {
            //
        }

        pub fn draw(self: Self) !void {
            // batcher.bind();
            var vertex_offset: u32 = 0;
            var index_offset: u32 = 0;
            for (queue.items) |mesh| {
                if (vertex_offset > batcher.buf_len or index_offset > batcher.buf_len * 3) {
                    // draw and reset
                    // batcher.draw();
                    vertex_offset = 0;
                    index_offset = 0;
                }

                // add mesh vertices and indices to batch buffer
                batcher.add(mesh.vertices, mesh.indices, vertex_offset, index_offset);
                vertex_offset += mesh.vertices.len;
                index_offset += mesh.vertices.len;
            }
            //  empty the queue
        }

        pub fn clear(self: Self) void {
            //
        }
    };
}
