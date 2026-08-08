TILE_SIZE : s32 : 16;
EMPTY_TILE :: 0xFFFF;

Tileset :: struct {
    cols, rows: s32;
    tile_size:  s32;

    name: string;
    texture: *Texture2D;
    collisions: [..]Collision_Type;
    rules: [..]Tileset_Rule;
}

Tilemap :: struct {
    name: string;
    tileset: *Tileset;

    // rows, cols: int;
    data: []Tile;
    has_collisions: bool;

    z_index: int;
    active  := true;
    visible := true;
}

Tile :: struct {
    id: s16 = EMPTY_TILE; // Empty tile.
    collision: Collision_Type;
    flags: Tile_Flags;
}

Tile_Flags :: enum_flags u8 {
    FLIPPED_X :: 0x01;
    FLIPPED_Y :: 0x02;
    MANUAL    :: 0x04;
    SEED      :: 0x08;
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
    mirror_x: bool;
    mirror_y: bool;
    active := true;
    tile_ids: []s16;
}

Collision_Type :: enum u8 {
    EMPTY;
    SOLID;
    SLOPE_UP;
    SLOPE_DOWN;
    ONE_WAY_UP;
}

create_tilemap :: (level: *Level, initial_tileset: *Tileset, has_collisions := true) -> Tilemap {
    tilemap := Tilemap.{ tileset = initial_tileset, has_collisions = has_collisions };
    tilemap.name = sprint("Layer %", level.layers.count + 1);
    tilemap.data = NewArray(level.rows * level.cols, Tile);

    return tilemap;
}

destroy_tilemap :: (tilemap: *Tilemap) {
    free(tilemap.name);
    array_free(tilemap.data);
    tilemap.active = false;
}

tile_index :: inline (tx: int, ty: int, t_width: int) -> int {
    return ty * t_width + tx;
}

tile_coords :: inline (index: s32, t_width: s32) -> s32, s32 {
    return index % t_width, index / t_width;
}

collision_at :: (tx: int, ty: int, level: *Level) -> Collision_Type {
    if tx < 0 || tx >= level.cols || ty < 0 || ty >= level.rows {
        return .SOLID; // bounds of level is solid.
    }

    for < level.layers {
        if !it.active || !it.has_collisions then continue;

        tile := it.data[tile_index(tx, ty, level.cols)];
        if tile.collision != .EMPTY then
            return tile.collision;
    }

    return .EMPTY;
}

tilemap_collision_at :: (tilemap: *Tilemap, tx: s32, ty: s32, cols: s32, rows: s32) -> Collision_Type {
    if !tilemap.active then return .EMPTY;
    if tx < 0 || tx >= cols || ty < 0 || ty >= rows then return .SOLID;

    return tilemap.data[tile_index(tx, ty, cols)].collision;
}

world_to_tile :: inline (pos: Vector2, tile_size := TILE_SIZE) -> Vector2i {
    return .{ world_to_tile_x(pos.x, tile_size), world_to_tile_y(pos.y, tile_size) };
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

tilemap_draw :: (tilemap: *Tilemap, start: Vector2i, end: Vector2i, cols: s32, rows: s32) {
    for y: start.y..end.y {
        for x: start.x..end.x {
            if x < 0 || x >= cols || y < 0 || y >= rows then continue;

            tile := tilemap.data[tile_index(x, y, cols)];
            if tile.id == EMPTY_TILE then continue;

            top    := cast(float) (y * TILE_SIZE);
            bottom := cast(float) (y * TILE_SIZE + TILE_SIZE);
            left   := cast(float) (x * TILE_SIZE);
            right  := cast(float) (x * TILE_SIZE + TILE_SIZE);

            tx, ty := tile_coords(tile.id, tilemap.tileset.texture.width / tilemap.tileset.tile_size);
            src := Rectangle.{ xx (tx * tilemap.tileset.tile_size), xx (ty * tilemap.tileset.tile_size), xx tilemap.tileset.tile_size, xx tilemap.tileset.tile_size };
            if tile.flags & .FLIPPED_X then src.width = -src.width;
            if tile.flags & .FLIPPED_Y then src.height = -src.height;
            dst := Rectangle.{left, top, right - left, bottom - top};

            DrawTexturePro(tilemap.tileset.texture, src, dst, .{0, 0}, 0, WHITE);
        }
    }
}

draw_tile :: inline (texture: Texture2D, tile_position: Vector2i, world_position: Vector2, tile_scale := 1.0, tile_size := TILE_SIZE) {
    src := Rectangle.{ xx (tile_position.x * tile_size), xx (tile_position.y * tile_size), xx tile_size, xx tile_size };
    dst := Rectangle.{ world_position.x, world_position.y, TILE_SIZE * tile_scale, TILE_SIZE * tile_scale };
    DrawTexturePro(texture, src, dst, .{0, 0}, 0, WHITE);
}

tilemap_calc_mask :: (tilemap: *Tilemap, x: s32, y: s32, cols: s32, rows: s32) -> Tileset_Flags {
    mask: Tileset_Flags;
    collision := tilemap_collision_at(tilemap, x, y, cols, rows);
    if collision == .EMPTY then return 0;

    for dy: -1..1 {
        for dx: -1..1 {
            if dx == 0 && dy == 0 then continue;

            nx := cast(s32) (x + dx);
            ny := cast(s32) (y + dy);

            if tilemap_collision_at(tilemap, nx, ny, cols, rows) == collision {
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

tilemap_update_autotiling :: (tilemap: *Tilemap, x: int, y: int, cols: s32, rows: s32) {
    for dy: -1..1 {
        for dx: -1..1 {
            nx := cast(s32) (x + dx);
            ny := cast(s32) (y + dy);

            index := tile_index(nx, ny, cols);
            if nx < 0 || nx >= cols || ny < 0 || ny >= rows then continue;
            if tilemap.data[index].flags & Tile_Flags.MANUAL then continue;
            if tilemap_collision_at(tilemap, nx, ny, cols, rows) == .EMPTY {
                tilemap.data[index].id = EMPTY_TILE;
                tilemap.data[index].flags = 0;
                continue;
            }

            tilemap.data[index].flags = 0;

            mask := tilemap_calc_mask(tilemap, nx, ny, cols, rows);
            found_tile: s16 = EMPTY_TILE;
            mirror_x := false;
            mirror_y := false;
            for rule: tilemap.tileset.rules {
                if !rule.active continue;

                if (rule.on_mask & mask) == rule.on_mask && (rule.off_mask & mask) == 0 {
                    if rule.tile_ids.count > 0 then found_tile = get_random_from(rule.tile_ids, nx, ny);
                    break;
                }

                if rule.mirror_x || rule.mirror_y {
                    on_mask := mirror_mask(rule.on_mask, rule.mirror_x, rule.mirror_y);
                    off_mask := mirror_mask(rule.off_mask, rule.mirror_x, rule.mirror_y);

                    if (on_mask & mask) == on_mask && (off_mask & mask) == 0 {
                        if rule.tile_ids.count > 0 {
                            found_tile = get_random_from(rule.tile_ids, nx, ny);
                            if rule.mirror_x then tilemap.data[index].flags |= .FLIPPED_X;
                            if rule.mirror_y then tilemap.data[index].flags |= .FLIPPED_Y;
                        }
                        break;
                    }
                }
            }

            if tilemap.tileset.rules.count > 0 {
                base_rule := tilemap.tileset.rules[tilemap.tileset.rules.count-1];
                if found_tile == -1 && base_rule.tile_ids.count > 0 {
                    found_tile = get_random_from(base_rule.tile_ids, nx, ny);
                }
            }

            tilemap.data[index].id = found_tile;
        }
    }
}

#scope_file

get_random_from :: inline (arr: []s16, x: int, y: int) -> s16 {
    // random_idx := cast(int) random_get_within_range(0.0, xx (arr.count-1));
    index := (x * 73856093 ^ y * 19349663) % arr.count;
    return arr[index];
}

mirror_mask :: (mask: Tileset_Flags, abscissa: bool, ordinate: bool) -> Tileset_Flags {
    out_mask: Tileset_Flags = 0;
    if abscissa {
        if mask & .TOP_LEFT     then out_mask |= .TOP_RIGHT;
        if mask & .LEFT         then out_mask |= .RIGHT;
        if mask & .BOTTOM_LEFT  then out_mask |= .BOTTOM_RIGHT;
        if mask & .TOP_RIGHT    then out_mask |= .TOP_LEFT;
        if mask & .RIGHT        then out_mask |= .LEFT;
        if mask & .BOTTOM_RIGHT then out_mask |= .BOTTOM_LEFT;
        if mask & .TOP          then out_mask |= .TOP;
        if mask & .BOTTOM       then out_mask |= .BOTTOM;
    }
    if ordinate {
        if mask & .TOP_LEFT     then out_mask |= .BOTTOM_LEFT;
        if mask & .TOP          then out_mask |= .BOTTOM;
        if mask & .TOP_RIGHT    then out_mask |= .BOTTOM_RIGHT;
        if mask & .BOTTOM_LEFT  then out_mask |= .TOP_LEFT;
        if mask & .BOTTOM       then out_mask |= .TOP;
        if mask & .BOTTOM_RIGHT then out_mask |= .TOP_RIGHT;
        if mask & .LEFT         then out_mask |= .LEFT;
        if mask & .RIGHT        then out_mask |= .RIGHT;
    }

    return out_mask;
}

#import "File";
#import "Random";
#import "Text_File_Handler";
