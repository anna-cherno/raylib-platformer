#import "File";
#import "Text_File_Handler";

TILESET_FILE_VERSION :: 1;

save_tileset_data_to_file :: (tileset: *Tileset) {
    filename := tprint("%/tilesets/%.data", data_folder, tileset.name);
    builder: String_Builder;
    builder.allocator = temp;

    // Meta data.
    print_to_builder(*builder, "[%]\n\n", TILESET_FILE_VERSION);
    print_to_builder(*builder, "# Texture name\n");
    print_to_builder(*builder, "%\n\n", tileset.name);

    // Collisions.
    collisions_count := max(tileset.rows * tileset.cols, cast(s32) tileset.collisions.count);
    print_to_builder(*builder, "# Collisions\n");
    print_to_builder(*builder, "%\n", tileset.tile_size);
    print_to_builder(*builder, "%\n", collisions_count);

    // Save ints.
    for 0..collisions_count {
        c: u8 = ifx it < tileset.collisions.count then cast(u8) tileset.collisions[it] else 0;
        print_to_builder(*builder, "% ", c);
    }

    // Rules.
    print_to_builder(*builder, "\n\n# Rules\n%\n", tileset.rules.count);

    for tileset.rules {
        print_to_builder(*builder, "on:% off:% mx:% my:% a:% t:% ",
            cast(u16) it.on_mask, cast(u16) it.off_mask, cast(u8) it.mirror_x, cast(u8) it.mirror_y, cast(u8) it.active, it.tile_ids.count
        );
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
        if !found then continue;
        array_add(*tileset.rules, parse_rule_string(line));
    }

    return true, "";
}

#scope_file

parse_rule_string :: (line: string) -> Tileset_Rule {
    rule: Tileset_Rule;
    remainder := line;

    while remainder {
        remainder = trim_left(remainder);
        if !remainder break;

        found: bool;
        token: string;
        found, token, remainder = split_from_left(remainder, " ");
        if !found then break;

        key, value: string;
        found, key, value = split_from_left(token, ":");
        if !found then break;

        // advance(*value); // remove ":"
        int_val, ok := parse_int(*value);
        if ok {
            if      key == "on"  then rule.on_mask  = xx int_val;
            else if key == "off" then rule.off_mask = xx int_val;
            else if key == "mx"  then rule.mirror_x = xx int_val;
            else if key == "my"  then rule.mirror_y = xx int_val;
            else if key == "a"   then rule.active   = xx int_val;
            else if key == "t" {
                array_resize(*rule.tile_ids, int_val);
                // Reading tile ids mode.
                for 0..int_val-1 {
                    id, ok := parse_int(*remainder);
                    if ok then rule.tile_ids[it] = xx id;
                }
            }
        }
    }

    return rule;
}