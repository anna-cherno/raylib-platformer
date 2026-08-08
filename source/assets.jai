#import "Hash_Table";

Asset_Registry :: struct {
    textures: Table(string, Texture2D);
    shaders:  Table(string, Shader);
    tilesets: Table(string, Tileset);

    data_folder: string;
    initialized: bool;
}

Asset_Entry :: struct {
    name: string;
    type: Asset_Type;
    path: string;
}

Asset_Type :: enum u8 {
    TEXTURE;
    TILESET;
}

assets_to_load :: Asset_Entry.[
    // Textures.
    .{"player",        .TEXTURE, "textures/player.png"},
    .{"green_tileset", .TEXTURE, "textures/green_tileset.png"},
    .{"arrows",        .TEXTURE, "textures/arrows.png"},

    // Tilesets.
    .{"green_tileset", .TILESET, "tilesets/green_tileset.data"},
];

load_assets :: () -> bool { 
    base_path := path_strip_filename(get_path_of_running_executable());
    assets.data_folder = join(base_path, "assets");
    log_info("Каталог data_folder: %", assets.data_folder);

    for assets_to_load {
        ok: bool;
        if it.type == {
            case .TEXTURE;
                ok = load_texture(it.name, it.path);
            case .TILESET;
                ok = load_tileset(it.name, it.path);
            case;
                log_error("Мы не знаем как загрузить %: '%' по пути: %", it.type, it.name, it.path);
        }

        if !ok {
            log_error("Ассет %: '%' не найден по пути: %", it.type, it.name, it.path);
            return false; 
        }
    }

    // Raygui style for editor.
    #if EDITOR {
        load_gui_style("editor/style_genesis.rgs");
    }

    assets.initialized = true;

    return true;
}

unload_assets :: () -> bool {
    for tex: assets.textures {
        UnloadTexture(tex);
    }
    for tileset: assets.tilesets {
        array_free(tileset.collisions);
        array_free(tileset.rules);
    }
    for sh: assets.shaders {
        UnloadShader(sh);
    }

    deinit(*assets.shaders);
    deinit(*assets.tilesets);
    deinit(*assets.textures);
    
    free(assets.data_folder);
    
    assets.initialized = false;

    return true;
}

load_texture :: (name: string, path: string) -> bool, *Texture2D {
    saved_texture := table_find_pointer(*assets.textures, name);
    if saved_texture != null then return true, saved_texture;

    filename := tprint("%/%", assets.data_folder, path);
    texture := LoadTexture(filename.data);
    if texture.width == 0 && texture.height == 0 {
        log_error("Не удалось загрузить текстуру %s по пути: %s\n", *name, *path);
        return false, null;
    }

    saved_texture = table_set(*assets.textures, name, texture);
    return true, saved_texture;
}

load_tileset :: (name: string, path: string) -> bool, *Tileset {
    tileset := Tileset.{};
    ok, err := load_tileset_data_from_file(*tileset, path);
    if !ok {
        log_error("Не удалось загрузить тайлсет %s по пути: %s, причина: %s\n", *name, *path, *err);
        return false, null;
    }

    // Find texture from hash table.
    texture := table_find_pointer(*assets.textures, tileset.name);
    if texture == null {
        log_error("Не удалось загрузить текстуру для тайлсета %s\n", *name);
        return false, null;
    }

    tileset.name = copy_string(name);
    tileset.texture = texture;
    tileset.rows = texture.height / tileset.tile_size;
    tileset.cols = texture.width  / tileset.tile_size;

    saved_tileset := table_set(*assets.tilesets, name, tileset);
    return true, saved_tileset;
}

load_shader :: (name: string, path: string) -> bool, *Shader {
    saved_shader := table_find_pointer(*assets.shaders, name);
    if saved_shader != null then return true, saved_shader;

    filename := tprint("%/%", assets.data_folder, path);
    shader := LoadShader(null, filename.data);
    if shader.id == 0 {
        log_error("Не удалось загрузить шейдер %s по пути: %s", *name, *path);
        return false, null;
    }

    saved_shader = table_set(*assets.shaders, name, shader);
    return true, saved_shader;
}

load_gui_style :: (name : string) -> bool {
    filename := tprint("%/%", assets.data_folder, name);
    GuiLoadStyle(filename.data);
    return true;
}

#scope_file

#import "File_Utilities";
#import "Compiler";
