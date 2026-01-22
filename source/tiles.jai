TILE_SIZE : s32 : 16;

Tileset :: struct {
    cols, rows: int;
    tile_size:  int;

    texture: *Texture2D;
    collisions: [..]Collision_Type;

    rules: [..]Tile_Rule;
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

Tile_Rule :: struct {
    input: u8;
    mask: u16;
    output_ids: [..] s32;
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

tile_coords :: inline (index: int, t_width: int) -> int, int {
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

world_to_tile_x :: inline (x: float) -> s32 {
    return xx floor(x / TILE_SIZE);
}

world_to_tile_y :: inline (y: float) -> s32 {
    return xx floor(y / TILE_SIZE);
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
    for y: start.y..end.y-1 {
        for x: start.x..end.x-1 {
            idx := tile_index(x, y, tilemap.width);
            t := tilemap.auto_tiles[idx];

            if t < 0 then continue;

            top    := cast(float) y * TILE_SIZE;
            bottom := cast(float) (y * TILE_SIZE) + TILE_SIZE;
            left   := cast(float) x * TILE_SIZE;
            right  := cast(float) (x * TILE_SIZE) + TILE_SIZE;

            tx, ty := tile_coords(t, tilemap.tileset.texture.width / TILE_SIZE);
            src := Rectangle.{ xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
            dst := Rectangle.{left, top, right - left, bottom - top};

            DrawTexturePro(tilemap.tileset.texture, src, dst, .{0, 0}, 0, WHITE);
        }
    }
}

TILESET_VER :: 1;

save_tileset_data :: (ts: *Tileset, path: string) {
    filename := tprint("%/%.data", data_folder, path);
    builder: String_Builder;

    print_to_builder(*builder, "[%]\n", TILESET_VER);
    print_to_builder(*builder, "%\n", ts.tile_size);
    print_to_builder(*builder, "%\n\n", ts.collisions.count);

    for c: ts.collisions {
        print_to_builder(*builder, "% ", cast(u8) c);
    }

    write_entire_file(filename, *builder);
}

read_tileset_data :: (ts: *Tileset, filename: string) {
    handler: Text_File_Handler;
    defer deinit(*handler);

    filepath := tprint("%/%", data_folder, filename);
    found, short_name := split_from_right(filepath, #char "/");
    if !found {
        print("File % not found", filename);
        return;
    }

    start_file(*handler, short_name, filepath, false);
    if handler.failed return;

    // read tile size.
    line: string;

    line, found = consume_next_line(*handler);
    if !found {
        print("Failed to read tile size");
        return;
    }
    ts.tile_size, found = parse_int(*line);
    if !found {
        print("Failed to parse tile size");
        return;
    }

    // read tiles count
    line, found = consume_next_line(*handler);
    if !found {
        print("Failed to read tiles count");
        return;
    }
    tiles_count: int;
    tiles_count, found = parse_int(*line);
    if !found {
        print("Failed to parse tile size");
        return;
    }

    // array_free(ts.tiles);
    // array_resize(*ts.tiles, tiles_count);

    line, found = consume_next_line(*handler);
    if !found {
        print("Failed to read tile data");
        return;
    }

    for i: 0..tiles_count-2 {
        // c := line[0];
        c := string_to_int(line);
        ts.collisions[i] = xx c;
        // ts.tiles[i].collision = xx c;
        advance(*line, 2);
    }

}

#scope_file

#import "File";
#import "Text_File_Handler";
