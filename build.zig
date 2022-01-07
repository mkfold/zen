const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

fn get_relative_path() []const u8 {
    comptime var src: std.builtin.SourceLocation = @src();
    return std.fs.path.dirname(src.file).? ++ std.fs.path.sep_str;
}

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("zen", "src/main.zig");
    const target = b.standardTargetOptions(.{
        .default_target = if (builtin.target.os.tag == .windows) .{ .abi = .gnu } else .{},
    });

    exe.setBuildMode(mode);
    exe.setTarget(target);

    exe.linkLibC();
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("epoxy");
    exe.addIncludeDir(get_relative_path() ++ "include/iqm");
    exe.install();

    // TODO: exe.linkLibrary(get_vk_lib(b, target));
    exe.linkLibrary(imgui_build(b, target));
    exe.addPackage(std.build.Pkg{
        .name = "imgui",
        .path = std.build.FileSource{ .path = get_relative_path() ++ "include/imgui.zig" },
    });
    exe.linkLibrary(stbi_build(b, target));
    exe.addPackage(std.build.Pkg{
        .name = "stbi",
        .path = std.build.FileSource{ .path = get_relative_path() ++ "include/stbi.zig" },
    });
    // exe.linkLibrary(get_glfw_lib(b, target));

    const run_step = b.step("run", "Run the app");
    const run = exe.run();
    run.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run.step);
}

pub fn imgui_build(b: *std.build.Builder, target: std.zig.CrossTarget) *std.build.LibExeObjStep {
    _ = target;
    comptime var cwd = get_relative_path();
    var flags = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer flags.deinit();

    if (b.is_release) {
        flags.append("-O3") catch unreachable;
    }

    var imgui = b.addStaticLibrary("imgui", null);
    const path = cwd ++ "include/cimgui/imgui/";
    imgui.addIncludeDir(path);
    imgui.addCSourceFiles(&.{
        path ++ "imgui.cpp",
        path ++ "imgui_demo.cpp",
        path ++ "imgui_draw.cpp",
        path ++ "imgui_tables.cpp",
        path ++ "imgui_widgets.cpp",
        "include/cimgui/cimgui.cpp",
    }, flags.items);

    imgui.linkLibC();
    imgui.linkSystemLibrary("c++");
    // bgfx.linkSystemLibrary("epoxy");

    return imgui;
}

pub fn stbi_build(b: *std.build.Builder, target: std.zig.CrossTarget) *std.build.LibExeObjStep {
    _ = target;
    comptime var cwd = get_relative_path();
    var flags = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer flags.deinit();

    if (b.is_release) {
        flags.append("-O3") catch unreachable;
    }

    var stbi = b.addStaticLibrary("stbi", null);
    const path = cwd ++ "include/";
    stbi.addIncludeDir(path);
    stbi.addCSourceFile(path ++ "stb_image.c", flags.items);
    stbi.linkLibC();

    return stbi;
}

// pub fn glfw_build(b: *std.build.Builder, target: std.zig.CrossTarget) *std.build.LibExeObjStep {
// }

// pub fn epoxy_build(b: *std.build.Builder, target: std.zig.CrossTarget) *std.build.LibExeObjStep {
// }

