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
