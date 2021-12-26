//! zen: queue.zig
//! batched rendering implementation

const std = @import("std");
const gl = @import("gl");

/// creates a vertex batcher. initializes a vao, ebo, and a vbo with attributes
/// for vertex struct members.
pub fn Batcher(comptime T: type) type {
    return struct {
        const Self = @This();

        vao: u32,
        vbo: u32,
        ebo: u32,

        vertices: []T,
        indices: []c_uint,

        voffs: usize = 0,
        eoffs: usize = 0,

        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator, vertex_buf_size: usize) !Self {
            var self: Self = undefined;

            self.vertices = try allocator.alloc(T, vertex_buf_size);
            errdefer allocator.free(self.vertices);

            self.indices = try allocator.alloc(c_uint, vertex_buf_size * 3);
            errdefer allocator.free(self.indices);

            gl.glGenVertexArrays(1, &self.vao);
            gl.glGenBuffers(1, &self.vbo);
            gl.glGenBuffers(1, &self.ebo);

            gl.glBindVertexArray(self.vao);
            gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);

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
                gl.glVertexAttribPointer(index, field_info.len, gl_type, gl.GL_FALSE, @sizeOf(T), @intToPtr(*allowzero c_void, @offsetOf(T, field.name)));
            }

            gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);
            gl.glBufferData(gl.GL_ARRAY_BUFFER, vertex_buf_size * @sizeOf(T), null, gl.GL_DYNAMIC_DRAW);

            gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.ebo);
            gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, 3 * vertex_buf_size * @sizeOf(c_uint), null, gl.GL_DYNAMIC_DRAW);

            gl.glBindVertexArray(0);

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.vertices);
            self.allocator.free(self.indices);
        }

        pub inline fn bind(self: *Self) void {
            gl.glBindVertexArray(self.vao);
        }

        pub fn add(self: *Self, vertices: []T, indices: []u32) !void {
            if (self.voffs + vertices.len > self.vertices.len or self.eoffs + indices.len > self.indices.len) {
                try self.draw();
            }

            for (vertices) |v, i| self.vertices[self.voffs + i] = v;
            for (indices) |e, i| self.indices[self.eoffs + i] = e;

            self.voffs += vertices.len;
            self.eoffs += indices.len;
        }

        pub fn draw(self: *Self) !void {
            self.bind();
            gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbo);
            gl.glBufferData(gl.GL_ARRAY_BUFFER, self.vertices.len * @sizeOf(T), self.vertices.ptr);
            gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.ebo);
            gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, self.indices.len, self.indices.ptr);
        }
    };
}

// queued batched rendering procedure:
// 1) for everything but gui, determine geometry visible from current view
// 2) queue visible geometry
// 3) sort queue by texture, shader, vbo, etc.
// 4) set uniforms for camera, etc.
// 5) split into batches and draw

pub fn RenderQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        queue: []T,
        // batcher: Batcher(...),
        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator) RenderQueue(T) {
            return Self{ .queue = std.ArrayList(T).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.queue.deinit();
        }

        // pub fn push(self: Self, mesh: T) !void {
        //
        // }

        pub fn draw(self: *Self) !void {
            // batcher.bind();
            var vertex_offset: u32 = 0;
            var index_offset: u32 = 0;
            for (self.queue.items) |_| {
                // if (vertex_offset > batcher.buf_len or index_offset > batcher.buf_len * 3) {
                // draw and reset
                // batcher.draw();
                vertex_offset = 0;
                index_offset = 0;
                //}

                // add mesh vertices and indices to batch buffer
                // self.batcher.add(mesh.vertices, mesh.indices, vertex_offset, index_offset);
            }
            //  empty the queue
        }

        pub fn clear(self: *Self) void {
            self.queue.clearRetainingCapacity();
        }
    };
}
