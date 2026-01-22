Seed :: struct {
    head_pos: Vector2i;
    head_dir: Vector2i;

    orig_pos: Vector2i;
    orig_dir: Vector2i;

    prefer_x: bool;
    energy: int;
    max_energy: int = 3;

    grow_timer: float;
    grow_time: float = 0.2;

    nodes: [..]Vector2i;
    active: bool;
}

seed_plant :: (level: *Level, pos: Vector2i, dir: Vector2i) -> Seed, bool {
    if !tile_is_solid(*level.tilemaps[0], pos) then return .{}, false;
    if has_any_seed_at(level, pos) then return .{}, false;

    seed := Seed.{
        head_pos = pos,
        head_dir = dir,
        orig_pos = pos,
        orig_dir = dir,
        max_energy = 3,
        active = true,
    };
    return seed, true;
}

seed_step :: (seed: *Seed, level: *Level, dt: float) {
    if !seed.active then return;
    if seed.energy >= seed.max_energy {
        seed.head_dir = .{0, 0};
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
        seed.head_pos = other.head_pos;
        seed.active = false;
        other.active = true;
        return;
    }

    if tile_is_empty(*level.tilemaps[0], next_pos) {
        array_add(*seed.nodes, next_pos);
        seed.head_pos = next_pos;
        seed.energy += 1;
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
    if pos.x < 0 || pos.x >= level.tilemaps[0].width || pos.y < 0 || pos.y >= level.tilemaps[0].height {
        return;
    }
    idx := tile_index(pos.x, pos.y, level.tilemaps[0].width);
    level.tilemaps[0].collisions[idx] = .SOLID;
}

seed_draw :: (s: *Seed) {
    DrawCircleV(.{ xx (s.orig_pos.x * TILE_SIZE + TILE_SIZE / 2.0), xx (s.orig_pos.y * TILE_SIZE + TILE_SIZE / 2.0) }, 2.0, RED);

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
