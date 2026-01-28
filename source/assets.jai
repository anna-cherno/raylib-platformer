#import "Hash_Table";

Assets :: struct {
    textures: Table(string, Texture2D);
    shaders:  Table(string, Shader);
    tilesets: Table(string, *Tileset);
}

Asset_Entry :: struct {
    name: string;
    type: Asset_Type;
    path: string;
}

Asset_Type :: enum {
    TEXTURE;
    TILESET;
    SHADER;
}

assets_to_load :: Asset_Entry.[
    .{"player",        .TEXTURE, "textures/player.png"},
    .{"paper_tileset", .TEXTURE, "textures/paper_tileset.png"},
    .{"default",       .TILESET, "tilesets/paper_tileset.data"},
];

assets_init :: () -> ok: bool, err: string { // Kind-a go pattern
    // Check at compile time that all assets is here.
    #run {
        for assets_to_load {
            filename := tprint("./%", data_folder, it.path);
            if !file_exists(filename)
                compiler_report(tprint("Asset '%' is not found", filename));
        }
    }

    for assets_to_load {
        asset: *void; err: string;

        if it.type == {
            case .TEXTURE;
                asset = load_texture(it.name, it.path);
            case .TILESET;
                asset, err = load_tileset(it.name, it.path);
            case .SHADER;
                asset = load_shader(it.name, it.path);
            case;
                err = tprint("We don't know how to load % %, at '%'", it.type, it.name, it.path);
        }

        if asset == null && err.count == 0 {
            return false, tprint("% % is not found at '%'", it.type, it.name, it.path);
        } else if err.count > 0 {
            return false, err;
        }
    }

    // Raygui style for editor.
    #if EDITOR {
        load_gui_style("editor/style_genesis.rgs");
    }

    return true, "";
}

assets_unload :: () {
    for tex: g_assets.textures {
        UnloadTexture(tex);
    }
    for tileset: g_assets.tilesets {
        array_free(tileset.collisions);
        array_free(tileset.rules);
        free(tileset);
    }
    for sh: g_assets.shaders {
        UnloadShader(sh);
    }

    deinit(*g_assets.shaders);
    deinit(*g_assets.tilesets);
    deinit(*g_assets.textures);
}

load_texture :: (name: string, path: string) -> *Texture2D {
    found, texture := table_find(*g_assets.textures, name);
    if found then return *texture;

    filename := tprint("%/%", data_folder, path);
    texture = LoadTexture(filename.data);
    if texture.width == 0 && texture.height == 0 {
        return null;
    }

    return table_set(*g_assets.textures, name, texture);
}

load_tileset :: (name: string, path: string) -> *Tileset, string {
    tileset := New(Tileset);
    ok, err := load_tileset_data_from_file(tileset, path);
    if !ok {
        return null, tprint("% at '%'", err, path);
    }

    // Find texture from hash table.
    texture := table_find_pointer(*g_assets.textures, tileset.name);
    if texture == null {
        return null, tprint("% texture for tileset % is not loaded", tileset.name, name);
    }

    tileset.texture = texture;
    tileset.rows = texture.height / tileset.tile_size;
    tileset.cols = texture.width / tileset.tile_size;

    // Set asset into hash_table.
    table_set(*g_assets.tilesets, name, tileset);
    return tileset, "";
}

load_shader :: (name: string, path: string) -> *Shader {
    found, shader := table_find(*g_assets.shaders, name);
    if found then return *shader;

    filename := tprint("%/%", data_folder, path);
    shader = LoadShader(null, filename.data);

    return table_set(*g_assets.shaders, name, shader);
}


load_gui_style :: (name : string) {
    filename := tprint("%/%", data_folder, name);
    GuiLoadStyle(filename.data);
}

#scope_file

#import "File_Utilities";
#import "Compiler";
