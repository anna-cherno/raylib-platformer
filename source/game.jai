GRAVITY :: 0.363281*60*60;

Game_State :: struct {
    world: *World;
    player: Player;
    camera: Camera2D;
    mode: Game_Mode = .PLAY;
    time_scale := 1.0;

    initialized: bool;
}

Game_Mode :: enum {
    PLAY;
    EDITOR;
}

game_init :: (game: *Game_State) -> ok: bool, err: string {
    assert(game != null);

    ok, err := player_init(*game.player, .{200, 100});
    if !ok {
        return false, err;
    }

    init_camera(*game.camera, game.player.position);

    // Default world.
    game.world = world_create();
    assert(game.world.levels.count > 0);

    game.initialized = true;

    return true, "";
}

game_update :: (game: *Game_State, dt: float) {
    assert(game.initialized);

    action := player_collect_action();

    dt *= game.time_scale;

    level := game.world.levels[game.world.current_level];
    if action.plant {
        skin := -1.0;
        if action.plant_dir.y < 0 {
            skin -= game.player.size.y + 10;
        }
        plant_pos := world_to_tile(game.player.position + .{ xx action.plant_dir.x, xx action.plant_dir.y + skin});
        g_debug.plant_pos = plant_pos;
        dir := -action.plant_dir;
        seed, ok := seed_plant(level, plant_pos, dir);
        if ok && game.player.seeds_left > 0 {
            array_add(*level.seeds, seed);
            game.player.seeds_left -= 1;
        }
    }

    if action.remove_all_seeds {
        array_reset(*level.seeds);
        game.player.seeds_left = game.player.seeds_max;
    }

    player_update(*game.player, level, dt);
    world_update(game.world, dt);
    clamp_camera(*game.camera, game.player.position, .{ xx virtual_width, xx virtual_height, level.rect.width, level.rect.height});
}

game_draw :: (game: *Game_State) {
    assert(game.initialized);

    ClearBackground(BLACK);

    BeginMode2D(game.camera);
        world_draw(game.world, game.camera);
        #if DEBUG
            if g_debug.enabled then debug_draw_game(game);

        player_draw(*game.player);
    EndMode2D();
}

game_close :: (game: *Game_State) {
    assert(game.initialized);

    player_close(*game.player);
    world_destroy(game.world);
}

#scope_file

init_camera :: (camera: *Camera2D, initial_position: Vector2) {
    // Init camera.
    camera.zoom = 4;
    camera.offset = .{ xx (virtual_width * 0.5), xx (virtual_height * 0.5) };
    camera.target = initial_position;
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
