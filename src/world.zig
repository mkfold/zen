const std = @import("std");
const math = @import("math");
const Vec3 = math.Vec3;
const Quat = math.Quat;
const Model = @import("asset/model.zig").Model;

pub const EntityId = u32;

pub const SpatialIndex = struct {
    pub const ClusterId = u32;
    pub const Node = struct {
        extent: math.AABB,

        contents: union {
            entities: []EntityId,
            children: []Node,
        },
    };
};

pub const EntityFlags = enum(u32) {
    invisible = 1,
    mounted = 1 << 2,
};

pub const Entity = struct {
    id: EntityId,
    group_id: EntityId,
    name: []const u8,
    flags: u32,
    bounding: struct { radius: f32, center: Vec3 },
    transform: struct { position: Vec3, orientation: Quat, scale: f32 = 1 },
    mount: ?struct { parent_id: EntityId, position: Vec3, orientation: Quat },
};

pub const StaticObject = struct {
    entity: Entity,
    model: ?*Model,
};

pub const Object = struct {
    entity: Entity,
    model: ?*Model,
    phys_props: struct { velocity: Vec3, acceleration: Vec3, rate: f32 = 1.0 },
};

pub const Light = struct {
    pub const Type = enum { point, spot };

    entity: Entity,
    kind: Type,
    color: Vec3,
    intensity: f32,
    radius: f32,
};

pub const Trigger = struct {
    pub const Type = enum {
        player_start,
    };

    entity: Entity,
};

pub const World = struct {
    entities: std.MultiArrayList(Entity),
    lights: std.MultiArrayList(Light),
};
