#import "Basic";

Entity :: struct {
    type: Entity_Type;

    // Transform.
    position: Vector2;
    velocity: Vector2;
    size: Vector2;

    active: bool = true;
}

Entity_Type :: enum {
    NONE;
    PLAYER;
    PLAYER_START;
    COLLISION_BOX;
}

entity_update :: (e: *Entity, dt: float) {
    // entity_move(e, dt);

    // // Apply gravity.
    // if e.velocity.y < 0 {
    //     e.velocity.y += GRAVITY * 0.7 * dt;
    // } else {
    //     e.velocity.y += GRAVITY * 1.3 * dt;
    // }

    // entity_update_movement_state();

    // // X movement.
    // // Accumulate fractional movement for pixel-perfect collision.
    // x_delta := e.velocity.x * dt + e.frac_movement.x;
    // x_move := cast(s32) abs(x_delta) * sign(x_delta);
    // e.frac_movement.x = x_delta - cast(float) x_move;
    // entity_move_and_collide_x(e, x_move);

    // // Y Movement.
    // y_delta := e.velocity.y * dt + e.frac_movement.y;
    // y_move := cast(s32) abs(y_delta) * sign(y_delta);
    // e.frac_movement.y = y_delta - cast(float) y_move;
    // entity_move_and_collide_y(e, y_move);
}

entity_apply_velocity :: (e: *Entity, dt: float) {

    // if e.direction.x > 0 {
    //     e.facing_right = true;
    // } else if e.direction.x < 0 {
    //     e.facing_right = false;
    // }
}

entity_apply_gravity :: (e: *Entity, dt: float) {


    // Limit velocity.
    // if e.velocity.y > -e.jump_force {
    //     e.velocity.y = -e.jump_force;
    // }
}

entity_jump :: (e: *Entity) {
    // e.velocity.y = e.jump_force;
    // e.is_jumping = true;
    // e.is_grounded = false;
}

entity_move_and_collide_x :: (e: *Entity, move: int) {
    // if move == 0 return;

    // e.collider.x += move;
    // e.position.x += move;
}

entity_move_and_collide_y :: (e: *Entity, move: int) {
    // if move == 0 return;

    // collider := e.collider;
    // collider.y += move;

    // e.hit_ceil = false;

    // rect := Rectangle.{
    //     world_bound.x, world_bound.y + world_bound.height,
    //     world_bound.width, 100,
    // };
    // if CheckCollisionRecs(collider, rect) {
    //     if move > 0 {
    //         e.position.y = rect.y - e.collider.height * 0.5;
    //         e.hit_on_floor = true;
    //     } else {
    //         e.position.y = rect.y + rect.height + e.collider.height;
    //         e.hit_on_ceil = true;
    //     }

    //     e.velocity.y = 0;
    // }

    // if e.velocity.y != 0 {
    //     e.position.y += move;
    //     e.collider = collider;
    // }
}

#scope_file

sign :: inline (x: float) -> int {
    if x < 0 return -1;
    else if x < 0.0001 return 0;
    return 1;
}
