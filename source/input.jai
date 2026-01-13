Input_State :: struct {
    movement: Vector2;
    jump_pressed: bool;
    jump_held: bool;

    mouse_left_down: bool;
    mouse_right_down: bool;

    seed: bool;
}

input_update :: (is: *Input_State) {
    is.movement = .{0, 0};
    if IsKeyDown(.KEY_A) || IsKeyDown(.KEY_LEFT) {
        is.movement.x = -1.0;
    } else if IsKeyDown(.KEY_D) || IsKeyDown(.KEY_RIGHT) {
        is.movement.x = 1.0;
    }

    is.jump_pressed = IsKeyPressed(.KEY_SPACE);
    is.jump_held = IsKeyDown(.KEY_SPACE);

    is.mouse_left_down = IsMouseButtonDown(MOUSE_LEFT_BUTTON);
    is.mouse_right_down = IsMouseButtonDown(MOUSE_RIGHT_BUTTON);

    is.seed = IsKeyPressed(.KEY_E);
}

to_virtual_coords :: inline (pos: Vector2) -> Vector2 {
    return .{
        pos.x / window_width  * VIRTUAL_WIDTH,
        pos.y / window_height * VIRTUAL_HEIGHT,
    };
}
