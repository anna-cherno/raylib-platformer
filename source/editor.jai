Editor_State :: struct {
    mode: Type = Editor_Tileset_Mode;
    camera: Camera2D;

    // Game data.
    level: *Level;
    player: *Player;

    // Assets data.
    tileset_names: []string;

    // Data.
    selected_layer_index: int;
    mouse_inside_editor := false;
    show_grid := true;

    // Panels.
    left_panel_rect:   Rectangle;
    left_panel_view:   Rectangle;
    left_panel_scroll: Vector2;

    bottom_panel_rect:    Rectangle;
    bottom_panel_content: Rectangle;
    bottom_panel_view:    Rectangle;
    bottom_panel_scroll:  Vector2;

    // States.
    tilemap_dropdown_edited_index := -1;
    should_add_new_layer: bool;
    should_delete_layer_index := -1;

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

    selected_collision: Collision_Type = .SOLID;
    hovered_tile: s16;
    selected_tiles: [..]s16;
    last_selected_tile: s16 = -1;
    should_delete_rule_index := -1;

    // Gui states.
    tileset_rect: Rectangle;
    tileset_content_rect: Rectangle;
    tileset_scroll: Vector2;
    tileset_view: Rectangle;
    tileset_zoom := 1.0;
    tile_size: float = xx TILE_SIZE;
    rule_scroll: Vector2;
    rule_view: Rectangle;
    tileset_dropdown_edit: bool;
    tileset_dropdown_active: s32;

    // Buttons.
    should_save_tileset: bool;
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
    assert(editor != null && game != null && game.world != null);

    // Game data.
    editor.level = game.world.levels[game.world.current_level_index];
    editor.player = *game.player;

    // Assets data.
    editor.tileset_names = collect_tileset_names();
    if editor.tileset_names.count == 0 {
        return false, "There is no any tileset found.";
    }

    init_panels(editor);
    init_camera(*editor.camera, editor.player.position);

    if editor.mode == {
        case Editor_Tileset_Mode;
            found, tileset := table_find(*g_assets.tilesets, editor.tileset_names[0]);
            if !found {
                return false, tprint("Tileset % not found in assets table", editor.tileset_names[0]);
            }
            ok, err := init_tileset_mode(editor, tileset);
            if !ok {
                return false, err;
            }
    }
    editor.initialized = true;

    return true, "";
}

editor_update :: (editor: *Editor_State, dt: float) {
    assert(editor && editor.initialized);

    mouse_pos := GetMousePosition();
    editor.mouse_inside_editor =
        CheckCollisionPointRec(mouse_pos, editor.bottom_panel_rect) || CheckCollisionPointRec(mouse_pos, editor.left_panel_rect);

    if editor.mouse_inside_editor {
        if editor.mode == {
            case Editor_Tileset_Mode;
                update_tileset_mode(editor, mouse_pos);
        }
    } else {
        update_camera(*editor.camera);

        layer := editor.level.layers[editor.selected_layer_index];
        tx, ty := editor_mouse_tile(editor.camera, mouse_pos);
        if tx < 0 || ty < 0 || tx >= editor.level.cols || ty >= editor.level.rows then return;

        idx := tile_index(tx, ty, editor.level.cols);
        if IsMouseButtonDown(MOUSE_LEFT_BUTTON) {
            layer.data[idx].collision = editor.tileset_mode.selected_collision;
            tilemap_update_autotiling(*layer, tx, ty, editor.level.cols, editor.level.rows);
        }
        if IsMouseButtonDown(MOUSE_RIGHT_BUTTON) {
            layer.data[idx].collision = .EMPTY;
            layer.data[idx].id = EMPTY_TILE;
            layer.data[idx].flags = 0;
            tilemap_update_autotiling(*layer, tx, ty, editor.level.cols, editor.level.rows);
        }
        if IsKeyDown(.KEY_F) {
            editor.level.fruit = Vector2i.{xx tx, xx ty};
        }
    }
}

editor_close :: (editor: *Editor_State) {
    assert(editor && editor.initialized);

    if editor.tileset_mode.initialized {
        close_tileset_mode(*editor.tileset_mode);
    }

    array_free(editor.tileset_names);

    editor.player = null;
    editor.level = null;
}

editor_draw :: (editor: *Editor_State) {
    ClearBackground(BLACK);

    editor_draw_viewport(editor);

    // Panels.
    draw_left_panel(editor);
    draw_bottom_panel(editor);
}

editor_draw_viewport :: (editor: *Editor_State) {
    BeginMode2D(editor.camera);
        level_draw(editor.level, editor.camera);
        // debug_draw_game(editor.game);
        player_draw(editor.player);

        if !editor.mouse_inside_editor {
            tx, ty := editor_mouse_tile(editor.camera, GetMousePosition());
            rect := Rectangle.{ xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE };
            DrawRectangleLinesEx(rect, 1, RED);

            debug_draw_collider(editor.tileset_mode.selected_collision, tx, ty);
        }
    EndMode2D();
}

editor_mouse_tile :: inline (cam: Camera2D, mouse_pos: Vector2) -> int, int {
    mouse_world  := GetScreenToWorld2D(mouse_pos, cam);
    return world_to_tile_x(mouse_world.x), world_to_tile_y(mouse_world.y);
}

#scope_file

/**
 * Panels.
 */
init_panels :: (editor: *Editor_State) {
    editor.bottom_panel_rect = .{ 0, window_height - 300.0, xx window_width, 300 };
    editor.bottom_panel_content = .{ 0, 0, editor.bottom_panel_rect.width - 5, editor.bottom_panel_rect.height - 30};
    editor.left_panel_rect = .{ 0, 0, 250, window_height - editor.bottom_panel_rect.height };
}

draw_left_panel :: (editor: *Editor_State) {
    content_rect := Rectangle.{
        0, 0,
        editor.left_panel_rect.width - 5.0,
        editor.level.layers.count * 48.0 + 50
    };

    GuiScrollPanel(editor.left_panel_rect, "Tilemap Layers", content_rect,
        *editor.left_panel_scroll, *editor.left_panel_view);

    layers_anchor := Vector2.{ content_rect.x + 12, content_rect.y + 32 };
    BeginScissorMode(
        xx editor.left_panel_view.x,
        xx editor.left_panel_view.y,
        xx editor.left_panel_view.width,
        xx editor.left_panel_view.height
    );
        editor.should_add_new_layer = xx GuiButton(
            .{
                layers_anchor.x + editor.left_panel_scroll.x,
                layers_anchor.y + editor.left_panel_scroll.y + editor.level.layers.count * 48.0,
                225, 24
            },
            "Add new layer"
        );
        for * editor.level.layers {
            draw_tilemap_layer_item(editor, it, it_index, layers_anchor + editor.left_panel_scroll);
            layers_anchor.y += 48;
        }
    EndScissorMode();
}

draw_bottom_panel :: (editor: *Editor_State) {
    anchor := Vector2.{ editor.bottom_panel_rect.x, editor.bottom_panel_rect.y };

    // Change editor mode.
    GuiScrollPanel(
        editor.bottom_panel_rect,
        "Tileset Editor",
        editor.bottom_panel_content,
        *editor.bottom_panel_scroll,
        *editor.bottom_panel_view
    );

    BeginScissorMode(
        xx editor.bottom_panel_view.x,
        xx editor.bottom_panel_view.y,
        xx editor.bottom_panel_view.width,
        xx editor.bottom_panel_view.height
    );
        if editor.mode == {
            case Editor_Tileset_Mode; draw_tileset_mode(editor);
        }
    EndScissorMode();

    mode := 0;
    GuiToggleGroup(.{ anchor.x, anchor.y, 150, 24 }, "Tileset Editor", xx *mode);
    if mode == {
        case 0; editor.mode = Editor_Tileset_Mode;
    }

}

/**
 * Camera.
 */
init_camera :: (camera: *Camera2D, initial_position: Vector2) {
    assert(camera != null);

    camera.zoom = 4;
    camera.offset = .{ xx (window_width * 0.5), xx (window_height * 0.5) };
    camera.target = initial_position;
}

update_camera :: (camera: *Camera2D) {
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
init_tileset_mode :: (editor: *Editor_State, tileset: *Tileset) -> ok: bool, err: string {
    editor.tileset_mode.tileset_rect = .{
        editor.bottom_panel_rect.x,
        editor.bottom_panel_rect.y + 52,
        xx clamp(tileset.texture.width, 150, 350),
        editor.bottom_panel_rect.height - 82
    };
    editor.tileset_mode.tileset = tileset;
    editor.tileset_mode.tile_size = xx tileset.tile_size;
    editor.tileset_mode.initialized = true;

    return true, "";
}

close_tileset_mode :: (state: *Editor_Tileset_Mode) {
    assert(state.initialized);

    state.tileset = null;
    array_reset(*state.selected_tiles);

    state.initialized = false;
}

update_tileset_mode :: (using editor: *Editor_State, mouse_pos: Vector2) {
    assert(tileset_mode.initialized);

    if CheckCollisionPointRec(mouse_pos, tileset_mode.tileset_rect) {
        wheel := GetMouseWheelMove();
        if wheel != 0 && IsKeyDown(.KEY_LEFT_ALT) {
            mouse_screen := GetMousePosition();
            zoom_factor := 1.0 + wheel * 0.05;
            tileset_mode.tileset_zoom = clamp(tileset_mode.tileset_zoom * zoom_factor, 0.5, 6);
            tileset_mode.tile_size = cast(float) tileset_mode.tileset.texture.width / cast(float) tileset_mode.tileset.cols * tileset_mode.tileset_zoom;
        }

        tx := world_to_tile_x(mouse_pos.x - (tileset_mode.tileset_view.x + tileset_mode.tileset_scroll.x), xx tileset_mode.tile_size);
        ty := world_to_tile_y(mouse_pos.y - (tileset_mode.tileset_view.y + tileset_mode.tileset_scroll.y), xx tileset_mode.tile_size);
        tx = clamp(tx, 0, tileset_mode.tileset.cols-1);
        ty = clamp(ty, 0, tileset_mode.tileset.rows-1);
        tileset_mode.hovered_tile = xx tile_index(tx, ty, tileset_mode.tileset.cols);

        if IsMouseButtonDown(MOUSE_LEFT_BUTTON) {
            selected_tile := tileset_mode.hovered_tile;
            if IsKeyDown(.KEY_LEFT_SHIFT) {
                if !array_find(tileset_mode.selected_tiles, selected_tile) {
                    array_add(*tileset_mode.selected_tiles, selected_tile);
                }
            } else {
                array_reset(*tileset_mode.selected_tiles);
                array_add(*tileset_mode.selected_tiles, selected_tile);
                tileset_mode.selected_collision = tileset_mode.tileset.collisions[selected_tile];
            }
            tileset_mode.last_selected_tile = selected_tile;
        } else if IsMouseButtonDown(MOUSE_RIGHT_BUTTON) {
            array_ordered_remove_by_value(*tileset_mode.selected_tiles, tileset_mode.hovered_tile);
        }
    }

    if should_add_new_layer {
        array_add(*level.layers, tilemap_create(level, tileset_mode.tileset));
        should_add_new_layer = false;
    }
    if should_delete_layer_index != -1 {
        array_ordered_remove_by_index(*level.layers, should_delete_layer_index);
        should_delete_layer_index = -1;
    }

    if tileset_mode.should_save_tileset {
        save_tileset_data_to_file(tileset_mode.tileset);
    }
    if tileset_mode.add_new_rule_pressed {
        array_add(*tileset_mode.tileset.rules);
    }

    if tileset_mode.should_delete_rule_index != -1 {
        array_ordered_remove_by_index(*tileset_mode.tileset.rules, tileset_mode.should_delete_rule_index);
        tileset_mode.should_delete_rule_index = -1;
    }

    loaded_tileset_name := tileset_names[tileset_mode.tileset_dropdown_active];
    if loaded_tileset_name != tileset_mode.tileset.name {
        found := false;
        found, tileset_mode.tileset = table_find(*g_assets.tilesets, loaded_tileset_name);
    }
}

draw_tileset_mode :: (editor: *Editor_State) {
    assert(editor.initialized && editor.tileset_mode.initialized);

    draw_tileset_picker(*editor.tileset_mode);
    // editor.bottom_panel_content.width = editor.tileset_mode.tileset_content_rect.width;
    draw_collision_picker(*editor.tileset_mode, .{ editor.tileset_mode.tileset_rect.x, editor.tileset_mode.tileset_rect.y + editor.tileset_mode.tileset_rect.height });

    // tileset dropdown.
    anchor := Vector2.{ editor.bottom_panel_rect.x, editor.bottom_panel_rect.y + 25 };
    dropdown_text := join(..editor.tileset_names, ";",, allocator = temp);
    if GuiDropdownBox(
        .{ anchor.x, anchor.y, editor.tileset_mode.tileset_rect.width - 55, 25 },
        get_c_string(dropdown_text),
        *editor.tileset_mode.tileset_dropdown_active,
        editor.tileset_mode.tileset_dropdown_edit
    ) then editor.tileset_mode.tileset_dropdown_edit = !editor.tileset_mode.tileset_dropdown_edit;


    anchor += editor.bottom_panel_scroll;
    // editor.bottom_panel_content.width +=
    draw_tileset_rules(*editor.tileset_mode, .{editor.tileset_mode.tileset_rect.width + 5, anchor.y });

    editor.tileset_mode.should_save_tileset = xx GuiButton(.{ editor.tileset_mode.tileset_rect.width - 50, anchor.y, 50, 25 }, "Save");
}

draw_tileset_picker :: (state: *Editor_Tileset_Mode) {
    content_rect := Rectangle.{0, 0, state.tileset.texture.width * state.tileset_zoom - 2, state.tileset.texture.height * state.tileset_zoom };

    GuiScrollPanel(state.tileset_rect, null, content_rect, *state.tileset_scroll, *state.tileset_view);

    src := Rectangle.{ 0, 0, xx state.tileset.texture.width, xx state.tileset.texture.height };
    dst := Rectangle.{
        state.tileset_view.x + state.tileset_scroll.x,
        state.tileset_view.y + state.tileset_scroll.y,
        state.tileset.texture.width * state.tileset_zoom,
        state.tileset.texture.height * state.tileset_zoom
    };

    BeginScissorMode(xx state.tileset_view.x, xx state.tileset_view.y, xx state.tileset_view.width, xx state.tileset_view.height);
        DrawTexturePro(state.tileset.texture, src, dst, .{ 0, 0 }, 0, WHITE);
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

draw_collision_picker :: (state: *Editor_Tileset_Mode, anchor: Vector2) {
    selected_collision: s32 = xx state.selected_collision;
    GuiToggleGroup( .{ anchor.x, anchor.y, state.tileset_rect.width / 4 - 1, 24 }, "EMPTY;SOLID;SLOPE_UP;SLOPE_DOWN", *selected_collision );

    if selected_collision != xx state.selected_collision {
        state.selected_collision = xx selected_collision;
    }
}

draw_tileset_rules :: (state: *Editor_Tileset_Mode, anchor: Vector2) -> float {
    x := anchor.x;
    for * state.tileset.rules {
        draw_rule(state, it, it_index, { x, anchor.y + 38 });
        x += 120;
    }

    state.add_new_rule_pressed = xx GuiButton(.{ anchor.x, anchor.y, 100, 25 }, "Add new rule");

    return x;
}

RULE_PICKER_SIZE :: 24.0;

draw_rule :: (state: *Editor_Tileset_Mode, rule: *Tileset_Rule, index: int, anchor: Vector2) {
    GuiGroupBox(.{ anchor.x, anchor.y, 112, 160 }, tprint("Rule %\0", index).data);

    draw_rule_grid_mask(rule, .{ anchor.x + 8, anchor.y + 8 });

    x := anchor.x + 8;
    y := anchor.y + RULE_PICKER_SIZE * 3 + 10;

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
    if GuiButton(.{ x + 74, y, 24, 24 }, "#143#") {
        state.should_delete_rule_index = index;
    }

    // Mirror X.
    GuiToggle(.{ x + RULE_PICKER_SIZE * 3 + 2, anchor.y + 8, 24, 24 }, "#40#", *rule.mirror_x);
    // Mirror Y.
    GuiToggle(.{ x + RULE_PICKER_SIZE * 3 + 2, anchor.y + 32, 24, 24 }, "#41#", *rule.mirror_y);

    // Active.
    GuiToggle(.{ x + RULE_PICKER_SIZE * 3 + 2, anchor.y + 56, 24, 24 }, "#212#", *rule.active);


    x = anchor.x + 8;
    y += 28;
    tile_size := 16;
    for tile_id: rule.tile_ids {
        tx, ty := tile_coords(tile_id, state.tileset.cols);
        if x + tile_size > anchor.x + 112 {
            x = anchor.x + 8;
            y += tile_size;
        }
        draw_tile(state.tileset.texture, .{ tx, ty }, .{ x, y }, 1.0, xx state.tileset.tile_size);
        x += tile_size + 1.0;
    }
}

draw_rule_grid_mask :: (rule: *Tileset_Rule, anchor: Vector2) {
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

collect_tileset_names :: () -> []string {
    names: [..]string;

    array_reserve(*names, g_assets.tilesets.count);

    for g_assets.tilesets {
        array_add(*names, it_index);
    }

    return names;
}

/**
 * Tilemap Layers.
 */
draw_tilemap_layer_item :: (editor: *Editor_State, tilemap: *Tilemap, index: int, anchor: Vector2) {
    GuiGroupBox(.{ anchor.x, anchor.y, 225, 40 }, tprint("Layer %\0", index).data);

    margin_top :: 8.0;
    margin_between :: 4.0;

    ok, tileset_index := array_find(editor.tileset_names, tilemap.tileset.name);
    if !ok {
        return;
    }

    dropdown_text := join(..editor.tileset_names, ";",, allocator=temp);
    edit := editor.tilemap_dropdown_edited_index == index;
    if GuiDropdownBox(.{ anchor.x + margin_between, anchor.y + margin_top, 105, 25 }, get_c_string(dropdown_text), xx *tileset_index, edit ) {
        if edit {
            editor.tilemap_dropdown_edited_index = -1;
            name := editor.tileset_names[tileset_index];
            ok, tilemap.tileset = table_find(*g_assets.tilesets, name);
        } else {
            editor.tilemap_dropdown_edited_index = index;
        }
    }

    icon := ifx tilemap.visible then "#44#" else "#45#";

    x := anchor.x + 105 + margin_between * 2;
    GuiToggle(.{ x, anchor.y + margin_top, 25, 25 }, get_c_string(icon), *tilemap.visible);

    x += 25 + margin_between;
    if GuiButton(.{ x, anchor.y + margin_top, 25, 25 }, "#121#") {
        if index + 1 < editor.level.layers.count {
            swap(*editor.level.layers[index+1], *editor.level.layers[index]);
        }
    }
    x += 25;
    if GuiButton(.{ x, anchor.y + margin_top, 25, 25 }, "#120#") {
        if index - 1 >= 0 {
            swap(*editor.level.layers[index-1], *editor.level.layers[index]);
        }
    }

    x += 25 + margin_between;
    if GuiButton(.{ x, anchor.y + margin_top, 25, 25 }, "#143#") {
        editor.should_delete_layer_index = index;
    }
}
