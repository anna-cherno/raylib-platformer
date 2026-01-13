World :: struct {
    name:   string;
    bounds: Rectangle;

    t_width, t_height: int;

    collisions: [..]Collision_Type;
    tilemaps:   [..]Tilemap;
    seeds:     [..]Seed;
}

// Create a new world.
world_create :: (name: string, t_width: int, t_height: int) -> World {
    w := World.{
        name = name,
        t_width = t_width,
        t_height = t_height,
        bounds = {0, 0, xx (t_width * TILE_SIZE), xx (t_height * TILE_SIZE)},
    };

    // Collision layer.
    array_resize(*w.collisions, t_width * t_height);

    // Default tile layer.
    array_add(*w.tilemaps, tilemap_create(t_width, t_height));

    return w;
}

// Destroy a world.
world_destroy :: (w: *World) {
    for *t: w.tilemaps {
        tilemap_destroy(t);
    }

    array_free(w.seeds);
    array_free(w.tilemaps);
    array_free(w.collisions);
}

world_update :: (w: *World, dt: float) {
    if g_input.seed {
        world_new_seed(w, g_game.player.position.x, g_game.player.position.y-1);
    }

    for *s: w.seeds {
        seed_update(s, w, dt);
    }
}

world_draw :: (w: *World) {
    draw_bounds(w.bounds);

    for *t: w.tilemaps {
        tilemap_draw(t);
    }

    for *s: w.seeds {
        seed_draw(s);
    }
}

world_new_seed :: (w: *World, x: float, y: float) {
    // tx := world_to_tile_x(x);
    // ty := world_to_tile_y(y);
    // t := tile_index(*w.seeds.tiles, tx, ty);
    // if w.tilemap.tiles[t] == .SOLID {
    //     array_add(*w.seeds, Seed.{tx = tx, ty = ty});
    // }
}
