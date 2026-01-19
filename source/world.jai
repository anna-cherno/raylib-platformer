World :: struct {
    name:   string;
    bounds: Rectangle;

    tilemaps: [..]Tilemap;
    seeds:    [..]Seed;
}

// Create a new world.
world_create :: (name: string, t_width: int, t_height: int) -> World {
    w := World.{
        name = name,
        bounds = {0, 0, xx (t_width * TILE_SIZE), xx (t_height * TILE_SIZE)},
    };

    // Default tile layer.
    _, tileset := table_find(*g_assets.tilesets, "default");
    array_add(*w.tilemaps, tilemap_create(t_width, t_height, tileset));

    return w;
}

// Destroy a world.
world_destroy :: (w: *World) {
    for *t: w.tilemaps {
        tilemap_destroy(t);
    }

    array_free(w.seeds);
    array_free(w.tilemaps);
}

world_update :: (w: *World, dt: float) {
    seed_update_growth(w, dt);
}

world_draw :: (w: *World) {
    draw_bounds(w.bounds);

    for *t: w.tilemaps {
        tilemap_draw(t);
    }

    for *s: w.seeds {
        if s.state == .GROWING || s.state == .MATURE {
            seed_draw(s);
        }
    }
}

world_valid_growth :: (w: *World, tx: int, ty: int) -> bool {
    return collision_at(tx, ty, *w.tilemaps[0]) == .EMPTY;
}
