Debug :: struct {
    enabled := true;

    show_camera := true;
    show_entity_info := true;
    show_player_colliders := true;
    show_world_colliders := true;
    show_grid := false;

    time_scale := 1.0;
    seed_len := 0;
    plant_pos: Vector2i;
    plant_pos_vec: Vector2;

    min_tx, max_tx: int;
    min_ty, max_ty: int;
}

init_debug :: () -> bool {
    // GuiSetStyle(xx GuiControl.DEFAULT, xx GuiDefaultProperty.TEXT_SIZE, 10);
    return true;
}

deinit_debug :: () -> bool {
    return true;
}

update_debug :: () {
    if IsKeyPressed(.KEY_F1) {
        debug.enabled = !debug.enabled;
    }
}

draw_debug_ui :: () {
    anchor := Vector2.{window_width-200.0, 0 };
    debug_rec := Rectangle.{anchor.x, anchor.y, 200, 100};
    margin := 15.0;
    padding := 5.0;

    GuiPanel(debug_rec, null);

    player := *game.player;

    // Player position.
    y := debug_rec.y + padding;
    GuiLabel(
        .{debug_rec.x + padding, y, 200, 20},
        tprint("Position: %\0", player.position).data,
    );

    // Player is on ground
    y += margin;
    GuiLabel(
        .{debug_rec.x + padding, y, 200, 20},
        tprint("On ground: %\0", player.is_grounded).data,
    );

    // Movement state.
    y += margin;
    GuiLabel(
        .{debug_rec.x + padding, y, 200, 20},
        tprint("Movement state %\0", player.state).data,
    );

    // Velocity.
    y += margin;
    GuiLabel(
        .{debug_rec.x + padding, y, 300, 20},
        tprint("Velocity %\0", player.velocity).data,
    );

    // Game mode.
    y += margin;
    GuiLabel(
        .{debug_rec.x + padding, y, 250, 20},
        tprint("Game mode %\0", game.mode).data,
    );
}

draw_debug_game :: () {
    if debug.show_player_colliders {
        draw_debug_player_colliders();
    }
    if debug.show_grid {
        draw_grid(game.world.levels[game.world.current_level_index].bounds);
    }

    if debug.plant_pos.x > 0 && debug.plant_pos.y > 0 {
        DrawRectangle(debug.plant_pos.x * TILE_SIZE, debug.plant_pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, Fade(RED, 0.1));
    }
    if debug.plant_pos_vec.x > 0 && debug.plant_pos_vec.y > 0 {
        DrawCircleV(debug.plant_pos_vec, 2.0, RED);
    }
}

draw_debug_collider :: (col: Collision_Type, tx: int, ty: int) {
    color := Fade(DARKBLUE, 0.5);

    top    := cast(float) ty * TILE_SIZE;
    bottom := cast(float) (ty * TILE_SIZE) + TILE_SIZE;
    left   := cast(float) tx * TILE_SIZE;
    right  := cast(float) (tx * TILE_SIZE) + TILE_SIZE;

    if col == {
        case .SOLID;
            DrawRectangle(xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), TILE_SIZE, TILE_SIZE, color);
        case .SLOPE_UP;
            v1 := Vector2.{ left, bottom };
            v2 := Vector2.{ right, bottom };
            v3 := Vector2.{ right, top };
            DrawTriangle(v1, v2, v3, color);
        case .SLOPE_DOWN;
            v1 := Vector2.{ left, bottom };
            v2 := Vector2.{ right, bottom };
            v3 := Vector2.{ left, top };
            DrawTriangle(v1, v2, v3, color);
    }
}

draw_debug_player_colliders :: () {
    for ty: debug.min_ty..debug.max_ty {
        for tx: debug.min_tx..debug.max_tx {
            DrawRectangle(xx (tx * TILE_SIZE), xx (ty * TILE_SIZE), TILE_SIZE, TILE_SIZE, Fade(DARKBLUE, 0.5));
        }
    }

    player := *game.player;
    // pivot
    DrawCircle(xx player.position.x, xx player.position.y, 1, Fade(RED, 0.9));
}
