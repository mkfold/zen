pub const GuiVertex = extern struct {
    position: [3]f32 = [3]f32{ 0, 0, 0 },
    tex_coord: [2]f32 = [2]f32{ 0, 0 },
    color: [4]u8 = [4]u8{ 0, 0, 0, 0 },
};

pub const StaticMeshVertex = extern struct {
    position: [3]f32 = [3]f32{ 0, 0, 0 },
    tex_coord: [2]f32 = [2]f32{ 0, 0 },
    normal: [3]f32 = [3]f32{ 0, 0, 0 },
    tangent: [4]f32 = [4]f32{ 0, 0, 0, 0 },
    color: [4]u8 = [4]u8{ 0, 0, 0, 0 },
};

pub const MeshVertex = extern struct {
    position: [3]f32 = [3]f32{ 0, 0, 0 },
    tex_coord: [2]f32 = [2]f32{ 0, 0 },
    normal: [3]f32 = [3]f32{ 0, 0, 0 },
    tangent: [4]f32 = [4]f32{ 0, 0, 0, 0 },
    blend_indices: [4]u8 = [4]u8{ 0, 0, 0, 0 },
    blend_weights: [4]u8 = [4]u8{ 0, 0, 0, 0 },
    color: [4]u8 = [4]u8{ 0, 0, 0, 0 },
};
