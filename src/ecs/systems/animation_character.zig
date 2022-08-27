const std = @import("std");
const zm = @import("zmath");
const flecs = @import("flecs");
const game = @import("game");
const components = game.components;

const Direction = game.math.Direction;

pub fn system() flecs.EcsSystemDesc {
    var desc = std.mem.zeroes(flecs.EcsSystemDesc);
    desc.query.filter.terms[0] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.CharacterAnimator) });
    desc.query.filter.terms[1] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_id(components.CharacterRenderer) });
    desc.query.filter.terms[2] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Direction, components.Movement) });
    desc.query.filter.terms[3] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Direction, components.Head) });
    desc.query.filter.terms[4] = std.mem.zeroInit(flecs.EcsTerm, .{ .id = flecs.ecs_pair(components.Direction, components.Body) });
    desc.run = run;
    return desc;
}

pub fn run(it: *flecs.EcsIter) callconv(.C) void {
    const world = it.world.?;

    while (flecs.ecs_iter_next(it)) {
        var i: usize = 0;
        while (i < it.count) : (i += 1) {
            const entity = it.entities[i];

            if (flecs.ecs_field(it, components.CharacterAnimator, 1)) |animators| {
                if (flecs.ecs_field(it, components.CharacterRenderer, 2)) |renderers| {
                    if (flecs.ecs_field(it, components.Direction, 4)) |head_directions| {
                        if (flecs.ecs_field(it, components.Direction, 5)) |body_directions| {
                            const move_direction: Direction = if (flecs.ecs_field(it, components.Direction, 3)) |move_directions| move_directions[i].value else Direction.none;
                            if (body_directions[i].value == .none) body_directions[i].value = if (move_direction != .none) move_direction else Direction.se;
                            if (head_directions[i].value == .none) head_directions[i].value = body_directions[i].value;
                            var temp_head_direction = head_directions[i].value;

                            if (flecs.ecs_has_id(world, entity, flecs.ecs_id(components.Player))) {
                                const mouse_world = game.state.controls.mouse.position.world();
                                const player_position = if (flecs.ecs_get(world, entity, components.Position)) |position| position.toF32x4() else zm.f32x4s(0);
                                const mouse_vector = mouse_world - player_position;
                                temp_head_direction = Direction.find(8, mouse_vector[0], mouse_vector[1]);
                            }

                            // Declare our needed animations
                            var head_animation: []usize = undefined;
                            var body_animation: []usize = undefined;
                            var top_animation: []usize = undefined;
                            var bottom_animation: []usize = undefined;
                            var hair_animation: []usize = undefined;

                            if (move_direction != .none) {
                                animators[i].state = components.CharacterAnimator.State.walk;
                                body_directions[i].value = move_direction;

                                // Clamp face direction to directions close to the movement direction
                                if (temp_head_direction == move_direction or
                                    temp_head_direction == move_direction.rotateCW() or
                                    temp_head_direction == move_direction.rotateCCW())
                                {
                                    head_directions[i].value = temp_head_direction;
                                } else if (head_directions[i].value != move_direction and
                                    head_directions[i].value != move_direction.rotateCW() and
                                    head_directions[i].value != move_direction.rotateCCW())
                                {
                                    head_directions[i].value = move_direction;
                                }

                                // Set relevant animations for the body based on movement direction
                                switch (body_directions[i].value) {
                                    .n => {
                                        body_animation = animators[i].body_set.walk_n;
                                        top_animation = animators[i].top_set.walk_n;
                                        bottom_animation = animators[i].bottom_set.walk_n;
                                    },
                                    .nw, .ne => {
                                        body_animation = animators[i].body_set.walk_ne;
                                        top_animation = animators[i].top_set.walk_ne;
                                        bottom_animation = animators[i].bottom_set.walk_ne;
                                    },
                                    .w, .e => {
                                        body_animation = animators[i].body_set.walk_e;
                                        top_animation = animators[i].top_set.walk_e;
                                        bottom_animation = animators[i].bottom_set.walk_e;
                                    },
                                    .sw, .se => {
                                        body_animation = animators[i].body_set.walk_se;
                                        top_animation = animators[i].top_set.walk_se;
                                        bottom_animation = animators[i].bottom_set.walk_se;
                                    },
                                    .s => {
                                        body_animation = animators[i].body_set.walk_s;
                                        top_animation = animators[i].top_set.walk_s;
                                        bottom_animation = animators[i].bottom_set.walk_s;
                                    },
                                    else => {},
                                }

                                switch (head_directions[i].value) {
                                    .n => {
                                        head_animation = animators[i].head_set.walk_n;
                                        hair_animation = animators[i].hair_set.walk_n;
                                    },
                                    .nw, .ne => {
                                        head_animation = animators[i].head_set.walk_ne;
                                        hair_animation = animators[i].hair_set.walk_ne;
                                    },
                                    .w, .e => {
                                        head_animation = animators[i].head_set.walk_e;
                                        hair_animation = animators[i].hair_set.walk_e;
                                    },
                                    .sw, .se => {
                                        head_animation = animators[i].head_set.walk_se;
                                        hair_animation = animators[i].hair_set.walk_se;
                                    },
                                    .s => {
                                        head_animation = animators[i].head_set.walk_s;
                                        hair_animation = animators[i].hair_set.walk_s;
                                    },
                                    else => {},
                                }
                            } else {
                                animators[i].state = components.CharacterAnimator.State.idle;

                                // When idle, only allow the 4 angled directions as body directions.
                                body_directions[i].value = switch (body_directions[i].value) {
                                    .n => .ne,
                                    .s => .se,
                                    .e => .ne,
                                    .w => .sw,
                                    else => body_directions[i].value,
                                };

                                // Clamp face direction to directions close to the body direction
                                if (temp_head_direction == body_directions[i].value or
                                    temp_head_direction == body_directions[i].value.rotateCW() or
                                    temp_head_direction == body_directions[i].value.rotateCCW() or
                                    temp_head_direction == body_directions[i].value.rotateCW().rotateCW() or
                                    temp_head_direction == body_directions[i].value.rotateCCW().rotateCCW())
                                {
                                    head_directions[i].value = temp_head_direction;
                                }

                                // Set relevant animations for the body based on previous body direction
                                switch (body_directions[i].value) {
                                    .n => {
                                        body_animation = animators[i].body_set.idle_n;
                                        top_animation = animators[i].top_set.idle_n;
                                        bottom_animation = animators[i].bottom_set.idle_n;
                                    },
                                    .nw, .ne => {
                                        body_animation = animators[i].body_set.idle_ne;
                                        top_animation = animators[i].top_set.idle_ne;
                                        bottom_animation = animators[i].bottom_set.idle_ne;
                                    },
                                    .w, .e => {
                                        body_animation = animators[i].body_set.idle_e;
                                        top_animation = animators[i].top_set.idle_e;
                                        bottom_animation = animators[i].bottom_set.idle_e;
                                    },
                                    .sw, .se => {
                                        body_animation = animators[i].body_set.idle_se;
                                        top_animation = animators[i].top_set.idle_se;
                                        bottom_animation = animators[i].bottom_set.idle_se;
                                    },
                                    .s => {
                                        body_animation = animators[i].body_set.idle_s;
                                        top_animation = animators[i].top_set.idle_s;
                                        bottom_animation = animators[i].bottom_set.idle_s;
                                    },
                                    else => {},
                                }

                                switch (head_directions[i].value) {
                                    .n => {
                                        head_animation = animators[i].head_set.idle_n;
                                        hair_animation = animators[i].hair_set.idle_n;
                                    },
                                    .nw, .ne => {
                                        head_animation = animators[i].head_set.idle_ne;
                                        hair_animation = animators[i].hair_set.idle_ne;
                                    },
                                    .w, .e => {
                                        head_animation = animators[i].head_set.idle_e;
                                        hair_animation = animators[i].hair_set.idle_e;
                                    },
                                    .sw, .se => {
                                        head_animation = animators[i].head_set.idle_se;
                                        hair_animation = animators[i].hair_set.idle_se;
                                    },
                                    .s => {
                                        head_animation = animators[i].head_set.idle_s;
                                        hair_animation = animators[i].hair_set.idle_s;
                                    },
                                    else => {},
                                }
                            }

                            animators[i].elapsed += it.delta_time;

                            if (animators[i].elapsed > (1.0 / @intToFloat(f32, animators[i].fps))) {
                                animators[i].elapsed = 0.0;

                                if (animators[i].frame < 7) {
                                    animators[i].frame += 1;
                                } else animators[i].frame = 0;
                            }

                            renderers[i].flip_body = body_directions[i].value.flippedHorizontally();
                            renderers[i].flip_head = head_directions[i].value.flippedHorizontally();

                            renderers[i].body_index = body_animation[animators[i].frame];
                            renderers[i].head_index = head_animation[animators[i].frame];
                            renderers[i].top_index = top_animation[animators[i].frame];
                            renderers[i].bottom_index = bottom_animation[animators[i].frame];
                            renderers[i].hair_index = hair_animation[animators[i].frame];
                        }
                    }
                }
            }
        }
    }
}
