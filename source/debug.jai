Debug_State :: struct {
    enabled := true;

    show_camera := true;
    show_entity_info := true;
    show_player_colliders := false;
    show_world_colliders := true;
    show_grid := false;

    time_scale := true;
    seed_len := 0;
    plant_pos: Vector2i;
}

debug_init :: () {
    // GuiSetStyle(xx GuiControl.DEFAULT, xx GuiDefaultProperty.TEXT_SIZE, 10);
}

debug_close :: () {

}

debug_update :: () {
    if IsKeyPressed(.KEY_F1) {
        g_debug.enabled = !g_debug.enabled;
    }
}

debug_draw_ui :: (g: *Game_State) {
    anchor := Vector2.{window_width-200.0, 0 };
    debug_rec := Rectangle.{anchor.x, anchor.y, 200, 100};
    margin := 15.0;
    padding := 5.0;

    GuiPanel(debug_rec, null);

    // Player position.
    y := debug_rec.y + padding;
    GuiLabel(
        .{debug_rec.x + padding, y, 200, 20},
        tprint("Position: %\0", g.player.position).data,
    );

    // Player is on ground
    y += margin;
    GuiLabel(
        .{debug_rec.x + padding, y, 200, 20},
        tprint("On ground: %\0", g.player.is_grounded).data,
    );

    // Movement state.
    y += margin;
    GuiLabel(
        .{debug_rec.x + padding, y, 200, 20},
        tprint("Movement state %\0", g.player.state).data,
    );

    // Velocity.
    y += margin;
    GuiLabel(
        .{debug_rec.x + padding, y, 300, 20},
        tprint("Velocity %\0", g.player.velocity).data,
    );

    // Game mode.
    y += margin;
    GuiLabel(
        .{debug_rec.x + padding, y, 250, 20},
        tprint("Game mode %\0", g.mode).data,

    );
}

debug_draw_game :: (g: *Game_State) {
    if g_debug.show_world_colliders {
        debug_draw_world_colliders(g.world);
    }
    if g_debug.show_player_colliders {
        debug_draw_player_colliders(*g.player);
    }
    if g_debug.show_grid {
        draw_grid(g.world.levels[g.world.current_level_index].bounds);
    }

    if g_debug.plant_pos.x > 0 && g_debug.plant_pos.y > 0 {
        DrawRectangle(g_debug.plant_pos.x * TILE_SIZE, g_debug.plant_pos.y * TILE_SIZE, TILE_SIZE, TILE_SIZE, Fade(RED, 0.5));
    }
}

debug_draw_world_colliders :: (w: *World) {
    // for y: 0..w.t_height-1 {
    //     for x: 0..w.t_width-1 {
    //         col := collision_at(x, y, *w.tilemaps[0]);
    //         if col == .EMPTY continue;

    //         debug_draw_collider(col, x, y);
    //     }
    // }
}

debug_draw_collider :: (col: Collision_Type, tx: int, ty: int) {
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

debug_draw_player_colliders :: (p: *Player) {
    // Draw player's collider.
    DrawRectangleRec(player_collider(p), Fade(RED, 0.1));

    // Draw player's pivot.
    DrawCircle(xx p.position.x, xx p.position.y, 1, Fade(RED, 0.9));
}
