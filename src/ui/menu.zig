const std = @import("std");
const ig = @import("imgui");
const show_console = @import("./console.zig").show_console;
const State = @import("../app.zig").State;

var demo_open: bool = false;

pub fn show_menu(state: *State) void {
    if (!state.*.menu_open) return;
    if (ig.igBegin(
        "Main",
        null,
        ig.ImGuiWindowFlags_NoBackground | ig.ImGuiWindowFlags_NoMove | ig.ImGuiWindowFlags_NoResize | ig.ImGuiWindowFlags_NoTitleBar | ig.ImGuiWindowFlags_NoDocking,
    )) {
        var io = ig.igGetIO();
        ig.igSetWindowPos_Vec2(.{ .x = (io.*.DisplaySize.x / 2) - 100.0, .y = (io.*.DisplaySize.y / 2) - 100.0 }, ig.ImGuiCond_Always);
        //ImGui::SetWindowSize(ImVec2(200.0f, 200.0f));

        const bsize = .{ .x = 128.0, .y = 0.0 };
        ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ButtonTextAlign, .{ .x = 0.0, .y = 0.0 });
        ig.igPushStyleColor_Vec4(ig.ImGuiCol_Button, .{ .x = 0, .y = 0, .z = 0, .w = 0 });
        ig.igPushStyleColor_Vec4(ig.ImGuiCol_ButtonActive, .{ .x = 0, .y = 0, .z = 0, .w = 0 });
        ig.igPushStyleColor_Vec4(ig.ImGuiCol_ButtonHovered, .{ .x = 0, .y = 0, .z = 0, .w = 0 });
        if (ig.igButton("New Game", bsize)) {}
        if (ig.igButton("Load", bsize)) {}
        if (ig.igButton("Options", bsize)) {
            state.*.options_open = true;
        }
        if (ig.igButton("Quit", bsize)) {} //events.quit(); }
        ig.igPopStyleColor(3);
        ig.igPopStyleVar(1);
    }
    ig.igEnd();

    if (state.*.console_open) show_console(&state.*.console_open);
    if (state.*.options_open) show_options(&state.*.options_open);
    if (demo_open) ig.igShowDemoWindow(&demo_open);
}

var corner: i32 = 1;

pub fn show_metrics(open: *bool) void {
    const DISTANCE: f32 = 32.0;
    var io = ig.igGetIO();
    if (corner != -1) {
        const window_pos = .{
            .x = if (corner & 1 != 0) io.*.DisplaySize.x - DISTANCE else DISTANCE,
            .y = if (corner & 2 != 0) io.*.DisplaySize.y - DISTANCE else DISTANCE,
        };
        const window_pos_pivot = .{
            .x = @as(f32, if (corner & 1 != 0) 1.0 else 0.0),
            .y = @as(f32, if (corner & 2 != 0) 0.0 else 1.0),
        };
        ig.igSetNextWindowPos(window_pos, ig.ImGuiCond_Always, window_pos_pivot);
    }
    ig.igSetNextWindowBgAlpha(0.35); // Transparent background
    ig.igPushStyleColor_Vec4(ig.ImGuiCol_Border, .{ .x = 0, .y = 0, .z = 0, .w = 0 });
    if (ig.igBegin(
        "Metrics",
        @ptrCast([*c]bool, open),
        (if (corner != -1) ig.ImGuiWindowFlags_NoMove else 0) | ig.ImGuiWindowFlags_NoDecoration | ig.ImGuiWindowFlags_AlwaysAutoResize | ig.ImGuiWindowFlags_NoSavedSettings | ig.ImGuiWindowFlags_NoFocusOnAppearing | ig.ImGuiWindowFlags_NoNav | ig.ImGuiWindowFlags_NoBringToFrontOnFocus | ig.ImGuiWindowFlags_NoDocking,
    )) {
        ig.igText("%s", "zen alpha");
        ig.igTextColored(.{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 1.0 }, "debug build");
        var tmp = [1]u8{0} ** 128;
        const fstr = std.fmt.bufPrintZ(
            tmp[0..],
            "{d:.3} ms/frame ({d:.1}) FPS",
            .{ 1000.0 / io.*.Framerate, io.*.Framerate },
        ) catch unreachable;
        ig.igTextUnformatted(
            @ptrCast([*c]const u8, fstr.ptr),
            @ptrCast([*c]const u8, fstr.ptr + fstr.len),
        );

        if (ig.igBeginPopupContextWindow("##metrics", 0)) {
            if (ig.igMenuItem_Bool("Custom", null, corner == -1, true)) corner = -1;
            if (ig.igMenuItem_Bool("Top-left", null, corner == 0, true)) corner = 0;
            if (ig.igMenuItem_Bool("Top-right", null, corner == 1, true)) corner = 1;
            if (ig.igMenuItem_Bool("Bottom-left", null, corner == 2, true)) corner = 2;
            if (ig.igMenuItem_Bool("Bottom-right", null, corner == 3, true)) corner = 3;
            if (ig.igMenuItem_BoolPtr("Close", null, null, true)) open.* = false;
            ig.igEndPopup();
        }
    }
    ig.igEnd();
    ig.igPopStyleColor(1);
}

pub fn show_options(open: *bool) void {
    if (ig.igBegin("Options", @ptrCast([*c]bool, open), ig.ImGuiWindowFlags_NoDocking)) {
        if (ig.igBeginTabBar("OptionsTabs", ig.ImGuiTabBarFlags_None)) {
            if (ig.igBeginTabItem("Controls", null, 0)) {
                ig.igEndTabItem();
            }
            if (ig.igBeginTabItem("Audio", null, 0)) {
                // set sfx volume
                // set bgm volume
                ig.igEndTabItem();
            }
            if (ig.igBeginTabItem("Video", null, 0)) {
                // toggle effects
                // toggle aa
                // etc
                ig.igEndTabItem();
            }
            ig.igEndTabBar();
        }
    }
    ig.igEnd();
}
