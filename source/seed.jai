SEED_MAX_ENERGY :: 3;

Seed :: struct {
    head_pos: Vector2i;
    head_dir: Vector2i;

    orig_pos: Vector2i;
    orig_dir: Vector2i;

    prefer_x: bool;
    energy: int;
    max_energy: int = SEED_MAX_ENERGY;

    grow_timer: float;
    grow_time: float = 0.2;

    nodes: [..]Vector2i;
    is_connected: bool;
    active: bool;
}

seed_plant :: (level: *Level, pos: Vector2i, dir: Vector2i) -> Seed, bool {
    if collision_at(pos.x, pos.y, level) != .SOLID then return .{}, false;
    if has_any_seed_at(level, pos) then return .{}, false;
    // other, found := seed_at_any_node(level, pos, null);
    // if found then return .{}, false;

    seed := Seed.{
        head_pos = pos,
        head_dir = dir,
        orig_pos = pos,
        orig_dir = dir,
        max_energy = SEED_MAX_ENERGY,
        active = true,
    };

    other, found := seed_at_any_node(level, pos, null);
    if found {
        other.head_dir += dir;
        if abs(dir.x) > abs(dir.y) {
            other.prefer_x = true;
        } else {
            other.prefer_x = false;
        }

        other.max_energy += seed.max_energy - seed.energy;
        seed.head_pos = other.head_pos;
        seed.active = false;
        other.active = true;
        other.is_connected = false;
        return .{}, true;
    }

    return seed, true;
}

seed_step :: (seed: *Seed, level: *Level, dt: float) {
    if !seed.active then return;
    if seed.energy >= seed.max_energy {
        // seed.head_dir = .{0, 0};
        seed.active = false;
        return;
    }

    seed.grow_timer += dt;
    if seed.grow_timer < seed.grow_time then return;
    seed.grow_timer = 0;

    next_dir := normalize_to_axis(seed);
    next_pos := seed.head_pos + next_dir;

    other, found := seed_at_any_node(level, next_pos, seed);
    if found {
        other.head_dir += next_dir;
        if abs(next_dir.x) > abs(next_dir.y) {
            other.prefer_x = true;
        } else {
            other.prefer_x = false;
        }

        other.max_energy += seed.max_energy - seed.energy;
        seed.max_energy = 0;
        seed.energy = 0;
        seed.head_pos = other.head_pos;
        seed.active = false;
        seed.is_connected = true;
        other.active = true;
        return;
    }

    if !collision_at(next_pos.x, next_pos.y, level) && !player_at(level.player, next_pos) {
        array_add(*seed.nodes, next_pos);
        seed.head_pos = next_pos;
        seed.energy += 1;
        seed_place_tile(level, seed.head_pos);
    } else {
        // seed.active = false;
    }
}

has_any_seed_at :: (level: *Level, pos: Vector2i) -> bool {
    for *seed: level.seeds {
        if seed.orig_pos == pos {
            return true;
        }
    }

    return false;
}

seed_at_any_node :: (level: *Level, pos: Vector2i, ignore: *Seed) -> *Seed, bool {
    for *seed: level.seeds {
        if seed == ignore then continue;

        if seed.head_pos == pos then return seed, true;
        for node_pos: seed.nodes {
            if node_pos == pos then return seed, true;
        }
    }

    return null, false;
}

seed_place_tile :: (level: *Level, pos: Vector2i) {
    if pos.x < 0 || pos.x >= level.cols || pos.y < 0 || pos.y >= level.rows {
        return;
    }
    index := tile_index(pos.x, pos.y, level.cols);
    level.layers[0].data[index].collision = .SOLID;
    level.layers[0].data[index].id = 10;
    level.layers[0].data[index].flags |= .MANUAL | .SEED;
}

seed_draw :: (s: *Seed) {
    pos := Vector2.{xx (s.orig_pos.x * TILE_SIZE + TILE_SIZE / 4.0), xx (s.orig_pos.y * TILE_SIZE) };
    DrawText(tprint("%\0", s.max_energy - s.energy).data, xx pos.x, xx pos.y, 16, ORANGE);
    draw_arrow(s.head_dir, .{xx (s.orig_pos.x * TILE_SIZE + 8), xx (s.orig_pos.y * TILE_SIZE + 8) });
    if !s.is_connected {
        DrawRectangle(s.head_pos.x * TILE_SIZE, s.head_pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, Fade(ORANGE, 0.4));
    }

    for node_pos: s.nodes {
        DrawRectangleV(.{ xx (node_pos.x * TILE_SIZE + TILE_SIZE / 4.0), xx (node_pos.y * TILE_SIZE + TILE_SIZE / 4.0) }, .{ xx TILE_SIZE / 2.0, xx TILE_SIZE / 2.0 }, LIME);
    }
}

#scope_file

normalize_to_axis :: (s: *Seed) -> Vector2i {
    d := s.head_dir;
    if abs(d.x) + abs(d.y) == 1 {
        return d;
    }

    step: Vector2i;
    if s.prefer_x {
        step = Vector2i.{ sign(d.x), 0 };
    } else {
        step = Vector2i.{ 0, sign(d.y) };
    }

    s.prefer_x = !s.prefer_x;
    return step;
}
