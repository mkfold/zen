const std = @import("std");
// const gltf = @import("cgltf");

const math = @import("../math.zig");
const MeshVertex = @import("../render/vertex.zig").MeshVertex;
const Texture = @import("./texture.zig").Texture;

const Mat3x4 = math.Mat(math.real, 3, 4);

const load_iqm = @import("./iqm.zig").load;

pub const Mesh = struct {
    indices: []u32,
    material: ?*Texture,
};

pub const Joint = struct {
    parent: i32,
    translate: [3]f32,
    rotate: [4]f32,
    scale: [3]f32,
};

pub const Pose = struct {
    parent: i32,
    mask: u32,
    ch_offs: [10]f32,
    ch_scale: [10]f32,
};

pub const Animation = struct {
    frames: []Mat3x4,
    flags: u32,
    framerate: f32,
};

pub const StaticModel = struct {
    vertices: []MeshVertex,
    indices: []u32,
    meshes: []Mesh,
    materials: []u32,
};

pub const Model = struct {
    vertices: []MeshVertex,
    indices: []u32,
    meshes: []Mesh,
    materials: []u32,
    anims: []Animation,
    joints: []Joint,
    poses: []Pose,
    frames: []Mat3x4,
    bounds: []math.AABB,
};

// fn chk(result: gltf.cgltf_result) !void {
//     if (result != gltf.cgltf_result_success) {
//         return switch (result) {
//             gltf.cgltf_result_data_too_short => error.DataTooShort,
//             gltf.cgltf_result_unknown_format => error.UnknownFormat,
//             gltf.cgltf_result_invalid_json => error.InvalidJson,
//             gltf.cgltf_result_invalid_gltf => error.InvalidGltf,
//             gltf.cgltf_result_invalid_options => error.InvalidOptions,
//             gltf.cgltf_result_file_not_found => error.FileNotFound,
//             gltf.cgltf_result_io_error => error.IoError,
//             gltf.cgltf_result_out_of_memory => error.OutOfMemory,
//             gltf.cgltf_result_legacy_gltf => error.UnsupportedFormat,
//             else => error.UnknownError, // lame
//         };
//     }
// }
//
// pub fn load(fname: []const u8) !Model {
//     var opts = std.mem.zeroes(gltf.cgltf_options);
//     var data: [*c]gltf.cgltf_data = null;
//
//     try chk(gltf.cgltf_parse_file(&opts, fname, &data));
//     defer gltf.cgltf_free(data);
//
//     try chk(gltf.cgltf_load_buffers(&opts, data, fname));
// }
