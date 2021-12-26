usingnamespace @import("./vertex.zig");

const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;

const Material = @import("./material.zig").Material;

pub fn Mesh(comptime T: type) type {
    return struct {
        vertices: []T,
        indices: []u32,
    };
}
