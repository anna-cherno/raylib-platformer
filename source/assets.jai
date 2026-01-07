load_texture :: (name: string) -> Texture, bool {
    filename := tprint("%/%", data_folder, name);
    result := LoadTexture(filename.data);

    return result, result.id > 0;
}
