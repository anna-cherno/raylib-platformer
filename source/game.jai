GRAVITY :: 0.363281*60*60;

Game_State :: struct {
    world: *World;
    player: Player;
    camera: Camera2D;
    mode: Game_Mode = .PLAY;
    time_scale := 1.0;
}

Game_Mode :: enum {
    PLAY;
    EDITOR;
}

game_init :: (g: *Game_State) {
    player_init(*g.player, .{200, 100});

    // Init camera.
    g.camera.zoom = 4;
    g.camera.offset = .{
        xx (virtual_width * 0.5),
        xx (virtual_height * 0.5),
    };
    g.camera.target = g.player.position;

    // Create default world.
    g.world = world_create();
}

game_update :: (g: *Game_State, dt: float) {
    action := player_collect_action();

    dt *= g.time_scale;

    level := g.world.levels[g.world.current_level];
    if action.plant {
        skin := -1.0;
        if action.plant_dir.y < 0 {
            skin -= g.player.size.y + 10;
        }
        plant_pos := world_to_tile(g.player.position + .{ xx action.plant_dir.x, xx action.plant_dir.y + skin});
        g_debug.plant_pos = plant_pos;
        dir := -action.plant_dir;
        seed, ok := seed_plant(level, plant_pos, dir);
        if ok && g.player.seeds_left > 0 {
            array_add(*level.seeds, seed);
            g.player.seeds_left -= 1;
        }
    }

    if action.remove_all_seeds {
        array_reset(*level.seeds);
        g.player.seeds_left = g.player.seeds_max;
    }

    player_update(*g.player, level, dt);
    world_update(g.world, dt);
    clamp_camera(*g.camera, g.player.position, .{ xx virtual_width, xx virtual_height, level.rect.width, level.rect.height});
}

game_draw :: (g: *Game_State) {
    ClearBackground(BLACK);
    BeginMode2D(g.camera);
        world_draw(g.world, g.camera);
        if g_debug.enabled {
            debug_draw_game(g);
        }
        player_draw(*g.player);
    EndMode2D();
}

game_shutdown :: (g: *Game_State) {
    player_unload(*g.player);

    world_destroy(g.world);
}

clamp_camera :: (camera: *Camera2D, position: Vector2, bounds: Rectangle) {
    half_w := bounds.x * 0.5 / camera.zoom;
    half_h := bounds.y * 0.5 / camera.zoom;

    min_x := half_w;
    max_x := bounds.width - half_w;
    min_y := half_h;
    max_y := bounds.height - half_h;

    camera.target = position;
    camera.target.x = clamp(camera.target.x, min_x, max_x);
    camera.target.y = clamp(camera.target.y, min_y, max_y);
}

move_towards :: (current: float, target: float, max_delta: float) -> float {
    if abs(target - current) <= max_delta return target;

    if target > current {
        return current + max_delta;
    } else {
        return current - max_delta;
    }
}
