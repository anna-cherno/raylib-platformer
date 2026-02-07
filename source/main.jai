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
#load "player.jai";
#load "game.jai";
#load "editor.jai";
#load "world.jai";
#load "draw.jai";
#load "tiles.jai";
#load "seed.jai";
#load "debug.jai";
#load "file.jai";

HPIXELS :: 380;
ASPECT :: 16.0 / 10.0;

// Window params.
window_width: s32;
window_height: s32;
render_scale: float;

// Global absolute path to asset folder.
data_folder : string;

// Render target texture.
render_target: RenderTexture2D;

// Global states.
g_assets: Assets;
g_game: Game_State;
g_editor: Editor_State;
g_debug: Debug_State;

main :: () {
    // Path to assets.
    base_path := path_strip_filename(get_path_of_running_executable());
    data_folder = join(base_path, "assets");
    defer free(data_folder);

    init_raylib_stuff();
    defer close_raylib_stuff();

    ok, err := init_global_states();
    if !ok {
        TraceLog(.LOG_ERROR, get_c_string(err));
        return;
    }
    defer close_global_states();

    while (!WindowShouldClose()) {
        #if DEBUG debug_update();

        #if EDITOR {
            if IsKeyPressed(.KEY_TAB) {
                toggle_mode();
            }
        }

        dt := GetFrameTime();
        if g_game.mode == .PLAY {
            game_update(*g_game, dt);
        } else if g_game.mode == .EDITOR {
            #if EDITOR editor_update(*g_editor, dt);

        }

        // Draw to the target texture.
        if g_game.mode == .PLAY {
            BeginTextureMode(render_target);
                game_draw(*g_game);
            EndTextureMode();
        }

        // Draw the target texture to the screen.
        BeginDrawing();
            if g_game.mode == .PLAY {
                src := Rectangle.{ 0, 0, xx render_target.texture.width, xx -render_target.texture.height};
                dst := Rectangle.{ 0, 0, xx window_width, xx window_height };
                DrawTexturePro(render_target.texture, src, dst, .{0, 0}, 0, WHITE);
            } else if g_game.mode == .EDITOR {
                #if EDITOR editor_draw(*g_editor);
            }

            #if DEBUG {
                if g_debug.enabled then debug_draw_ui(*g_game);
            }
        EndDrawing();

        reset_temporary_storage();
    }
}

init_raylib_stuff :: () {
    SetConfigFlags(.FLAG_WINDOW_HIGHDPI | .FLAG_VSYNC_HINT);
    InitWindow(100, 100, "Seedo");

    // Detect best monitor (bigger wins (for dev)).
    monitor := GetCurrentMonitor();
    for 0..GetMonitorCount()-1 {
        if GetMonitorWidth(it) > GetMonitorWidth(monitor) {
            monitor = it;
            break;
        }
    }

    init_window_dimensions(monitor);
    SetWindowSize(window_width, window_height);
    SetWindowPosition(
        (GetMonitorWidth(monitor) - window_width) / 2,
        (GetMonitorHeight(monitor) - window_height) / 2,
    );

    // Set refresh rate.
    SetTargetFPS(GetMonitorRefreshRate(monitor));

    SetWindowMonitor(monitor);

    // We are rendering in the render target texture.
    render_target = LoadRenderTexture(window_width, window_height);
    SetTextureFilter(render_target.texture, .TEXTURE_FILTER_POINT);
}

init_window_dimensions :: (monitor: s32) {
    display_w := GetMonitorWidth(monitor);
    display_h := GetMonitorHeight(monitor);
    max_window_h := display_h * 0.8;
    base_h := HPIXELS / ASPECT;

    scale := floor(max_window_h / base_h);
    if scale < 1.0 then scale = 1.0;

    render_scale = scale;

    window_height = cast(s32) (base_h * render_scale);
    window_width = cast(s32) (window_height * ASPECT);

    if window_width > display_w {
        window_width = cast(s32) (display_w * 0.9);
        window_height = cast(s32) (cast(float) window_width / ASPECT);
    }

}

init_global_states :: () -> ok: bool, err: string {
    // Assets.
    ok, err := assets_init();
    if !ok {
        return false, err;
    }

    // Game.
    ok, err = game_init(*g_game);
    if !ok {
        return false, err;
    }

    // Editor.
    #if EDITOR {
        ok, err = editor_init(*g_editor, *g_game);
        if !ok {
            return false, err;
        }
    }

    // Debug.
    #if DEBUG debug_init();

    return true, "";
}

close_global_states :: () {
    #if DEBUG debug_close();
    #if EDITOR editor_close(*g_editor);
    game_close(*g_game);
    assets_unload();
}

close_raylib_stuff :: () {
    UnloadRenderTexture(render_target);
    CloseWindow();
}

toggle_mode :: () {
    if g_game.mode == .PLAY {
        g_game.mode = .EDITOR;
        g_editor.camera.zoom = render_scale;
        g_editor.camera.offset.x = xx (window_width / 2);
        g_editor.camera.offset.y = xx (window_height / 2);
        g_editor.camera.target = g_game.player.position;
        g_debug.show_grid = true;
    } else if g_game.mode == .EDITOR {
        g_game.mode = .PLAY;
        g_debug.show_grid = false;
    }
}
