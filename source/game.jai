GRAVITY :: 0.363281*60*60;

Game_State :: struct {
    player: Player;
    world: World;
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
    g.camera.zoom = 1;
    g.camera.offset = .{
        cast(float)(VIRTUAL_WIDTH * 0.5),
        cast(float)(VIRTUAL_HEIGHT * 0.5),
    };
    g.camera.target = g.player.position;
}

game_update :: (g: *Game_State, dt: float) {
    dt *= g.time_scale;
    player_update(*g.player, *g.world, dt);
    clamp_camera(*g.camera, g.player.position, .{ xx VIRTUAL_WIDTH, xx VIRTUAL_HEIGHT, g.world.bounds.width, g.world.bounds.height});
}

game_set_world :: (g: *Game_State, world: *World) {
    g.world = world;
}

game_draw :: (g: *Game_State) {
    ClearBackground(RAYWHITE);
    BeginMode2D(g.camera);
        draw_bounds(g.world.bounds);
        draw_tilemap(*g.world.tilemap);
        player_draw(*g.player);

        if g_debug.enabled {
            debug_draw_game(g);
        }
    EndMode2D();
}

game_shutdown :: (g: *Game_State) {
    player_unload(*g.player);
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
