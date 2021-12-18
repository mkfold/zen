const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const time = std.time;

// type definitions
const mem_index = u64;

/// get time in nanoseconds as a float.
pub fn gettime() f32 {
    return @intToFloat(f32, time.nanoTimestamp());
}

pub fn minimum(comptime T: type, a: T, b: T) T {
    return if (a < b) a else b;
}

pub fn maximum(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

pub fn is_power_of_two(x: mem_index) bool {
    return (x > 0) and !(x & (x - 1));
}

/// LIST: STRETCHY BUFFER
/// general-purpose buffer. only the basics.
/// use std.ArrayList if you need more features.
pub fn List(comptime T: type) type {
    return struct {
        const Self = @This();
        const list_cap_default: mem_index = 64;
        const list_grow_rate: mem_index = 2;

        allocator: *mem.Allocator,
        size: mem_index,
        data: []T,

        pub fn init(allocator: *mem.Allocator) Self {
            const data = allocator.alloc(T, list_cap_default) catch return Self{
                .size = 0,
                .allocator = allocator,
                .data = undefined,
            };

            return Self{
                .size = 0,
                .allocator = allocator,
                .data = data,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.data);
        }

        pub fn push(self: *Self, e: T) !void {
            if (self.data.len == self.size) {
                try self.resize(self.data.len * list_grow_rate);
            }
            self.data[self.size] = e;
            self.size += 1;
        }

        pub fn pop(self: *Self) T {
            if (self.size > 0) {
                self.size -= 1;
            }
            self.data[self.size];
        }

        pub fn resize(self: *Self, s: mem_index) !void {
            assert(s > 0);
            const slc = self.data.ptr[0..self.data.len];
            self.data = try self.allocator.realloc(slc, s);
        }

        pub fn clear(self: *Self) void {
            self.size = 0;
        }

        pub fn shrink(self: *Self) !void {
            try self.resize(maximum(mem_index, 1, self.size));
        }

        pub fn len(self: Self) mem_index {
            return self.size;
        }

        // unfinished stuff
        // /// remove element at index i.
        // pub fn remove(self: Self, i: mem_index) void {
        //    unreachable;
        // }
    }; // end struct
}

/// read a file into a buffer and return it. caller must free allocated memory.
pub fn read_file(allocator: *mem.Allocator, fname: []const u8) ![]const u8 {
    const f = try std.fs.cwd().openFile(fname, .{ .read = true });
    defer f.close();

    const fsize = try f.getEndPos();
    var buf = try allocator.alloc(u8, fsize);
    errdefer allocator.free(buf);

    _ = try f.reader().readAll(buf);
    return buf;
}

test "cc.List create, push elements, shrink" {
    const expect = std.testing.expect;

    var r = std.rand.DefaultPrng.init(123);
    var static_arr: [100]i8 = undefined;

    for (static_arr) |_, i| {
        static_arr[i] = r.random.int(i8);
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var l = List(i8).init(&arena.allocator);
    defer l.deinit();

    for (static_arr) |e| {
        try l.push(e);
    }
    try expect(l.size == static_arr.len);

    try l.shrink();
    try expect(l.data.len == static_arr.len);

    for (l.data) |e, i| {
        try expect(e == static_arr[i]);
    }
}

test "gettime" {
    std.debug.warn("\ngettime() returned {}\n", .{gettime()});
}

test "read_file" {
    const alloc = std.heap.page_allocator;
    var text = try read_file(alloc, "src/cc.zig");
    defer alloc.free(text);
    // std.debug.warn("\n{}\n", .{text});
}
