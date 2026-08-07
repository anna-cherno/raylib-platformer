grid_line_thickness :: 0.5;

draw_grid :: (bounds: Rectangle) {
    start_x := cast(s32) (bounds.x / TILE_SIZE);
    end_x := cast(s32) ((bounds.x + bounds.width) / TILE_SIZE);
    start_y := cast(s32) (bounds.y / TILE_SIZE);
    end_y := cast(s32) ((bounds.y + bounds.height) / TILE_SIZE);

    for x: start_x .. end_x {
        DrawLineEx(.{ xx (x * TILE_SIZE), bounds.y}, .{ xx (x * TILE_SIZE), (bounds.y + bounds.height)}, grid_line_thickness, Fade(DARKGRAY, 0.1));
    }

    for y: start_y .. end_y {
        DrawLineEx(.{ bounds.x, xx (y * TILE_SIZE) }, .{bounds.x + bounds.width, xx (y * TILE_SIZE) }, grid_line_thickness, Fade(DARKGRAY, 0.1));
    }
}

draw_bounds :: (bounds: Rectangle) {
    DrawRectangleRec(bounds, RAYWHITE);
}

draw_arrow :: (v: Vector2i, position: Vector2) {
    found, texture := table_find(*g_assets.textures, "arrows");
    if !found then true;
    src := Rectangle.{0, 0, 16, 16};
    dst := Rectangle.{position.x, position.y, 8, 8};

    angle_rad := atan2(xx v.x, xx -v.y);
    angle_deg := angle_rad * (180.0 / PI);

    DrawTexturePro(texture, src, dst, .{0, 0}, angle_deg, WHITE);
}