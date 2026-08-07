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

    level := game.world.levels[game.world.current_level_index];
    if action.plant {
        left := game.player.position.x - game.player.width * 0.5;
        right := game.player.position.x + game.player.width * 0.5;
        top := game.player.position.y - game.player.height;
        bottom := game.player.position.y;

        plant_offset := Vector2.{ game.player.position.x, bottom - 4 };
        if action.plant_dir.x > 0 then plant_offset.x = right + 4;
        else if action.plant_dir.x < 0 then plant_offset.x = left - 4;
        if action.plant_dir.y > 0 then plant_offset.y = bottom + 4;
        else if action.plant_dir.y < 0 then plant_offset.y = top - 4;

        plant_pos := world_to_tile(plant_offset);
        g_debug.plant_pos = plant_pos;
        g_debug.plant_pos_vec = plant_offset;
        dir := -action.plant_dir;
        if game.player.seeds_left > 0 {
            seed_snapshot_take(level);
            seed, ok := seed_plant(level, plant_pos, dir);
            if ok {
                if seed.active {
                    array_add(*level.seeds, seed);
                }
                game.player.seeds_left -= 1;
            }
        }
    }

    if action.remove_all_seeds {
        array_free(level.seed_snapshot.seeds);
        array_free(level.seed_snapshot.tiles);
        array_reset(*level.seeds);
        game.player.seeds_left = game.player.seeds_max;
        for * level.layers[0].data {
            if it.flags & .SEED {
                it.collision = .EMPTY;
                it.id = EMPTY_TILE;
                it.flags = 0;
            }
        }
    }

    if action.undo_seed {
        if seed_snapshot_valid(level.seed_snapshot) {
            seed_snapshot_restore(level);
            game.player.seeds_left += 1;
        }
    }

    player_update(*game.player, level, dt);
    world_update(game.world, dt);
    clamp_camera(*game.camera, game.player.position, .{ xx window_width, xx window_height, level.bounds.width, level.bounds.height});
}

game_draw :: (game: *Game_State) {
    assert(game.initialized);

    ClearBackground(BLACK);

    BeginMode2D(game.camera);
        world_draw(game.world, game.camera);
        draw_grid(game.world.levels[game.world.current_level_index].bounds);
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
    camera.offset = .{ xx (window_width * 0.5), xx (window_height * 0.5) };
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
