TILE_SIZE : s32 : 16;

Tilemap :: struct {
    width: int;
    height: int;
    tiles: []Tile_Type;
}

Tile_Type :: enum {
    EMPTY;
    SOLID;
    SLOPE_UP;
    SLOPE_DOWN;
}

tile_index :: inline (m: *Tilemap, x: int, y: int) -> int {
    return y * m.width + x;
}

tile_at :: (m: *Tilemap, tx: int, ty: int) -> Tile_Type {
    if tx < 0 || tx >= m.width || ty < 0 || ty >= m.height {
        return .SOLID; // bounds of tile is solid
    }
    return m.tiles[tile_index(m, tx, ty)];
}

tile_at_position :: (m: *Tilemap, x: float, y: float) -> Tile_Type, int, int {
    tx := world_to_tile_x(x);
    ty := world_to_tile_y(y);

    if tx < 0 || tx >= m.width || ty < 0 || ty >= m.height {
        return .SOLID, tx, ty; // bounds of tile is solid
    }
    return m.tiles[tile_index(m, tx, ty)], tx, ty;
}

tile_is_slope :: inline (t: Tile_Type) -> bool {
    return t == .SLOPE_UP || t == .SLOPE_DOWN;
}

world_to_tile_x :: inline (x: float) -> int {
    return cast(int) floor(x / TILE_SIZE);
}

world_to_tile_y :: inline (y: float) -> int {
    return cast(int) floor(y / TILE_SIZE);
}

tile_slope_at :: (m: *Tilemap, x: int, y: int) -> Tile_Type, bool {
    tx := world_to_tile_x(xx x);
    ty := world_to_tile_y(xx y);

    if tx < 0 || tx >= m.width || ty < 0 || ty >= m.height {
        return .SOLID, false; // bounds of tile is solid
    }
    tile := m.tiles[tile_index(m, tx, ty)];

    if tile != .SLOPE_UP && tile != .SLOPE_DOWN {
        return .EMPTY, false;
    }

    return tile, true;
}

tile_solid_at :: (m: *Tilemap, x: int, y: int) -> bool {
    tx := world_to_tile_x(xx x);
    ty := world_to_tile_y(xx y);

    if tx < 0 || tx >= m.width || ty < 0 || ty >= m.height {
        return true; // bounds of tile is solid
    }

    return m.tiles[tile_index(m, tx, ty)] == .SOLID;
}

tile_slope_y :: (tile: Tile_Type, world_x: float, tx: int, ty: int) -> float {
    // Relative position of X inside the tile.
    local_x := (world_x - cast(float) (tx * TILE_SIZE)) / cast(float) TILE_SIZE;
    local_x = clamp(local_x, 0.0, 1.0);

    tile_bottom_y := cast(float) ((ty + 1) * TILE_SIZE);
    tile_top_y := cast(float) (ty * TILE_SIZE);

    result: float;
    if tile == {
        case .SLOPE_UP;
            result = tile_bottom_y - local_x * TILE_SIZE;
        case .SLOPE_DOWN;
            result = tile_top_y + local_x * TILE_SIZE;
        case .SOLID;
            result = tile_top_y;
        case;
            result = tile_top_y + TILE_SIZE; // empty
    }

    return result;
}

tile_floor_y_at :: (m: *Tilemap, x: float, y: float) -> float, bool {
    tx := world_to_tile_x(x);
    ty := world_to_tile_y(y);

    tile_top_y := cast(float) (ty * TILE_SIZE);

    if tx < 0 || tx >= m.width || ty < 0 || ty >= m.height {
        return tile_top_y, true;
    }

    t := m.tiles[tile_index(m, tx, ty)];
    if t == .SLOPE_UP || t == .SLOPE_DOWN {
        return tile_slope_y(t, x, tx, ty), true;
    } else if t == .SOLID {
        return tile_top_y, true;
    }

    return -1, false;
}

tile_floor_y_collider :: (m: *Tilemap, collider: Rectangle) -> float, bool {
    eps :: 1.0;
    left  := collider.x;
    right := collider.x + collider.width;
    center := collider.x + collider.width*0.5;
    top := collider.y;
    bottom := collider.y + collider.height;

    tx0 := world_to_tile_x(center);
    ty0 := world_to_tile_y(top);
    tx1 := world_to_tile_x(center);
    ty1 := world_to_tile_y(bottom);

    tx1 = clamp(tx1, 0, m.width);
    tx0 = clamp(tx0, 0, tx1);
    ty1 = clamp(ty1, 0, m.height);
    ty0 = clamp(ty0, 0, ty1);

    g_debug.tx0 = tx0;
    g_debug.ty0 = ty0;
    g_debug.tx1 = tx1;
    g_debug.ty1 = ty1;

    best_y := 1000000.0;
    for tx: tx0..tx1 {
        for ty: ty0..ty1 {
            if tx < 0 || tx >= m.width || ty < 0 || ty >= m.height {
                // array_add(*floors, xx (ty * TILE_SIZE));
                floor_y := cast(float) (ty * TILE_SIZE);
                if floor_y < best_y {
                    best_y = floor_y;
                }
                continue;
            }

            t := m.tiles[tile_index(m, tx, ty)];
            if t == .EMPTY {
                continue;
            }

            floor_y := tile_slope_y(t, center, tx, ty);
            if floor_y < best_y {
                best_y = floor_y;
            }
        }
    }

    // max_floor := -1.0;
    // if floors.count == 0 {
    //     return -1, false;
    // }
    // if floors.count > 0 {
    //     max_floor = floors[0];
    // }

    // for floor_y: floors {
    //     max_floor = min(max_floor, floor_y);
    // }
    //
    g_debug.bottom_y = best_y;

    return best_y, best_y != 1000000;
}

max_floor_at_tile :: (m: *Tilemap, x_left: float, x_right: float, bottom_y: float) -> float, bool {
    eps :: 1.0;
    lx := x_left + eps;
    cx := (x_left + x_right) * 0.5;
    rx := x_right - eps;

    found := false;
    max_surface_y := -1000000.0;

    // Left sample.
    y, ok := tile_floor_y_at(m, lx, bottom_y);
    if ok {
        max_surface_y = y;
        found = true;
    }

    // Central sample.
    y, ok = tile_floor_y_at(m, cx, bottom_y);
    if ok {
        max_surface_y = ifx found then max(max_surface_y, y) else y;
        found = true;
    }

    // Right sample.
    y, ok = tile_floor_y_at(m, rx, bottom_y);
    if ok {
        max_surface_y = ifx found then max(max_surface_y, y) else y;
        found = true;
    }

    return max_surface_y, found;
}

draw_tilemap :: (m: *Tilemap) {
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            idx := tile_index(m, x, y);
            t := m.tiles[idx];

            if t == .EMPTY continue;

            color := DARKBLUE;

            top := cast(float) y * TILE_SIZE;
            bottom := cast(float) (y * TILE_SIZE) + TILE_SIZE;
            left := cast(float) x * TILE_SIZE;
            right := cast(float) (x * TILE_SIZE) + TILE_SIZE;

            if t == {
                case .SOLID;
                    DrawRectangle(xx (x * TILE_SIZE), xx (y * TILE_SIZE), TILE_SIZE, TILE_SIZE, color);
                case .SLOPE_UP;
                    v1 := Vector2.{ left, bottom };
                    v2 := Vector2.{ right, bottom };
                    v3 := Vector2.{ right, top };
                    DrawTriangle(v1, v2, v3, color);
                case .SLOPE_DOWN;
                    v1 := Vector2.{ left, bottom };
                    v2 := Vector2.{ right, bottom };
                    v3 := Vector2.{ left, top };
                    DrawTriangle(v1, v2, v3, color);
            }
        }
    }
}

tile_slope_tangent :: (t: Tile_Type) -> Vector2 {
    if t == {
        case .SLOPE_UP;
            return normalize(Vector2.{ -1.0, 1.0 });
        case .SLOPE_DOWN;
            return normalize(Vector2.{ 1.0, 1.0 });
        case;
            return Vector2.{ 1.0, 0.0 };
    }
}

tile_slope_normal :: (tile: Tile_Type) -> Vector2 {
    if tile == .SLOPE_UP {
        return Vector2.{ -1.0, -1.0 };
    } else if tile == .SLOPE_DOWN {
        return Vector2.{ 1.0, -1.0 };
    } else {
        return Vector2.{ 0.0, -1.0 };
    }
}

tile_slope_y_at :: (t: Tile_Type, x: float, tx: int, ty: int) -> float {
    local_x := x - cast(float) (tx * TILE_SIZE);

    if t == .SLOPE_UP {
        return xx ((ty + 1) * TILE_SIZE) - local_x;
    } else if t == .SLOPE_DOWN {
        return xx (ty * TILE_SIZE) + local_x;
    } else if  t == .SOLID {
        return xx (ty * TILE_SIZE);
    }

    return xx ((ty + 1) * TILE_SIZE);
}
