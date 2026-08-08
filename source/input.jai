Game_Input :: struct {
    movement:      Vector2;
    jump_pressed:  bool;
    run_down:      bool;

    left_pressed, right_pressed: bool;
    up_pressed,   down_pressed:  bool;
    
    plant_pressed: bool;
    reset_plants_pressed: bool;
    undo_seed_pressed: bool;

    toggle_editor_pressed: bool;
}

update_input :: () {
    input := *game.input;
    input.* = .{};

    if IsKeyDown(.KEY_A) || IsKeyDown(.KEY_LEFT)  input.movement.x -= 1;
    if IsKeyDown(.KEY_D) || IsKeyDown(.KEY_RIGHT) input.movement.x += 1;
    if IsKeyDown(.KEY_W) || IsKeyDown(.KEY_UP)    input.movement.y -= 1;
    if IsKeyDown(.KEY_S) || IsKeyDown(.KEY_DOWN)  input.movement.y += 1;

    input.jump_pressed  = IsKeyPressed(.KEY_SPACE);
    input.run_down      = IsKeyDown(.KEY_LEFT_SHIFT);
    
    input.left_pressed  = IsKeyPressed(.KEY_A);
    input.right_pressed = IsKeyPressed(.KEY_D);
    input.up_pressed    = IsKeyPressed(.KEY_W);
    input.down_pressed  = IsKeyPressed(.KEY_S);

    input.plant_pressed = IsKeyPressed(.KEY_E);
    input.reset_plants_pressed = IsKeyPressed(.KEY_R);
    input.undo_seed_pressed = IsKeyPressed(.KEY_Z);
    
    #if EDITOR {
        input.toggle_editor_pressed = IsKeyPressed(.KEY_TAB);
    }
}
