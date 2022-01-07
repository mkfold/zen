const std = @import("std");
const log = std.log.scoped(.editor);

const ig = @import("imgui");

const math = @import("../math.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

const Editor = @import("../editor.zig").Editor;

/// GRAPHICAL USER INTERFACE FOR EDITOR

//// selection
//
//const Selection = struct {
//    const Tag = enum { none, brush, face, edge, vertex, entity, light };
//    tag: Tag,
//    id: usize,
//};
//
//fn show_selection_menu() void {
//    ig.igBegin("Brush", null);
//    switch (selection.tag) {
//        .brush => ig.igText("Brush %d", selection.id),
//        .entity => ig.igText("Entity %d", selection.id),
//        .face => ig.igText("Face %d", selection.id),
//        else => {},
//    }
//    ig.igEnd();
//}

// fn item_tree() void {
//
// }

// editor map view state
var view: struct {
    pos: Vec2 = Vec2.fill(100),
    scale: f32 = 2.0,

    tools: struct {
        show: bool = true,
        obj_pos: Vec3 = Vec3.zero(),
        obj_rot: Vec3 = Vec3.zero(),
        obj_scl: Vec3 = Vec3.fill(1),
    },
} = .{ .tools = .{} };

fn tool_window(editor: *Editor) void {
    if (!view.tools.show) return;
    _ = editor;

    var io = ig.igGetIO();
    ig.igSetNextWindowPos(.{ .x = 0, .y = 20 }, ig.ImGuiCond_Always, .{ .x = 0, .y = 0 });
    ig.igSetNextWindowSize(.{ .x = 200, .y = io.*.DisplaySize.y - 20 }, ig.ImGuiCond_Always);
    if (ig.igBegin("Editor Tools", null, ig.ImGuiWindowFlags_NoTitleBar | ig.ImGuiWindowFlags_NoResize | ig.ImGuiWindowFlags_NoMove)) {
        if (ig.igDragFloat3("Pos", &view.tools.obj_pos.data, 0.1, 0, 0, "%.3f", 0)) {}
        if (ig.igDragFloat3("Rot", &view.tools.obj_rot.data, 0.1, 0, 0, "%.3f", 0)) {}
        if (ig.igDragFloat3("Scl", &view.tools.obj_scl.data, 0.1, 0.01, 100.0, "%.3f", 0)) {}

        ig.igText("Add");
        ig.igSeparator();
        if (ig.igButton("Brush", .{ .x = 64, .y = 24 })) {
            const tools = view.tools;
            editor.*.brushadd(.air, tools.obj_pos, tools.obj_scl, tools.obj_rot, .cube) catch |e| {
                log.err("could not add brush; reason: {}", .{e});
            };
            log.debug("added brush", .{});
        }
        //ig.igSameLine(4, 64);
        if (ig.igButton("Light", .{ .x = 64, .y = 24 })) {}
        //ig.igSameLine(4, 128);
        if (ig.igButton("Entity", .{ .x = 64, .y = 24 })) {}
        // ig.igSameLine(200, 4);
    }
    ig.igEnd();
}

// immediate mode brush drawing T_T
fn map_view(editor: *Editor) void {
    // if (editor.current_map == null) return;

    const map = editor.current_map;
    const brushes = map.brushes;
    const polys = map.polys;
    const pos = view.pos.data;
    var vmat = math.lookat(
        math.vec3(pos[0], pos[1], view.scale),
        math.vec3(pos[0], pos[1], 0),
        math.vec3(1, 0, 0),
    );
    if (ig.igBegin("Map", null, ig.ImGuiWindowFlags_MenuBar)) {
        if (ig.igBeginMenuBar()) {
            ig.igPushItemWidth(64);
            if (ig.igDragFloat("X", &view.pos.data[1], 1, 0, 0, "%.3f", 0)) {}
            if (ig.igDragFloat("Y", &view.pos.data[0], 1, 0, 0, "%.3f", 0)) {}
            if (ig.igDragFloat("Scale", &view.scale, 0.1, 0.01, 100.0, "%.3f", 0)) {}
            ig.igPopItemWidth();
            ig.igEndMenuBar();
        }

        var dl = ig.igGetWindowDrawList();
        var windowpos: ig.ImVec2 = undefined;
        ig.igGetWindowPos(&windowpos);
        var offset = math.vec2(windowpos.x, windowpos.y);

        for (brushes.values()) |b| {
            // log.debug("brush={}", .{b});
            for (b.polys) |polyid| {
                // log.debug("polyid={}", .{polyid});
                const poly = polys.get(polyid).?;
                const npts = poly.points.len;
                var plist = std.heap.c_allocator.alloc(ig.ImVec2, npts) catch unreachable;
                defer std.heap.c_allocator.free(plist);

                // if (plist == NULL) {  // something has gone very wrong
                //     nb::log(ERR, "Could not allocate memory for face %d draw list!", b.polys[i]);
                //     return;
                // }

                for (poly.points) |p, i| {
                    // var v = polys.get(p).?;
                    // log.debug("point={}", .{p});
                    var v = p.muls(view.scale).expand(1.0);
                    v = vmat.vecmul(v);
                    v.data[0] += offset.data[0];
                    v.data[1] += offset.data[1];

                    // log.debug("{}", .{v});
                    plist[i] = ig.ImVec2{ .x = v.data[0], .y = v.data[1] };
                }

                ig.ImDrawList_AddPolyline(dl, @ptrCast([*c]ig.ImVec2, plist), @intCast(c_int, npts), std.math.maxInt(ig.ImU32), 0, 2.0);
            }
        }
    }
    ig.igEnd();
}

const AppState = @import("../app.zig").State;

pub fn show_editor(state: *AppState) void {
    if (!state.*.menu_open) return;
    var editor = if (state.*.editor) |*e| e else return;

    if (ig.igBeginMainMenuBar()) {
        if (ig.igBeginMenu("File", true)) {
            if (ig.igMenuItem_Bool("New", "Ctrl+N", false, true)) {
                // confirm save if unsaved changes
            }
            if (ig.igMenuItem_Bool("Open", "Ctrl+O", false, true)) {
                // confirm save if unsaved changes
            }
            ig.igSeparator();
            if (ig.igMenuItem_Bool("Options", "", false, true)) state.*.options_open = true;

            if (ig.igMenuItem_Bool("Show Metrics", "", state.*.metrics_open, true)) state.*.metrics_open = !state.*.metrics_open;
            ig.igSeparator();
            if (ig.igMenuItem_Bool("Quit Editor", "Ctrl+Q", false, true)) {
                // TODO: confirm, save, etc.
                editor.deinit();
                state.*.editor = null;
            }
            ig.igEndMenu();
        }

        if (ig.igBeginMenu("Edit", true)) {
            if (ig.igMenuItem_Bool("Undo", "Ctrl+Z", false, false)) {}
            if (ig.igMenuItem_Bool("Redo", "Ctrl+Shift+Z", false, false)) {}
            ig.igSeparator();
            if (ig.igMenuItem_Bool("Delete", "Del", false, false)) {}
            if (ig.igMenuItem_Bool("Duplicate", "Ins", false, false)) {}
            ig.igSeparator();
            if (ig.igMenuItem_Bool("Compile Map", "F6", false, true)) {
                // TODO: skip if !editor.needs_compile
                // make sure this flag is used correctly first
                editor.*.compile() catch {
                    log.err("map failed to compile!", .{});
                };
            }
            ig.igEndMenu();
        }

        if (ig.igBeginMenu("Game", true)) {
            if (ig.igMenuItem_Bool("Game Mode", "Alt+G", false, false)) {
                // if (editor.dirty) { editor.save(); }
                // if (editor.needs_rebuild) { editor.compile(); }
                // game.launch(); or something
            }
            ig.igEndMenu();
        }
        ig.igEndMainMenuBar();
    }

    // show_selection_menu();
    map_view(editor);
    // ui.show_console(open, true);
    tool_window(editor);
}
