Animation :: struct {
    texture: *Texture2D;

    looped: bool = true;
    flipped: bool = false;

    frame: int;
    frame_count: int;
    frame_time: float = 0.1;
    frame_times: []float;
    timer: float;
    frame_row: int;
    frame_width: int;
    frame_height: int;

    target_width: int;
    target_height: int;
}

animation_create :: (tex: *Texture2D, row: int, w: int, h: int, count: int, base_time: float, loop: bool = true) -> Animation {
    anim := Animation.{
        texture = tex,
        frame_row = row,
        frame_width = w,
        frame_height = h,
        frame_count = count,
        frame_time = base_time,
        target_width = w,
        target_height = h,
        looped = loop,
    };
    // array_resize(*anim.frame_times, count);
    // for i in 0..count {
    //     anim.frame_times[i] = base_time;
    // }
    return anim;
}

animation_reset :: (anim: *Animation) {
    anim.frame = 0;
    anim.timer = 0;
}

animation_update :: (anim: *Animation, dt: float) {
    anim.timer += dt;
    current_time := ifx anim.frame_times.count > 0 then anim.frame_times[anim.frame] else anim.frame_time;
    if anim.timer >= current_time {
        anim.timer -= current_time;
        anim.frame += 1;
        if anim.frame >= anim.frame_count {
            anim.frame = ifx anim.looped then 0 else anim.frame_count - 1;
        }
    }
}

animation_draw :: (anim: *Animation, pos: Vector2, flipped: bool) {
    src := Rectangle.{
        xx (anim.frame * anim.frame_width),
        xx (anim.frame_height * anim.frame_row),
        xx anim.frame_width,
        xx anim.frame_height,
    };
    if flipped {
        src.width = -src.width;
    }
    dst := Rectangle.{ pos.x, pos.y, xx anim.frame_width, xx anim.frame_height };
    origin := Vector2.{dst.width * 0.5, dst.height * 0.5};

    DrawTexturePro(anim.texture, src, dst, origin, 0, WHITE);
}
