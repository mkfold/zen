const std = @import("std");

const model = @import("./model.zig");
const Model = model.Model;
const Mesh = model.Mesh;

const asset = @import("../asset.zig");
const c = @import("../c.zig");
const math = @import("../math.zig");
const vertex = @import("../render/vertex.zig");
const MeshVertex = vertex.MeshVertex;
const texture = @import("./texture.zig");
// const StaticMeshVertex = vertex.StaticMeshVertex;

pub const Mat3x4 = math.Mat(math.real, 3, 4);
const AABB = math.AABB;

pub const Error = error{
    InvalidHeader,
    InvalidMagic,
    UnsupportedVersion,
    InvalidVertexFormat,
    UnsupportedVertexAttribute,
};

pub fn load(allocator: std.mem.Allocator, fname: []const u8) !Model {
    var _gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = _gpa.deinit();
        if (leaked) @panic("");
    }
    const gpa = _gpa.allocator();

    const file = try std.fs.cwd().openFile(fname, .{ .read = true });
    defer file.close();

    var h: c.iqmheader = undefined;
    {
        const s = try file.read(std.mem.asBytes(&h)[0..]);
        if (s != @sizeOf(c.iqmheader)) return Error.InvalidHeader;
    }
    if (!std.mem.eql(u8, h.magic[0..15], c.IQM_MAGIC[0..15]))
        return Error.InvalidMagic;

    var buf: []u8 = try gpa.alloc(u8, h.filesize);
    defer gpa.free(buf);

    {
        try file.seekTo(0);
        const s = try file.readAll(buf);
        if (s != h.filesize) return error.FileReadError;
    }

    const str: []const u8 = if (h.ofs_text != 0) buf[h.ofs_text .. h.ofs_text + h.num_text] else "";

    // loading meshes
    var m: Model = std.mem.zeroes(Model);

    // get vertex data
    const v_arrays = @ptrCast(
        [*]c.iqmvertexarray,
        @alignCast(@alignOf(c.iqmvertexarray), &buf[h.ofs_vertexarrays]),
    )[0..h.num_vertexarrays];
    m.vertices = try allocator.alloc(MeshVertex, h.num_vertexes);
    for (v_arrays) |va| {
        switch (va.type) {
            c.IQM_POSITION => {
                if (va.format != c.IQM_FLOAT or va.size != 3) return Error.InvalidVertexFormat;
                const verts = @ptrCast([*]f32, @alignCast(@alignOf(f32), &buf[va.offset]))[0 .. h.num_vertexes * 3];
                for (verts) |v, k| m.vertices[@divTrunc(k, 3)].position[(k + 2) % 3] = v;
            },
            c.IQM_NORMAL => {
                if (va.format != c.IQM_FLOAT or va.size != 3) return Error.InvalidVertexFormat;
                const verts = @ptrCast([*]f32, @alignCast(@alignOf(f32), &buf[va.offset]))[0 .. h.num_vertexes * 3];
                for (verts) |v, k| m.vertices[@divTrunc(k, 3)].normal[(k + 2) % 3] = v;
            },
            c.IQM_TANGENT => {
                if (va.format != c.IQM_FLOAT or va.size != 4) return Error.InvalidVertexFormat;
                const verts = @ptrCast([*]f32, @alignCast(@alignOf(f32), &buf[va.offset]))[0 .. h.num_vertexes * 4];
                for (verts) |v, k| m.vertices[@divTrunc(k, 4)].tangent[k % 4] = v;
            },
            c.IQM_TEXCOORD => {
                if (va.format != c.IQM_FLOAT or va.size != 2) return Error.InvalidVertexFormat;
                const verts = @ptrCast([*]f32, @alignCast(@alignOf(f32), &buf[va.offset]))[0 .. h.num_vertexes * 2];
                for (verts) |v, k| m.vertices[@divTrunc(k, 2)].tex_coord[k % 2] = v;
            },
            c.IQM_BLENDINDEXES => {
                if (va.format != c.IQM_UBYTE or va.size != 4) return Error.InvalidVertexFormat;
                const verts = @ptrCast([*]u8, @alignCast(@alignOf(u8), &buf[va.offset]))[0 .. h.num_vertexes * 4];
                for (verts) |v, k| m.vertices[@divTrunc(k, 4)].blend_indices[k % 4] = v;
            },
            c.IQM_BLENDWEIGHTS => {
                if (va.format != c.IQM_UBYTE or va.size != 4) return Error.InvalidVertexFormat;
                const verts = @ptrCast([*]u8, @alignCast(@alignOf(u8), &buf[va.offset]))[0 .. h.num_vertexes * 4];
                for (verts) |v, k| m.vertices[@divTrunc(k, 4)].blend_weights[k % 4] = v;
            },
            c.IQM_COLOR => {
                if (va.format != c.IQM_UBYTE or va.size != 4) return Error.InvalidVertexFormat;
                const verts = @ptrCast([*]u8, @alignCast(@alignOf(u8), &buf[va.offset]))[0 .. h.num_vertexes * 4];
                for (verts) |v, k| m.vertices[k].color[k % 4] = v;
            },
            else => return Error.UnsupportedVertexAttribute,
        }
    }

    // get indices from triangle data
    const indices = @ptrCast(
        [*]c_uint,
        @alignCast(@alignOf(c_uint), &buf[h.ofs_triangles]),
    )[0 .. h.num_triangles * 3];
    m.indices = try allocator.alloc(u32, h.num_triangles * 3);
    var ii: usize = 0;
    while (ii < h.num_triangles * 3) : (ii += 3) {
        m.indices[ii] = indices[ii];
        m.indices[ii + 2] = indices[ii + 1];
        m.indices[ii + 1] = indices[ii + 2];
    }
    // for (indices) |src, k| m.indices[k] = src;

    // get discrete meshes and their material ids
    const meshes = @ptrCast(
        [*]c.iqmmesh,
        @alignCast(@alignOf(c.iqmmesh), &buf[h.ofs_meshes]),
    )[0..h.num_meshes];
    m.meshes = try allocator.alloc(Mesh, h.num_meshes);
    for (meshes) |src, i| {
        const ioffs = src.first_triangle * 3;
        const inum = src.num_triangles * 3;
        std.debug.print(
            "loaded mesh {s}: {} tris\n",
            .{ std.mem.sliceTo(str[src.name..], '\x00'), src.num_triangles },
        );
        const material_name = std.mem.sliceTo(str[src.material..], '\x00');
        var tex: ?*texture.Texture = null;
        if (material_name.len != 0) {
            var mpath = try std.mem.join(gpa, "", &.{ "assets/tex/", material_name });
            defer gpa.free(mpath);
            tex = try allocator.create(texture.Texture);
            tex.?.* = try asset.textures.load(mpath);
        }
        m.meshes[i] = .{
            .indices = m.indices[ioffs .. ioffs + inum],
            .material = tex,
        };
    }

    return m;
    // model.materials = try allocator.alloc(u32, h.num_meshes);

    // TODO: all this animation bullshit
    //    const joints = @ptrCast(
    //        [*]c.iqmjoint,
    //        @alignCast(@alignOf(c.iqmjoint), &buf[h.ofs_joints]),
    //    )[0..h.num_joints];
    //    model.joints = try allocator.alloc(model.Joint, h.num_joints);
    //    model.frames = try allocator.alloc(Mat3x4, h.num_joints);
    //
    //    var base_frames = try gpa.alloc(Mat3x4, h.num_joints);
    //    defer gpa.free(base_frames);
    //    var inverse_base_frames = try gpa.alloc(Mat3x4, h.num_joints);
    //    defer gpa.free(inverse_base_frames);
    //    for (joints) |j, i| {
    //        const qr = math.Quat.from_vec4(
    //            math.Vec4.normalize(.{ .x = j.rotate[0], .y = j.rotate[1], .z = j.rotate[2], .w = j.rotate[3] }),
    //        );
    //        const scale = math.Vec3{ .x = j.scale[0], .y = j.scale[1], .z = j.scale[2] };
    //        const trans = math.Vec3{ .x = j.translate[0], .y = j.translate[1], .z = j.translate[2] };
    //        var f = qr.to_mat3(qr);
    //        f.mul_rowwise(scale);
    //        // : a(Vec4(rot.a, trans.x)), b(Vec4(rot.b, trans.y)), c(Vec4(rot.c, trans.z))
    //        base_frames[i] = math.Mat3x4.from_rows(
    //            math.Vec4{ .x = f.mat[0].x, .y = f.mat[0].y, .z = f.mat[0].z, .w = trans.x },
    //            math.Vec4{ .x = f.mat[1].x, .y = f.mat[1].y, .z = f.mat[1].z, .w = trans.y },
    //            math.Vec4{ .x = f.mat[2].x, .y = f.mat[2].y, .z = f.mat[2].z, .w = trans.z },
    //        );
    //        inverse_base_frames[i] = base_frames[i]; // TODO: this needs to be the inverse
    //
    //        std.debug.warn("{?}\n", .{f});
    //    }
}

test "load iqm test model" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    _ = try load(alloc, "assets/models/sponza.iqm");
}
