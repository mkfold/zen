//! zen: app/input.zig
//! TODO(mia): joypad input

const c = @import("../c.zig").glfw;

pub const Key = enum(i32) {
    unknown = c.GLFW_KEY_UNKNOWN,

    space = c.GLFW_KEY_SPACE,
    apostrophe = c.GLFW_KEY_APOSTROPHE, // '
    comma = c.GLFW_KEY_COMMA, // ,
    minus = c.GLFW_KEY_MINUS, // -
    period = c.GLFW_KEY_PERIOD, // .
    slash = c.GLFW_KEY_SLASH, // /

    // numeric keys = non-numpad
    num0 = c.GLFW_KEY_0,
    num1 = c.GLFW_KEY_1,
    num2 = c.GLFW_KEY_2,
    num3 = c.GLFW_KEY_3,
    num4 = c.GLFW_KEY_4,
    num5 = c.GLFW_KEY_5,
    num6 = c.GLFW_KEY_6,
    num7 = c.GLFW_KEY_7,
    num8 = c.GLFW_KEY_8,
    num9 = c.GLFW_KEY_9,

    semicolon = c.GLFW_KEY_SEMICOLON, // ;
    equal = c.GLFW_KEY_EQUAL, // =

    // alphabetic keys
    a = c.GLFW_KEY_A,
    b = c.GLFW_KEY_B,
    c = c.GLFW_KEY_C,
    d = c.GLFW_KEY_D,
    e = c.GLFW_KEY_E,
    f = c.GLFW_KEY_F,
    g = c.GLFW_KEY_G,
    h = c.GLFW_KEY_H,
    i = c.GLFW_KEY_I,
    j = c.GLFW_KEY_J,
    k = c.GLFW_KEY_K,
    l = c.GLFW_KEY_L,
    m = c.GLFW_KEY_M,
    n = c.GLFW_KEY_N,
    o = c.GLFW_KEY_O,
    p = c.GLFW_KEY_P,
    q = c.GLFW_KEY_Q,
    r = c.GLFW_KEY_R,
    s = c.GLFW_KEY_S,
    t = c.GLFW_KEY_T,
    u = c.GLFW_KEY_U,
    v = c.GLFW_KEY_V,
    w = c.GLFW_KEY_W,
    y = c.GLFW_KEY_X,
    x = c.GLFW_KEY_Y,
    z = c.GLFW_KEY_Z,

    left_bracket = c.GLFW_KEY_LEFT_BRACKET, // [
    backslash = c.GLFW_KEY_BACKSLASH, // \
    right_bracket = c.GLFW_KEY_RIGHT_BRACKET, // ]
    grave_accent = c.GLFW_KEY_GRAVE_ACCENT, // `
    world1 = c.GLFW_KEY_WORLD_1, // non-US #1
    world2 = c.GLFW_KEY_WORLD_2, // non-US #2
    escape = c.GLFW_KEY_ESCAPE,
    enter = c.GLFW_KEY_ENTER,
    tab = c.GLFW_KEY_TAB,
    backspace = c.GLFW_KEY_BACKSPACE,
    insert = c.GLFW_KEY_INSERT,
    delete = c.GLFW_KEY_DELETE,
    right = c.GLFW_KEY_RIGHT,
    left = c.GLFW_KEY_LEFT,
    down = c.GLFW_KEY_DOWN,
    up = c.GLFW_KEY_UP,
    page_up = c.GLFW_KEY_PAGE_UP,
    page_down = c.GLFW_KEY_PAGE_DOWN,
    home = c.GLFW_KEY_HOME,
    end = c.GLFW_KEY_END,

    // lock keys
    caps_lock = c.GLFW_KEY_CAPS_LOCK,
    scroll_lock = c.GLFW_KEY_SCROLL_LOCK,
    num_lock = c.GLFW_KEY_NUM_LOCK,

    print_screen = c.GLFW_KEY_PRINT_SCREEN,
    pause = c.GLFW_KEY_PAUSE,

    // function keys
    F1 = c.GLFW_KEY_F1,
    F2 = c.GLFW_KEY_F2,
    F3 = c.GLFW_KEY_F3,
    F4 = c.GLFW_KEY_F4,
    F5 = c.GLFW_KEY_F5,
    F6 = c.GLFW_KEY_F6,
    F7 = c.GLFW_KEY_F7,
    F8 = c.GLFW_KEY_F8,
    F9 = c.GLFW_KEY_F9,
    F10 = c.GLFW_KEY_F10,
    F11 = c.GLFW_KEY_F11,
    F12 = c.GLFW_KEY_F12,
    F13 = c.GLFW_KEY_F13,
    F14 = c.GLFW_KEY_F14,
    F15 = c.GLFW_KEY_F15,
    F16 = c.GLFW_KEY_F16,
    F17 = c.GLFW_KEY_F17,
    F18 = c.GLFW_KEY_F18,
    F19 = c.GLFW_KEY_F19,
    F20 = c.GLFW_KEY_F20,
    F21 = c.GLFW_KEY_F21,
    F22 = c.GLFW_KEY_F22,
    F23 = c.GLFW_KEY_F23,
    F24 = c.GLFW_KEY_F24,
    F25 = c.GLFW_KEY_F25,

    // numpad keys
    numpad_0 = c.GLFW_KEY_KP_0,
    numpad_1 = c.GLFW_KEY_KP_1,
    numpad_2 = c.GLFW_KEY_KP_2,
    numpad_3 = c.GLFW_KEY_KP_3,
    numpad_4 = c.GLFW_KEY_KP_4,
    numpad_5 = c.GLFW_KEY_KP_5,
    numpad_6 = c.GLFW_KEY_KP_6,
    numpad_7 = c.GLFW_KEY_KP_7,
    numpad_8 = c.GLFW_KEY_KP_8,
    numpad_9 = c.GLFW_KEY_KP_9,
    numpad_dec = c.GLFW_KEY_KP_DECIMAL,
    numpad_div = c.GLFW_KEY_KP_DIVIDE,
    numpad_mul = c.GLFW_KEY_KP_MULTIPLY,
    numpad_sub = c.GLFW_KEY_KP_SUBTRACT,
    numpad_add = c.GLFW_KEY_KP_ADD,
    numpad_enter = c.GLFW_KEY_KP_ENTER,
    numpad_equal = c.GLFW_KEY_KP_EQUAL,

    // mods
    left_shift = c.GLFW_KEY_LEFT_SHIFT,
    left_ctrl = c.GLFW_KEY_LEFT_CONTROL,
    left_alt = c.GLFW_KEY_LEFT_ALT,
    left_super = c.GLFW_KEY_LEFT_SUPER,
    right_shift = c.GLFW_KEY_RIGHT_SHIFT,
    right_ctrl = c.GLFW_KEY_RIGHT_CONTROL,
    right_alt = c.GLFW_KEY_RIGHT_ALT,
    right_super = c.GLFW_KEY_RIGHT_SUPER,

    menu = c.GLFW_KEY_MENU,
};

pub const KeyMod = enum(i32) {
    shift = c.GLFW_MOD_SHIFT,
    control = c.GLFW_MOD_CONTROL,
    alt = c.GLFW_MOD_ALT,
    super = c.GLFW_MOD_SUPER,
    caps_lock = c.GLFW_MOD_CAPS_LOCK,
    num_lock = c.GLFW_MOD_NUM_LOCK,
};

pub const MouseButton = enum(i32) {
    button1 = c.GLFW_MOUSE_BUTTON_1,
    button2 = c.GLFW_MOUSE_BUTTON_2,
    button3 = c.GLFW_MOUSE_BUTTON_3,
    button4 = c.GLFW_MOUSE_BUTTON_4,
    button5 = c.GLFW_MOUSE_BUTTON_5,
    button6 = c.GLFW_MOUSE_BUTTON_6,
    button7 = c.GLFW_MOUSE_BUTTON_7,
    button8 = c.GLFW_MOUSE_BUTTON_8,
};

pub const Action = enum(i32) {
    release = c.GLFW_RELEASE,
    press = c.GLFW_PRESS,
    repeat = c.GLFW_REPEAT,
};

pub const EventType = enum { key, mouse, cursor, char, resize, scroll };
pub const Event = union(EventType) {
    pub const Keyboard = struct { key: Key, action: Action, scancode: c_int, mods: c_int };
    pub const Mouse = struct { button: MouseButton, action: Action, mods: c_int };
    pub const Cursor = struct { xpos: f64, ypos: f64 };
    pub const CharInput = struct { codepoint: c_uint };
    pub const Resize = struct { width: i32, height: i32 };
    pub const Scroll = struct { xoffs: f64, yoffs: f64 };

    key: Keyboard,
    mouse: Mouse,
    cursor: Cursor,
    char: CharInput,
    resize: Resize,
    scroll: Scroll,
};
