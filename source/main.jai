#import "Basic";
#import "String";
#import "System";
#import "Math";
#import "Random";
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
#load "seed.jai";
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
g_assets: Assets;
g_game: Game_State;
g_editor: Editor_State;
// g_input: Input_State;
g_debug: Debug_State;

Vector2i :: struct {
    x, y: s32;
    #overlay (x) component: [2] s32;
}

operator + :: (a: Vector2i, b: Vector2i) -> Vector2i {
    return Vector2i.{ a.x + b.x, a.y + b.y };
}

operator == :: (a: Vector2i, b: Vector2i) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator - :: (a: Vector2i) -> Vector2i {
    return .{-a.x, -a.y};
}

main :: () {
    base_path := path_strip_filename(get_path_of_running_executable());
    data_folder = join(base_path, "assets");

    SetConfigFlags(.FLAG_WINDOW_HIGHDPI);
    InitWindow(window_width, window_height, "Seed");
    SetTargetFPS(75);

    target := LoadRenderTexture(xx VIRTUAL_WIDTH, xx VIRTUAL_HEIGHT);
    SetTextureFilter(target.texture, .TEXTURE_FILTER_POINT);

    // Init systems.
    assets_init();
    game_init(*g_game);
    g_game.world = world_create("hello", 250, 100);
    editor_init(*g_editor, *g_game);
    debug_init();

    while (!WindowShouldClose()) {
        // input_update(*g_input);
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
        // if g_game.mode == .PLAY {
        //     BeginTextureMode(target);
        //         game_draw(*g_game);
        //     EndTextureMode();
        // }

        // Draw the target texture to the screen.
        BeginDrawing();
            if g_game.mode == .PLAY {
                ClearBackground(DARKGRAY);
                // src := Rectangle.{ 0, 0, xx target.texture.width, xx -target.texture.height};
                // dst := Rectangle.{ 0, 0, xx window_width, xx window_height };
                // DrawTexturePro(target.texture, src, dst, .{0, 0}, 0, WHITE);
                game_draw(*g_game);
            } else if g_game.mode == .EDITOR {
                editor_draw(*g_editor);
            }

            if g_debug.enabled {
                debug_draw_ui(*g_game);
            }
        EndDrawing();

        reset_temporary_storage();
    }

    world_destroy(*g_game.world);
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

sign :: inline (x: $T/.[float32, float64, s8, s16, s32, s64, u8, u16, u32, u64]) -> T {
    if x > 0 return 1;
    if x < 0 return -1;
    return 0;
}

sign :: inline (using v: Vector2) -> Vector2 {
    return .{ sign(x), sign(y) };
}
