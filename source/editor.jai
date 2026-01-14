Editor_State :: struct {
    camera: Camera2D;
    game: *Game_State;

    selected_tile: Collision_Type;
    show_grid: bool = true;
    mouse_inside: bool = false;

    left_panel: Rectangle = .{ 5.0, 45.0, 190, 190 };
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
    if xx tile.x >= e.game.world.t_width return;
    if xx tile.y >= e.game.world.t_height return;

    idx := tile_index(xx tile.x, xx tile.y, e.game.world.t_width);

    e.mouse_inside = CheckCollisionPointRec(GetMousePosition(), e.left_panel);
    if g_input.mouse_left_down && !e.mouse_inside {
        e.game.world.collisions[idx] = e.selected_tile;
    }
}

editor_draw :: (e: *Editor_State) {
    ClearBackground(BLACK);
    BeginMode2D(e.camera);
        draw_bounds(e.game.world.bounds);
        world_draw(*e.game.world);
        if e.show_grid {
            draw_grid(e.game.world.bounds);
        }
        debug_draw_game(e.game);

        player_draw(*e.game.player);

        editor_draw_overlays(e);
    EndMode2D();

    editor_draw_ui(e);
}

editor_draw_overlays :: (e: *Editor_State) {
    if !e.mouse_inside {
        mouse_world := GetScreenToWorld2D(GetMousePosition(), e.camera);
        tx := world_to_tile_x(mouse_world.x);
        ty := world_to_tile_y(mouse_world.y);

        rect := Rectangle.{ xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
        DrawRectangleLinesEx(rect, 1.1, RED);
        debug_draw_collider(e.selected_tile, tx, ty);
    }

    // DrawText(tprint("%, %\0", tile_x, tile_y).data, xx (tile_x * TILE_SIZE), xx (tile_y * TILE_SIZE), 1, BLACK);
}

editor_draw_ui :: (e: *Editor_State) {
    // World's name.
    GuiStatusBar(.{0, 0, xx window_width, 40.0}, tprint("World: %\0", e.game.world.name).data);

    DrawRectangleLinesEx(.{0, 40, xx window_width, xx window_height - 40.0}, 5.0, GOLD);

    anchor := Vector2.{ 5, 45 };
    pad := 8;
    mar := 10;
    y := anchor.y + mar;

    GuiPanel(e.left_panel, "Editor");
    y += mar + 10;
    GuiToggleGroup(.{ anchor.x + pad, y, 32, 32 }, "N;S;U;D", cast(*s32) *e.selected_tile);
    y += mar + 32;
    GuiCheckBox(.{ anchor.x + pad, y, 20, 20 }, "Show grid", *e.show_grid);
    y += mar + 10;
    GuiCheckBox(.{ anchor.x + pad, y, 20, 20 }, "Show world colliders", *g_debug.show_world_colliders);
    y += mar + 10;
    GuiCheckBox(.{ anchor.x + pad, y, 20, 20 }, "Show player colliders", *g_debug.show_player_colliders);
    y += mar + 20;
    GuiSlider(.{ anchor.x + pad, y, 100, 20 }, null, tprint("% time\0", e.game.time_scale).data, *e.game.time_scale, 0.1, 1.0);
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
}
