const std = @import("std");
const log = std.log.scoped(.asset);

const model = @import("asset/model.zig");
const Model = model.Model;
const texture = @import("asset/texture.zig");
const Texture = texture.Texture;
const vertex = @import("render/vertex.zig");

var model_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var tex_alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn Manager_(comptime T: type, comptime DH: type) type {
    return struct {
        const Self = @This();
        const CacheData = struct { gen: u16, handle: DH };
        pub const Handle = struct { id: u32, gen: u16 = 0 };

        pub const InitF = fn (std.mem.Allocator, []const u8) anyerror!T;
        pub const MapF = fn (T) anyerror!DH;
        pub const DeinitF = fn (T) void;

        cache: std.MultiArrayList(CacheData),
        by_fname: std.StringArrayHashMap(u32),
        freed: std.ArrayList(usize),

        init_fn: ?InitF = null,
        map_fn: ?MapF = null,
        deinit_fn: ?DeinitF = null,

        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .cache = std.ArrayList(T).init(gpa.allocator()),
                .by_fname = std.StringArrayHashMap(u32).init(gpa.allocator()),
                .freed = std.ArrayList(usize).init(gpa.allocator()),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.cache.deinit();
            self.by_fname.deinit();
            self.freed.deinit();
        }

        pub fn load(self: *Self, fname: []const u8) !Handle {
            std.debug.assert(self.init_fn != null and self.map_fn != null and self.deinit_fn != null);
            if (self.by_fname.get(fname)) |i| return .{
                .id = i,
                .gen = self.cache.slice().items(.gen)[i],
            };
            const x = try self.?.init_fn(self.allocator, fname);
            defer self.?.deinit_fn(fname);

            const dh = try self.?.map_fn(x);

            var h = Handle{ .id = 0, .gen = 1 };
            if (self.freed.items.len != 0) {
                const i = self.freed.pop();
                var s = self.cache.slice();
                s.items(.handle)[i] = dh;
                s.items(.gen)[i] += 1;
                h.id = @intCast(u32, i);
                h.gen = s.items.gen[i];
            } else {
                h.id = @intCast(u32, self.cache.items.len - 1);
                try self.cache.append(.{ .handle = dh, .gen = 1 });
            }
            try self.by_fname.put(fname, h.id);
            return h;
        }

        pub fn get(self: *Self, handle: Handle) ?T {
            const i = @intCast(usize, handle.id);
            std.debug.assert(i < self.cache.len);
            const item = self.cache.get(i);
            if (item.gen != handle.gen) return null;
            return item.data;
        }

        pub fn get_by_fname(self: *Self, fname: []const u8) ?T {
            const i = self.by_fname.get(fname) orelse return null;
            return self.cache.slice().items(.data)[i];
        }
    };
}

pub fn Manager(
    comptime T: type,
    comptime LoadF: fn (std.mem.Allocator, []const u8) anyerror!T,
    comptime UnloadF: fn (T) void,
) type {
    return struct {
        const Self = @This();
        const CacheData = struct { gen: u16, data: T };

        pub const Handle = struct { id: u32, gen: u16 = 0 };

        cache: std.MultiArrayList(CacheData),
        by_fname: std.StringArrayHashMap(u32),
        freed: std.ArrayList(usize),

        allocator: std.mem.Allocator,

        const load_fn = LoadF;
        const unload_fn = UnloadF;

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .cache = std.ArrayList(T).init(gpa.allocator()),
                .by_fname = std.StringArrayHashMap(u32).init(gpa.allocator()),
                .freed = std.ArrayList(usize).init(gpa.allocator()),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.cache.deinit();
            self.by_fname.deinit();
            self.freed.deinit();
        }

        pub fn load(self: *Self, fname: []const u8, opts: anytype) !Handle {
            if (self.by_fname.get(fname)) |i| return .{
                .id = i,
                .gen = self.cache.slice().items(.gen)[i],
            };
            const x = try Self.load_fn(self.allocator, fname, opts);
            var h = Handle{ .id = 0, .gen = 1 };
            if (self.freed.items.len != 0) {
                const i = self.freed.pop();
                var s = self.cache.slice();
                s.items(.data)[i] = x;
                s.items(.gen)[i] += 1;
                h.id = @intCast(u32, i);
                h.gen = s.items.gen[i];
            } else {
                h.id = @intCast(u32, self.cache.items.len - 1);
                try self.cache.append(.{ .data = x, .gen = 1 });
            }
            try self.by_fname.put(fname, h.id);
            return h;
        }

        pub fn get(self: *Self, handle: Handle) ?T {
            const i = @intCast(usize, handle.id);
            std.debug.assert(i < self.cache.len);
            const item = self.cache.get(i);
            if (item.gen != handle.gen) return null;
            return item.data;
        }

        pub fn get_by_fname(self: *Self, fname: []const u8) ?T {
            const i = self.by_fname.get(fname) orelse return null;
            return self.cache.slice().items(.data)[i];
        }

        pub fn unload(self: *Self, fname: []const u8) void {
            const id = @intCast(usize, self.by_fname.fetchSwapRemove(fname) orelse return);
            std.debug.assert(id < self.cache.len);
            var item = &self.cache.slice.items(.data)[id];
            Self.unload_fn(item.*.data);
            try self.freed.append(id);
        }
    };
}

const TexManager = Manager_(Texture, TexHandle);
const ModelManager = Manager_(Model, model.load);
pub const TexHandle = TexManager.Handle;
pub const ModelHandle = ModelHandle.Handle;

pub var textures = TexManager.init(tex_alloc.allocator());
pub var models = ModelManager.init(model_alloc.allocator());

/// recursively search and load all assets in a directory
/// this will likely be updated according to how assets are packaged and/or referenced by other
/// parts of zen.
pub fn load_assets(dir_path: []const u8) !void {
    const ext_map = std.ComptimeStringMap(enum { texture, model, sound }, .{
        .{ "png", .texture },
        .{ "jpg", .texture },
        .{ "iqm", .model },
        .{ "wav", .sound },
        .{ "ogg", .sound },
    });

    var dir = try std.fs.cwd().openDir(
        dir_path,
        .{ .access_sub_paths = true, .iterate = true, .no_follow = false },
    );
    defer dir.close();

    var walker = try dir.walk(gpa.allocator());
    defer walker.deinit();

    log.debug("reading assets from {s}...", .{dir_path});
    while (try walker.next()) |file| {
        if (file.kind != .File) continue;
        const ext_offs = (std.mem.lastIndexOfAny(u8, file.path, ".") orelse continue) + 1;
        var buf = [1]u8{0} ** 2048;
        const kind = blk: {
            var i: usize = 0;
            for (file.path[ext_offs..]) |c| {
                if (i >= 8) break;
                buf[i] = std.ascii.toLower(c);
                i += 1;
            }
            break :blk ext_map.get(buf[0..i]) orelse continue;
        };

        for (dir_path) |c, i| buf[i] = c;
        for (file.path) |c, i| buf[dir_path.len + i] = c;

        const fname = buf[0 .. dir_path.len + file.path.len];
        switch (kind) {
            .texture => {
                if (textures.get(fname) != null) continue;
                _ = textures.load(fname, .{}) catch |e| {
                    log.warn("failed to load texture \"{s}\"; reason: {}", .{ fname, e });
                    continue;
                };
                log.debug("loaded texture \"{s}\"", .{fname});
            },
            .model => {
                if (models.get(fname) != null) continue;
                _ = models.load(fname, .{}) catch |e| {
                    log.warn("failed to load model \"{s}\"; reason: {}", .{ fname, e });
                    continue;
                };
                log.debug("loaded model \"{s}\"", .{fname});
            },
            .sound => {
                continue;
            },
        }
    }
}

pub fn deinit() void {
    textures.deinit();
    models.deinit();
}
