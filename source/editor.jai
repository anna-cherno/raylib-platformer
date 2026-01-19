Editor_State :: struct {
    camera: Camera2D;
    game: *Game_State;

    selected_collision: Collision_Type;
    selected_tile: int;
    hovered_tile: int;
    show_grid: bool = true;
    mouse_inside_editor: bool = false;

    left_panel: Rectangle = .{ 5.0, 45.0, 190, 190 };
    bottom_panel: Rectangle = .{ 5.0, 0, 0, 222 };

    tileset: *Tileset;
    tileset_rect: Rectangle;

    save_pressed: bool;
}

Editor_Tileset :: struct {
    texture: *Texture2D;
    t_width, t_height: int;
    rect: Rectangle;
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

    _, e.tileset = table_find(*g_assets.tilesets, "default");
    e.tileset_rect = .{ e.bottom_panel.x + 5, e.bottom_panel.y + 25, xx e.tileset.texture.width, xx e.tileset.texture.height };
    e.selected_collision = e.tileset.tiles[0].collision;
}

editor_update :: (e: *Editor_State, dt: float) {
    camera_update(*e.camera, .{ xx window_width, xx window_height, g_game.world.bounds.width * 2, g_game.world.bounds.height * 2});

    mouse_pos := GetMousePosition();
    e.mouse_inside_editor = CheckCollisionPointRec(mouse_pos, e.left_panel) || CheckCollisionPointRec(mouse_pos, e.bottom_panel);
    if e.mouse_inside_editor {
        // if mouse over tileset.
        if CheckCollisionPointRec(mouse_pos, e.tileset_rect) {
            tx := world_to_tile_x(mouse_pos.x - e.tileset_rect.x);
            ty := world_to_tile_y(mouse_pos.y - e.tileset_rect.y);
            e.hovered_tile = tile_index(tx, ty, xx (e.tileset_rect.width / TILE_SIZE));
            if g_input.mouse_left_down {
                e.selected_tile = e.hovered_tile;
                e.selected_collision = e.tileset.tiles[e.selected_tile].collision;
            }
        }
    } else {
        tx, ty := editor_mouse_tile(e.camera, mouse_pos);
        if tx < 0 || ty < 0 || tx >= e.game.world.tilemaps[0].width || ty >= e.game.world.tilemaps[0].height then return;
        idx := tile_index(tx, ty, e.game.world.tilemaps[0].width);
        if g_input.mouse_left_down {
            e.game.world.tilemaps[0].tiles[idx] = e.selected_tile;
        }
    }

    if e.save_pressed {
        save_tileset_data(e.tileset, "tilesets/default");
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
    if e.mouse_inside_editor {

    } else {
        tx, ty := editor_mouse_tile(e.camera, GetMousePosition());
        rect := Rectangle.{ xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
        DrawRectangleLinesEx(rect, 1.1, RED);

        debug_draw_collider(e.selected_collision, tx, ty);
    }
}

editor_draw_ui :: (e: *Editor_State) {
    // World's name.
    GuiStatusBar(.{0, 0, xx window_width, 40.0}, tprint("World: %\0", e.game.world.name).data);

    DrawRectangleLinesEx(.{0, 40, xx window_width, xx window_height - 40.0}, 5.0, GOLD);

    draw_left_panel(e);
    draw_bottom_panel(e);
}

editor_mouse_tile :: inline (cam: Camera2D, mouse_pos: Vector2) -> int, int {
    mouse_world  := GetScreenToWorld2D(mouse_pos, cam);
    return world_to_tile_x(mouse_world.x), world_to_tile_y(mouse_world.y);
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
    // y += mar + 10;
    // GuiToggleGroup(.{ anchor.x + pad, y, 32, 32 }, "N;S;U;D", cast(*s32) *e.selected_collision);
    y += mar + 10;
    GuiCheckBox(.{ anchor.x + pad, y, 20, 20 }, "Show grid", *e.show_grid);
    y += mar + 10;
    GuiCheckBox(.{ anchor.x + pad, y, 20, 20 }, "Show world colliders", *g_debug.show_world_colliders);
    y += mar + 10;
    GuiCheckBox(.{ anchor.x + pad, y, 20, 20 }, "Show player colliders", *g_debug.show_player_colliders);
    y += mar + 15;
    GuiSlider(.{ anchor.x + pad, y, 100, 20 }, null, tprint("% time\0", e.game.time_scale).data, *e.game.time_scale, 0.1, 1.0);
}

draw_bottom_panel :: (e: *Editor_State) {
    anchor := Vector2.{ e.bottom_panel.x, e.bottom_panel.y };
    pad := 8;
    mar := 10;
    y := anchor.y + 30.0;

    GuiPanel(e.bottom_panel, "Tiles");

    // Tileset texture.
    DrawTextureV(e.tileset.texture, .{ e.tileset_rect.x, e.tileset_rect.y }, WHITE);

    // Hovered tile.
    tx, ty := tile_coords(e.hovered_tile, xx (e.tileset_rect.width / TILE_SIZE));
    DrawRectangleLinesEx(.{ e.tileset_rect.x + tx * TILE_SIZE, e.tileset_rect.y + ty * TILE_SIZE, xx TILE_SIZE, xx TILE_SIZE }, 1.5, RED);

    // Selected tile.
    tx, ty = tile_coords(e.selected_tile, xx (e.tileset_rect.width / TILE_SIZE));
    DrawRectangleLinesEx(.{ e.tileset_rect.x + tx * TILE_SIZE, e.tileset_rect.y + ty * TILE_SIZE, xx TILE_SIZE, xx TILE_SIZE }, 1.5, GREEN);

    anchor.x += e.tileset_rect.width + pad;
    GuiLabel(.{ anchor.x + pad, y, 200, 20 }, TextFormat("Selected Tile: %d, %d", e.selected_tile, e.tileset.tiles[e.selected_tile].collision));

    y += 30;
    // tx, ty := tile_coords(t, m.tileset.texture.width / TILE_SIZE);
    src := Rectangle.{ xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
    dst := Rectangle.{ anchor.x + pad, y, xx TILE_SIZE * 4.0, xx TILE_SIZE * 4.0};
    GuiDummyRec(dst, null);
    DrawTexturePro(e.tileset.texture, src, dst, .{0, 0}, 0, WHITE);

    // collision picker
    anchor.x += pad*2 + TILE_SIZE*4.0;
    GuiToggleGroup(.{ anchor.x, y, 70, 30 }, "EMPTY;SOLID;SLOPE_UP;SLOPE_DOWN", xx *e.selected_collision);
    e.tileset.tiles[e.selected_tile].collision = e.selected_collision;

    y += 50;
    e.save_pressed = xx GuiButton(.{ anchor.x, y, 70, 30 }, "Save");
}
