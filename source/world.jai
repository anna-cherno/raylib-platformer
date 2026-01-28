World :: struct {
    levels: [..]*Level;
    current_level: int;
}

Level :: struct {
    name: string;
    rect: Rectangle;

    tilemaps: [..]Tilemap;
    seeds:    [..]Seed;

    active := true;
}

// Create a new world.
world_create :: () -> *World {
    world := New(World);

    // Create initial level.
    array_add(*world.levels, level_create("level_01", 50, 25));
    world.current_level = 0;

    return world;
}

// Destroy a world.
world_destroy :: (world: *World) {
    world.current_level = 0;

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

level_create :: (name: string, rows: int, cols: int) -> *Level {
    level := New(Level);
    level.name = "default";
    level.rect = {0, 0, xx (rows * TILE_SIZE), xx (cols * TILE_SIZE)};

    // Default tile layer.
    ok, tileset := table_find(*g_assets.tilesets, "default");
    if ok {
        array_add(*level.tilemaps, tilemap_create(rows, cols, tileset));
    }

    return level;
}

level_destroy :: (level: *Level) {
    array_free(level.seeds);
    array_free(level.tilemaps);

    free(level);
}

level_update :: (level: *Level, dt: float) {
    for *s: level.seeds {
        seed_step(s, level, dt);
    }
}

level_draw :: (level: *Level, camera: Camera2D) {
    draw_bounds(level.rect);

    top_left     := GetScreenToWorld2D(.{0, 0}, camera);
    bottom_right := GetScreenToWorld2D(.{xx window_width, xx window_height}, camera);

    size  := cast(float) TILE_SIZE;
    start := Vector2i.{ xx floor(top_left.x / size), xx floor(top_left.y / size) };
    end   := Vector2i.{ xx floor(bottom_right.x / size), xx floor(bottom_right.y / size) };

    start.x = clamp(start.x, 0, cast(s32) floor(level.rect.width / size));
    start.y = clamp(start.y, 0, cast(s32) floor(level.rect.height / size));
    end.x = clamp(end.x, 0, cast(s32) floor(level.rect.width / size));
    end.y = clamp(end.y, 0, cast(s32) floor(level.rect.height / size));

    for *t: level.tilemaps {
        tilemap_draw(t, start, end);
    }

    for *s: level.seeds {
        seed_draw(s);
    }
}
