Seed :: struct {
    tx, ty: int;
    type: Seed_Type = .BASIC;

    grow_time: float = 1.0; // seconds
    grow_timer: float;
    is_grown: bool = false;

    direction: Vector2;
    next: *Seed;
}

Seed_Type :: enum {
    BASIC;
}

seed_update :: (s: *Seed, w: *World, dt: float) {
    if s.grow_timer >= s.grow_time {
        s.is_grown = true;
    } else {
        s.grow_timer += dt;
    }
}

seed_draw :: (s: *Seed) {
    if s.is_grown {
        DrawRectangle(xx s.tx * TILE_SIZE, xx s.ty * TILE_SIZE, TILE_SIZE, TILE_SIZE, RED);
    } else {
        DrawRectangle(xx s.tx * TILE_SIZE, xx s.ty * TILE_SIZE, TILE_SIZE, TILE_SIZE, Fade(RED, s.grow_timer / s.grow_time));
    }
}
