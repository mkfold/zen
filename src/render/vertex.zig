pub const GuiVertex = extern struct {
    position: [3]f32,
    tex_coord: [2]f32,
    color: [4]u8,
};

pub const StaticMeshVertex = extern struct {
    position: [3]f32,
    tex_coord: [2]f32,
    normal: [3]f32,
    tangent: [4]f32,
    color: [4]u8,
};

pub const MeshVertex = extern struct {
    position: [3]f32,
    tex_coord: [2]f32,
    normal: [3]f32,
    tangent: [4]f32,
    blend_indices: [4]u8,
    blend_weights: [4]u8,
    color: [4]u8,
};
