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
