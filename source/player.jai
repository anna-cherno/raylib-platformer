#import "Math";
#import "raylib";

STEP_HEIGHT :: 4.0;
MAX_FALL_SPEED :: 600.0;

Player :: struct {
    #as using base: Entity;
    base.type = .PLAYER;

    width, height: float;

    // Movement.
    speed        := 1.5625*60;
    jump_force   := -6.5625*60;
    jump_release := -12.5625*60*0.4;
    acceleration := 0.118164*60*60*1.5;
    friction     := 0.118164*60*60*1.5;
    gravity_scale:= 1.0;
    slope_dy     := 0.0;

    // State flags.
    prev_state: Player_State;
    state: Player_State = .IDLE;
    is_grounded: bool;
    is_jumping:  bool;
    is_facing_right: bool;
    is_wall_sliding: bool;
    is_hit_ceil: bool;

    // Jump stuff.
    jump_buffer_time := 0.2;
    jump_coyote_time := 0.5;
    jump_buffer_timer: float;
    jump_coyote_timer: float;
    landing_timer: float;

    // Render stuff.
    texture: Texture2D;

    // Collision.
    collider: Rectangle;

    // Animation.
    anim_idle: Animation;
    anim_run:  Animation;
    anim_jump: Animation;
    anim_fall: Animation;
    anim_land: Animation;
    current_anim: *Animation;

    // Debug.
    debug_tile_slope: Vector2;
}

Player_State :: enum {
    IDLE;
    RUN;
    JUMP;
    FALL;
    LAND;
}

UPHILL_PENALTY :: 0.8;
DOWNHILL_BOOST :: 1.2;

player_init :: (p: *Player, start_pos: Vector2) {
    p.position = start_pos;
    p.size = .{32, 32};
    p.is_facing_right = true;
    p.is_grounded = false;
    p.width = p.size.x * 0.34;
    p.height = p.size.y;

    p.texture = load_texture("player_sprite.png");

    p.anim_idle = animation_create(*p.texture, 3, 32, 32, 3, 0.2);
    array_resize(*p.anim_idle.frame_times, 3);
    p.anim_idle.frame_times = float.[1.0, 0.2, 0.2];

    p.anim_run  = animation_create(*p.texture, 4, 32, 32, 8, 0.1);
    p.anim_jump = animation_create(*p.texture, 2, 32, 32, 3, 0.1, false);
    p.anim_fall = animation_create(*p.texture, 1, 32, 32, 2, 0.1, false);
    p.anim_land = animation_create(*p.texture, 0, 32, 32, 2, 0.05, false);
    p.current_anim = *p.anim_idle;
}

player_update :: (p: *Player, world: *World, dt: float) {
    // Input and timers.
    direction := g_input.movement;
    if p.is_grounded {
        p.jump_coyote_timer = p.jump_coyote_time;
    } else if p.jump_coyote_timer > 0 {
        p.jump_coyote_timer -= dt;
    }
    if g_input.jump_pressed {
        p.jump_buffer_timer = p.jump_buffer_time;
    } else if p.jump_buffer_timer > 0 {
        p.jump_buffer_timer -= dt;
    }
    was_grounded := p.is_grounded;

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
    } else if p.velocity.y < 0 && !g_input.jump_held {
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
        tile := tile_at(*world.tilemap, tx, ty);
        if tile == .SOLID {
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

    min_y = xx floor((prev.y - STEP_HEIGHT) / TILE_SIZE);
    max_y = xx floor((next.y + STEP_HEIGHT)  / TILE_SIZE);

    tx = xx floor(next.x / TILE_SIZE);

    g_debug.tx0 = tx;
    g_debug.tx1 = tx;
    g_debug.ty0 = min_y;
    g_debug.ty1 = max_y;

    best_y := FLOAT32_INFINITY;
    found := false;
    skin :: 1.0;
    for ty: min_y .. max_y {
        tile := tile_at(*world.tilemap, tx, ty);
        g_debug.on_tile = tile;
        if tile != .EMPTY {
            floor_y := tile_slope_y(tile, next.x, tx, ty);
            if floor_y < best_y - skin {
                best_y = floor_y;
                found = true;
            }
        }
    }
    dy := best_y - prev_y;
    if found && p.velocity.y >= 0 && dy <= 3.0 {
        next.y = best_y;
        p.velocity.y = 0;
        p.is_grounded = true;
        p.is_jumping = false;
        p.jump_coyote_timer = p.jump_coyote_time;
        p.slope_dy = dy;
    } else {
        p.is_grounded = false;
    }

    p.position = next;

    // Define state.
    p.state = choose_movement_state(p);

    // // Just landing.
    // just_landed := !was_grounded && p.is_grounded;
    // if just_landed {
    //     p.landing_timer = 0.2;
    // } else if p.landing_timer > 0 {
    //     p.landing_timer -= dt;
    // }

    // Animation.
    next_anim := choose_animation(p);
    if next_anim != p.current_anim {
        p.current_anim = next_anim;
        animation_reset(p.current_anim);
    }
    animation_update(p.current_anim, dt);
}

player_update_1 :: (p: *Player, world: *World, dt: float) {
    // Input and timers.
    direction := g_input.movement;
    if p.is_grounded {
        p.jump_coyote_timer = p.jump_coyote_time;
    } else if p.jump_coyote_timer > 0 {
        p.jump_coyote_timer -= dt;
    }
    if g_input.jump_pressed {
        p.jump_buffer_timer = p.jump_buffer_time;
    } else if p.jump_buffer_timer > 0 {
        p.jump_buffer_timer -= dt;
    }
    was_grounded := p.is_grounded;

    // Apply horizontal movement velocity.
    target_speed := direction.x * p.speed;
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

    // Movement X.
    p.position.x += p.velocity.x * dt;

    // Gravity.
    gravity_force := GRAVITY * p.gravity_scale;
    if p.velocity.y > 0 {
        gravity_force *= 1.5;
    } else if p.velocity.y < 0 && !g_input.jump_held {
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

    // Movement Y.
    p.position.y += p.velocity.y * dt;

    collider := player_collider(p);

    floor_y, ok := tile_floor_y_collider(*world.tilemap, collider);
    // floor_y, ok := tile_floor_y_at(*world.tilemap, p.position.x, p.position.y);
    g_debug.bottom_y = floor_y;
    if p.velocity.y > 0 && ok {
        tile, is_slope := tile_slope_at(*world.tilemap, xx (collider.x + collider.width*0.5), xx (collider.y + collider.height));
        if is_slope {
            normal := tile_slope_normal(tile);
            tangent := tile_slope_tangent(tile);
            vn := dot(p.velocity, normal);
            if vn < 0 {
                p.velocity -= normal * dt;
            }
            vt := dot(Vector2.{0, gravity_force}, tangent);
            p.velocity += tangent * vt * dt;
            p.position.x += p.velocity.x * dt;
            p.position.y += p.velocity.y * dt;
        } else {
            p.position.y = floor_y;
            p.velocity.y = 0;
        }
        p.is_grounded = true;
        p.is_jumping = false;
        p.jump_coyote_timer = p.jump_coyote_time;
    } else {
        p.is_grounded = false;
    }

    // Define state.
    p.state = choose_movement_state(p);

    // Just landing.
    just_landed := !was_grounded && p.is_grounded;
    if just_landed {
        p.landing_timer = 0.1;
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

#scope_file

intersect_wall_above_floor :: (collider: Rectangle, floor_y: float, tilemap: *Tilemap) -> bool {
    left := collider.x;
    right := collider.x + collider.width;
    top := collider.y;
    bottom := collider.y + collider.height;

    tile_top, ok := tile_floor_y_at(tilemap, xx right, xx bottom);
    if ok {
        return true;
    }
    tile_top, ok = tile_floor_y_at(tilemap, xx right, xx top);
    if ok {
        return true;
    }
    tile_top = tile_floor_y_at(tilemap, xx left, xx bottom);
    if ok {
        return true;
    }
    tile_top = tile_floor_y_at(tilemap, xx left, xx top);
    if ok {
        return true;
    }

    return false;
}

try_step_up :: (collider: Rectangle, floor_y: float, tilemap: *Tilemap) -> bool {
    col := collider;
    for y: 1 .. cast(int) STEP_HEIGHT {
        col.y -= xx y;
        if !intersect_wall_above_floor(col, floor_y, tilemap) {
            return true;
        }
        col.y += xx y;
    }

    return false;
}

move_horizontal :: (p: *Player, dt: float, tilemap: *Tilemap) {
    p.position.x += p.velocity.x * dt;

    collider := player_collider(p);
    left   := collider.x;
    right  := collider.x + collider.width;
    top    := collider.y + 1.0;
    bottom := collider.y + collider.height - 1.0;

    floor_y, grounded := tile_floor_y_collider(tilemap, collider);
    if p.velocity.x > 0 { // moving right
        tx := cast(int) (right / TILE_SIZE);
        if tile_solid_at(tilemap, xx right, xx bottom) {
            ty: float = xx(cast(int)(bottom / TILE_SIZE));
            tile_top := ty * TILE_SIZE;
            if tile_top < floor_y - 0.01 {
                wall_x := xx (tx * TILE_SIZE);
                p.position.x = xx wall_x - collider.width*0.5;
                p.velocity.x = 0;
            }
        } else if tile_solid_at(tilemap, xx right, xx top) {
            wall_x := xx (tx * TILE_SIZE - collider.width);
            p.position.x = wall_x + collider.width;
            p.velocity.x = 0;
        }
        // if tile_solid_at(tilemap, xx right, xx top) || tile_solid_at(tilemap, xx right, xx bottom) {
        //     wall_x := xx (cast(int)(left / TILE_SIZE + 1) * TILE_SIZE);
        //     p.position.x = wall_x - collider.width * 0.5;
        //     p.velocity.x = 0;
        // }
    } else if p.velocity.x < 0 { // moving left
        if tile_solid_at(tilemap, xx left, xx top) || tile_solid_at(tilemap, xx left, xx bottom) {
            wall_x := xx (cast(int)(left / TILE_SIZE + 1) * TILE_SIZE);
            p.position.x = wall_x + collider.width * 0.5;
            p.velocity.x = 0;
        }
    }
}

move_vertical :: (p: *Player, dt: float, tilemap: *Tilemap) {
    p.position.y += p.velocity.y * dt;

    skin :: 4.0;

    collider := player_collider(p);
    left   := collider.x;
    right  := collider.x + collider.width;
    top    := collider.y;
    bottom := collider.y + collider.height;

    if p.velocity.y > 0 {
        support_y, ok := max_floor_at_tile(tilemap, left, right, bottom);
        if ok && bottom >= support_y - skin {
            p.position.y = support_y;
            p.velocity.y = 0;
            p.is_grounded = true;
            p.is_jumping = false;
            p.jump_coyote_timer = p.jump_coyote_time;
        } else {
            p.is_grounded = false;
        }
    } else {
        if tile_solid_at(tilemap, xx left, xx top) || tile_solid_at(tilemap, xx right, xx top) {
            ceil_y := xx ((cast(int)top / TILE_SIZE + 1) * TILE_SIZE);
            p.position.y = xx ceil_y;
            p.velocity.y = 0;
            p.is_hit_ceil = true;
        } else {
            p.is_hit_ceil = false;
        }
    }
}

snap_to_floor :: (p: *Player, tilemap: *Tilemap) {
    if p.is_jumping && p.velocity.y < 0 {
        return;
    }

    collider := player_collider(p);

    left   := collider.x;
    right  := collider.x + collider.width;
    bottom := collider.y + collider.height - 1;

    snap_up_max   := 6.0;
    snap_down_max := 12.0;

    floor_y, ok := tile_floor_y_collider(tilemap, collider);
    if !ok return;

    eps :: 1.0;

    if abs(p.position.y - floor_y) < eps {
        p.position.y = floor_y;
        p.velocity.y = 0;
        p.is_grounded = true;
        p.is_jumping = false;
        p.jump_coyote_timer = p.jump_coyote_time;
    }

    // delta := floor_y - bottom;
    // did_snap := false;

    // // Движемся вниз или стоим: можно доклеиться вниз
    // if p.velocity.y >= 0 {
    //     if delta >= 0 && delta <= snap_down_max {
    //         did_snap = true;
    //     } else if delta < 0 && -delta <= penetration_max {
    //         // немного въехали внутрь из-за дискретности — выправляем вверх
    //         did_snap = true;
    //     }
    // } else {
    //     if delta < 0 && -delta <= snap_up_max {
    //         did_snap = true;
    //     }
    // }

    // if did_snap {
    //     p.position.y = floor_y;
    //     p.velocity.y = 0;
    //     p.is_grounded = true;
    //     p.is_jumping  = false;
    //     p.jump_coyote_timer = p.jump_coyote_time;
    // }
}

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
        else if p.velocity.y > 200 return .FALL;
        else return .JUMP;
    }

    return ifx abs(p.velocity.x) > 0.1 then .RUN else .IDLE;
}

update_collider :: (p: *Player) {
    p.collider.x = p.position.x - p.collider.width * 0.5;
    p.collider.y = p.position.y - p.collider.height * 0.5;
}

sign :: inline (x: $T/.[float32, float64]) -> T {
    if x > 0.0 return 1.0;
    if x < 0.0 return -1.0;
    return 0.0;
}

sign :: inline (using v: Vector2) -> Vector2 {
    return .{ sign(x), sign(y) };
}
