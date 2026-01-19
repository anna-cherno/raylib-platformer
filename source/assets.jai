#import "Hash_Table";

Assets :: struct {
    textures: Table(string, Texture2D);
    tilesets: Table(string, *Tileset);
}

assets_init :: () {
    load_texture("player_sprite.png");
    tileset_texture := load_texture("tilesets/default.png");

    tileset := load_tileset("default", tileset_texture, 16);
    read_tileset_data(tileset, "tilesets/default.tileset");
}

assets_unload :: () {
    // Unload textures.
    for tex: g_assets.textures {
        UnloadTexture(tex);
    }
    for *tileset: g_assets.tilesets {
        free(tileset);
    }
    deinit(*g_assets.tilesets);
    deinit(*g_assets.textures);
}

load_texture :: (path: string) -> *Texture2D {
    found, texture := table_find(*g_assets.textures, path);
    if found then return *texture;

    filename := tprint("%/%", data_folder, path);
    texture = LoadTexture(filename.data);

    return table_set(*g_assets.textures, path, texture);
}

load_tileset :: (name: string, tex: *Texture2D, tile_size: int) -> *Tileset {
    tileset := New(Tileset);
    tileset.tile_size = tile_size;
    tileset.width = tex.width / tile_size;
    tileset.height = tex.height / tile_size;
    array_resize(*tileset.tiles, tileset.width * tileset.height);
    for *t, i: tileset.tiles {
        t.sprite = i;
        t.collision = .SOLID;
    }
    tileset.texture = tex;

    // Set asset into hash_table.
    table_set(*g_assets.tilesets, name, tileset);
    return tileset;
}
