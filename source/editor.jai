Editor :: struct {
    mode: Type = Editor_Tileset_Mode;
    camera: Camera2D;

    // Assets data.
    tileset_names: []string;

    // Data.
    selected_layer_index: int;
    mouse_inside_editor := false;
    show_grid := true;
    hovered_tile: Vector2i;

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
    tileset_min_width := 450.0;
    tileset_rect: Rectangle;
    tileset_content_rect: Rectangle;
    tileset_scroll: Vector2;
    tileset_view: Rectangle;
    tileset_zoom := 3.0;
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

init_editor :: () -> bool {
    assert(game.state == .RUNNING);

    editor.tileset_names = collect_tileset_names();
    if editor.tileset_names.count == 0 {
        log_warning("[РЕДАКТОР]: Не найдено ни одного тайлсета");
    }

    init_editor_panels();
    init_editor_camera();

    // Режимы редактора.
    if !init_editor_tileset_mode() {
        log_error("[РЕДАКТОР]: Не удалось инициализировать редактор в режиме тайлсет");
        return false;
    }
    
    editor.initialized = true;

    return true;
}

update_editor :: (dt: float) {
    assert(editor.initialized);

    mouse_pos := GetMousePosition();
    editor.mouse_inside_editor =
        CheckCollisionPointRec(mouse_pos, editor.bottom_panel_rect) ||
        CheckCollisionPointRec(mouse_pos, editor.left_panel_rect);

    if editor.mouse_inside_editor {
        if editor.mode == {
            case Editor_Tileset_Mode;
                update_editor_tileset_mode(mouse_pos);
        }
        return;
    }
    
    update_editor_camera();

    level := current_level();
    layer := level.layers[editor.selected_layer_index];
    tx, ty := editor_mouse_tile(mouse_pos);
    if tx >= 0 && ty >= 0 && tx < level.cols && ty < level.rows {
        editor.hovered_tile = .{xx tx, xx ty};
    }

    idx := tile_index(tx, ty, level.cols);
    if idx >= 0 && idx < layer.data.count {
        if IsMouseButtonDown(MOUSE_LEFT_BUTTON) {
            layer.data[idx].collision = editor.tileset_mode.selected_collision;
            tilemap_update_autotiling(*layer, tx, ty, level.cols, level.rows);
        }
        if IsMouseButtonDown(MOUSE_RIGHT_BUTTON) {
            layer.data[idx].collision = .EMPTY;
            layer.data[idx].id = EMPTY_TILE;
            layer.data[idx].flags = 0;
            tilemap_update_autotiling(*layer, tx, ty, level.cols, level.rows);
        }
    }
    if IsKeyDown(.KEY_F) {
        level.fruit = Vector2i.{xx tx, xx ty};
    }
}

deinit_editor :: () -> bool {
    assert(editor.initialized);

    if editor.tileset_mode.initialized {
        deinit_editor_tileset_mode();
    }

    array_free(editor.tileset_names);
    editor.initialized = false;

    return true;
}

draw_editor_overlay :: () {
    draw_editor_left_panel();
    draw_editor_bottom_panel();
}

draw_editor_tile_hovers :: () {
    if editor.mouse_inside_editor then return;
    rect := Rectangle.{
        xx (editor.hovered_tile.x * TILE_SIZE),
        xx (editor.hovered_tile.y * TILE_SIZE),
        xx TILE_SIZE,
        xx TILE_SIZE,
    };
    DrawRectangleLinesEx(rect, 1, ORANGE);
}

editor_mouse_tile :: inline (mouse_pos: Vector2) -> int, int {
    mouse_world := GetScreenToWorld2D(mouse_pos, editor.camera);
    return world_to_tile_x(mouse_world.x), world_to_tile_y(mouse_world.y);
}

#scope_file

/**
 * Panels.
 */
init_editor_panels :: () {
    editor.bottom_panel_rect = .{ 0, window_height - 300.0, xx window_width, 300 };
    editor.bottom_panel_content = .{ 0, 0, editor.bottom_panel_rect.width - 5, editor.bottom_panel_rect.height - 30};
    editor.left_panel_rect = .{ 0, 0, 250, window_height - editor.bottom_panel_rect.height };
}

draw_editor_left_panel :: () {
    level  := current_level();
    content_rect := Rectangle.{
        0, 0,
        editor.left_panel_rect.width - 5.0,
        level.layers.count * 48.0 + 50
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
                layers_anchor.y + editor.left_panel_scroll.y + level.layers.count * 48.0,
                225, 24
            },
            "Add new layer"
        );
        for * level.layers {
            draw_tilemap_layer_item(it, it_index, layers_anchor + editor.left_panel_scroll);
            layers_anchor.y += 48;
        }
    EndScissorMode();
}

draw_editor_bottom_panel :: () {
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
            case Editor_Tileset_Mode; draw_editor_tileset_mode();
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
init_editor_camera :: () {
    editor.camera.zoom = 4;
    editor.camera.offset = .{ xx (window_width * 0.5), xx (window_height * 0.5) };
    editor.camera.target = game.player.position;
}

update_editor_camera :: () {
    camera := *editor.camera;
    
    if IsMouseButtonDown(MOUSE_MIDDLE_BUTTON) {
        delta := GetMouseDelta();
        camera.target -= delta / camera.zoom;
    }

    wheel := GetMouseWheelMove();
    if wheel != 0 {
        mouse_screen := GetMousePosition();
        before := GetScreenToWorld2D(mouse_screen, camera);
        zoom_factor := 1.0 + wheel * 0.05;
        camera.zoom = clamp(camera.zoom * zoom_factor, 0.2, 10);
        after := GetScreenToWorld2D(mouse_screen, camera);
        camera.target += before - after;
    }
}

/**
 * Tileset Mode.
 */
init_editor_tileset_mode :: () -> bool {
    assert(editor.tileset_names.count > 0);
    
    tileset := table_find_pointer(*assets.tilesets, editor.tileset_names[0]);
    if tileset == null {
        log_error("Не удалось найти тайлсет %s среди ассетов", *editor.tileset_names[0]);
        return false; 
    }
    
    editor.tileset_mode.tileset_rect = .{
        editor.bottom_panel_rect.x,
        editor.bottom_panel_rect.y + 52,
        xx clamp(tileset.texture.width, 300, 450),
        editor.bottom_panel_rect.height - 82
    };
    editor.tileset_mode.tileset = tileset;
    editor.tileset_mode.tile_size = tileset.texture.width / tileset.cols * editor.tileset_mode.tileset_zoom;
    editor.tileset_mode.initialized = true;

    return true;
}

deinit_editor_tileset_mode :: () {
    state := *editor.tileset_mode;
    assert(state.initialized);

    state.tileset = null;
    array_reset(*state.selected_tiles);

    state.initialized = false;
}

update_editor_tileset_mode :: (mouse_pos: Vector2) {
    using editor;
    assert(editor.tileset_mode.initialized);

    if CheckCollisionPointRec(mouse_pos, tileset_mode.tileset_rect) {
        wheel := GetMouseWheelMove();
        if wheel != 0 && IsKeyDown(.KEY_LEFT_ALT) {
            mouse_screen := GetMousePosition();
            zoom_factor := 1.0 + wheel * 0.05;
            tileset_mode.tileset_zoom = clamp(tileset_mode.tileset_zoom * zoom_factor, 2, 6);
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

    level := current_level();
    if should_add_new_layer {
        array_add(*level.layers, create_tilemap(level, tileset_mode.tileset));
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
        tileset_mode.tileset = table_find_pointer(*assets.tilesets, loaded_tileset_name);
    }
}

draw_editor_tileset_mode :: () {
    assert(editor.initialized && editor.tileset_mode.initialized);

    draw_tileset_picker(*editor.tileset_mode);
    // editor.bottom_panel_content.width = editor.tileset_mode.tileset_content_rect.width;
    draw_collision_picker(*editor.tileset_mode, .{ editor.tileset_mode.tileset_rect.x, editor.tileset_mode.tileset_rect.y + editor.tileset_mode.tileset_rect.height });

    // tileset dropdown.
    anchor := Vector2.{ editor.bottom_panel_rect.x, editor.bottom_panel_rect.y + 25 };
    dropdown_text := join(..editor.tileset_names, ";",, allocator = temp);
    if GuiDropdownBox(
        .{ anchor.x, anchor.y, editor.tileset_mode.tileset_rect.width - 55, 25 },
        to_c_string(dropdown_text),
        *editor.tileset_mode.tileset_dropdown_active,
        editor.tileset_mode.tileset_dropdown_edit
    ) then editor.tileset_mode.tileset_dropdown_edit = !editor.tileset_mode.tileset_dropdown_edit;


    anchor += editor.bottom_panel_scroll;
    // editor.bottom_panel_content.width +=
    draw_tileset_rules(*editor.tileset_mode, .{editor.tileset_mode.tileset_rect.width + 5, anchor.y });

    editor.tileset_mode.should_save_tileset = xx GuiButton(.{ editor.tileset_mode.tileset_rect.width - 50, anchor.y, 50, 25 }, "Save");
}

// Draws the tileset picker GUI..
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

    array_reserve(*names, assets.tilesets.count);

    for assets.tilesets {
        array_add(*names, it_index);
    }

    return names;
}

/**
 * Tilemap Layers.
 */
draw_tilemap_layer_item :: (tilemap: *Tilemap, index: int, anchor: Vector2) {
    GuiGroupBox(.{ anchor.x, anchor.y, 225, 40 }, tprint("Layer %\0", index).data);

    margin_top :: 8.0;
    margin_between :: 4.0;

    ok, tileset_index := array_find(editor.tileset_names, tilemap.tileset.name);
    if !ok {
        return;
    }

    dropdown_text := join(..editor.tileset_names, ";",, allocator=temp);
    edit := editor.tilemap_dropdown_edited_index == index;
    if GuiDropdownBox(.{ anchor.x + margin_between, anchor.y + margin_top, 105, 25 }, to_c_string(dropdown_text), xx *tileset_index, edit ) {
        if edit {
            editor.tilemap_dropdown_edited_index = -1;
            name := editor.tileset_names[tileset_index];
            tilemap.tileset = table_find_pointer(*assets.tilesets, name);
        } else {
            editor.tilemap_dropdown_edited_index = index;
        }
    }

    icon := ifx tilemap.visible then "#44#" else "#45#";

    x := anchor.x + 105 + margin_between * 2;
    GuiToggle(.{ x, anchor.y + margin_top, 25, 25 }, to_c_string(icon), *tilemap.visible);

    x += 25 + margin_between;
    level := current_level();
    if GuiButton(.{ x, anchor.y + margin_top, 25, 25 }, "#121#") {
        if index + 1 < level.layers.count {
            swap(*level.layers[index+1], *level.layers[index]);
        }
    }
    x += 25;
    if GuiButton(.{ x, anchor.y + margin_top, 25, 25 }, "#120#") {
        if index - 1 >= 0 {
            swap(*level.layers[index-1], *level.layers[index]);
        }
    }

    x += 25 + margin_between;
    if GuiButton(.{ x, anchor.y + margin_top, 25, 25 }, "#143#") {
        editor.should_delete_layer_index = index;
    }
}
