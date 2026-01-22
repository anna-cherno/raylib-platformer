draw_grid :: (bounds: Rectangle) {
    start_x := cast(s32) (bounds.x / TILE_SIZE);
    end_x := cast(s32) ((bounds.x + bounds.width) / TILE_SIZE);
    start_y := cast(s32) (bounds.y / TILE_SIZE);
    end_y := cast(s32) ((bounds.y + bounds.height) / TILE_SIZE);

    for x: start_x .. end_x {
        DrawLineEx(.{ xx (x * TILE_SIZE), bounds.y}, .{ xx (x * TILE_SIZE), (bounds.y + bounds.height)}, 0.5, Fade(DARKGRAY, 0.1));
    }

    for y: start_y .. end_y {
        DrawLineEx(.{ bounds.x, xx (y * TILE_SIZE) }, .{bounds.x + bounds.width, xx (y * TILE_SIZE) }, 0.5, Fade(DARKGRAY, 0.1));
    }
}

draw_bounds :: (bounds: Rectangle) {
    DrawRectangleRec(bounds, RAYWHITE);
}
