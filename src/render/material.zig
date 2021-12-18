//! material.zig
//! texture and material definitions and loading for zng.

const std = @import("std");
const log = std.log.scoped(.material);

const Texture = @import("../assets/texture.zig").Texture;

const cc = @import("../cc.zig");
const c = @import("../c.zig");

const Material = struct {
    id: u32,
};

pub fn buffer(tex: Texture) u32 {
    var id: c_int = undefined;
    c.glGenTextures(1, &id);
    c.glBindTexture(c.GL_TEXTURE_2D, id);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, tex.width, tex.height, tex.channels, c.GL_RGB, c.GL_UNSIGNED_BYTE, tex.data.ptr);
    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

    return id;
}
