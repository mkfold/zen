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
    .{ .norm = math.vec3(1, 0, 0), .dist = 0.5 },
    .{ .norm = math.vec3(0, 1, 0), .dist = 0.5 },
    .{ .norm = math.vec3(0, 0, 1), .dist = 0.5 },
    .{ .norm = math.vec3(-1, 0, 0), .dist = 0.5 },
    .{ .norm = math.vec3(0, -1, 0), .dist = 0.5 },
    .{ .norm = math.vec3(0, 0, -1), .dist = 0.5 },
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
    faces: []u32 = &[_]u32{},
    polys: []Polygon,

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

const Polygon = struct { points: []Vec3, indices: []u32 };

pub const Map = struct {
    brushes: std.ArrayList(Brush),
    faces: std.ArrayList(Brush.Face),
    polys: std.AutoHashMap(u32, Polygon),
    entities: std.ArrayList(Entity),
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

    pub fn init(allocator: std.mem.Allocator, temp_allocator: std.mem.Allocator) Editor {
        return Editor{
            .allocator = allocator,
            .temp_allocator = temp_allocator,
            .current_map = Map{
                .brushes = std.ArrayList(Brush).init(allocator),
                .faces = std.ArrayList(Brush.Face).init(allocator),
                .entities = std.ArrayList(Entity).init(allocator),
                .polys = std.AutoHashMap(u32, Polygon).init(allocator),
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
        map.faces.clearRetainingCapacity();
        map.polys.clearRetainingCapacity();
        map.entities.clearRetainingCapacity();
        log.info("map cleared.", .{});
    }

    pub fn deinit(self: *Editor) void {
        var map = self.current_map;
        map.brushes.deinit();
        map.faces.deinit();
        map.polys.deinit();
        map.entities.deinit();
    }

    pub fn brushadd(self: *Editor, kind: Brush.Type, pos: Vec3, scale: Vec3, rot: Vec3, shape: PrefabShape) !void {
        var map = self.current_map;
        var b = Brush{ .tag = kind };

        switch (shape) {
            .cube => {
                for (cube_planes) |p| {
                    try map.faces.append(p);
                    try b.faces.append(p);
                }
            },
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

        try map.brushes.append(b);
        // TODO: make this happen somewhere else
        // if (auto_intersect) { gen_brush_polys(brushct-1); }
        // return;
    }

    pub fn brushdel(self: *Editor, id: usize) void {
        var map = self.current_map;
        map.brushes.orderedRemove(id);
    }

    // pub fn entadd(id: u32, pos: Vec3, rot: Vec3, scale: Vec3) void {
    //     return;
    // }

    // pub fn entdel(id: u32) void {
    //     return;
    // }

    fn compile(self: *Editor) !void {
        var map = self.current_map;
        // steps:
        // 1) get polygons from brushes
        //    a) compute intersections of planes
        //    b) sort vertices of each polygon
        // 2) compute union of brush polygons
        // 3) build bsp tree from polygons
        // 4) attach entities to nodes
        if (map.brushes.items.len == 0) {
            log.err("Cannot compile map with no geometry!", .{});
            return error.MapCompileFailed;
        }

        // 1) get polygons from brushes
        log.info("Compiling map...", .{});
        for (map.brushes) |_, i| {
            _ = gen_brush_polys(i);
            // TODO: these loops are only meant to print the vertices in each polygon
            // for (auto &p_id : b.polys) {
            //     poly_t p = polys[p_id];
            //     for (u32 k = 0; k < p.points.size(); k++) {
            //         glm::vec3 v = p.points[k];
            //         nb::log(EDITOR, "%f, %f, %f", v.x, v.y, v.z);
            //     }
            // }
        }

        // csg union
        for (map.brushes) |_, i| {
            for (map.brushes) |_, j| {
                if (i == j) continue;
            }
        }
    }
    /// compute intersections of brush planes
    pub fn gen_brush_polys(self: *Editor, brush_id: usize) void {
        const map = self.current_map;

        var brush = map.brushes.items[brush_id];

        var n_faces: usize = brush.faces.len;
        brush.polys.ensureCapacity(n_faces);

        // clear old vertex information
        for (brush.polys) |p| {
            p.points.clear();
            p.indices.clear();
        }

        // project brush vertices into world space
        // TODO: make ALL of this less gross
        var xfm = Mat4.fill(1.0);
        xfm = math.scale(xfm, brush.scale);
        xfm = math.rotate(xfm, brush.rotation.x, math.vec3(1, 0, 0));
        xfm = math.rotate(xfm, brush.rotation.y, math.vec3(0, 1, 0));
        xfm = math.rotate(xfm, brush.rotation.z, math.vec3(0, 0, 1));
        xfm = math.translate(xfm, brush.position);

        var i: usize = 0;
        while (i < n_faces - 2) : (i += 1) {
            var j = i;
            while (j < n_faces - 1) : (j += 1) {
                var k = j;
                while (k < n_faces) : (k += 1) {
                    if (i == j or j == k or i == k) continue;
                    const fi = map.faces[brush.faces[i]].plane;
                    const fj = map.faces[brush.faces[j]].plane;
                    const fk = map.faces[brush.faces[k]].plane;
                    if (Plane.intersect(fi.plane, fj.plane, fk.plane)) |vert| {

                        // test new vertex, ensure its inside the brush
                        var outside: bool = false;
                        var n: usize = 0;
                        while (n < n_faces and !outside) : (n += 1) {
                            const plane = brush.faces[n];
                            outside = outside or (plane.normal.dot(vert) - plane.dist) > 0.0;
                        }

                        if (!outside) {
                            const xvert = xfm.vecmul(vert.expand(1.0));
                            log.debug("adding {}", .{xvert});
                            map.polys[brush.polys[i]].points.append(vert);
                            map.polys[brush.polys[j]].points.append(vert);
                            map.polys[brush.polys[k]].points.append(vert);
                        } else {
                            log.debug("discarding exterior vertex ({}, {}, {})", .{ vert.v[0], vert.v[1], vert.v[2] });
                        }
                    } else continue;
                }
            }
        }

        for (brush.polys) |p| {
            sort_verts(p);
            p.indices.append(0);
            var k: usize = 1;
            while (k < p.points.items.len - 1) : (k += 1) {
                try p.indices.append(k);
                try p.indices.append(k + 1);
                try p.indices.append(0);
            }
        }
    }
};

fn sort_verts(plane: *Polygon) void {
    const nverts = plane.points.size();

    // find polygon center
    var ctr = Vec3.zero();
    for (plane.points.items) |p| {
        ctr.add_(p);
    }
    ctr.sdiv_(@intToFloat(f32, nverts));

    var i: usize = 0;
    while (i < nverts - 3) : (i += 1) {
        var min: u32 = 0;
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
