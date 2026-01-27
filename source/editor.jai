Editor_State :: struct {
    mode: Editor_Mode = .TILESET_MODE;
    camera: Camera2D;
    game: *Game_State;

    mouse_inside_editor := false;
    show_grid := true;

    bottom_panel: Rectangle = .{ 0, 0, 0, 300 };

    tileset_state: Editor_Tileset_State;
}

Editor_Tileset_State :: struct {
    tileset: *Tileset;
    tileset_rect: Rectangle;
    tile_size: float = xx TILE_SIZE;

    // Data.
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
    select_mode: Editor_Tileset_Select_Mode = .SINGLE_MODE;
}

Editor_Mode :: enum u8 {
    TILESET_MODE;
}

Editor_Tileset_Select_Mode :: enum u8 {
    SINGLE_MODE;
    MULTIPLE_MODE;
}

editor_init :: (editor: *Editor_State, game: *Game_State) {
    editor.game = game;
    editor.camera.zoom = 4;
    editor.camera.offset = .{ xx (virtual_width * 0.5), xx (virtual_height * 0.5) };
    editor.camera.target = game.player.position;

    editor_init_panels(editor);

    // Tileset state.
    found := false;
    found, editor.tileset_state.tileset = table_find(*g_assets.tilesets, "default");
    if !found {
        log_error("tileset default not found");
        return;
    }

    tileset_aspect := cast(float) editor.tileset_state.tileset.texture.width / cast(float) editor.tileset_state.tileset.texture.height;
    editor.tileset_state.tileset_rect = .{
        editor.bottom_panel.x,
        editor.bottom_panel.y + 64,
        xx ((editor.bottom_panel.height - 64) * tileset_aspect),
        xx (editor.bottom_panel.height - 64)
    };
    editor.tileset_state.tile_size = cast(float) editor.tileset_state.tileset_rect.width / cast(float) editor.tileset_state.tileset.cols;
    editor.tileset_state.selected_collision = editor.tileset_state.tileset.collisions[0];

    // Resize selected tiles for entire tileset.
    array_reserve(*editor.tileset_state.selected_tiles, editor.tileset_state.tileset.cols * editor.tileset_state.tileset.rows);
}

editor_init_panels :: (editor: *Editor_State) {
    editor.bottom_panel.y = window_height - editor.bottom_panel.height;
    editor.bottom_panel.width = window_width - editor.bottom_panel.x;
}

editor_update :: (e: *Editor_State, dt: float) {
    level := e.game.world.levels[e.game.world.current_level];
    camera_update(*e.camera, .{ xx window_width, xx window_height, level.rect.width * 2, level.rect.height * 2});

    mouse_pos := GetMousePosition();
    e.mouse_inside_editor = CheckCollisionPointRec(mouse_pos, e.bottom_panel);

    if e.mouse_inside_editor {
        if e.mode == {
            case .TILESET_MODE; editor_update_tileset_mode(*e.tileset_state, mouse_pos);
        }
    } else {
        tx, ty := editor_mouse_tile(e.camera, mouse_pos);
        if tx < 0 || ty < 0 || tx >= level.tilemaps[0].width || ty >= level.tilemaps[0].height then return;
        idx := tile_index(tx, ty, level.tilemaps[0].width);
        if IsMouseButtonDown(MOUSE_LEFT_BUTTON) {
            // level.tilemaps[0].auto_tiles[idx] = e.selected_tile;
            level.tilemaps[0].collisions[idx] = e.tileset_state.selected_collision;
            tilemap_update_autotiling(*level.tilemaps[0], tx, ty);
        }
        if IsMouseButtonDown(MOUSE_RIGHT_BUTTON) {
            level.tilemaps[0].collisions[idx] = .EMPTY;
            level.tilemaps[0].auto_tiles[idx] = -1;
            tilemap_update_autotiling(*level.tilemaps[0], tx, ty);
        }
    }
}

editor_update_tileset_mode :: (state: *Editor_Tileset_State, mouse_pos: Vector2) {
    // for tile_index: state.selected_tiles {
    //     state.tileset.collisions[tile_index] = state.selected_collision;
    // }

    if CheckCollisionPointRec(mouse_pos, state.tileset_rect) {
        tx := world_to_tile_x(mouse_pos.x - state.tileset_rect.x, xx state.tile_size);
        ty := world_to_tile_y(mouse_pos.y - state.tileset_rect.y, xx state.tile_size);
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
        } else if IsMouseButtonDown(MOUSE_RIGHT_BUTTON) {
            array_ordered_remove_by_value(*state.selected_tiles, state.hovered_tile);
        }

        state.last_selected_tile = state.hovered_tile;
    }

    if state.save_tileset_data_pressed {
        save_tileset_data_to_file(state.tileset, "tilesets/tileset");
    }
    if state.add_new_rule_pressed {
        array_add(*state.tileset.rules);
    }

    if state.should_delete_rule_index != -1 {
        array_ordered_remove_by_index(*state.tileset.rules, state.should_delete_rule_index);
        state.should_delete_rule_index = -1;
    }
}

editor_draw :: (e: *Editor_State) {
    ClearBackground(BLACK);

    BeginMode2D(e.camera);
        world_draw(e.game.world, e.camera);
        debug_draw_game(e.game);

        player_draw(*e.game.player);

        editor_draw_overlays(e);
    EndMode2D();

    editor_draw_ui(e);
}

editor_draw_overlays :: (e: *Editor_State) {
    if !e.mouse_inside_editor {
        tx, ty := editor_mouse_tile(e.camera, GetMousePosition());
        rect := Rectangle.{ xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
        DrawRectangleLinesEx(rect, 1.1, RED);

        debug_draw_collider(e.tileset_state.selected_collision, tx, ty);
    }
}

editor_draw_ui :: (e: *Editor_State) {
    // draw_left_panel(e);
    draw_bottom_panel(e);
}

editor_mouse_tile :: inline (cam: Camera2D, mouse_pos: Vector2) -> int, int {
    mouse_world  := GetScreenToWorld2D(mouse_pos, cam);
    return world_to_tile_x(mouse_world.x), world_to_tile_y(mouse_world.y);
}

#scope_file

camera_update :: (camera: *Camera2D, bounds: Rectangle) {
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

draw_bottom_panel :: (editor: *Editor_State) {
    anchor := Vector2.{ editor.bottom_panel.x, editor.bottom_panel.y };

    // Toggle group for state change.
    GuiToggleGroup(.{ anchor.x, anchor.y, 320.0, 24.0 }, "Tileset", xx *editor.mode);
    GuiPanel(.{ anchor.x, anchor.y + 24.0, editor.bottom_panel.width, editor.bottom_panel.height}, null);

    if editor.mode == {
        case .TILESET_MODE; draw_tileset_mode(*editor.tileset_state, anchor);
    }
}

draw_tileset_mode :: (state: *Editor_Tileset_State, anchor: Vector2) {
    draw_tileset_collision_picker(state, .{ anchor.x, anchor.y + 32 });
    draw_tileset_picker(state);

    x := anchor.x + state.tileset_rect.width + 12;

    state.add_new_rule_pressed = xx GuiButton(.{ x, anchor.y + 32, 100, 24 }, "Add new rule");
    state.save_tileset_data_pressed = xx GuiButton(.{ x, anchor.y + 270, 70, 25 }, "Save");

    rule_rect := Rectangle.{ x, anchor.y + 64, window_width - x - 20, 200 };
    rule_content := Rectangle.{ 0, 0, state.tileset.rules.count * 120.0 + 8, rule_rect.height - 20 };

    GuiScrollPanel(rule_rect, null, rule_content, *state.rule_scroll, *state.rule_view);
    BeginScissorMode(xx state.rule_view.x, xx state.rule_view.y, xx state.rule_view.width, xx state.rule_view.height);
    for *state.tileset.rules {
        draw_rule(it, state, it_index, { x + 10 + state.rule_scroll.x, anchor.y + 80 + state.rule_scroll.y });
        x += 120;
    }
    EndScissorMode();
}

draw_tileset_picker :: (state: *Editor_Tileset_State) {
    src := Rectangle.{ 0, 0, xx state.tileset.texture.width, xx state.tileset.texture.height };
    DrawTexturePro(state.tileset.texture, src, state.tileset_rect, .{ 0, 0 }, 0, WHITE);

    // Hovered tile.
    tx, ty := tile_coords(state.hovered_tile, state.tileset.cols);
    DrawRectangleLinesEx(.{
        state.tileset_rect.x + tx * state.tile_size,
        state.tileset_rect.y + ty * state.tile_size,
        state.tile_size,
        state.tile_size,
    }, 1.5, RED);

    // Selected tiles.
    for tile_index: state.selected_tiles {
        tx, ty = tile_coords(tile_index, state.tileset.cols);
        DrawRectangleLinesEx(.{
            state.tileset_rect.x + tx * state.tile_size,
            state.tileset_rect.y + ty * state.tile_size,
            state.tile_size,
            state.tile_size,
        }, 1.5, GREEN);
    }

}

draw_tileset_collision_picker :: (state: *Editor_Tileset_State, anchor: Vector2) {
    // collision picker
    GuiToggleGroup(.{ anchor.x, anchor.y, 80, 25, }, "EMPTY;SOLID;SLOPE_UP;SLOPE_DOWN", xx *state.selected_collision);

}

RULE_PICKER_SIZE :: 24.0;

draw_rule :: (rule: *Tileset_Rule, state: *Editor_Tileset_State, index: int, anchor: Vector2) {
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

make_rule_tstring :: (rules: []Tileset_Rule) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    for i: 0..rules.count-1 {
        print_to_builder(*builder, "mask_%", i);

        if i < rules.count - 1 {
            append(*builder, ";");
        }
    }

    return builder_to_string(*builder,, allocator=temp);
}
