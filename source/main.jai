#import "Basic";
#import "String";
#import "System";
#import "Math";
#import "Random";
#import "raylib";

#load "types.jai";
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
#load "seed.jai";
#load "debug.jai";
#load "file.jai";

WINDOW_ASPECT :: 16.0 / 10.0;
GAME_ASPECT   :: 4.0 / 3.0;
HPIXELS :: 380;
SCALE :: 4.0;

virtual_width:  s32 = xx (HPIXELS * SCALE);
virtual_height: s32 = xx (HPIXELS / WINDOW_ASPECT * SCALE);
window_width:   s32 = xx (HPIXELS * SCALE);
window_height:  s32 = xx (HPIXELS / WINDOW_ASPECT * SCALE);

data_folder : string;

// Global states.
g_assets: Assets;
g_game: Game_State;
g_editor: Editor_State;
g_debug: Debug_State;

main :: () {
    base_path := path_strip_filename(get_path_of_running_executable());
    data_folder = join(base_path, "assets");
    defer free(data_folder);

    SetConfigFlags(.FLAG_WINDOW_HIGHDPI);
    InitWindow(window_width, window_height, "Seedo");
    SetTargetFPS(75);

    target := LoadRenderTexture(virtual_width, virtual_height);
    SetTextureFilter(target.texture, .TEXTURE_FILTER_POINT);

    // Init systems.
    assets_init();
    game_init(*g_game);
    editor_init(*g_editor, *g_game);
    debug_init();

    while (!WindowShouldClose()) {
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
                ClearBackground(BLACK);
                src := Rectangle.{ 0, 0, xx target.texture.width, xx -target.texture.height};
                dst := Rectangle.{ 0, 0, xx virtual_width, xx virtual_height };
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
        g_editor.camera.zoom = SCALE;
        g_editor.camera.offset.x = xx (window_width / 2);
        g_editor.camera.offset.y = xx (window_height / 2);
        g_editor.camera.target = g_game.player.position;
    } else if g_game.mode == .EDITOR {
        g_game.mode = .PLAY;
    }
}
