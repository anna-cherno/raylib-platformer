World :: struct {
    levels: [..]*Level;
    current_level_index: int;
}

Level :: struct {
    name: string;
    bounds: Rectangle;
    cols, rows: s32;

    layers:   [..]Tilemap;
    seeds:    [..]Seed;

    active := true;
}

// Create a new world.
world_create :: () -> *World {
    world := New(World);

    // Create initial level.
    array_add(*world.levels, level_create("level_01", 50, 25));

    return world;
}

// Destroy a world.
world_destroy :: (world: *World) {
    for l: world.levels {
        level_destroy(l);
    }

    free(world);
}

world_update :: (w: *World, dt: float) {
    for l: w.levels {
        if l.active then level_update(l, dt);
    }
}

world_draw :: (w: *World, camera: Camera2D) {
    for l: w.levels {
        if l.active then level_draw(l, camera);
    }
}

level_create :: (name: string, cols: s32, rows: s32) -> *Level {
    level := New(Level);
    level.name = "default";
    level.bounds = {0, 0, xx (cols * TILE_SIZE), xx (rows * TILE_SIZE)};
    level.cols = cols;
    level.rows = rows;

    // Default tile layer.
    ok, tileset := table_find(*g_assets.tilesets, "green_tileset");
    if ok {
        array_add(*level.layers, tilemap_create(level, tileset));
    }

    return level;
}

level_destroy :: (level: *Level) {
    for * level.layers {
        tilemap_destroy(it);
    }
    array_free(level.seeds);
    array_free(level.layers);

    free(level);
}

level_update :: (level: *Level, dt: float) {
    for *s: level.seeds {
        seed_step(s, level, dt);
    }
}

level_draw :: (level: *Level, camera: Camera2D) {
    draw_bounds(level.bounds);

    top_left     := GetScreenToWorld2D(.{0, 0}, camera);
    bottom_right := GetScreenToWorld2D(.{xx window_width, xx window_height}, camera);

    size  := cast(float) TILE_SIZE;
    start := Vector2i.{ xx floor(top_left.x / size), xx floor(top_left.y / size) };
    end   := Vector2i.{ xx floor(bottom_right.x / size), xx floor(bottom_right.y / size) };

    start.x = clamp(start.x, 0, cast(s32) floor(level.bounds.width / size));
    start.y = clamp(start.y, 0, cast(s32) floor(level.bounds.height / size));
    end.x = clamp(end.x, 0, cast(s32) floor(level.bounds.width / size));
    end.y = clamp(end.y, 0, cast(s32) floor(level.bounds.height / size));

    for * level.layers {
        tilemap_draw(it, start, end, level.cols, level.rows);
    }

    for *s: level.seeds {
        seed_draw(s);
    }
}
