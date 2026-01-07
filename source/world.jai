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
    return w;
}
