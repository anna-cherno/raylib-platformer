
TILE_SIZE : s32 : 16;

Tilemap :: struct {
    width, height: int;
    visible: bool;
    tiles: [..]int;
    tileset: *Tileset;
}

Tileset :: struct {
    width, height: int;
    tile_size: int;
    texture: *Texture2D;
    tiles: [..]Tile;
}

Tile :: struct {
    sprite: int; // index
    collision: Collision_Type;
}

Collision_Type :: enum {
    EMPTY;
    SOLID;
    SLOPE_UP;
    SLOPE_DOWN;
    ONE_WAY_UP;
}

Tile_ID :: u16;

SEED_TILE_ID :: 10;

tilemap_create :: (width: int, height: int, tileset: *Tileset) -> Tilemap {
    tilemap := Tilemap.{
        width = width,
        height = height,
        visible = true,
        tileset = tileset,
    };
    array_resize(*tilemap.tiles, width * height);
    for i: 0..tilemap.tiles.count-1 {
        tilemap.tiles[i] = -1;
    }

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

tile_coords :: inline (index: int, t_width: int) -> int, int {
    return index % t_width, index / t_width;
}

tile_is_solid :: (tm: *Tilemap, pos: Vector2i) -> bool {
    return collision_at(pos.x, pos.y, tm) == .SOLID;
}

tile_is_empty :: (tm: *Tilemap, pos: Vector2i) -> bool {
    return collision_at(pos.x, pos.y, tm) == .EMPTY;
}

tile_is_seed :: (tm: *Tilemap, pos: Vector2i) -> bool {
    idx := tile_index(pos.x, pos.y, tm.width);
    if idx < 0 || idx >= tm.width * tm.height {
        return false;
    }
    return tm.tiles[idx] == SEED_TILE_ID;
}


collision_at :: (tx: int, ty: int, tm: *Tilemap) -> Collision_Type {
    if tx < 0 || tx >= tm.width || ty < 0 || ty >= tm.height {
        return .SOLID; // bounds of tile is solid
    }
    t := tm.tiles[tile_index(tx, ty, tm.width)];
    if t < 0 return .EMPTY;

    return tm.tileset.tiles[t].collision;
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

tilemap_draw :: (m: *Tilemap) {
    for y: 0..m.height-1 {
        for x: 0..m.width-1 {
            idx := tile_index(x, y, m.width);
            t := m.tiles[idx];

            if t < 0 then continue;

            top := cast(float) y * TILE_SIZE;
            bottom := cast(float) (y * TILE_SIZE) + TILE_SIZE;
            left := cast(float) x * TILE_SIZE;
            right := cast(float) (x * TILE_SIZE) + TILE_SIZE;

            tx, ty := tile_coords(t, m.tileset.texture.width / TILE_SIZE);
            src := Rectangle.{ xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
            dst := Rectangle.{left, top, right - left, bottom - top};

            DrawTexturePro(m.tileset.texture, src, dst, .{0, 0}, 0, WHITE);
        }
    }
}

TILESET_VER   :: 1;

save_tileset_data :: (ts: *Tileset, path: string) {
    filename := tprint("%/%.tileset", data_folder, path);
    builder: String_Builder;

    print_to_builder(*builder, "[%]\n", TILESET_VER);
    print_to_builder(*builder, "%\n", ts.tile_size);
    print_to_builder(*builder, "%\n\n", ts.tiles.count);

    for t: ts.tiles {
        print_to_builder(*builder, "% ", cast(s32) t.collision);
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
        ts.tiles[i].sprite = i;
        ts.tiles[i].collision = xx c;
        advance(*line, 2);
    }

}

#scope_file

#import "File";
#import "Text_File_Handler";
