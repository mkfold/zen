//! zen: render/gl/texture.zig

const std = @import("std");
const log = std.log.scoped(.render);
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const texture = @import("../../assets/texture.zig");
const Texture = texture.Texture;

const gl = @import("../c.zig").gl;

/// each texture type (dimension, pixel format, etc.) receives its own "bank"
/// var b = banks_by_fmt.get(.{ .w = tex.width, .h = tex.height, ...})
///
/// each bank has a set of pages associated with it, each with a fixed number of avaliable layers
/// for buffering individual textures. when the page is exhausted, a new one is created and added to
/// the bank for use in future allocations.
/// var b_pages = pages.get(b);
const TexArray = struct {
    handle: gl.GLuint,

    width: u32,
    height: u32,
    channels: u32,
    mip_count: u32,

    layers: u32,

    used: u32 = 0,

    pub fn init(width: u32, height: u32, channels: u32, layers: u32, mip_count: u32) TexArray {
        var arr = TexArray{
            .handle = undefined,
            .width = width,
            .height = height,
            .channels = channels,
            .layers = layers,
            .used = 0,
            .mip_count = mip_count,
        };
        gl.glGenTextures(1, &arr.handle);
        gl.glBindTexture(gl.GL_TEXTURE_2D_ARRAY, arr.handle);
        // TODO: allow for tex parameter configuration
        // set_tex_params(opts);
        var i: usize = 0;
        var divisor: u32 = 1;
        while (i < mip_count) : (i += 1) {
            gl.glTexStorage3D(
                gl.GL_TEXTURE_2D_ARRAY,
                @intCast(gl.GLsizei, i),
                gl.GL_RGBA8,
                @intCast(gl.GLsizei, arr.width / divisor),
                @intCast(gl.GLsizei, arr.height / divisor),
                @intCast(gl.GLsizei, arr.mip_count),
            );
            divisor *= 2;
        }

        return arr;
    }

    pub fn deinit(self: *TexArray) void {
        gl.glDeleteTextures(1, &self.handle);
        self.handle = 0;
        self.width = 0;
        self.height = 0;
        self.channels = 0;
        self.layers = 0;
        self.used = 0;
        self.mip_count = 0;
    }

    // fn set_tex_params(opts: anytype) void {
    //     gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_REPEAT);
    //     gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_REPEAT);
    //     gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
    //     gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
    // }

    pub fn buffer(self: *TexArray, tex: Texture) !u32 {
        gl.glBindTexture(gl.GL_TEXTURE_ARRAY_2D, self.handle);
        const layer_id = self.used;
        if (layer_id >= 2048) return error.OutOfLayers;
        gl.glTexSubImage3D(
            gl.GL_TEXTURE_ARRAY_2D,
            0,
            0,
            @intCast(gl.GLint, layer_id),
            gl.GL_RGB,
            tex.width,
            tex.height,
            1,
            gl.GL_RGB,
            gl.GL_UNSIGNED_BYTE,
            tex.data.ptr,
        );
        gl.glGenerateMipmap(gl.GL_TEXTURE_ARRAY_2D);
        self.used += 1;
        return layer_id;
    }
};

pub const TexManager = struct {
    pub const Handle = struct {
        bank_id: u8,
        page_id: u8,
        layer_id: u16,
    };

    const FmtKey = struct { w: u32, h: u32, c: u32 };

    banks_by_fmt: std.AutoArrayHashMap(FmtKey, u8),
    pages: std.ArrayList(TexArray),
    page_table: std.ArrayList(std.ArrayList(u16)),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TexManager {
        return TexManager{
            .allocator = allocator,
            .banks_by_fmt = std.AutoArrayHashMap(FmtKey, u8).init(allocator),
            .pages = std.ArrayList(TexArray).init(allocator),
            .page_table = std.ArrayList(std.ArrayList(u16)).init(allocator),
        };
    }

    pub fn deinit(self: *TexManager) void {
        for (self.pages.items) |p| {
            p.deinit();
        }
        self.pages.deinit();
        for (self.page_table.items) |p| {
            p.deinit();
        }
        self.page_table.deinit();
        self.banks_by_fmt.deinit();
    }

    pub fn load(self: *TexManager, tex: Texture) !Handle {
        const fk = FmtKey{ .w = tex.width, .h = tex.height };
        // look-up target bank by resource metadata
        // if no bank is found, we allocate the resource in the 0th page of a new bank
        // without bothering to do any page offset calculation.
        const bank_id = blk: {
            if (self.banks_by_fmt.get(fk)) |b| break :blk @intCast(usize, b);
            const _id = self.page_table.len;

            // add new bank row to page table
            if (_id >= 255) return error.OutOfBanks;
            try self.page_table.append(std.ArrayList(u16).init(self.allocator));

            // add new page to flat page buffer
            const page_offset = self.pages.len;
            try self.pages.append(TexArray.init(tex.width, tex.height, 4, 2048, 3));

            // add new page to bank row
            try self.page_table.items[_id].append(@intCast(u16, page_offset));

            // add resource to page layer
            const layer_id = try self.pages.items[page_offset].buffer(tex);
            return .{ .bank_id = @intCast(u8, _id), .page_id = 0, .layer_id = layer_id };
        };

        var bank_pages = &self.page_table.items[bank_id].items;
        var page_id = if (bank_pages.*.len != 0) bank_pages.*.len - 1 else unreachable;
        var page = &self.page_table.items[bank_id].items[page_id];

        // if page is full, we need to create a new one in our current bank
        if (page.*.used >= 2048) {
            page_id = self.page_table.items[bank_id].items.len;
            if (page_id >= 255) return error.OutOfPages;

            // add new page to flat page buffer
            const page_offset = self.pages.len;
            try self.pages.append(TexArray.init(tex.width, tex.height, 4, 2048, 3));

            // add new page to bank row
            try self.page_table.items[bank_id].append(@intCast(u16, page_offset));

            // update page to be used for buffering
            page = &self.pages[page_offset];
        }

        const layer_id = try page.*.buffer(tex);

        return .{
            .bank_id = @intCast(u8, bank_id),
            .page_id = @intCast(u8, page_id),
            .layer_id = layer_id,
        };
    }
};
