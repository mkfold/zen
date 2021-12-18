//! gui.zig: graphical user interface elements
//! doesn't need to be terribly sophisticated

const c = @import("../c.zig");

pub const Context = struct {
    const Self = @This();

    pub fn init() void {
        //
    }

    pub fn deinit() void {
        //
    }
};

fn mk_rectangle(position: [2]f32, width: f32, height: f32) void {}
fn mk_convex_poly(position: [2]f32, radius: f32, num_segments: u32) void {}
