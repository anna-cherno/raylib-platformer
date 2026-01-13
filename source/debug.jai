Debug_State :: struct {
    enabled: bool;

    show_camera: bool;
    show_entity_info: bool;
    show_player_colliders: bool;
    show_world_colliders: bool;

    time_scale: float;

    show_main_window: bool = true;

    bottom_y: float;

    on_tile: Tile_Type = .EMPTY;

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
    margin :: 30;
    padding :: 10;
    panel := Rectangle.{xx (window_width - 265), 5, 260, 300};

    GuiPanel(panel, "DEBUG");

    // World colliders.
    y := panel.y + margin;
    GuiCheckBox(.{panel.x + padding, y, 20, 20}, "Show world colliders", *g_debug.show_world_colliders);

    // Player colliders.
    y += margin;
    GuiCheckBox(.{panel.x + padding, y, 20, 20}, "Show player colliders", *g_debug.show_player_colliders);

    // Player position.
    y += margin;
    GuiLabel(
        .{panel.x + padding, y, 200, 20},
        tprint("Player position: %, %\0",
            formatFloat(g.player.position.x, trailing_width=2),
            formatFloat(g.player.position.y, trailing_width=2),
        ).data,
    );

    // Player is on ground
    y += margin;
    GuiLabel(
        .{panel.x + padding, y, 200, 20},
        tprint("Player on ground: %\0", g.player.is_grounded).data,
    );

    // Movement state.
    y += margin;
    GuiLabel(
        .{panel.x + padding, y, 200, 20},
        tprint("Player movement state %\0", g.player.state).data,
    );

    // Velocity.
    y += margin;
    GuiLabel(
        .{panel.x + padding, y, 300, 20},
        tprint("Player velocity %\0", g.player.velocity).data,
    );

    // Game mode.
    y += margin;
    GuiLabel(
        .{panel.x + padding, y, 250, 20},
        tprint("Game mode %\0", g.mode).data,

    );
    // bottom y
    y += margin;
    GuiLabel(
        .{panel.x + padding, y, 200, 20},
        tprint("bottom_y %\0", g_debug.bottom_y).data,
    );

    // Seed len.
    y += margin;
    GuiLabel(
        .{panel.x + padding, y, 200, 20},
        tprint("Seed len: %\0", g_game.world.seeds.count).data,
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

            color := DARKBLUE;

            top    := cast(float) y * TILE_SIZE;
            bottom := cast(float) (y * TILE_SIZE) + TILE_SIZE;
            left   := cast(float) x * TILE_SIZE;
            right  := cast(float) (x * TILE_SIZE) + TILE_SIZE;

            if t == {
                case .SOLID;
                    DrawRectangle(xx (x * TILE_SIZE), xx (y * TILE_SIZE), TILE_SIZE, TILE_SIZE, color);
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
