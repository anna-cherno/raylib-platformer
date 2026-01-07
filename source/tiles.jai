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
    // ONE_WAY;
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
    tx := cast(int) (x / TILE_SIZE);
    ty := cast(int) (y / TILE_SIZE);

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
    tx := cast(int) (x / TILE_SIZE);
    ty := cast(int) (y / TILE_SIZE);

    if tx < 0 || tx >= m.width || ty < 0 || ty >= m.height {
        return true; // bounds of tile is solid
    }

    return m.tiles[tile_index(m, tx, ty)] == .SOLID;
}

tile_get_slope_y :: (tile: Tile_Type, world_x: float, tile_x: int, tile_y: int) -> float {
    // Relative position of X inside the tile.
    local_x := (world_x - cast(float) (tile_x * TILE_SIZE)) / cast(float) TILE_SIZE;
    local_x = clamp(local_x, 0.0, 1.0);

    base_y := cast(float) (tile_y * TILE_SIZE);

    if tile == {
        case .SLOPE_UP;   return base_y + (1.0 - local_x) * TILE_SIZE;
        case .SLOPE_DOWN; return base_y + local_x * TILE_SIZE;
        case .SOLID;      return base_y;
        case;             return base_y + TILE_SIZE; // empty
    }
}

tile_surface_y_at :: (m: *Tilemap, world_x: float, bottom_y: float) -> float, bool {
    tx := world_to_tile_x(world_x);
    ty := world_to_tile_y(bottom_y);

    if tx < 0 || tx >= m.width || ty < 0 || ty >= m.height {
        return cast(float) (ty * TILE_SIZE), true;
    }

    t := m.tiles[tile_index(m, tx, ty)];
    if t == .SOLID {
        return cast(float) (ty * TILE_SIZE), true;
    }
    if tile_is_slope(t) {
        return tile_get_slope_y(t, world_x, tx, ty), true;
    }

    return 0.0, false;
}

ground_query_under_segment :: (m: *Tilemap, x_left: float, x_right: float, bottom_y: float) -> float, bool {
    eps :: 1.0;
    lx := x_left + eps;
    cx := (x_left + x_right) * 0.5;
    rx := x_right - eps;

    found := false;
    max_surface_y := -1000000.0;

    // Left sample.
    y, ok := tile_surface_y_at(m, lx, bottom_y);
    if ok {
        max_surface_y = y;
        found = true;
    }

    // Central sample.
    y, ok = tile_surface_y_at(m, cx, bottom_y);
    if ok {
        max_surface_y = ifx found then max(max_surface_y, y) else y;
        found = true;
    }

    // Right sample.
    y, ok = tile_surface_y_at(m, rx, bottom_y);
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
