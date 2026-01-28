Editor_State :: struct {
    camera: Camera2D;
    game: *Game_State;
    mode: Type = Editor_Tileset_Mode;

    // Data.
    mouse_inside_editor := false;
    show_grid := true;

    // Panels.
    bottom_panel: Rectangle = .{ 0, 0, 0, 300 };

    // Modes.
    tileset_mode: Editor_Tileset_Mode;

    initialized: bool;
}

Editor_Mode :: struct {
    type: Type;
    name: string;
    initialized: bool;
}

Editor_Tileset_Mode :: struct {
    #as using base: Editor_Mode;
    base.type = Editor_Tileset_Mode;

    // Data.
    tileset: *Tileset;
    tileset_rect: Rectangle;
    tileset_content_rect: Rectangle;
    tileset_scroll: Vector2;
    tileset_view: Rectangle;
    tileset_zoom := 2.0;
    tile_size: float = xx TILE_SIZE;

    selected_collision: Collision_Type;
    hovered_tile: s32;
    selected_tiles: [..]s32;
    last_selected_tile: s32 = -1;
    should_delete_rule_index := -1;
    rule_scroll: Vector2;
    rule_view: Rectangle;

    // Buttons.
    save_tileset_data_pressed: bool;
    add_new_rule_pressed: bool;

    // States.
    select_mode: Select_Mode = .SINGLE;
    brush_mode: Brush_Mode = .AUTOTILE;

    Select_Mode :: enum u8 {
        SINGLE;
        MULTIPLE;
    }

    Brush_Mode :: enum u8 {
        AUTOTILE;
        MANUAL;
    }
}

editor_init :: (editor: *Editor_State, game: *Game_State) -> ok: bool, err: string {
    assert(editor != null && game != null);

    editor.game = game;

    init_panels(editor);
    init_camera(*editor.camera, game.player.position);

    if editor.mode == {
        case Editor_Tileset_Mode;
            ok, err := init_tileset_mode(*editor.tileset_mode, editor.bottom_panel, "default");
            if !ok {
                return false, err;
            }
    }

    editor.initialized = true;

    return true, "";
}

editor_update :: (editor: *Editor_State, dt: float) {
    assert(editor && editor.initialized);
    assert(editor.game.world && editor.game.world.levels.count > 0);

    level := editor.game.world.levels[editor.game.world.current_level];

    mouse_pos := GetMousePosition();
    editor.mouse_inside_editor = CheckCollisionPointRec(mouse_pos, editor.bottom_panel);

    if editor.mouse_inside_editor {
        if editor.mode == {
            case Editor_Tileset_Mode;
                update_tileset_mode(*editor.tileset_mode, mouse_pos);
        }
    } else {
        update_camera(*editor.camera, .{ xx window_width, xx window_height, level.rect.width * 2, level.rect.height * 2});
        tx, ty := editor_mouse_tile(editor.camera, mouse_pos);
        if tx < 0 || ty < 0 || tx >= level.tilemaps[0].width || ty >= level.tilemaps[0].height then return;

        idx := tile_index(tx, ty, level.tilemaps[0].width);
        if IsMouseButtonDown(MOUSE_LEFT_BUTTON) {
            // level.tilemaps[0].auto_tiles[idx] = editor.selected_tile;
            level.tilemaps[0].collisions[idx] = editor.tileset_mode.selected_collision;
            tilemap_update_autotiling(*level.tilemaps[0], tx, ty);
        }
        if IsMouseButtonDown(MOUSE_RIGHT_BUTTON) {
            level.tilemaps[0].collisions[idx] = .EMPTY;
            level.tilemaps[0].auto_tiles[idx] = -1;
            tilemap_update_autotiling(*level.tilemaps[0], tx, ty);
        }
    }
}

editor_close :: (editor: *Editor_State) {
    assert(editor && editor.initialized);

    if editor.tileset_mode.initialized {
        close_tileset_mode(*editor.tileset_mode);
    }

    editor.game = null;
}

editor_draw :: (editor: *Editor_State) {
    ClearBackground(BLACK);

    editor_draw_viewport(editor);
    editor_draw_ui(editor);
}

editor_draw_viewport :: (editor: *Editor_State) {
    BeginMode2D(editor.camera);
        world_draw(editor.game.world, editor.camera);
        debug_draw_game(editor.game);
        player_draw(*editor.game.player);

        if !editor.mouse_inside_editor {
            tx, ty := editor_mouse_tile(editor.camera, GetMousePosition());
            rect := Rectangle.{ xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
            DrawRectangleLinesEx(rect, 1, RED);

            debug_draw_collider(editor.tileset_mode.selected_collision, tx, ty);
        }
    EndMode2D();
}

editor_draw_ui :: (editor: *Editor_State) {
    anchor := Vector2.{ editor.bottom_panel.x, editor.bottom_panel.y };

    // Toggle group for state change.
    mode := 0;
    GuiToggleGroup(.{ anchor.x, anchor.y, 320.0, 24.0 }, "Tileset", xx *mode);
    if mode == {
        case 0; editor.mode = Editor_Tileset_Mode;
    }

    anchor.y += 24;
    GuiPanel(.{ anchor.x, anchor.y, editor.bottom_panel.width, editor.bottom_panel.height}, null);

    anchor.y += 8;
    if editor.mode == {
        case Editor_Tileset_Mode; draw_tileset_mode(*editor.tileset_mode, anchor);
    }
}

editor_mouse_tile :: inline (cam: Camera2D, mouse_pos: Vector2) -> int, int {
    mouse_world  := GetScreenToWorld2D(mouse_pos, cam);
    return world_to_tile_x(mouse_world.x), world_to_tile_y(mouse_world.y);
}

#scope_file

RULE_PICKER_SIZE :: 24.0;

draw_rule :: (rule: *Tileset_Rule, state: *Editor_Tileset_Mode, index: int, anchor: Vector2) {
    GuiGroupBox(.{ anchor.x, anchor.y, 112, 160 }, tprint("Rule %\0", index).data);

    draw_rule_picker(rule, .{ anchor.x + 8, anchor.y + 8 });

    x := anchor.x + 8;
    y := anchor.y + RULE_PICKER_SIZE * 3 + 14;
    // Move left.
    if GuiButton(.{ x, y, 24, 24 }, "#118#") {
        if index - 1 >= 0 {
            swap(*state.tileset.rules[index-1], *state.tileset.rules[index]);
        }
    }

    // Move right.
    if GuiButton(.{ x + 24, y, 24, 24 }, "#119#") {
        if index + 1 < state.tileset.rules.count {
            swap(*state.tileset.rules[index+1], *state.tileset.rules[index]);
        }
    }

    // Set tiles.
    if GuiButton(.{ x + 48, y, 24, 24 }, "#101#") {
        array_free(rule.tile_ids);
        rule.tile_ids = array_copy(state.selected_tiles);
    }

    // Delete tile.
    if GuiButton(.{ x + 72, y, 24, 24 }, "#143#") {
        state.should_delete_rule_index = index;
    }

    x = anchor.x + 8;
    y += 28;
    for tile_id: rule.tile_ids {
        tx, ty := tile_coords(tile_id, state.tileset.cols);
        if x + TILE_SIZE > anchor.x + 112 {
            x = anchor.x + 8;
            y += TILE_SIZE;
        }
        draw_tile(state.tileset.texture, .{ tx, ty }, .{ x, y });
        x += TILE_SIZE + 1.0;
    }

}

draw_rule_picker :: (rule: *Tileset_Rule, anchor: Vector2) {
    for 0..8 {
        x := it % 3; y := it / 3;

        offset: Tileset_Flags = xx 1 << it;
        on_mask  := rule.on_mask  & offset;
        off_mask := rule.off_mask & offset;

        icon: string;
        on_active  := on_mask != 0;
        off_active := off_mask != 0;
        if on_active && off_active {
            icon = "#48#";
        } else if off_active {
            icon = "#113#";
        } else if on_active {
            icon = "#112#";
        }

        active := on_active || off_active;
        prev_active := active;

        GuiToggle(.{ anchor.x + x * RULE_PICKER_SIZE, anchor.y + y * RULE_PICKER_SIZE, RULE_PICKER_SIZE, RULE_PICKER_SIZE }, icon.data, *active);
        if prev_active != active {
            if !on_active && active {
                rule.on_mask |= offset;
            } else if on_active && !active  {
                rule.on_mask &= ~offset;
                rule.off_mask |= offset;
            } else {
                rule.on_mask &= ~offset;
                rule.off_mask &= ~offset;
            }
        }
    }
}

/**
 * Panels.
 */
init_panels :: (editor: *Editor_State) {
    editor.bottom_panel.y = window_height - editor.bottom_panel.height;
    editor.bottom_panel.width = window_width - editor.bottom_panel.x;
}

/**
 * Camera.
 */
init_camera :: (camera: *Camera2D, initial_position: Vector2) {
    assert(camera != null);

    camera.zoom = 4;
    camera.offset = .{ xx (virtual_width * 0.5), xx (virtual_height * 0.5) };
    camera.target = initial_position;
}

update_camera :: (camera: *Camera2D, bounds: Rectangle) {
    assert(camera != null);

    if IsMouseButtonDown(MOUSE_MIDDLE_BUTTON) {
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

/**
 * Tileset Mode.
 */
init_tileset_mode :: (state: *Editor_Tileset_Mode, panel_rect: Rectangle, tileset_name := "default") -> ok: bool, err: string {
    assert(g_assets.tilesets.count > 0);

    found := false;
    found, state.tileset = table_find(*g_assets.tilesets, tileset_name);
    if !found {
        return false, tprint("Tileset % not found", tileset_name);
    }

    // Tileset state.
    state.tileset_rect = .{ panel_rect.x, panel_rect.y + 24, 380, panel_rect.height - 24 };
    state.tile_size = state.tileset.texture.width / cast(float) state.tileset.cols * state.tileset_zoom;
    // state.tileset_content_rect = .{ 0, 0, xx state.tileset.texture.width, xx state.tileset.texture.height };

    // Resize selected tiles for entire tileset.
    array_reserve(*state.selected_tiles, state.tileset.cols * state.tileset.rows);

    state.initialized = true;

    return true, "";
}

close_tileset_mode :: (state: *Editor_Tileset_Mode) {
    assert(state.initialized);

    array_reset(*state.selected_tiles);

    state.initialized = false;
}

update_tileset_mode :: (state: *Editor_Tileset_Mode, mouse_pos: Vector2) {
    assert(state.initialized);

    if CheckCollisionPointRec(mouse_pos, state.tileset_rect) {
        tx := world_to_tile_x(mouse_pos.x - (state.tileset_view.x + state.tileset_scroll.x), xx state.tile_size);
        ty := world_to_tile_y(mouse_pos.y - (state.tileset_view.y + state.tileset_scroll.y), xx state.tile_size);
        tx = clamp(tx, 0, state.tileset.cols-1);
        ty = clamp(ty, 0, state.tileset.rows-1);
        state.hovered_tile = xx tile_index(tx, ty, state.tileset.cols);

        if IsMouseButtonDown(MOUSE_LEFT_BUTTON) {
            if IsKeyDown(.KEY_LEFT_SHIFT) {
                if !array_find(state.selected_tiles, state.hovered_tile) {
                    array_add(*state.selected_tiles, state.hovered_tile);
                }
            } else {
                array_reset(*state.selected_tiles);
                array_add(*state.selected_tiles, state.hovered_tile);
                state.selected_collision = state.tileset.collisions[state.selected_tiles[0]];
            }
            state.last_selected_tile = state.hovered_tile;
        } else if IsMouseButtonDown(MOUSE_RIGHT_BUTTON) {
            array_ordered_remove_by_value(*state.selected_tiles, state.hovered_tile);
        }

        wheel := GetMouseWheelMove();
        if wheel != 0 && !IsKeyDown(.KEY_LEFT_SHIFT) {
            mouse_screen := GetMousePosition();
            zoom_factor := 1.0 + wheel * 0.05;
            state.tileset_zoom = clamp(state.tileset_zoom * zoom_factor, 1, 6);
            state.tile_size = state.tileset.texture.width / cast(float) state.tileset.cols * state.tileset_zoom;
        }

    }

    if state.save_tileset_data_pressed {
        save_tileset_data_to_file(state.tileset, "tilesets/paper_tileset");
    }
    if state.add_new_rule_pressed {
        array_add(*state.tileset.rules);
    }

    if state.should_delete_rule_index != -1 {
        array_ordered_remove_by_index(*state.tileset.rules, state.should_delete_rule_index);
        state.should_delete_rule_index = -1;
    }
}

draw_tileset_mode :: (state: *Editor_Tileset_Mode, anchor: Vector2) {
    assert(state.initialized);

    draw_tileset_collision_picker(state, anchor);
    draw_tileset_picker(state, anchor);

    // x := anchor.x + state.tileset_rect.width + 12;

    // state.add_new_rule_pressed = xx GuiButton(.{ x, anchor.y + 32, 100, 24 }, "Add new rule");
    // state.save_tileset_data_pressed = xx GuiButton(.{ x, anchor.y + 270, 70, 25 }, "Save");

    // rule_rect := Rectangle.{ x, anchor.y + 64, window_width - x - 20, 200 };
    // rule_content := Rectangle.{ 0, 0, state.tileset.rules.count * 120.0 + 8, rule_rect.height - 20 };

    // GuiScrollPanel(rule_rect, null, rule_content, *state.rule_scroll, *state.rule_view);
    // BeginScissorMode(xx state.rule_view.x, xx state.rule_view.y, xx state.rule_view.width, xx state.rule_view.height);
    // for *state.tileset.rules {
    //     draw_rule(it, state, it_index, { x + 10 + state.rule_scroll.x, anchor.y + 80 + state.rule_scroll.y });
    //     x += 120;
    // }
    // EndScissorMode();

    // Status bar.
    GuiStatusBar(.{}, "Status: Hello;World: 01");
}

draw_tileset_picker :: (using state: *Editor_Tileset_Mode, anchor: Vector2) {
    content_rect := Rectangle.{0, 0, tileset.texture.width * tileset_zoom, tileset.texture.height * tileset_zoom };

    GuiScrollPanel(tileset_rect, null, content_rect, *tileset_scroll, *tileset_view);

    src := Rectangle.{ 0, 0, xx tileset.texture.width, xx tileset.texture.height };
    dst := Rectangle.{
        tileset_view.x + tileset_scroll.x,
        tileset_view.y + tileset_scroll.y,
        tileset.texture.width * tileset_zoom,
        tileset.texture.height * tileset_zoom
    };

    BeginScissorMode(xx tileset_view.x, xx tileset_view.y, xx tileset_view.width, xx tileset_view.height);
        DrawTexturePro(tileset.texture, src, dst, .{ 0, 0 }, 0, WHITE);
        // Hovered tile.
        tx, ty := tile_coords(state.hovered_tile, state.tileset.cols);
        DrawRectangleLinesEx(.{
            tx * state.tile_size + dst.x,
            ty * state.tile_size + dst.y,
            state.tile_size,
            state.tile_size,
        }, 1.5, RED);

        // Selected tiles.
        for tile_index: state.selected_tiles {
            tx, ty = tile_coords(tile_index, state.tileset.cols);
            DrawRectangleLinesEx(.{
                dst.x + tx * state.tile_size,
                dst.y + ty * state.tile_size,
                state.tile_size,
                state.tile_size,
            }, 1.5, GREEN);
        }
    EndScissorMode();
}

draw_tileset_collision_picker :: (state: *Editor_Tileset_Mode, anchor: Vector2) {
    // collision picker
    GuiToggleGroup(.{ anchor.x, anchor.y, 120, 25, }, "EMPTY;SOLID;SLOPE_UP;SLOPE_DOWN", xx *state.selected_collision);
}
