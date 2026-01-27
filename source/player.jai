#import "Math";
#import "raylib";

STEP_HEIGHT    :: 4.0;
MAX_FALL_SPEED :: 600.0;
UPHILL_PENALTY :: 0.7;
DOWNHILL_BOOST :: 1.3;

Player :: struct {
    #as using base: Entity;
    base.type = .PLAYER;

    width, height: float;

    // Movement.
    speed         := 1.5625*60;
    jump_force    := -6.5625*60;
    jump_release  := -12.5625*60*0.4;
    acceleration  := 0.118164*60*60*1.5;
    friction      := 0.118164*60*60*1.5;
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
    texture: Texture2D;

    // Animation.
    anim_idle: Animation;
    anim_run:  Animation;
    anim_jump: Animation;
    anim_fall: Animation;
    anim_land: Animation;
    current_anim: *Animation;

    // Gameplay stuff.
    seeds_max: int = 3;
    seeds_left: int = 3;
}

Player_Action :: struct {
    move: Vector2;
    jump: bool;
    plant: bool;
    plant_dir: Vector2i;
    remove_all_seeds: bool;
}

Player_State :: enum {
    IDLE;
    RUN;
    JUMP;
    FALL;
    LAND;
}

player_init :: (p: *Player, start_pos: Vector2) {
    p.position = start_pos;
    p.size = .{32, 32};
    p.is_facing_right = true;
    p.is_grounded = false;
    p.width = p.size.x * 0.34;
    p.height = p.size.y;

    ok := false;
    ok, p.texture = table_find(*g_assets.textures, "player");
    if !ok {
        log_error("Failed to find player texture");
        return;
    }

    p.anim_idle = animation_create(*p.texture, 3, 32, 32, 3, 0.1);
    array_resize(*p.anim_idle.frame_times, 3);
    p.anim_idle.frame_times = float.[4.0, 0.1, 0.05];

    p.anim_run  = animation_create(*p.texture, 4, 32, 32, 8, 0.1);
    p.anim_jump = animation_create(*p.texture, 2, 32, 32, 3, 0.1, false);
    p.anim_fall = animation_create(*p.texture, 1, 32, 32, 2, 0.1, false);
    p.anim_land = animation_create(*p.texture, 0, 32, 32, 2, 0.05, false);
    p.current_anim = *p.anim_idle;
}

player_update :: (p: *Player, level: *Level, dt: float) {
    // Input and timers.
    action := player_collect_action();
    direction := action.move;
    if p.is_grounded {
        p.jump_coyote_timer = p.jump_coyote_time;
    } else if p.jump_coyote_timer > 0 {
        p.jump_coyote_timer -= dt;
    }
    if IsKeyPressed(.KEY_SPACE) {
        p.jump_buffer_timer = p.jump_buffer_time;
    } else if p.jump_buffer_timer > 0 {
        p.jump_buffer_timer -= dt;
    }
    was_grounded := p.is_grounded;
    p.is_hit_ceil = false;

    // Apply horizontal movement velocity.
    target_speed := direction.x * p.speed;
    if p.slope_dy < 0 {
        target_speed *= UPHILL_PENALTY;
    } else if p.slope_dy > 0 {
        target_speed *= DOWNHILL_BOOST;
    }
    accel_rate: float;
    if abs(target_speed) > 0.01 {
        is_turning := (target_speed > 0 && p.velocity.x < 0) || (target_speed < 0 && p.velocity.x > 0);
        accel_rate = ifx is_turning then p.acceleration * 2.0 else p.acceleration;
    } else {
        accel_rate = p.friction;
    }
    p.velocity.x = move_towards(p.velocity.x, target_speed, accel_rate * dt);
    if direction.x != 0 {
        p.is_facing_right = direction.x > 0;
    }

    // Gravity.
    gravity_force := GRAVITY * p.gravity_scale;
    if p.velocity.y > 0 {
        gravity_force *= 1.5;
    } else if p.velocity.y < 0 && !IsKeyDown(.KEY_SPACE) {
        gravity_force *= 3.0;
    }
    p.velocity.y += gravity_force * dt;
    p.velocity.y = clamp(p.velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED);

    // Jump.
    can_jump := p.jump_coyote_timer > 0;
    wants_jump := p.jump_buffer_timer > 0;
    if can_jump && wants_jump && !p.is_jumping {
        p.velocity.y = p.jump_force;
        p.jump_buffer_timer = 0;
        p.jump_coyote_timer = 0;
        p.is_jumping = true;
        p.is_grounded = false;
    }

    // Movement X.
    prev := p.position;
    next := p.position;
    next.x += p.velocity.x * dt;

    min_y : int = xx floor((prev.y - p.height) / TILE_SIZE);
    max_y : int = xx floor((next.y - 1) / TILE_SIZE);
    tx : int = xx floor(next.x / TILE_SIZE);

    blocked := false;
    for ty: min_y .. max_y {
        if collision_at(tx, ty, *level.tilemaps[0]) == .SOLID {
            blocked = true;
            break;
        }
    }
    if blocked {
        next.x = prev.x;
        p.velocity.x = 0;
    }
    p.position = next;

    // Movement Y.
    prev_y := p.position.y;
    prev = p.position;
    next = p.position;
    next.y += p.velocity.y * dt;


    tx = xx floor(next.x / TILE_SIZE);

    skin :: 1.0;
    just_landed := false;
    if p.velocity.y >= 0 {
        min_y = xx floor((prev.y - STEP_HEIGHT) / TILE_SIZE);
        max_y = xx floor((next.y + STEP_HEIGHT)  / TILE_SIZE);
        // Find floor.
        best_floor_y := FLOAT32_INFINITY;
        found_floor := false;
        for ty: min_y .. max_y {
            col := collision_at(tx, ty, *level.tilemaps[0]);
            if col != .EMPTY {
                floor_y := collision_floor_y(col, next.x, tx, ty);
                if floor_y < best_floor_y - skin {
                    best_floor_y = floor_y;
                    found_floor = true;
                }
            }
        }
        dy := best_floor_y - prev_y;
        if found_floor && dy <= 3.0 {
            next.y = best_floor_y;
            p.is_grounded = true;
            p.is_jumping = false;
            p.jump_coyote_timer = p.jump_coyote_time;
            p.slope_dy = dy;
            just_landed = !was_grounded && p.is_grounded && p.velocity.y >= 400.0;
            p.velocity.y = 0;
        } else {
            p.is_grounded = false;
        }
    } else {
        // Find ceil.
        min_y = xx floor((prev.y - p.size.y) / TILE_SIZE);
        max_y = xx floor((next.y - p.size.y) / TILE_SIZE);
        best_ceil_y := -FLOAT32_INFINITY;
        found_ceil := false;
        for ty: min_y .. max_y {
            col := collision_at(tx, ty, *level.tilemaps[0]);
            if col != .EMPTY {
                ceil_y := collision_ceil_y(col, next.x, tx, ty);
                if ceil_y > best_ceil_y + skin {
                    best_ceil_y = ceil_y;
                    found_ceil = true;
                }
            }
        }
        if found_ceil {
            next.y = best_ceil_y + p.size.y;
            p.velocity.y = 0;
            p.is_hit_ceil = true;
        }
    }

    p.position = next;

    // Define state.
    p.state = choose_movement_state(p);

    // Just landing.
    if just_landed {
        p.landing_timer = 0.2;
    } else if p.landing_timer > 0 {
        p.landing_timer -= dt;
    }

    // Animation.
    next_anim := choose_animation(p);
    if next_anim != p.current_anim {
        p.current_anim = next_anim;
        animation_reset(p.current_anim);
    }
    animation_update(p.current_anim, dt);
}

player_draw :: (p: *Player) {
    p.current_anim.target_width = xx p.size.x;
    p.current_anim.target_height = xx p.size.y;
    animation_draw(p.current_anim, p.position, !p.is_facing_right);
}

player_unload :: (p: *Player) {
    UnloadTexture(p.texture);
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

    a.plant = IsKeyPressed(.KEY_E);
    a.remove_all_seeds = IsKeyPressed(.KEY_R);

    return a;
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
