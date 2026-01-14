Debug_State :: struct {
    enabled: bool;

    show_camera: bool;
    show_entity_info: bool;
    show_player_colliders: bool;
    show_world_colliders: bool;

    time_scale: float;
    seed_len: int;
}

debug_init :: () {
    load_style("style_genesis.rgs");
    // GuiSetStyle(xx GuiControl.DEFAULT, xx GuiDefaultProperty.TEXT_SIZE, 10);
}

debug_update :: () {
    if IsKeyPressed(.KEY_F1) {
        g_debug.enabled = !g_debug.enabled;
    }
}

debug_draw_ui :: (g: *Game_State) {
    anchor := Vector2.{window_width-205.0, window_height-115.0};
    debug_rec := Rectangle.{anchor.x, anchor.y, 200, 110};
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

    // Seed len.
    y += margin;
    GuiLabel(
        .{debug_rec.x + padding, y, 200, 20},
        tprint("Seed length: %\0", g_game.world.seeds.count).data,
    );
}

debug_draw_game :: (g: *Game_State) {
    if g_debug.show_world_colliders {
        debug_draw_world_colliders(*g.world);
    }
    if g_debug.show_player_colliders {
        debug_draw_player_colliders(*g.player);
    }
}

debug_draw_world_colliders :: (w: *World) {
    for y: 0..w.t_height-1 {
        for x: 0..w.t_width-1 {
            idx := tile_index(x, y, w.t_width);
            t := w.collisions[idx];
            if t == .EMPTY continue;

            debug_draw_collider(t, x, y);
        }
    }
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

#scope_file

load_style :: (name : string) {
    filename := tprint("%/%", data_folder, name);
    GuiLoadStyle(filename.data);
}
