Editor_State :: struct {
    camera: Camera2D;
    game: *Game_State;

    selected_collision: Collision_Type;
    selected_tile: Tile_ID;
    show_grid: bool = true;
    mouse_inside: bool = false;

    left_panel: Rectangle = .{ 5.0, 45.0, 190, 190 };
    bottom_panel: Rectangle = .{ 5.0, 0, 0, 222 };
}

editor_init :: (e: *Editor_State, g: *Game_State) {
    e.game = g;
    e.camera.zoom = 4;
    e.camera.offset = .{
        xx (VIRTUAL_WIDTH * 0.5),
        xx (VIRTUAL_HEIGHT * 0.5),
    };
    e.camera.target = g.player.position;

    e.bottom_panel.y = window_height - e.bottom_panel.height - 5;
    e.bottom_panel.width = window_width - e.bottom_panel.x - 5;
}

editor_update :: (e: *Editor_State, dt: float) {
    camera_update(*e.camera, .{ xx window_width, xx window_height, g_game.world.bounds.width * 2, g_game.world.bounds.height * 2});

    tile := editor_mouse_tile(e.camera);
    if tile.x < 0 || tile.y < 0 return;
    if xx tile.x >= e.game.world.t_width return;
    if xx tile.y >= e.game.world.t_height return;

    idx := tile_index(xx tile.x, xx tile.y, e.game.world.t_width);

    e.mouse_inside = CheckCollisionPointRec(GetMousePosition(), e.left_panel);
    if g_input.mouse_left_down && !e.mouse_inside {
        e.game.world.collisions[idx] = e.selected_collision;
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
        mouse_tile := editor_mouse_tile(e.camera);

        rect := Rectangle.{ xx (mouse_tile.x * TILE_SIZE), xx (mouse_tile.y * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
        DrawRectangleLinesEx(rect, 1.1, RED);
        debug_draw_collider(e.selected_collision, xx mouse_tile.x, xx mouse_tile.y);
    }
}

editor_draw_ui :: (e: *Editor_State) {
    // World's name.
    GuiStatusBar(.{0, 0, xx window_width, 40.0}, tprint("World: %\0", e.game.world.name).data);

    DrawRectangleLinesEx(.{0, 40, xx window_width, xx window_height - 40.0}, 5.0, GOLD);

    draw_left_panel(e);
    draw_bottom_panel(e);
}

editor_mouse_tile :: (cam: Camera2D) -> Vector2 {
    mouse_world  := GetScreenToWorld2D(GetMousePosition() * 2, cam);

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

draw_left_panel :: (e: *Editor_State) {
    anchor := Vector2.{ e.left_panel.x, e.left_panel.y };
    pad := 8;
    mar := 10;
    y := anchor.y + mar;

    GuiPanel(e.left_panel, "Editor");
    y += mar + 10;
    GuiToggleGroup(.{ anchor.x + pad, y, 32, 32 }, "N;S;U;D", cast(*s32) *e.selected_collision);
    y += mar + 32;
    GuiCheckBox(.{ anchor.x + pad, y, 20, 20 }, "Show grid", *e.show_grid);
    y += mar + 10;
    GuiCheckBox(.{ anchor.x + pad, y, 20, 20 }, "Show world colliders", *g_debug.show_world_colliders);
    y += mar + 10;
    GuiCheckBox(.{ anchor.x + pad, y, 20, 20 }, "Show player colliders", *g_debug.show_player_colliders);
    y += mar + 20;
    GuiSlider(.{ anchor.x + pad, y, 100, 20 }, null, tprint("% time\0", e.game.time_scale).data, *e.game.time_scale, 0.1, 1.0);
}

draw_bottom_panel :: (e: *Editor_State) {
    anchor := Vector2.{ e.bottom_panel.x, e.bottom_panel.y };
    pad := 8;
    mar := 10;
    y := anchor.y + 30.0;

    GuiPanel(e.bottom_panel, "Tiles");

    DrawTextureV(e.game.world.tilemaps[0].tileset, .{ anchor.x + pad, y }, WHITE);
}
