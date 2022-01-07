const std = @import("std");
const stbi = @import("stbi");
const log = std.log.scoped(.asset);
const kf = @import("../kf.zig");

pub const Texture = struct {
    data: []const u8,
    width: u32,
    height: u32,
    depth: u32,
};

pub fn load(allocator: std.mem.Allocator, fname: []const u8) !Texture {
    var x: c_int = undefined;
    var y: c_int = undefined;
    var n: c_int = undefined;

    var bindata = try kf.read_file(std.heap.page_allocator, fname);
    defer std.heap.page_allocator.free(bindata);

    // stbi.stbi_set_flip_vertically_on_load(1);
    var data = stbi.stbi_load_from_memory(@ptrCast([*c]const u8, bindata), @intCast(c_int, bindata.len), &x, &y, &n, 3) orelse {
        log.err("texture \"{s}\" failed to load; reason: {s}", .{ fname, stbi.stbi_failure_reason() });
        return error.ImageLoadFailed;
    };
    defer stbi.stbi_image_free(data);

    const size = @intCast(usize, x) * @intCast(usize, y) * @intCast(usize, 3);
    const tex = Texture{
        .data = try allocator.dupe(u8, data[0..size]),
        .width = @intCast(u32, x),
        .height = @intCast(u32, y),
        .depth = @intCast(u32, 3),
    };
    return tex;
}

test "load texture" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    _ = try load(alloc, "assets/tex/test.png");
}
