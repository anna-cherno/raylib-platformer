#import "Math";
#import "raylib";

STEP_HEIGHT :: 4;

Player :: struct {
    #as using base: Entity;
    base.type = .PLAYER;

    // Movement.
    speed        := 1.5625*60;
    jump_force   := -6.5625*60;
    jump_release := -12.5625*60*0.4;
    acceleration := 0.118164*60*60*1.5;
    friction     := 0.118164*60*60*1.5;
    gravity_scale:= 1.0;

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
    p.collider.width = p.size.x * 0.34;
    p.collider.height = p.size.y;
    p.collider.x = p.position.x - p.collider.width * 0.5;
    p.collider.y = p.position.y - p.collider.height * 0.5;

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

    // Movement along X.
    p.position.x += p.velocity.x * dt;
    update_collider(p);
    move_and_slide_x(p, *world.tilemap);

    // Gravity.
    gravity_force := GRAVITY * p.gravity_scale;
    if p.velocity.y > 0 {
        gravity_force *= 1.5;
    } else if p.velocity.y < 0 && !g_input.jump_held {
        gravity_force *= 3.0;
    }
    p.velocity.y += gravity_force * dt;

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

    // Movement along Y.
    p.position.y += p.velocity.y * dt;
    update_collider(p);
    move_and_slide_y(p, *world.tilemap);

    // Snap to the ground.
    if p.is_grounded && !p.is_jumping && p.velocity.y >= 0 {
        snap_to_ground(p, *world.tilemap);
    }

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

#scope_file

move_and_slide_x :: (p: *Player, tilemap: *Tilemap) {
    left   := p.collider.x;
    right  := p.collider.x + p.collider.width;
    top    := p.collider.y + 2.0;
    bottom := p.collider.y + p.collider.height - 4.0;

    if p.velocity.x > 0 { // moving right
        if tile_solid_at(tilemap, xx right, xx top) || tile_solid_at(tilemap, xx right, xx bottom) {
            wall_x := xx (cast(int)(right / TILE_SIZE) * TILE_SIZE - p.collider.width);
            p.position.x = wall_x + p.collider.width * 0.5;
            p.velocity.x = 0;
        }
    } else if p.velocity.x < 0 { // moving left
        if tile_solid_at(tilemap, xx left, xx top) || tile_solid_at(tilemap, xx left, xx bottom) {
            wall_x := xx (cast(int)(left / TILE_SIZE + 1) * TILE_SIZE);
            p.position.x = wall_x + p.collider.width * 0.5;
            p.velocity.x = 0;
        }
    }
}

move_and_slide_y :: (p: *Player, tilemap: *Tilemap) {
    skin :: 8.0;

    left   := p.collider.x;
    right  := p.collider.x + p.collider.width;
    top    := p.collider.y;
    bottom := p.collider.y + p.collider.height;

    if p.velocity.y >= 0 {
        support_y, has_support := ground_query_under_segment(tilemap, left, right, bottom);
        if has_support && bottom >= support_y - skin {
            p.position.y = support_y - p.collider.height * 0.5;
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
            p.position.y = ceil_y + p.collider.height * 0.5;
            p.velocity.y = 0;
            p.is_hit_ceil = true;
        } else {
            p.is_hit_ceil = false;
        }
    }
}

snap_to_ground :: (p: *Player, tilemap: *Tilemap) {
    snap_distance :: 8.0;

    left   := p.collider.x;
    right  := p.collider.x + p.collider.width;
    bottom := p.collider.y + p.collider.height + snap_distance;

    support_y, has_support := ground_query_under_segment(tilemap, left, right, bottom);
    if has_support {
        current_bottom := p.collider.y + p.collider.height;
        if current_bottom < support_y && current_bottom >= support_y - snap_distance - 1.0 {
            p.position.y = support_y - p.collider.height * 0.5;
            p.velocity.y = 0;
            p.is_grounded = true;
        }
    }
}

choose_animation :: (p: *Player) -> *Animation {
    if p.landing_timer > 0 {
        return *p.anim_land;
    }

    if p.state == {
        case .IDLE; return *p.anim_idle;
        case .JUMP; return *p.anim_jump;
        case .FALL;
            if p.velocity.y > 200.0 return *p.anim_fall;
            else return *p.anim_jump;
        case .RUN;  return *p.anim_run;
        case .LAND; return *p.anim_land;
    }

    return *p.anim_idle;
}

choose_movement_state :: (p: *Player) -> Player_State {
    if !p.is_grounded {
        return ifx p.velocity.y < 0 then .JUMP else .FALL;
    }

    return ifx abs(p.velocity.x) > 0.1 then .RUN else .IDLE;
}

update_collider :: (p: *Player) {
    p.collider.x = p.position.x - p.collider.width * 0.5;
    p.collider.y = p.position.y - p.collider.height * 0.5;
}
