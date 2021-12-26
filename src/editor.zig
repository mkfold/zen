const std = @import("std");
const math = @import("math.zig");
const Vec3 = math.Vec3;

// editor error ids
const Error = error{
    UnknownEntityId,
    InvalidBrushProps,
};

const Brush = struct {
    pub const Face = struct {
        position: Vec3,
        normal: Vec3,

        tex_id: u32,
        u_coords: [4]f32,
        v_coords: [4]f32,
        u_scale: f32,
        v_scale: f32,
    };

    pub const Tag = enum { air, solid, water, fog, clip, sky };

    tag: Tag,
    faces: []u32,
};

const Entity = struct {
    pub const Tag = enum {
        player_start,
        object,
        light,
        trigger,
    };

    tag: Tag,

    position: Vec3,
    rotation: Vec3,
    scale: Vec3,
};

const Map = struct {
    brushes: std.ArrayList(Brush),
    faces: std.ArrayList(Brush.Face),

    entities: std.ArrayList(Entity),

    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) !Map {
        return Map{
            .brushes = try std.ArrayList(Brush).init(allocator),
            .faces = try std.ArrayList(Brush.Face).init(allocator),
            .entities = try std.ArrayList(Entity).init(allocator),
            .allocator = allocator,
        };
    }
};

const EditorState = struct {
    map_path: []const u8 = "",
    current_map: ?Map = null,
    dirty: bool = false,
    needs_rebuild: bool = false,

    cam_pos: Vec3 = Vec3.zero(),
    cam_theta: Vec3 = Vec3.zero(),
};

const def_brush_scale = Vec3{ .x = 16.0, .y = 16.0, .z = 16.0 };
const def_brush_pos = Vec3.zero();
const def_brush_rot = Vec3.zero();
