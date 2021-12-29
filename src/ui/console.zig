const std = @import("std");
const ig = @import("imgui");
const log = std.log.scoped(.app);
const logger = @import("../logger.zig");
const LogItem = logger.LogItem;

// TODO: watch how this is used and see if a FixedBufferAllocator would be better
var _gpa = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = _gpa.allocator();

const msg_colors = [4]ig.ImVec4{
    .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 },
    .{ .x = 1.0, .y = 0.4, .z = 0.4, .w = 1.0 },
    .{ .x = 1.0, .y = 0.8, .z = 0.6, .w = 1.0 },
    .{ .x = 0.0, .y = 0.4, .z = 1.0, .w = 1.0 },
};

// console state
const cmd_buf_size: usize = 2048;
var cmdbuf = [1]u8{'\x00'} ** cmd_buf_size;
var log_filter: [*c]ig.ImGuiTextFilter = null;
var history_pos: i32 = -1;
var autoscroll: bool = true;
var scroll_bottom: bool = false;
var cmds: std.StringArrayHashMapUnmanaged(?fn ([][]const u8) void) = undefined;
var history: std.ArrayListUnmanaged([]const u8) = undefined;

/// register command with console at runtime
pub fn register_cmd(name: []const u8, func: ?fn ([][]const u8) void) !void {
    if (cmds.get(name)) |_| return error.CmdNameInUse;
    try cmds.put(gpa, name, func);
}

pub fn unregister_cmd(name: []const u8) void {
    if (!cmds.remove(name)) log.warn("command \"{s}\" not removed because it doesn't exist", .{});
}

fn exec(buf: []const u8) !void {
    if (buf.len == 0) return;

    var buf_ = try gpa.alloc(u8, buf.len);
    defer gpa.free(buf_);

    for (buf_) |*x| x.* = '\x00';
    std.mem.copy(u8, buf_, buf);
    var buf_trim = std.mem.trim(u8, buf_, " ");

    var argv_it = std.mem.tokenize(u8, buf_trim, " \n\t\x00");
    var argv = std.ArrayList([]const u8).init(gpa);
    defer argv.deinit();
    while (argv_it.next()) |a| try argv.append(a[0..a.len]);

    if (argv.items.len == 0) return;
    // addlog("# %s\n", buf);

    // Insert into history. First find match and delete it so it can be pushed to the back. This isn't trying to be smart or optimal.
    history_pos = -1;
    var i: usize = history.items.len;
    while (i > 0) : (i -= 1) {
        if (std.mem.eql(u8, history.items[i - 1], buf)) {
            var dup = history.orderedRemove(i - 1);
            gpa.free(dup);
            break;
        }
    }

    try history.append(gpa, try gpa.dupe(u8, buf));

    errdefer {
        var a = history.pop();
        gpa.free(dup);
    }

    const cmd = cmds.get(argv.items[0]);
    if (cmd) |func| {
        func.?(argv.items);
    } else {
        log.err("command \"{s}\" not found", .{argv.items[0][0..]});
    }

    scroll_bottom = true;
}

fn _input_callback(dptr: [*c]ig.ImGuiInputTextCallbackData) callconv(.C) c_int {
    if (dptr == null) return 0;
    const data = dptr.?;
    switch (data.*.EventFlag) {
        ig.ImGuiInputTextFlags_CallbackCompletion => {
            // Locate beginning of current word
            var word_end = @ptrCast([*c]u8, &data.*.Buf[@intCast(usize, data.*.CursorPos)]);
            // + data.*.CursorPos;
            var word_start = word_end;
            while (word_start > data.*.Buf) : (word_start -= 1) {
                const c = (word_start - 1)[0];
                if (c == ' ' or c == '\t' or c == ',' or c == ';') break;
                word_start -= 1;
            }

            // Build a list of candidates
            var candidates = std.ArrayList([]const u8).init(gpa);
            defer candidates.deinit();

            const word = word_start[0 .. @ptrToInt(word_end) - @ptrToInt(word_start)];
            for (cmds.keys()) |p| {
                if (std.mem.eql(u8, p, word)) candidates.append(p) catch unreachable;
            }

            if (candidates.items.len == 0) {
                log.err("No match for \"{s}\".", .{word});
            } else if (candidates.items.len == 1) {
                // Single match. Delete the beginning of the word and replace it entirely so we've got nice casing
                ig.ImGuiInputTextCallbackData_DeleteChars(
                    data,
                    @intCast(c_int, @ptrToInt(word_start) - @ptrToInt(data.*.Buf)),
                    @intCast(c_int, @ptrToInt(word_end) - @ptrToInt(word_start)),
                );
                const str = candidates.items[0];
                ig.ImGuiInputTextCallbackData_InsertChars(
                    data,
                    data.*.CursorPos,
                    @ptrCast([*c]const u8, str),
                    @ptrCast([*c]const u8, str.ptr + str.len),
                );
                ig.ImGuiInputTextCallbackData_InsertChars(data, data.*.CursorPos, " ", "");
            } else {
                var match_len = @ptrToInt(word_end) - @ptrToInt(word_start);
                while (true) {
                    var c: i32 = 0;
                    var all_candidates_matches: bool = true;
                    for (candidates.items) |candidate, i| {
                        if (!all_candidates_matches) break;
                        if (i == 0) {
                            c = std.ascii.toUpper(candidate[match_len]);
                        } else if (c == 0 or c != std.ascii.toUpper(candidate[match_len])) {
                            all_candidates_matches = false;
                        }
                    }
                    if (!all_candidates_matches) break;
                    match_len += 1;
                }

                if (match_len > 0) {
                    ig.ImGuiInputTextCallbackData_DeleteChars(
                        data,
                        @intCast(c_int, @ptrToInt(word_start) - @ptrToInt(data.*.Buf)),
                        @intCast(c_int, @ptrToInt(word_end) - @ptrToInt(word_start)),
                    );
                    const str = candidates.items[0];
                    ig.ImGuiInputTextCallbackData_InsertChars(
                        data,
                        data.*.CursorPos,
                        @ptrCast([*c]const u8, str),
                        @ptrCast([*c]const u8, str.ptr + match_len),
                    );
                }

                log.info("Possible matches:", .{});
                for (candidates.items) |candidate| log.info("- {s}", .{candidate});
            }
        },
        ig.ImGuiInputTextFlags_CallbackHistory => {
            const prev_history_pos = history_pos;
            if (data.*.EventKey == ig.ImGuiKey_UpArrow) {
                if (history_pos == -1) {
                    history_pos = std.math.max(0, @intCast(i32, history.items.len) - 1);
                } else if (history_pos > 0) {
                    history_pos -= 1;
                }
            } else if (data.*.EventKey == ig.ImGuiKey_DownArrow) {
                if (history_pos != -1) {
                    history_pos += 1;
                    if (history_pos >= history.items.len) {
                        history_pos = -1;
                    }
                }
            }

            // A better implementation would preserve the data on the current input line along with cursor position.
            if (prev_history_pos != history_pos) {
                const history_str = if (history_pos >= 0 and history.items.len != 0) history.items[@intCast(usize, history_pos)] else "";
                ig.ImGuiInputTextCallbackData_DeleteChars(data, 0, data.*.BufTextLen);
                ig.ImGuiInputTextCallbackData_InsertChars(
                    data,
                    0,
                    @ptrCast([*c]const u8, history_str),
                    @ptrCast([*c]const u8, history_str.ptr + history_str.len),
                );
            }
        },
        else => {},
    }
    return 0;
}

pub fn show_console(open: *bool) void {
    if (log_filter == null) {
        log_filter = ig.ImGuiTextFilter_ImGuiTextFilter("");
    }
    if (true) {
        ig.igSetNextWindowSize(.{ .x = 520, .y = 600 }, ig.ImGuiCond_FirstUseEver);
        if (!ig.igBegin("Console", open, ig.ImGuiWindowFlags_MenuBar | ig.ImGuiWindowFlags_NoDocking)) {
            ig.igEnd();
            return;
        }
    } else {
        var io = ig.igGetIO();
        const DISTANCE: f32 = 16.0;
        const WIDTH = std.math.min(io.*.DisplaySize.x, 360) - DISTANCE * 2;
        // const XPOS = std.math.max(0, io.*.DisplaySize.x - WIDTH - DISTANCE);
        ig.igSetNextWindowBgAlpha(0.0);
        ig.igSetNextWindowSize(.{ .x = WIDTH, .y = 100 }, 0);
        //ig.igSetNextWindowPos(.{ .x = XPOS, .y = io.*.DisplaySize.y - 100 - DISTANCE });
        ig.igPushStyleColor_Vec4(ig.ImGuiCol_Border, .{ .x = 0, .y = 0, .z = 0, .w = 0 });
        if (!ig.igBegin("ConsoleMini", null, ig.ImGuiWindowFlags_NoDecoration | ig.ImGuiWindowFlags_AlwaysAutoResize | ig.ImGuiWindowFlags_NoSavedSettings | ig.ImGuiWindowFlags_NoFocusOnAppearing | ig.ImGuiWindowFlags_NoNav | ig.ImGuiWindowFlags_NoBringToFrontOnFocus)) {
            ig.igEnd();
            return;
        }
        ig.igPopStyleColor(1);
    }

    // As a specific feature guaranteed by the library, after calling Begin() the last Item represent the title bar. So e.g. IsItemHovered() will return true when hovering the title bar.
    // Here we create a context menu only available from the title bar.
    var copy_to_clipboard: bool = false;
    if (ig.igBeginMenuBar()) {
        if (ig.igBeginMenu("Options", true)) {
            if (ig.igMenuItem_BoolPtr("Autoscroll", null, &autoscroll, true)) {}
            ig.igEndMenu();
        }
        if (ig.igBeginMenu("Edit", true)) {
            if (ig.igMenuItem_Bool("Clear", "Ctrl+L", false, true)) {} //clearlog(); }
            if (ig.igMenuItem_Bool("Copy", "Ctrl+C", false, true)) {
                copy_to_clipboard = true;
            }
            if (ig.igMenuItem_Bool("Close", "`", false, true)) {
                open.* = false;
            }
            ig.igEndMenu();
        }
        ig.igEndMenuBar();
    }

    // Filter
    _ = ig.ImGuiTextFilter_Draw(log_filter, "Filter (\"incl,-excl\") [\"error\"]", 180);
    ig.igSeparator();

    const footer_height_to_reserve = ig.igGetStyle().*.ItemSpacing.y + ig.igGetFrameHeightWithSpacing(); // 1 separator, 1 input text
    _ = ig.igBeginChild_Str("ScrollingRegion", .{ .x = 0, .y = -footer_height_to_reserve }, false, ig.ImGuiWindowFlags_HorizontalScrollbar); // Leave room for 1 separator + 1 InputText
    if (ig.igBeginPopupContextWindow("##filter", 0)) {
        if (ig.igSelectable_Bool("Clear", false, 0, .{})) {} //clearlog();
        ig.igEndPopup();
    }

    // TODO:
    ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ItemSpacing, .{ .x = 4, .y = 1 }); // Tighten spacing
    if (copy_to_clipboard) ig.igLogToClipboard(-1);

    var log_items = logger.get_logs();
    for (log_items) |item| {
        if (!ig.ImGuiTextFilter_PassFilter(
            log_filter,
            @ptrCast([*c]const u8, item.data),
            @ptrCast([*c]const u8, item.data.ptr + item.data.len),
        )) continue;

        var pop_color: bool = false;
        const id = @intCast(usize, @enumToInt(item.tag));
        if (item.tag != .none) {
            ig.igPushStyleColor_Vec4(ig.ImGuiCol_Text, msg_colors[id]);
            pop_color = true;
        }
        // var out = [1]u8{'\x00'} ** cmd_buf_size;
        // std.mem.copy(u8, out[0..], item.data);
        ig.igTextUnformatted(
            @ptrCast([*c]const u8, item.data),
            @intToPtr([*c]const u8, @ptrToInt(item.data.ptr) + item.data.len),
        );
        if (pop_color) ig.igPopStyleColor(1);
    }

    if (copy_to_clipboard) ig.igLogFinish();

    if (scroll_bottom or (autoscroll and ig.igGetScrollY() >= ig.igGetScrollMaxY())) {
        ig.igSetScrollHereY(1.0);
    }
    scroll_bottom = false;

    ig.igPopStyleVar(1);
    ig.igEndChild();
    ig.igSeparator();

    // Command-line
    var reclaim_focus: bool = false;
    if (ig.igInputText(
        "Input",
        @ptrCast([*c]u8, &cmdbuf),
        cmd_buf_size,
        ig.ImGuiInputTextFlags_EnterReturnsTrue | ig.ImGuiInputTextFlags_CallbackCompletion | ig.ImGuiInputTextFlags_CallbackHistory,
        _input_callback,
        null,
    )) {
        exec(cmdbuf[0..]) catch |err| {
            std.debug.print("exec error: {}\n", .{err});
        };

        cmdbuf = std.mem.zeroes(@TypeOf(cmdbuf));
        reclaim_focus = true;
    }

    // Auto-focus on window apparition
    ig.igSetItemDefaultFocus();
    if (reclaim_focus) ig.igSetKeyboardFocusHere(-1); // Auto focus previous widget

    ig.igEnd();
}

//void show_mini() {
//    const footer_height_to_reserve = ig.igGetStyle().ItemSpacing.y + ig.igGetFrameHeightWithSpacing(); // 1 separator, 1 input text
//    ig.igBeginChild_Str("ScrollingRegion", .{.x= 0,.y= -footer_height_to_reserve}, false, ig.ImGuiWindowFlags_HorizontalScrollbar,);
//    ig.igPushStyleVar_Vec2(ig.ImGuiStyleVar_ItemSpacing, .{.x=4,.y=1});
//
//    for (u32 i = MAX(0, (i32)items.size() - 10); i < items.size(); i++)
//    {
//        const item_t item = items.at(i);
//        ig.igPushStyleColor_Vec4(ImGuiCol_Text, MSG_COLORS[item.type]);
//        char out[CMDBUF_SIZE];
//        strcpy(out, MSG_PREFIX[item.type]);
//        ig.igTextUnformatted(strncat(out, item.data, CMDBUF_SIZE));
//        ig.igPopStyleColor();
//    }
//
//    ig.igSetScrollHereY(1.0f);
//
//    ig.igPopStyleVar();
//    ig.igEndChild();
//
//    ig.igEnd();
//}

// BUILT-INS

fn echo(argv: [][]const u8) void {
    _ = argv;
    // string a = "";
    // if (argv.size() == 1) {
    //     addlog("%s", a.c_str());
    // } else {
    //     for (u32 i=1; i<argv.size()-1; i++) {
    //         a+=argv.at(i); a+=' ';  // TODO: make this less lame
    //     }
    //     a+=argv.back();
    //     addlog("%s", a.c_str());
    // }
}
