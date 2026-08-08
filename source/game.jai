GRAVITY :: 0.363281*60*60;

Game :: struct {
    state: Game_State;
    
    world: World;
    player: Player;
    camera: Camera2D;
    input: Game_Input;

    mode: Game_Mode;

    time_scale := 1.0;
}

Game_State :: enum u8 {
    UNINITIALIZED;
    RUNNING;
    SHUTTING_DOWN;
}

Game_Mode :: enum u8 {
    PLAY;
    EDITOR;
}

init_game :: () -> bool {
    if !init_player() {
        log_error("Не удалось инициализировать игрока");
        return false;
    }
    
    init_game_camera(game.player.position);
    init_world();
    init_player();

    game.mode = .PLAY;
    game.state = .RUNNING;

    return true;
}

update_game :: (dt: float) {
    assert(game.state == .RUNNING);

    dt *= game.time_scale;

    level := current_level(); 
    if game.input.plant_pressed {
        plant_dir := Vector2i.{xx game.input.movement.x, xx game.input.movement.y};
        
        left := game.player.position.x - game.player.width * 0.5;
        right := game.player.position.x + game.player.width * 0.5;
        top := game.player.position.y - game.player.height;
        bottom := game.player.position.y;

        plant_offset := Vector2.{ game.player.position.x, bottom - 4 };
        if plant_dir.x > 0      then plant_offset.x = right + 4;
        else if plant_dir.x < 0 then plant_offset.x = left - 4;
        if plant_dir.y > 0      then plant_offset.y = bottom + 4;
        else if plant_dir.y < 0 then plant_offset.y = top - 4;

        plant_pos := world_to_tile(plant_offset);
        debug.plant_pos = plant_pos;
        debug.plant_pos_vec = plant_offset;
        dir := -plant_dir;
        
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

    if game.input.reset_plants_pressed {
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

    if game.input.undo_seed_pressed {
        if seed_snapshot_valid(level.seed_snapshot) {
            seed_snapshot_restore(level);
            game.player.seeds_left += 1;
        }
    }
    
    update_world(dt);
    update_player(dt);
    update_game_camera();
}

draw_game :: () {
    assert(game.state == .RUNNING);

    camera := active_camera();
    BeginMode2D(camera);
        draw_world();
        
        level := current_level();
        draw_grid(level.bounds);
        
        #if EDITOR {
            if game.mode == .EDITOR then draw_editor_tile_hovers();
        }
        
        #if DEBUG {
            if debug.enabled then draw_debug_game();
        }
    EndMode2D();

    draw_ui();
    
    #if EDITOR {
        if game.mode == .EDITOR then draw_editor_overlay();
    }
}

deinit_game :: () -> bool {
    assert(game.state == .RUNNING);
    
    game.state = .SHUTTING_DOWN;

    deinit_player();
    deinit_world();
    
    return true;
}

init_game_camera :: (initial_position: Vector2) {
    game.camera.zoom = 4;
    game.camera.offset = .{ xx (window_width * 0.5), xx (window_height * 0.5) };
    game.camera.target = initial_position;
}

update_game_camera :: () {
    level := current_level();

    half_w := (window_width * 0.5) / game.camera.zoom;
    half_h := (window_height * 0.5) / game.camera.zoom;

    min_x := half_w;
    max_x := level.bounds.width - half_w;
    min_y := half_h;
    max_y := level.bounds.height - half_h;

    game.camera.target = game.player.position;
    game.camera.target.x = clamp(game.camera.target.x, min_x, max_x);
    game.camera.target.y = clamp(game.camera.target.y, min_y, max_y);
}

active_camera :: inline () -> *Camera2D {
    return ifx game.mode == .PLAY then *game.camera else *editor.camera;
}

log_error :: inline (text: string, args: ..Any) {
    TraceLog(.LOG_ERROR, to_c_string(tprint(text, ..args)));
}

log_warning :: inline (text: string, args: ..Any) {
    TraceLog(.LOG_WARNING, to_c_string(tprint(text, ..args)));
}

log_info :: inline (text: string, args: ..Any) {
    TraceLog(.LOG_INFO, to_c_string(tprint(text, ..args)));
}