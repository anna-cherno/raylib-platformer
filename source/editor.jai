Editor_State :: struct {
    camera: Camera2D;
    game: *Game_State;

    selected_tile: Tile_Type;
    show_grid: bool = true;
}

editor_init :: (e: *Editor_State, g: *Game_State) {
    e.game = g;
    e.camera.zoom = 4;
    e.camera.offset = .{
        xx (VIRTUAL_WIDTH * 0.5),
        xx (VIRTUAL_HEIGHT * 0.5),
    };
    e.camera.target = g.player.position;
}

editor_update :: (e: *Editor_State, dt: float) {
    camera_update(*e.camera, .{ xx window_width, xx window_height, g_game.world.bounds.width * 2, g_game.world.bounds.height * 2});

    tile := editor_mouse_tile(e);
    if tile.x < 0 || tile.y < 0 return;
    if xx tile.x >= e.game.world.tilemap.width return;
    if xx tile.y >= e.game.world.tilemap.height return;

    idx := tile_index(*e.game.world.tilemap, xx tile.x, xx tile.y);

    if g_input.mouse_left_down {
        e.game.world.tilemap.tiles[idx] = e.selected_tile;
    }
}

editor_draw :: (e: *Editor_State) {
    ClearBackground(BLACK);
    BeginMode2D(e.camera);
        draw_bounds(e.game.world.bounds);
        if e.show_grid {
            draw_grid(e.game.world.bounds);
        }
        player_draw(*e.game.player);
        draw_tilemap(*e.game.world.tilemap);
        debug_draw_game(e.game);
        editor_draw_overlays(e);
    EndMode2D();

    editor_draw_ui(e);
}

editor_draw_overlays :: (e: *Editor_State) {
    mouse_world := GetScreenToWorld2D(GetMousePosition(), e.camera);
    tile_x := floor(mouse_world.x / TILE_SIZE);
    tile_y := floor(mouse_world.y / TILE_SIZE);

    rect := Rectangle.{ tile_x * TILE_SIZE, tile_y * TILE_SIZE, xx TILE_SIZE, xx TILE_SIZE };

    DrawRectangleLinesEx(rect, 1.1, RED);
}

editor_draw_ui :: (e: *Editor_State) {
    anchor := Vector2.{ 5, 5 };

    GuiPanel(.{ anchor.x, anchor.y, 192, 200 }, "Editor");
    GuiListView(.{ anchor.x + 8, anchor.y + 24, 176, 128 }, "NONE;SOLID;SLOPE_UP;SLOPE_DOWN", null, cast(*s32) *e.selected_tile);
    GuiCheckBox(.{ anchor.x + 8, anchor.y + 160, 24, 24 }, "Show grid", *e.show_grid);
}

editor_mouse_tile :: (e: *Editor_State) -> Vector2 {
    mouse_screen := GetMousePosition();
    mouse_world  := GetScreenToWorld2D(mouse_screen, e.camera);

    return .{ floor(mouse_world.x / TILE_SIZE), floor(mouse_world.y / TILE_SIZE) };
}

#scope_file

camera_update :: (camera: *Camera2D, bounds: Rectangle) {
    if g_input.mouse_right_down {
        delta := GetMouseDelta();
        camera.target -= delta / camera.zoom;
    }

    wheel := GetMouseWheelMove();
    if wheel != 0 {
        mouse_screen := GetMousePosition();
        before := GetScreenToWorld2D(mouse_screen, camera.*);
        zoom_factor := 1.0 + wheel * 0.05;
        camera.zoom = clamp(camera.zoom * zoom_factor, 0.2, 10);
        after := GetScreenToWorld2D(mouse_screen, camera.*);
        camera.target += before - after;
    }

    // clamp_camera(camera, camera.target, bounds);
}
