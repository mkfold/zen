const std = @import("std");
const builtin = @import("builtin");
const ztBuild = @import("include/ZT/build.zig");
const Builder = std.build.Builder;

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
    exe.install();

    ztBuild.link(b, exe, target);

    const run_step = b.step("run", "Run the app");
    const run = exe.run();
    run.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run.step);
}
