TILE_SIZE : s32 : 16;

Tileset :: struct {
    cols, rows: s32;
    tile_size:  s32;

    name: string;
    texture: *Texture2D;
    collisions: [..]Collision_Type;
    rules: [..]Tileset_Rule;
}

Tilemap :: struct {
    tileset: *Tileset;

    collisions:    [..]Collision_Type;
    auto_tiles:    [..]s32;
    // manual_tiles:  [..]u16;

    width, height: int;
    active := true;
}

Tile :: struct {
    sprite: int; // index from tileset
    collision: Collision_Type;
    flipped: bool;
}

Collision_Map :: struct {
    width, height: int;
    data: [..]Collision_Type;
}

Tileset_Flags :: enum_flags u16 {
    TOP_LEFT     :: 0x01;
    TOP          :: 0x02;
    TOP_RIGHT    :: 0x04;
    LEFT         :: 0x08;
    MIDDLE       :: 0x10;
    RIGHT        :: 0x20;
    BOTTOM_LEFT  :: 0x40;
    BOTTOM       :: 0x80;
    BOTTOM_RIGHT :: 0x100;
}

Tileset_Rule :: struct {
    on_mask:  Tileset_Flags;
    off_mask: Tileset_Flags;
    tile_ids: [] s32;
}

Collision_Type :: enum {
    EMPTY;
    SOLID;
    SLOPE_UP;
    SLOPE_DOWN;
    ONE_WAY_UP;
}

tilemap_create :: (rows: int, cols: int, tileset: *Tileset) -> Tilemap {
    tilemap := Tilemap.{ width = rows, height = cols, tileset = tileset };

    size := rows * cols;
    array_resize(*tilemap.auto_tiles, size);
    array_resize(*tilemap.collisions, size);

    for i: 0..tilemap.auto_tiles.count-1 {
        tilemap.auto_tiles[i] = -1;
    }

    return tilemap;
}

tilemap_destroy :: (tilemap: *Tilemap) {
    tilemap.width = 0;
    tilemap.height = 0;
    tilemap.active = false;
    array_free(tilemap.collisions);
    array_free(tilemap.auto_tiles);
}

tile_index :: inline (tx: int, ty: int, t_width: int) -> int {
    return ty * t_width + tx;
}

tile_coords :: inline (index: s32, t_width: s32) -> s32, s32 {
    return index % t_width, index / t_width;
}

tile_is_solid :: (tm: *Tilemap, pos: Vector2i) -> bool {
    return collision_at(pos.x, pos.y, tm) == .SOLID;
}

tile_is_empty :: (tm: *Tilemap, pos: Vector2i) -> bool {
    return collision_at(pos.x, pos.y, tm) == .EMPTY;
}

collision_at :: (tx: int, ty: int, tm: *Tilemap) -> Collision_Type {
    if tx < 0 || tx >= tm.width || ty < 0 || ty >= tm.height {
        return .SOLID; // bounds of tile is solid
    }
    return tm.collisions[tile_index(tx, ty, tm.width)];
    // t := tm.tiles[tile_index(tx, ty, tm.width)];
    // if t < 0 return .EMPTY;

    // return tm.tileset.tiles[t].collision;
}

world_to_tile :: inline (pos: Vector2) -> Vector2i {
    return .{ world_to_tile_x(pos.x), world_to_tile_y(pos.y) };
}

world_to_tile_x :: inline (x: float, tile_size := TILE_SIZE) -> s32 {
    return xx floor(x / tile_size);
}

world_to_tile_y :: inline (y: float, tile_size := TILE_SIZE) -> s32 {
    return xx floor(y / tile_size);
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

collision_ceil_y :: (col: Collision_Type, world_x: float, tx: int, ty: int) -> float {
    return xx ((ty + 1) * TILE_SIZE);
}

tilemap_draw :: (tilemap: *Tilemap, start: Vector2i, end: Vector2i) {
    for y: start.y..end.y {
        for x: start.x..end.x {
            idx := tile_index(x, y, tilemap.width);
            if x < 0 || x >= tilemap.width || y < 0 || y >= tilemap.height then continue;
            t := tilemap.auto_tiles[idx];

            if t < 0 then continue;

            top    := cast(float) (y * TILE_SIZE);
            bottom := cast(float) (y * TILE_SIZE + TILE_SIZE);
            left   := cast(float) (x * TILE_SIZE);
            right  := cast(float) (x * TILE_SIZE + TILE_SIZE);

            tx, ty := tile_coords(t, tilemap.tileset.texture.width / TILE_SIZE);
            src := Rectangle.{ xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
            dst := Rectangle.{left, top, right - left, bottom - top};

            DrawTexturePro(tilemap.tileset.texture, src, dst, .{0, 0}, 0, WHITE);
        }
    }
}

draw_tile :: inline (texture: Texture2D, tile_position: Vector2i, world_position: Vector2, tile_scale := 1.0, tile_size := TILE_SIZE) {
    src := Rectangle.{ xx (tile_position.x * tile_size), xx (tile_position.y * tile_size), xx tile_size, xx tile_size };
    dst := Rectangle.{ world_position.x, world_position.y, tile_size * tile_scale, tile_size * tile_scale };
    DrawTexturePro(texture, src, dst, .{0, 0}, 0, WHITE);
}

tileset_default_rules :: (tileset: *Tileset) {
    // left corner
    array_add(*tileset.rules, .{
        on_mask = .RIGHT | .BOTTOM,
        tile_ids = s32.[0],
    });

    // left wall
    array_add(*tileset.rules, .{
        on_mask = .TOP,
        tile_ids = s32.[20],
    });
    array_add(*tileset.rules, .{
        on_mask = .BOTTOM,
        tile_ids = s32.[20],
    });
    array_add(*tileset.rules, .{
        on_mask = .TOP | .BOTTOM,
        tile_ids = s32.[20],
    });
    array_add(*tileset.rules, .{
        on_mask = .TOP | .TOP_RIGHT | .BOTTOM,
        tile_ids = s32.[20],
    });

    // base rule
    array_add(*tileset.rules, Tileset_Rule.{
        on_mask = 0,
        tile_ids = s32.[1, 2, 3, 4],
    });
}

tilemap_calc_mask :: (tilemap: *Tilemap, x: int, y: int) -> Tileset_Flags {
    mask: Tileset_Flags;
    collision := collision_at(x, y, tilemap);
    if collision == .EMPTY then return 0;

    for dy: -1..1 {
        for dx: -1..1 {
            if dx == 0 && dy == 0 then continue;

            nx := x + dx;
            ny := y + dy;

            if collision_at(nx, ny, tilemap) == collision {
                if dx == -1 && dy == -1 then mask |= .TOP_LEFT;
                if dx ==  0 && dy == -1 then mask |= .TOP;
                if dx ==  1 && dy == -1 then mask |= .TOP_RIGHT;
                if dx == -1 && dy ==  0 then mask |= .LEFT;
                if dx ==  0 && dy ==  0 then mask |= .MIDDLE;
                if dx ==  1 && dy ==  0 then mask |= .RIGHT;
                if dx == -1 && dy ==  1 then mask |= .BOTTOM_LEFT;
                if dx ==  0 && dy ==  1 then mask |= .BOTTOM;
                if dx ==  1 && dy ==  1 then mask |= .BOTTOM_RIGHT;
            }
        }
    }

    return mask;
}

tilemap_update_autotiling :: (tilemap: *Tilemap, x: int, y: int) {
    for dy: -1..1 {
        for dx: -1..1 {
            nx := x + dx;
            ny := y + dy;

            idx := tile_index(nx, ny, tilemap.width);
            if nx < 0 || nx >= tilemap.width || ny < 0 || ny >= tilemap.height {
                continue;
            }
            if collision_at(nx, ny, tilemap) == .EMPTY {
                tilemap.auto_tiles[idx] = -1;
                continue;
            }
            // if tilemap.auto_tiles[idx] != -1 then continue;

            mask := tilemap_calc_mask(tilemap, nx, ny);
            found_tile: s32 = -1;
            for rule: tilemap.tileset.rules {
                if (rule.on_mask & mask) == rule.on_mask && (rule.off_mask & mask) == 0 {
                    if rule.tile_ids.count > 0 {
                        found_tile = get_random_from(rule.tile_ids, nx, ny);
                    }
                    break;
                }
            }

            if tilemap.tileset.rules.count > 0 {
                base_rule := tilemap.tileset.rules[0];
                if found_tile == -1 && base_rule.tile_ids.count > 0 {
                    found_tile = get_random_from(base_rule.tile_ids, nx, ny);
                }
            }

            tilemap.auto_tiles[idx] = found_tile;
        }
    }
}

#scope_file

get_random_from :: inline (arr: []s32, x: int, y: int) -> s32 {
    // random_idx := cast(int) random_get_within_range(0.0, xx (arr.count-1));
    idx := (x * 73856093 ^ y * 19349663) % arr.count;
    return arr[idx];
}

#import "File";
#import "Random";
#import "Text_File_Handler";
