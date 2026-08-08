World :: struct {
    levels: [..]Level;
    current_level_index: int;
}

Level :: struct {
    name: string;
    bounds: Rectangle;
    cols, rows: s32;

    layers:   [..]Tilemap;
    seeds:    [..]Seed;
    fruit:    Vector2i;

    seed_snapshot: Seed_Snapshot;

    active := true;
}

init_world :: () -> bool {
    // Тайлсет по умолчанию.
    default_tileset := table_find_pointer(*assets.tilesets, "green_tileset");
    if default_tileset == null {
        log_error("Не удалось найти %s тайлсет при инициализации мира", "green_tileset");
        return false;
    }
    
    // Уровень по умолчанию.
    array_add(*game.world.levels, create_level("level_01", 50, 25, default_tileset));

    return true;
}

deinit_world :: () -> bool {
    for *game.world.levels {
        destroy_level(it);
    }
    game.world.current_level_index = 0;

    return true;
}

update_world :: (dt: float) {
    cur_level := current_level();
    if cur_level != null {
        update_level(cur_level, dt);
    }
}

draw_world :: () {
    cur_level := current_level();
    if cur_level != null {
        draw_level(cur_level);
    }

    draw_player();
}

create_level :: (name: string, cols: s32, rows: s32, tileset: *Tileset) -> Level {
    level := Level.{
        name = name,
        bounds = {0, 0, xx (cols * TILE_SIZE), xx (rows * TILE_SIZE)},
        cols = cols,
        rows = rows,
    };

    array_add(*level.layers, create_tilemap(*level, tileset));

    return level;
}

destroy_level :: (level: *Level) {
    for *level.layers {
        destroy_tilemap(it);
    }
    array_free(level.seed_snapshot.seeds);
    array_free(level.seed_snapshot.tiles);
    array_free(level.seeds);
    array_free(level.layers);
    level.active = false;
}

update_level :: (level: *Level, dt: float) {
    for *level.seeds {
        seed_step(it, level, dt);
    }
}

draw_level :: (level: *Level) {
    draw_bounds(level.bounds);

    camera := active_camera();
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

    DrawCircleV(.{ xx (level.fruit.x * TILE_SIZE + TILE_SIZE * 0.5), xx (level.fruit.y * TILE_SIZE + TILE_SIZE * 0.5) }, 4.0, RED);
}

current_level :: inline () -> *Level {
    return *game.world.levels[game.world.current_level_index];
}