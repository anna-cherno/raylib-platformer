#import "File";
#import "Text_File_Handler";

TILESET_FILE_VERSION :: 1;

save_tileset_data_to_file :: (tileset: *Tileset, path: string) {
    filename := tprint("%/%.data", data_folder, path);
    builder: String_Builder;
    builder.allocator = temp;

    // Meta data.
    print_to_builder(*builder, "[%]\n\n", TILESET_FILE_VERSION);
    print_to_builder(*builder, "# Texture name\n");
    print_to_builder(*builder, "%\n", tileset.name);

    // Collisions.
    print_to_builder(*builder, "# Collisions\n");
    print_to_builder(*builder, "%\n", tileset.tile_size);
    print_to_builder(*builder, "%\n", tileset.collisions.count);

    // Save ints.
    for tileset.collisions {
        print_to_builder(*builder, "% ", cast(u8) it);
    }

    // Rules.
    print_to_builder(*builder, "\n\n# Rules\n%\n", tileset.rules.count);

    for tileset.rules {
        print_to_builder(*builder, "% % % ", cast(u16) it.on_mask, cast(u16) it.off_mask, it.tile_ids.count);
        for id: it.tile_ids {
            print_to_builder(*builder, "% ", id);
        }
        print_to_builder(*builder, "\n");
    }

    write_entire_file(filename, *builder);
}

load_tileset_data_from_file :: (tileset: *Tileset, filename: string) -> ok: bool, err: string {
    handler: Text_File_Handler;
    defer deinit(*handler);

    filepath := tprint("%/%", data_folder, filename);
    found, short_name := split_from_right(filepath, "/");
    if !found {
        return false, tprint("File % not found", filename);
    }

    start_file(*handler, short_name, filepath, false);
    if handler.failed then return false, "Unable to start a file";

    line: string;
    // Read tileset texture name.
    line, found = consume_next_line(*handler);
    if !found {
        return false, "Failed to read tileset texture name";
    }
    tileset.name = line;

    // Read tile size.
    line, found = consume_next_line(*handler);
    if !found {
        return false, "Failed to read tile size";
    }
    tileset.tile_size, found = xx parse_int(*line);
    if !found {
        return false, "Failed to parse tile size";
    }

    // read tiles count
    line, found = consume_next_line(*handler);
    if !found {
        return false, "Failed to read tiles count";
    }
    tiles_count: int;
    tiles_count, found = parse_int(*line);
    if !found {
        return false, "Failed to parse tile size";
    }

    line, found = consume_next_line(*handler);
    if !found {
        return false, "Failed to read tile data";
    }

    // Read collisions.
    array_resize(*tileset.collisions, tiles_count);
    for i: 0..tiles_count-2 {
        c := string_to_int(line);
        tileset.collisions[i] = xx c;
        advance(*line, 2);
    }

    // Read rules.
    // Rules count.
    line, found = consume_next_line(*handler);
    if !found {
        return false, "Failed to read rule count";
    }
    rules_count: int;
    rules_count, found = parse_int(*line);
    if !found {
        return false, "Failed to parse rules count";
    }
    array_reserve(*tileset.rules, rules_count);

    // Rules data.
    for i: 0..rules_count-1 {
        line, found = consume_next_line(*handler);
        if !found {
            return false, "Failed to read rule data";
        }

        rule: Tileset_Rule;

        parts := split(line, " ");
        defer array_free(parts);
        if parts.count < 3 {
            return false, "Rule item should have at least 3 numbers";
        }

        // Mask.
        rule.on_mask = xx string_to_int(parts[0]);
        rule.off_mask = xx string_to_int(parts[1]);

        // Tile ids.
        tile_ids_count := string_to_int(parts[2]);
        array_resize(*rule.tile_ids, tile_ids_count);
        if tile_ids_count > parts.count - 3 {
            return false, "Empty tile ids";
        }
        for j: 0..tile_ids_count-1 {
            // left, right = break_by_spaces(right);
            t_id := string_to_int(parts[j+3]);
            rule.tile_ids[j] = xx t_id;
        }

        array_add(*tileset.rules, rule);
    }

    return true, "";
}
