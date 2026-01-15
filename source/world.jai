World :: struct {
    name:   string;
    bounds: Rectangle;

    t_width, t_height: int;

    collisions: [..]Collision_Type;
    tilemaps:   [..]Tilemap;
    seeds:      [..]Seed;
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
    // Default floor.
    for x: 0 .. t_width-1 {
        w.collisions[tile_index(x, t_height-1, t_width)] = .SOLID;
    }

    // Default tile layer.
    array_add(*w.tilemaps, tilemap_create(t_width, t_height));
    // Load tileset assets.
    w.tilemaps[0].tileset = load_texture("tileset.png");

    // Default floor.
    for x: 0 .. t_width-1 {
        w.tilemaps[0].tiles[tile_index(x, t_height-1, t_width)] = xx Tile_Type.GROUND;
    }


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
    return collision_at(tx, ty, w) == .EMPTY;
}
