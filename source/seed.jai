Seed :: struct {
    tx, ty: int;
    type: Seed_Type = .LINEAR_UP;
    state: Seed_State;

    age: float;
    growth_step: float = 0.2;
    total_steps: int;
    max_total_steps := 10;
    max_depth := 10;

    nodes: [..]Growth_Node;
}

Growth_Node :: struct {
    tx, ty: int;
    direction: int;
    depth: int;
    max_depth := 10;

    age: float;
    growth_step: float = 0.2;

    parent_seed: *Seed;
}

Seed_State :: enum {
    NONE;
    SEEDED;
    GROWING;
    MATURE;
    DEAD;
}

Seed_Type :: enum {
    LINEAR_UP;
    BRANCHING_TREE;
    LIVE;
}

seed_create :: (w: *World, pos: Vector2) {
    tx := world_to_tile_x(pos.x);
    ty := world_to_tile_y(pos.y);
    if tx < 0 || tx >= w.t_width || ty < 0 || ty >= w.t_height {
        return;
    }
    idx := tile_index(tx, ty, w.t_width);
    if w.collisions[idx] == .SOLID {
        array_add(*w.seeds, Seed.{tx = tx, ty = ty, state = .GROWING, type = .LIVE});
    }
}

seed_update_growth :: (w: *World, dt: float) {
    for *seed: w.seeds {
        if seed.state != .GROWING then continue;

        seed.age += dt;

        // Init first node.
        if seed.age < seed.growth_step && seed.nodes.count == 0 {
            initial_node := Growth_Node.{
                tx = seed.tx, ty = seed.ty,
                direction = 0,
                growth_step = seed.growth_step,
                parent_seed = seed,
            };
            array_add(*seed.nodes, initial_node);
        }

        // Handle every node.
        for *node, i : seed.nodes {
            if node.age >= 0 {
                process_growth_node(w, node, dt);
            } else {
                array_unordered_remove_by_index(*seed.nodes, i);
            }
        }

        if seed.nodes.count == 0 {
            seed.state = .MATURE;
        }

    }
}

seed_draw :: (s: *Seed) {
    if s.state == {
        case .GROWING;
            DrawRectangle(xx s.tx * TILE_SIZE, xx s.ty * TILE_SIZE, TILE_SIZE, TILE_SIZE, Fade(RED, s.age / s.growth_step));
        case .MATURE;
            DrawRectangle(xx s.tx * TILE_SIZE, xx s.ty * TILE_SIZE, TILE_SIZE, TILE_SIZE, RED);
    }
}

directions : [4]Vector2 : .[
    .{0, -1},
    .{1, 0},
    .{0, 1},
    .{-1, 0},
 ];

 process_growth_node :: (w: *World, node: *Growth_Node, dt: float) {
    node.age += dt;

    if node.age < node.growth_step then return;
    if node.parent_seed.total_steps > node.parent_seed.max_total_steps {
        node.age = -1.0;
        return;
    }
    if node.depth >= node.parent_seed.max_depth {
        node.age = -1.0;
        return;
    }

    node.age -= node.growth_step;

    dx := cast(int) directions[node.direction].x;
    dy := cast(int) directions[node.direction].y;
    nx := node.tx + dx;
    ny := node.ty + dy;

    if world_valid_growth(w, nx, ny) {
        idx := tile_index(nx, ny, w.t_width);
        w.collisions[idx] = .SOLID;
        w.tilemaps[0].tiles[idx] = xx Tile_Type.BRANCH;

        node.tx = nx;
        node.ty = ny;

        node.parent_seed.total_steps += 1;

        if node.depth < node.max_depth && random_get_zero_to_one() <= 0.1 {
            // Left.
            left_node := Growth_Node.{tx = nx, ty = ny, direction = (node.direction + 1) % 4, depth = node.depth + 1, parent_seed = node.parent_seed };
            array_add(*node.parent_seed.nodes, left_node);

            // Right.
            right_node := Growth_Node.{tx = nx, ty = ny, direction = (node.direction + 3) % 4, depth = node.depth + 1, parent_seed = node.parent_seed };
            array_add(*node.parent_seed.nodes, right_node);
        }
    } else {
        node.age = -1.0;
    }
 }

 count_live_neighbors :: (w: *World, tx: int, ty: int) -> int {
     count := 0;

     for i: 0..3 {
         nx := tx + cast(int)directions[i].x;
         ny := ty + cast(int)directions[i].y;
         if world_valid_growth(w, nx, ny) {
             idx := tile_index(nx, ny, w.t_width);
             if w.tilemaps[0].tiles[idx] == xx Tile_Type.BRANCH {
                 count += 1;
             }
         }
     }

     return count;
 }
