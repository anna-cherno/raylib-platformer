Debug_State :: struct {
    enabled: bool;

    show_colliders: bool;
    show_camera: bool;
    show_entity_info: bool;

    slow_motion: bool;
    time_scale: float;

    show_main_window: bool = true;

    bottom_y: float;

    tx0, ty0: int;
    tx1, ty1: int;

    on_tile: Tile_Type = .EMPTY;
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

    y := panel.y + margin;
    GuiCheckBox(.{panel.x + padding, y, 20, 20}, "Show colliders", *g_debug.show_colliders);

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

    // t0
    y += margin;
    GuiLabel(
        .{panel.x + padding, y, 200, 20},
        tprint("g.player.: %, tx1: %\0", g_debug.tx0, g_debug.tx1).data,
    );
    // t1
    y += margin;
    GuiLabel(
        .{panel.x + padding, y, 200, 20},
        tprint("ty0: %, ty1: %\0", g_debug.ty0, g_debug.ty1).data,
    );

    // tile type
    // y += margin;
    // GuiLabel(
    //     .{panel.x + padding, y, 200, 20},
    //     tprint("Tile Type: %\0", g_debug.on_tile).data,
    // );
}

debug_draw_game :: (g: *Game_State) {
    if g_debug.show_colliders {
        debug_draw_colliders(g);
    }
}

debug_draw_colliders :: (g: *Game_State) {
    // Draw player's collider.
    DrawRectangleRec(player_collider(*g.player), Fade(RED, 0.1));

    // Draw player's pivot.
    DrawCircle(xx g.player.position.x, xx g.player.position.y, 1, Fade(RED, 0.9));

    for tile_x: g_debug.tx0..g_debug.tx1 {
        for tile_y: g_debug.ty0..g_debug.ty1 {
            rect := Rectangle.{xx (tile_x * TILE_SIZE), xx (tile_y * TILE_SIZE), xx TILE_SIZE, xx TILE_SIZE};
            DrawRectangleRec(rect, Fade(BLUE, 0.1));
        }
    }
}

#scope_file

load_style :: (name : string) {
    filename := tprint("%/%", data_folder, name);
    GuiLoadStyle(filename.data);
}
