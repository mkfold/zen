/// thanks http://realtimecollisiondetection.net/blog/?p=86 <3
const Key = packed struct {
    layer: FullscreenLayer,
    translucency: TranslucencyType,
};

const FullscreenLayer = enum(u2) {
    Game,
    Effect,
    Gui,
};

const TranslucencyType = enum(u3) {
    Opaque,
    Translucent,
    Additive,
    Subtractive,
};
