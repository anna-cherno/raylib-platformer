#import "Basic";
#import "String";
#import "System";
#import "Math";
#import "raylib";

#load "assets.jai";
#load "animation.jai";
#load "entity.jai";
#load "input.jai";
#load "player.jai";
#load "game.jai";
#load "editor.jai";
#load "world.jai";
#load "draw.jai";
#load "tiles.jai";
#load "debug.jai";

ASPECT  :: 16.0 / 10.0;
HPIXELS :: 400;

VIRTUAL_WIDTH  :: HPIXELS;
VIRTUAL_HEIGHT :: HPIXELS / ASPECT;

SCALE :: 4;

window_width := cast(s32) VIRTUAL_WIDTH * SCALE;
window_height := cast(s32) VIRTUAL_HEIGHT * SCALE;

data_folder : string;

// Global states.
g_game: Game_State;
g_editor: Editor_State;
g_input: Input_State;
g_debug: Debug_State = .{
    enabled = true,
    show_colliders = true,
    show_camera = false,
    show_entity_info = false,
    slow_motion = false,
    time_scale = 1.0
};

main :: () {
    base_path := path_strip_filename(get_path_of_running_executable());
    data_folder = join(base_path, "assets");

    InitWindow(window_width, window_height, "Game about seeding stuff");
    SetTargetFPS(75);

    target := LoadRenderTexture(xx VIRTUAL_WIDTH, xx VIRTUAL_HEIGHT);
    SetTextureFilter(target.texture, .TEXTURE_FILTER_POINT);

    game_init(*g_game);
    editor_init(*g_editor, *g_game);
    debug_init();

    world := world_create("hello", 25, 20);
    game_set_world(*g_game, *world);

    while (!WindowShouldClose()) {
        input_update(*g_input);
        debug_update();
        if IsKeyPressed(.KEY_TAB) {
            toggle_mode();
        }

        dt := GetFrameTime();
        if g_game.mode == .PLAY {
            game_update(*g_game, dt);
        } else if g_game.mode == .EDITOR {
            editor_update(*g_editor, dt);
        }

        // Draw to the target texture.
        if g_game.mode == .PLAY {
            BeginTextureMode(target);
                game_draw(*g_game);
            EndTextureMode();
        }

        // Draw the target texture to the screen.
        BeginDrawing();
            if g_game.mode == .PLAY {
                ClearBackground(DARKGRAY);
                src := Rectangle.{ 0, 0, xx target.texture.width, xx -target.texture.height};
                dst := Rectangle.{ 0, 0, xx window_width, xx window_height };
                DrawTexturePro(target.texture, src, dst, .{0, 0}, 0, WHITE);
            } else if g_game.mode == .EDITOR {
                editor_draw(*g_editor);
            }

            if g_debug.enabled {
                debug_draw_ui(*g_game);
            }
        EndDrawing();

        reset_temporary_storage();
    }

    game_shutdown(*g_game);
    CloseWindow();
}

toggle_mode :: () {
    if g_game.mode == .PLAY {
        g_game.mode = .EDITOR;
        g_editor.camera.target = g_game.player.position;
    } else if g_game.mode == .EDITOR {
        g_game.mode = .PLAY;
    }
}
