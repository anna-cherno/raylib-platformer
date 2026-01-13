TILE_SIZE : s32 : 16;

Tilemap :: struct {
    width, height: int;
    tiles: [..]Tile_Type;
    visible: bool;
}

Collision_Type :: enum {
    EMPTY;
    SOLID;
    SLOPE_UP;
    SLOPE_DOWN;
    ONE_WAY_UP;
}

Tile_Type :: enum {
    EMPTY;
    SOLID;
    SLOPE_UP;
    SLOPE_DOWN;
}

tilemap_create :: (width: int, height: int) -> Tilemap {
    tilemap := Tilemap.{width = width, height = height, visible = true};
    array_resize(*tilemap.tiles, width * height);
    return tilemap;
}

tilemap_destroy :: (tilemap: *Tilemap) {
    tilemap.width = 0;
    tilemap.height = 0;
    tilemap.visible = false;
    array_free(tilemap.tiles);
}

tile_index :: inline (tx: int, ty: int, t_width: int) -> int {
    return ty * t_width + tx;
}

collision_at :: (tx: int, ty: int, w: *World) -> Collision_Type {
    if tx < 0 || tx >= w.t_width || ty < 0 || ty >= w.t_height {
        return .SOLID; // bounds of tile is solid
    }
    return w.collisions[tile_index(tx, ty, w.t_width)];
}

world_to_tile_x :: inline (x: float) -> int {
    return cast(int) floor(x / TILE_SIZE);
}

world_to_tile_y :: inline (y: float) -> int {
    return cast(int) floor(y / TILE_SIZE);
}

collision_floor_y :: (col: Collision_Type, world_x: float, tx: int, ty: int) -> float {
    // Relative position of X inside the tile.
    local_x := (world_x - cast(float) (tx * TILE_SIZE)) / cast(float) TILE_SIZE;
    local_x = clamp(local_x, 0.0, 1.0);

    col_bottom_y := cast(float) ((ty + 1) * TILE_SIZE);
    col_top_y := cast(float) (ty * TILE_SIZE);

    result: float;
    if col == {
        case .SLOPE_UP;
            result = col_bottom_y - local_x * TILE_SIZE;
        case .SLOPE_DOWN;
            result = col_top_y + local_x * TILE_SIZE;
        case .SOLID;
            result = col_top_y;
        case;
            result = col_top_y + TILE_SIZE; // empty
    }

    return result;
}

tilemap_draw :: (m: *Tilemap) {
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            idx := tile_index(x, y, m.width);
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

// tile_slope_tangent :: (t: Tile_Type) -> Vector2 {
//     if t == {
//         case .SLOPE_UP;
//             return normalize(Vector2.{ -1.0, 1.0 });
//         case .SLOPE_DOWN;
//             return normalize(Vector2.{ 1.0, 1.0 });
//         case;
//             return Vector2.{ 1.0, 0.0 };
//     }
// }

// tile_slope_normal :: (tile: Tile_Type) -> Vector2 {
//     if tile == .SLOPE_UP {
//         return Vector2.{ -1.0, -1.0 };
//     } else if tile == .SLOPE_DOWN {
//         return Vector2.{ 1.0, -1.0 };
//     } else {
//         return Vector2.{ 0.0, -1.0 };
//     }
// }

// tile_slope_y_at :: (t: Tile_Type, x: float, tx: int, ty: int) -> float {
//     local_x := x - cast(float) (tx * TILE_SIZE);

//     if t == .SLOPE_UP {
//         return xx ((ty + 1) * TILE_SIZE) - local_x;
//     } else if t == .SLOPE_DOWN {
//         return xx (ty * TILE_SIZE) + local_x;
//     } else if  t == .SOLID {
//         return xx (ty * TILE_SIZE);
//     }

//     return xx ((ty + 1) * TILE_SIZE);
// }
