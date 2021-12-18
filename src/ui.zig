const ig_impl = @import("zt").ig_impl;

pub fn init() void {
    ig_impl.init("#version 330");
}

pub fn deinit() void {
    ig_impl.Shutdown();
}
