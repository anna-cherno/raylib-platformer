draw_grid :: (bounds: Rectangle) {
    start_x := cast(s32) (bounds.x / TILE_SIZE);
    end_x := cast(s32) ((bounds.x + bounds.width) / TILE_SIZE);
    start_y := cast(s32) (bounds.y / TILE_SIZE);
    end_y := cast(s32) ((bounds.y + bounds.height) / TILE_SIZE);

    for x: start_x .. end_x {
        DrawLine(x * TILE_SIZE, xx bounds.y, x * TILE_SIZE, xx (bounds.y + bounds.height), Fade(DARKGRAY, 0.3));
    }

    for y: start_y .. end_y {
        DrawLine(xx bounds.x, y * TILE_SIZE, xx (bounds.x + bounds.width), y * TILE_SIZE, Fade(DARKGRAY, 0.3));
    }
}

draw_bounds :: (bounds: Rectangle) {
    DrawRectangleRec(bounds, RAYWHITE);
}
