#import "Hash_Table";

Assets :: struct {
    textures: Table(string, Texture2D);
    tilesets: Table(string, *Tileset);
}

assets_init :: () {
    load_texture("player", "textures/player.png");
    tileset_texture := load_texture("tileset", "textures/tileset.png");

    tileset := load_tileset("default", tileset_texture, 16);
    read_tileset_data(tileset, "tilesets/tileset.data");

    load_style("editor/style_genesis.rgs");
}

assets_unload :: () {
    for tex: g_assets.textures {
        UnloadTexture(tex);
    }
    for *tileset: g_assets.tilesets {
        free(tileset);
    }
    deinit(*g_assets.tilesets);
    deinit(*g_assets.textures);
}

load_texture :: (name: string, path: string) -> *Texture2D {
    found, texture := table_find(*g_assets.textures, path);
    if found then return *texture;

    filename := tprint("%/%", data_folder, path);
    texture = LoadTexture(filename.data);

    return table_set(*g_assets.textures, name, texture);
}

load_tileset :: (name: string, tex: *Texture2D, tile_size: int) -> *Tileset {
    tileset := New(Tileset);
    tileset.tile_size = tile_size;
    tileset.rows = tex.width / tile_size;
    tileset.cols = tex.height / tile_size;

    array_resize(*tileset.collisions, tileset.rows * tileset.cols);

    for i: 0..tileset.collisions.count-1 {
        tileset.collisions[i] = .SOLID;
    }
    tileset.texture = tex;

    // Set asset into hash_table.
    table_set(*g_assets.tilesets, name, tileset);
    return tileset;
}

load_style :: (name : string) {
    filename := tprint("%/%", data_folder, name);
    GuiLoadStyle(filename.data);
}
