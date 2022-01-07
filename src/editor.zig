const std = @import("std");
const log = std.log.scoped(.editor);

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Plane = math.Plane;

const Error = error{ UnknownEntityId, InvalidBrushProps };

const PrefabShape = enum {
    cube,
    tetrahedron,
    dodecahedron,
    cylinder,
};

const def_brush_scale = math.vec3(16.0, 16.0, 16.0);
const def_brush_pos = Vec3.zero();
const def_brush_rot = Vec3.zero();

const cube_planes = [_]Brush.Face{
    .{ .plane = .{ .norm = math.vec3(1, 0, 0), .dist = 0.5 } },
    .{ .plane = .{ .norm = math.vec3(0, 1, 0), .dist = 0.5 } },
    .{ .plane = .{ .norm = math.vec3(0, 0, 1), .dist = 0.5 } },
    .{ .plane = .{ .norm = math.vec3(-1, 0, 0), .dist = 0.5 } },
    .{ .plane = .{ .norm = math.vec3(0, -1, 0), .dist = 0.5 } },
    .{ .plane = .{ .norm = math.vec3(0, 0, -1), .dist = 0.5 } },
};

const Brush = struct {
    pub const Face = struct {
        plane: math.Plane = undefined,

        tex_id: u32 = 0,
        u_coords: [4]f32 = undefined,
        v_coords: [4]f32 = undefined,
        u_scale: f32 = 0,
        v_scale: f32 = 0,
    };

    pub const Tag = enum { air, solid, water, fog, clip, sky };

    tag: Tag = .air,

    faces: []Face = &[0].{},
    polys: []Polygon = &[0].{},

    position: Vec3 = Vec3.zero(),
    rotation: Vec3 = Vec3.zero(),
    scale: Vec3 = Vec3.one(),
};

const Entity = struct {
    pub const Tag = enum {
        player_start,
        object,
        light,
        trigger,
    };

    tag: Tag = .object,

    position: Vec3 = Vec3.zero(),
    rotation: Vec3 = Vec3.zero(),
    scale: Vec3 = Vec3.one(),
};

const Polygon = struct { points: std.ArrayList(Vec3) };

pub const Map = struct {
    brushes: std.AutoArrayHashMap(u64, Brush),
    entities: std.AutoArrayHashMap(u64, Entity),
};

pub const Editor = struct {
    map_path: []const u8 = "",
    current_map: Map,
    dirty: bool = false,
    needs_rebuild: bool = false,

    auto_intersect: bool = true,
    auto_compile: bool = false,

    cam_pos: Vec3 = Vec3.zero(),
    cam_theta: Vec3 = Vec3.zero(),

    allocator: std.mem.Allocator,
    temp_allocator: std.mem.Allocator,

    _bid: u64 = 0,
    _fid: u64 = 0,
    _eid: u64 = 0,
    _polyid: u64 = 0,
    _pointid: u64 = 0,
    _vid: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, temp_allocator: std.mem.Allocator) Editor {
        return Editor{
            .allocator = allocator,
            .temp_allocator = temp_allocator,
            .current_map = Map{
                .brushes = std.AutoArrayHashMap(u64, Brush).init(allocator),
                .entities = std.AutoArrayHashMap(u64, Entity).init(allocator),
            },
        };
    }

    pub fn load(self: *Editor, fname: []const u8) !void {
        // parse map brush list for calls to brushadd
        _ = self;
        _ = fname;
        return error.NotImplemented;
    }

    pub fn clear(self: *Editor) void {
        var map = self.current_map;
        map.brushes.clearRetainingCapacity();
        map.entities.clearRetainingCapacity();
        log.info("map cleared.", .{});
    }

    pub fn deinit(self: *Editor) void {
        var map = self.current_map;
        map.brushes.deinit();
        map.entities.deinit();
    }

    pub fn brushadd(self: *Editor, kind: Brush.Tag, pos: Vec3, scale: Vec3, rot: Vec3, shape: PrefabShape) !void {
        var map = &self.current_map;
        var b = Brush{ .tag = kind };
        errdefer {
            b.faces.deinit();
            b.polys.deinit();
        }

        switch (shape) {
            .cube => b.faces = try self.temp_allocator.dupe(Brush.Face, cube_planes),
            // .cylinder => {
            // var d_theta: f32 = math.two_pi / n_cyl_faces;
            // var theta: f32 = 0;
            // var i: usize = 0;
            // while (i < n_cyl_faces) : (i += 1) {
            //     theta = x * d_theta;
            //     f.plane = {{glm::cos(theta), glm::sin(theta), 0}};
            // },
            else => return Error.InvalidBrushProps,
        }

        b.position = pos;
        b.scale = scale;
        b.rotation = rot;

        try map.*.brushes.put(self._bid, b);
        // TODO: make this happen somewhere else
        try self.gen_brush_polys(self._bid);
        self._bid += 1;
        // return;
    }

    pub fn brushdel(self: *Editor, id: u64) void {
        var map = &self.current_map;
        var b = map.*.brushes.fetchSwapRemove(id).?;
        self.temp_allocator.free(b.faces);
        for (b.polys) |p| self.temp_allocator.free(p.points);
        self.temp_allocator.free(b.polys);
    }

    // pub fn entadd(id: u32, pos: Vec3, rot: Vec3, scale: Vec3) void {
    //     return;
    // }

    // pub fn entdel(id: u32) void {
    //     return;
    // }

    pub fn compile(self: *Editor) !void {
        var map = &self.current_map;
        // steps:
        // 1) get polygons from brushes
        //    a) compute intersections of planes
        //    b) sort vertices of each polygon
        // 2) compute union of brush polygons
        // 3) build bsp tree from polygons
        // 4) attach entities to nodes
        if (map.*.brushes.count() == 0) {
            log.err("Cannot compile map with no geometry!", .{});
            return error.MapCompileFailed;
        }

        // 1) get polygons from brushes
        log.info("Compiling map...", .{});
        for (map.*.brushes.keys()) |i| {
            _ = try self.gen_brush_polys(i);
        }

        // laboriously copy brush map and reallocate memory for copied faces, polys, and points
        var clipped_brushes = map.*.brushes.clone();
        for (clipped_brushes.keys()) |i| {
            const bsrc = map.*.brushes.get(i) orelse unreachable;
            var b = clipped_brushes.getPtr(i) orelse unreachable;
            b.*.polys = self.temp_allocator.dupe(Polygon, bsrc.polys);
            for (b.*.polys) |*p, j| {
                p.*.points = try self.temp_allocator.dupe(Vec3, bsrc.polys[j].points);
            }
            b.*.faces = self.temp_allocator.dupe(Brush.Face, bsrc.faces);
        }

        // 2) csg union
        for (map.*.brushes.keys()) |i| {
            var clip_on_plane: bool = false;
            for (map.*.brushes.keys()) |j| {
                if (i == j) {
                    clip_on_plane = true;
                } else {
                    var bi = clipped_brushes.getPtr(i) orelse unreachable;
                    const bj = map.*.brushes.get(j) orelse unreachable;
                    // clip to brush
                    for (bi.*.polys) |*p| {
                        // clip to list of bj polys
                        _ = p;
                        _ = bj;
                    }
                }
            }
        }
    }

    /// compute intersections of brush planes
    pub fn gen_brush_polys(self: *Editor, brush_id: usize) !void {
        var map = &self.current_map;

        var brush = map.*.brushes.getPtr(brush_id).?;

        var n_faces: usize = brush.*.faces.len;

        // clear old vertex information
        for (brush.*.polys) |p| {
            if (p.points.len != 0) self.temp_allocator.free(p.points);
        }
        if (brush.*.polys.len != 0) self.temp_allocator.free(brush.*.polys);

        brush.*.polys = try self.temp_allocator.alloc(Polygon, n_faces);
        errdefer self.temp_allocator.free(brush.*.polys);

        var verts = try self.temp_allocator.alloc(std.ArrayList(Vec3), n_faces);
        defer self.temp_allocator.free(verts);

        // TODO: make sure toOwnedSlice is doing what i think it's doing
        // for (verts) |*v| v.* = std.ArrayList(Vec3).init(self.temp_allocator);
        // defer for (verts) |*v| v.*.deinit();

        // project brush vertices into world space
        // TODO: make ALL of this less gross
        var xfm = Mat4.fill(1.0);
        // xfm = math.scale(xfm, brush.scale);
        // xfm = math.rotate(xfm, brush.rotation.x, math.vec3(1, 0, 0));
        // xfm = math.rotate(xfm, brush.rotation.y, math.vec3(0, 1, 0));
        // xfm = math.rotate(xfm, brush.rotation.z, math.vec3(0, 0, 1));
        // xfm = math.translate(xfm, brush.position);

        var i: usize = 0;
        while (i < n_faces - 2) : (i += 1) {
            var j = i;
            while (j < n_faces - 1) : (j += 1) {
                var k = j;
                while (k < n_faces) : (k += 1) {
                    if (i == j or j == k or i == k) continue;
                    const fi = brush.*.faces[i].plane;
                    const fj = brush.*.faces[j].plane;
                    const fk = brush.*.faces[k].plane;
                    if (Plane.intersect(fi, fj, fk)) |vert| {

                        // test new vertex, ensure its inside the brush
                        var outside: bool = false;
                        var n: usize = 0;
                        while (n < n_faces and !outside) : (n += 1) {
                            const plane = brush.*.faces[n].plane;
                            outside = outside or (plane.norm.dot(vert) - plane.dist) > 0.0;
                        }

                        if (!outside) {
                            const xvert = xfm.vecmul(vert.expand(1.0));
                            log.debug("adding {}", .{xvert});
                            try verts[i].append(vert);
                            try verts[j].append(vert);
                            try verts[k].append(vert);
                            // map.polys[brush.polys[i]].points.append(vert);
                            // map.polys[brush.polys[j]].points.append(vert);
                            // map.polys[brush.polys[k]].points.append(vert);
                        } else {
                            log.debug("discarding exterior vertex {}", .{vert});
                        }
                    } else continue;
                }
            }
        }

        for (brush.*.polys) |*p, k| {
            var pl = Polygon{ .points = verts[k].toOwnedSlice() };
            sort_verts(&pl);
            p.* = pl;
        }

        //try map.brushes.put(brush_id, brush);
        // for (brush.polys) |pid| {
        //     var p = map.polys.get(pid).?;
        //     map.polys.put(pid, p);
        //     p.indices.append(0);
        //     var k: usize = 1;
        //     while (k < p.points.items.len - 1) : (k += 1) {
        //         try p.indices.append(k);
        //         try p.indices.append(k + 1);
        //         try p.indices.append(0);
        //     }
        // }
    }
};

fn sort_verts(plane: *Polygon) void {
    const nverts = plane.points.len;

    // find polygon center
    var ctr = Vec3.zero();
    for (plane.points) |p| {
        ctr.add_(p);
    }
    ctr.divs_(@intToFloat(f32, nverts));

    var i: usize = 0;
    while (i < nverts - 3) : (i += 1) {
        var min: usize = 0;
        var mindp: f32 = 1;
        var v1 = plane.points[i].sub(ctr).normalize();
        var j: usize = i + 1;
        while (j < nverts) : (j += 1) {
            var v2 = plane.points[j].sub(ctr).normalize();
            const dp = v1.dot(v2);
            if (dp < mindp) {
                mindp = dp;
                min = j;
            }
        }
        // swap min with i+1
        v1 = plane.points[min];
        plane.points[min] = plane.points[i + 1];
        plane.points[i + 1] = v1;
    }
}
