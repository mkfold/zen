const std = @import("std");

const ig = @import("imgui");

const math = @import("../math.zig");
const Vec2 = math.Vec2;

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
} = .{};

// immediate mode brush drawing T_T
fn map_view(editor: *Editor) void {
    // if (editor.current_map == null) return;

    const map = editor.current_map;
    const brushes = map.brushes;
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

        for (brushes.items) |b| {
            for (b.polys) |poly| {
                const npts = poly.points.len;
                var plist = std.heap.c_allocator.alloc(ig.ImVec2, npts) catch unreachable;
                defer std.heap.c_allocator.free(plist);

                // if (plist == NULL) {  // something has gone very wrong
                //     nb::log(ERR, "Could not allocate memory for face %d draw list!", b.polys[i]);
                //     return;
                // }

                for (poly.points) |p, i| {
                    var v = p.muls(view.scale).expand(1.0);
                    v = vmat.vecmul(v);
                    v.data[0] += offset.data[0];
                    v.data[1] += offset.data[1];

                    plist[i] = ig.ImVec2{ .x = v.data[0], .y = v.data[1] };
                }

                ig.ImDrawList_AddPolyline(dl, @ptrCast([*c]ig.ImVec2, plist), @intCast(c_int, npts), std.math.maxInt(ig.ImU32), 0, 1.0);
            }
        }
    }
    ig.igEnd();
}

const AppState = @import("../app.zig").State;

pub fn show_editor(state: *AppState) void {
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
            if (ig.igMenuItem_Bool("Compile Map", "F6", false, false)) {
                // TODO: skip if !editor.needs_compile
                // make sure this flag is used correctly first
                // editor.compile();
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
}
