World :: struct {
    name: string;
    bounds: Rectangle;
    tilemap: Tilemap;
}

world_create :: (name: string, tile_w: int, tile_h: int) -> World {
    w := World.{};
    w.name = name;
    w.tilemap.width = tile_w;
    w.tilemap.height = tile_h;
    array_resize(*w.tilemap.tiles, tile_w * tile_h);
    w.bounds = {0, 0, xx (tile_w * TILE_SIZE), xx (tile_h * TILE_SIZE)};

    world_create_test_tilemap(*w.tilemap);
    return w;
}

world_create_test_tilemap :: (tilemap: *Tilemap) {
    x : int = xx (tilemap.width * 0.5);
    y : int = tilemap.height-1;
    tilemap.tiles[x + y * tilemap.width] = .SLOPE_UP;
    tilemap.tiles[x+1 + (y-1) * tilemap.width] = .SLOPE_UP;
    tilemap.tiles[x+2 + (y-2) * tilemap.width] = .SLOPE_UP;
}
