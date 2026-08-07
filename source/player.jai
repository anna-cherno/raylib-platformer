#import "Math";

STEP_HEIGHT    :: 1.0;
MAX_FALL_SPEED :: 600.0;
UPHILL_PENALTY :: 0.7;
DOWNHILL_BOOST :: 1.3;

Player :: struct {
    #as using base: Entity;
    base.type = .PLAYER;

    width, height: float;

    // Movement.
    speed         := 130.0;
    jump_force    := -330.0;
    acceleration  := 1400.0;
    friction      := 1800.0;
    gravity_scale := 1.0;
    slope_dy      := 0.0;

    // State flags.
    prev_state: Player_State;
    state: Player_State = .IDLE;
    is_grounded: bool;
    is_jumping:  bool;
    is_facing_right: bool;
    is_wall_sliding: bool;
    is_hit_ceil: bool;

    // Jump stuff.
    jump_buffer_time := 0.1;
    jump_coyote_time := 0.1;
    jump_buffer_timer: float;
    jump_coyote_timer: float;
    landing_timer: float;

    // Render stuff.
    texture: *Texture2D;

    // Animation.
    anim_idle: Animation;
    anim_run:  Animation;
    anim_jump: Animation;
    anim_fall: Animation;
    anim_land: Animation;
    current_anim: *Animation;

    // Gameplay stuff.
    seeds_max  := 4;
    seeds_left := 4;
}

Player_Action :: struct {
    move: Vector2;
    jump: bool;
    plant: bool;
    plant_dir: Vector2i;
    remove_all_seeds: bool;
    undo_seed: bool;
}

Player_State :: enum {
    IDLE;
    RUN;
    JUMP;
    FALL;
    LAND;
}

player_init :: (using player: *Player, initial_position: Vector2) -> ok: bool, err: string {
    position = initial_position;
    size = .{ 32, 32 };
    is_facing_right = true;
    is_grounded = false;
    width = size.x * 0.34;
    height = size.y;

    // Find player's texture.
    texture = table_find_pointer(*g_assets.textures, "player");
    if texture == null {
        return false, "Unable to find player's texture";
    }

    anim_idle = animation_create(texture, 3, 32, 32, 3, 0.1);
    array_resize(*anim_idle.frame_times, 3);
    anim_idle.frame_times = float.[4.0, 0.1, 0.05];

    anim_run  = animation_create(texture, 4, 32, 32, 8, 0.1);
    anim_jump = animation_create(texture, 2, 32, 32, 3, 0.1, false);
    anim_fall = animation_create(texture, 1, 32, 32, 2, 0.1, false);
    anim_land = animation_create(texture, 0, 32, 32, 2, 0.05, false);
    current_anim = *anim_idle;

    return true, "";
}

player_update :: (player: *Player, level: *Level, dt: float) {
    action := player_collect_action();
    direction := action.move;

    // Coyote timer.
    if player.is_grounded {
        player.jump_coyote_timer = player.jump_coyote_time;
    } else if player.jump_coyote_timer > 0 {
        player.jump_coyote_timer -= dt;
    }

    // Buffer timer.
    if action.jump {
        player.jump_buffer_timer = player.jump_buffer_time;
    } else if player.jump_buffer_timer > 0 {
        player.jump_buffer_timer -= dt;
    }

    // Horizontal speed.
    target_speed := direction.x * player.speed;

    // Slope modifiers.
    if player.slope_dy < 0 then target_speed *= UPHILL_PENALTY;
    else if player.slope_dy > 0 then target_speed *= DOWNHILL_BOOST;

    // Acceleration / friction.
    accel_rate: float;
    if abs(target_speed) > 0.01 {
        is_turning := (target_speed > 0 && player.velocity.x < 0)
            || (target_speed < 0 && player.velocity.x > 0);
        accel_rate = player.acceleration;
        if is_turning then accel_rate *= 2.0;
    } else {
        accel_rate = player.friction;
    }
    player.velocity.x = move_towards(player.velocity.x, target_speed, accel_rate * dt);
    if direction.x != 0 then player.is_facing_right = direction.x > 0;

    // Gravity.
    gravity_force := GRAVITY * player.gravity_scale;
    if player.velocity.y > 0 {
        gravity_force *= 1.0;
    } else if player.velocity.y < 0 && !action.jump {
        gravity_force *= 2.0;
    }
    player.velocity.y += gravity_force * dt;
    player.velocity.y = clamp(player.velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED);

    // Jump.
    can_jump := player.jump_coyote_timer > 0;
    wants_jump := player.jump_buffer_timer > 0;
    if can_jump && wants_jump && !player.is_jumping {
        player.velocity.y = player.jump_force;
        player.is_jumping = true;
        player.is_grounded = true;
        player.jump_buffer_timer = 0;
        player.jump_coyote_timer = 0;
    }

    // Movement.
    pos := player.position;

    // Movement X.
    pos.x += player.velocity.x * dt;
    // Collision X.
    pos = resolve_collisions_x(player, pos, level);
    // player.position = pos;

    // Movement Y.
    was_grounded := player.is_grounded;
    player.is_grounded = false;
    player.slope_dy = 0;
    pos.y += player.velocity.y * dt;
    // Collision Y.
    pos = resolve_collisions_y(player, pos, level, was_grounded);

    player.position = pos;
    player.state = choose_movement_state(player);

    if !player.is_grounded then player.slope_dy = 0;

    just_landed := false;
    // Just landing.
    if just_landed {
        player.landing_timer = 0.2;
    } else if player.landing_timer > 0 {
        player.landing_timer -= dt;
    }

    // Animation.
    next_anim := choose_animation(player);
    if next_anim != player.current_anim {
        player.current_anim = next_anim;
        animation_reset(player.current_anim);
    }
    animation_update(player.current_anim, dt);
}

resolve_collisions_x :: (player: *Player, pos: Vector2, level: *Level) -> Vector2 {
    out_pos := pos;

    half_w := player.width * 0.5;
    top := pos.y - player.height + 1;
    bottom := pos.y - 1;

    min_ty: int = xx floor(top / TILE_SIZE);
    max_ty: int = xx floor(bottom / TILE_SIZE);

    if player.velocity.x > 0 {
        // Moving right — check right edge.
        right_edge := out_pos.x + half_w;
        tx: int = xx floor(right_edge / TILE_SIZE);
        for ty: min_ty..max_ty {
            if collision_at(tx, ty, level) == .SOLID {
                out_pos.x = cast(float)(tx * TILE_SIZE) - half_w;
                player.velocity.x = 0;
                break;
            }
        }
    } else if player.velocity.x < 0 {
        // Moving left — check left edge.
        left_edge := out_pos.x - half_w;
        tx: int = xx floor(left_edge / TILE_SIZE);
        for ty: min_ty..max_ty {
            if collision_at(tx, ty, level) == .SOLID {
                out_pos.x = cast(float)((tx + 1) * TILE_SIZE) + half_w;
                player.velocity.x = 0;
                break;
            }
        }
    }

    return out_pos;
}

resolve_collisions_y :: (player: *Player, pos: Vector2, level: *Level, was_grounded: bool) -> Vector2 {
    out_pos := pos;

    half_w := player.width * 0.5;
    left  := pos.x - half_w;
    right := pos.x + half_w - 1;

    min_tx: int = xx floor(left / TILE_SIZE);
    max_tx: int = xx floor(right / TILE_SIZE);

    player.is_hit_ceil = false;

    if player.velocity.y < 0 {
        // Ceiling check.
        head_y := out_pos.y - player.height;
        ty: int = xx floor(head_y / TILE_SIZE);

        best_ceil_y := -FLOAT32_INFINITY;
        found_ceil := false;

        for tx: min_tx..max_tx {
            col := collision_at(tx, ty, level);
            if col != .EMPTY {
                ceil_y := cast(float)((ty + 1) * TILE_SIZE);
                if ceil_y > best_ceil_y {
                    best_ceil_y = ceil_y;
                    found_ceil = true;
                }
            }
        }

        if found_ceil && (out_pos.y - player.height) < best_ceil_y {
            out_pos.y = best_ceil_y + player.height;
            player.velocity.y = 0;
            player.is_hit_ceil = true;
        }
    } else {
        // Floor check (velocity >= 0, includes standing still).
        feet_y := out_pos.y;
        ty: int = xx floor(feet_y / TILE_SIZE);

        // Also check one tile above to catch slopes we might step onto.
        best_floor_y := FLOAT32_INFINITY;
        found_floor := false;

        for check_ty: ty - 1 .. ty {
            for tx: min_tx..max_tx {
                col := collision_at(tx, check_ty, level);
                if col != .EMPTY {
                    floor_y := collision_floor_y(col, out_pos.x, tx, check_ty);
                    if floor_y <= out_pos.y + STEP_HEIGHT && floor_y < best_floor_y {
                        best_floor_y = floor_y;
                        found_floor = true;
                    }
                }
            }
        }

        if found_floor {
            dy := best_floor_y - out_pos.y;
            out_pos.y = best_floor_y;
            player.velocity.y = 0;
            player.is_grounded = true;
            player.is_jumping = false;
            player.slope_dy = dy;
        }
    }

    return out_pos;
}

// player_update :: (p: *Player, level: *Level, dt: float) {
//     // Input and timers.
//     action := player_collect_action();
//     direction := action.move;
//     if p.is_grounded {
//         p.jump_coyote_timer = p.jump_coyote_time;
//     } else if p.jump_coyote_timer > 0 {
//         p.jump_coyote_timer -= dt;
//     }
//     if IsKeyPressed(.KEY_SPACE) {
//         p.jump_buffer_timer = p.jump_buffer_time;
//     } else if p.jump_buffer_timer > 0 {
//         p.jump_buffer_timer -= dt;
//     }
//     was_grounded := p.is_grounded;
//     p.is_hit_ceil = false;

//     // Apply horizontal movement velocity.
//     target_speed := direction.x * p.speed;
//     if p.slope_dy < 0 {
//         target_speed *= UPHILL_PENALTY;
//     } else if p.slope_dy > 0 {
//         target_speed *= DOWNHILL_BOOST;
//     }
//     accel_rate: float;
//     if abs(target_speed) > 0.01 {
//         is_turning := (target_speed > 0 && p.velocity.x < 0) || (target_speed < 0 && p.velocity.x > 0);
//         accel_rate = ifx is_turning then p.acceleration * 2.0 else p.acceleration;
//     } else {
//         accel_rate = p.friction;
//     }
//     p.velocity.x = move_towards(p.velocity.x, target_speed, accel_rate * dt);
//     if direction.x != 0 {
//         p.is_facing_right = direction.x > 0;
//     }

//     // Gravity.
//     gravity_force := GRAVITY * p.gravity_scale;
//     if p.velocity.y > 0 {
//         gravity_force *= 1.5;
//     } else if p.velocity.y < 0 && !IsKeyDown(.KEY_SPACE) {
//         gravity_force *= 3.0;
//     }
//     p.velocity.y += gravity_force * dt;
//     p.velocity.y = clamp(p.velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED);

//     // Jump.
//     can_jump := p.jump_coyote_timer > 0;
//     wants_jump := p.jump_buffer_timer > 0;
//     if can_jump && wants_jump && !p.is_jumping {
//         p.velocity.y = p.jump_force;
//         p.jump_buffer_timer = 0;
//         p.jump_coyote_timer = 0;
//         p.is_jumping = true;
//         p.is_grounded = false;
//     }

//     // Movement X.
//     prev := p.position;
//     next := p.position;
//     next.x += p.velocity.x * dt;

//     min_y : int = xx floor((prev.y - p.height) / TILE_SIZE);
//     max_y : int = xx floor((next.y - 1) / TILE_SIZE);
//     tx : int = xx floor(next.x / TILE_SIZE);

//     blocked := false;
//     for ty: min_y .. max_y {
//         if collision_at(tx, ty, level) == .SOLID {
//             blocked = true;
//             break;
//         }
//     }
//     if blocked {
//         next.x = prev.x;
//         p.velocity.x = 0;
//     }
//     // p.position = next;

//     // Movement Y.
//     prev_y := p.position.y;
//     next = p.position;
//     // next.y = prev.y;
//     next.y += p.velocity.y * dt;

//     tx = xx floor(next.x / TILE_SIZE);

//     skin :: 1.0;
//     just_landed := false;
//     if p.velocity.y >= 0 {
//         min_y = xx floor((prev.y - STEP_HEIGHT) / TILE_SIZE);
//         max_y = xx floor((next.y + STEP_HEIGHT)  / TILE_SIZE);
//         // Find floor.
//         best_floor_y := FLOAT32_INFINITY;
//         found_floor := false;
//         for ty: min_y .. max_y {
//             col := collision_at(tx, ty, level);
//             if col != .EMPTY {
//                 floor_y := collision_floor_y(col, next.x, tx, ty);
//                 if floor_y < best_floor_y - skin {
//                     best_floor_y = floor_y;
//                     found_floor = true;
//                 }
//             }
//         }
//         dy := best_floor_y - prev_y;
//         if found_floor && dy <= 3.0 {
//             next.y = best_floor_y;
//             p.is_grounded = true;
//             p.is_jumping = false;
//             p.jump_coyote_timer = p.jump_coyote_time;
//             p.slope_dy = dy;
//             just_landed = !was_grounded && p.is_grounded && p.velocity.y >= 400.0;
//             p.velocity.y = 0;
//         } else {
//             p.is_grounded = false;
//         }
//     } else {
//         // Find ceil.
//         min_y = xx floor((prev.y - p.size.y) / TILE_SIZE);
//         max_y = xx floor((next.y - p.size.y) / TILE_SIZE);
//         best_ceil_y := -FLOAT32_INFINITY;
//         found_ceil := false;
//         for ty: min_y .. max_y {
//             col := collision_at(tx, ty, level);
//             if col != .EMPTY {
//                 ceil_y := collision_ceil_y(col, next.x, tx, ty);
//                 if ceil_y > best_ceil_y + skin {
//                     best_ceil_y = ceil_y;
//                     found_ceil = true;
//                 }
//             }
//         }
//         if found_ceil {
//             next.y = best_ceil_y + p.size.y;
//             // p.velocity.y = 0;
//             p.is_hit_ceil = true;
//         }
//     }

//     p.position = next;

//     // Define state.
//     p.state = choose_movement_state(p);

//     // Just landing.
//     if just_landed {
//         p.landing_timer = 0.2;
//     } else if p.landing_timer > 0 {
//         p.landing_timer -= dt;
//     }

//     // Animation.
//     next_anim := choose_animation(p);
//     if next_anim != p.current_anim {
//         p.current_anim = next_anim;
//         animation_reset(p.current_anim);
//     }
//     animation_update(p.current_anim, dt);
// }

player_draw :: (p: *Player) {
    animation_draw(p.current_anim, p.position, !p.is_facing_right);
}

player_close :: (using player: *Player) {
    // array_free(anim_idle.frame_times);
    // array_free(anim_run.frame_times);
    // array_free(anim_jump.frame_times);
    // array_free(anim_fall.frame_times);
    // array_free(anim_land.frame_times);
    current_anim = null;
}

player_collider :: inline (p: *Player) -> Rectangle {
    return .{
        p.position.x - p.width * 0.5,
        p.position.y - p.height,
        p.width,
        p.height,
    };
}

player_collect_action :: () -> Player_Action {
    a: Player_Action;
    if IsKeyDown(.KEY_A) || IsKeyDown(.KEY_LEFT) {
        a.move.x = -1.0;
        a.plant_dir.x = -1;
    } else if IsKeyDown(.KEY_D) || IsKeyDown(.KEY_RIGHT) {
        a.move.x = 1.0;
        a.plant_dir.x = 1;
    }
    if IsKeyDown(.KEY_W) || IsKeyDown(.KEY_UP) {
        a.plant_dir.y = -1;
    } else if IsKeyDown(.KEY_S) || IsKeyDown(.KEY_DOWN) {
        a.plant_dir.y = 1;
    }

    a.jump = IsKeyPressed(.KEY_SPACE);
    a.plant = IsKeyPressed(.KEY_E);
    a.remove_all_seeds = IsKeyPressed(.KEY_R);
    a.undo_seed = IsKeyPressed(.KEY_Z);

    return a;
}

player_at :: (player: *Player, pos: Vector2i) -> bool {
    left := player.position.x - player.width / 2;
    right := player.position.x + player.width / 2;
    top := player.position.y - player.height;
    bottom := player.position.y;

    min_tx := world_to_tile_x(left);
    max_tx := world_to_tile_x(right);
    min_ty := world_to_tile_y(top);
    max_ty := world_to_tile_y(bottom);

    for tx : min_tx..max_tx {
        for ty : min_ty..max_ty {
            tile_pos := Vector2i.{tx, ty};
            if tile_pos == pos {
                return true;
            }
        }
    }

    return false;
}

#scope_file

choose_animation :: (p: *Player) -> *Animation {
    if p.landing_timer > 0 {
        return *p.anim_land;
    }

    if p.state == {
        case .IDLE; return *p.anim_idle;
        case .JUMP; return *p.anim_jump;
        case .FALL; return *p.anim_fall;
        case .RUN;  return *p.anim_run;
        case .LAND; return *p.anim_land;
    }

    return *p.anim_idle;
}

choose_movement_state :: (p: *Player) -> Player_State {
    if !p.is_grounded {
        if p.velocity.y < 0 return .JUMP;
        else if p.velocity.y > 400.0 return .FALL;
        else return .JUMP;
    }

    return ifx abs(p.velocity.x) > 0.1 then .RUN else .IDLE;
}

move_towards :: (current: float, target: float, max_delta: float) -> float {
    if abs(target - current) <= max_delta return target;

    if target > current {
        return current + max_delta;
    } else {
        return current - max_delta;
    }
}
