#import "Basic";
#import "String";
#import "System";
#import "Math";
#import "Random";
#import "raylib";

#load "types.jai";
#load "assets.jai";
#load "input.jai";
#load "animation.jai";
#load "entity.jai";
#load "player.jai";
#load "ui.jai";
#load "game.jai";
#load "editor.jai";
#load "world.jai";
#load "draw.jai";
#load "tiles.jai";
#load "seed.jai";
#load "debug.jai";
#load "file.jai";

HPIXELS :: 380;
ASPECT  :: 16.0 / 10.0;
SCALE   :: 3;

window_width : s32 = xx (HPIXELS * ASPECT * SCALE);
window_height: s32 = HPIXELS * SCALE;
render_scale : float = 3.0;

// Global states.
assets : Asset_Registry;
game   : Game;
editor : Editor;
debug  : Debug;

main :: () {
    init_raylib_stuff();
    defer deinit_raylib_stuff();

    if !init_global_states() {
        TraceLog(.LOG_FATAL, "Не удалось инициализировать глобальные состояния");
        exit(1);
        return;
    }
    defer deinit_global_states();

    while (!WindowShouldClose()) {
        #if DEBUG update_debug();
        update_input();
        
        #if EDITOR {
            if game.input.toggle_editor_pressed {
                game.mode = ifx game.mode == .PLAY then .EDITOR else .PLAY;
            }
        }

        dt := GetFrameTime();
        if game.mode == {
            case .EDITOR; update_editor(dt);
            case .PLAY;   update_game(dt);
        }

        BeginDrawing();
            ClearBackground(BLACK);
            draw_game();
        EndDrawing();

        reset_temporary_storage();
    }
}

init_raylib_stuff :: () {
    SetConfigFlags(.FLAG_VSYNC_HINT);
    InitWindow(window_width, window_height, "seeder");

    // Detect best monitor (bigger wins (for dev)).
    monitor := GetCurrentMonitor();
    for 0..GetMonitorCount()-1 {
        if GetMonitorWidth(it) > GetMonitorWidth(monitor) {
            monitor = it;
            break;
        }
    }

    // init_window_dimensions(monitor);
    // SetWindowSize(window_width, window_height);
    SetWindowPosition(
        (GetMonitorWidth(monitor) - window_width) / 2,
        (GetMonitorHeight(monitor) - window_height) / 2,
    );

    // Set refresh rate.
    SetTargetFPS(GetMonitorRefreshRate(monitor));
    SetWindowMonitor(monitor);

    // We are rendering in the render target texture.
    // render_target = LoadRenderTexture(window_width, window_height);
    // SetTextureFilter(render_target.texture, .TEXTURE_FILTER_POINT);
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

init_global_states :: () -> bool {
    if !load_assets() {
        log_error("Не удалось загрузить ассеты");
        return false;
    }

    if !init_game() {
        log_error("Не удалось инициализировать игру");
        return false;
    }

    #if DEBUG {
        if !init_debug() {
            log_error("Не удалось инициализировать дебаг");
            return false;
        }
    }
    
    #if EDITOR {
        if !init_editor() {
            log_warning("Не удалось инициализировать редактор");
        }
    }

    return true;
}

deinit_global_states :: () -> bool {
    #if EDITOR { 
        if !deinit_editor() {
            log_warning("Не удалось деинициализировать редактор");
        }
    }

    #if DEBUG {
        if !deinit_debug() {
            log_error("Не удалось деинициализировать дебаг");
            return false;
        }
    }
    
    if !deinit_game() {
        log_error("Не удалось деинициализировать игру");
        return false;
    }
        
    if !unload_assets() {
        log_error("Не удалось выгрузить ассеты");
        return false;
    }

    return true;
}

deinit_raylib_stuff :: () {
    // UnloadRenderTexture(render_target);
    CloseWindow();
}

toggle_mode :: () {
    if game.mode == .PLAY {
        game.mode = .EDITOR;
        // game.editor.camera.zoom = render_scale;
        // game.editor.camera.offset.x = xx (window_width / 2);
        // game.editor.camera.offset.y = xx (window_height / 2);
        // game.editor.camera.target = game.player.position;
        debug.show_grid = true;
    } else if game.mode == .EDITOR {
        game.mode = .PLAY;
        debug.show_grid = false;
    }
}
