Vector2i :: struct {
    x, y: s32;
    #overlay (x) component: [2] s32;
}

operator + :: (a: Vector2i, b: Vector2i) -> Vector2i {
    return Vector2i.{ a.x + b.x, a.y + b.y };
}

operator == :: (a: Vector2i, b: Vector2i) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator - :: (a: Vector2i) -> Vector2i {
    return .{-a.x, -a.y};
}

sign :: inline (x: $T/.[float32, float64, s8, s16, s32, s64, u8, u16, u32, u64]) -> T {
    if x > 0 return 1;
    if x < 0 return -1;
    return 0;
}

sign :: inline (using v: Vector2) -> Vector2 {
    return .{ sign(x), sign(y) };
}
