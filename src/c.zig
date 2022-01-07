pub usingnamespace @cImport({
    @cInclude("iqm/iqm.h");
});

pub const stbi = @cImport({
    @cDefine("STB_IMAGE_IMPLEMENTATION", "");
    @cInclude("stb_image.h");
});

pub const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const gl = @cImport({
    @cInclude("epoxy/gl.h");
    @cInclude("epoxy/glx.h");
});
