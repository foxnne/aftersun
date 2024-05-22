const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

const Direction = game.math.Direction;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.CharacterAnimator) };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.CharacterRenderer) };
    desc.query.filter.terms[2] = .{ .id = ecs.pair(ecs.id(components.Direction), ecs.id(components.Movement)) };
    desc.query.filter.terms[3] = .{ .id = ecs.pair(ecs.id(components.Direction), ecs.id(components.Head)) };
    desc.query.filter.terms[4] = .{ .id = ecs.pair(ecs.id(components.Direction), ecs.id(components.Body)) };
    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities()[i];
            if (ecs.field(it, components.CharacterAnimator, 1)) |animators| {
                if (ecs.field(it, components.CharacterRenderer, 2)) |renderers| {
                    if (ecs.field(it, components.Direction, 4)) |head_directions| {
                        if (ecs.field(it, components.Direction, 5)) |body_directions| {
                            const move_direction: Direction = if (ecs.field(it, components.Direction, 3)) |move_directions| move_directions[i] else Direction.none;
                            if (body_directions[i] == .none) body_directions[i] = if (move_direction != .none) move_direction else Direction.se;
                            if (head_directions[i] == .none) head_directions[i] = body_directions[i];
                            var temp_head_direction = head_directions[i];

                            if (entity == game.state.entities.player) {
                                const mouse_world = game.state.camera.screenToWorld(zmath.f32x4(game.state.mouse.position[0], game.state.mouse.position[1], 0, 0));
                                const player_position = if (ecs.get(world, entity, components.Position)) |position| position.toF32x4() else zmath.f32x4s(0);
                                const mouse_vector = mouse_world - player_position;
                                temp_head_direction = Direction.find(8, mouse_vector[0], mouse_vector[1]);
                            }

                            // Declare our needed animations
                            var head_animation: []usize = undefined;
                            var body_animation: []usize = undefined;
                            var top_animation: []usize = undefined;
                            var bottom_animation: []usize = undefined;
                            var feet_animation: []usize = undefined;
                            var hair_animation: []usize = undefined;
                            var back_animation: []usize = undefined;

                            if (move_direction != .none) {
                                animators[i].state = components.CharacterAnimator.State.walk;
                                animators[i].fps = @intFromFloat((((1.0 - game.settings.movement_cooldown) * 100.0) / 5.0));
                                body_directions[i] = move_direction;

                                // Clamp face direction to directions close to the movement direction
                                if (temp_head_direction == move_direction or
                                    temp_head_direction == move_direction.rotateCW() or
                                    temp_head_direction == move_direction.rotateCCW())
                                {
                                    head_directions[i] = temp_head_direction;
                                } else if (head_directions[i] != move_direction and
                                    head_directions[i] != move_direction.rotateCW() and
                                    head_directions[i] != move_direction.rotateCCW())
                                {
                                    head_directions[i] = move_direction;
                                }

                                // Set relevant animations for the body based on movement direction
                                switch (body_directions[i]) {
                                    .n => {
                                        body_animation = animators[i].body_set.walk_n;
                                        top_animation = animators[i].top_set.walk_n;
                                        bottom_animation = animators[i].bottom_set.walk_n;
                                        feet_animation = animators[i].feet_set.walk_n;
                                        back_animation = animators[i].back_set.walk_n;
                                    },
                                    .nw, .ne => {
                                        body_animation = animators[i].body_set.walk_ne;
                                        top_animation = animators[i].top_set.walk_ne;
                                        bottom_animation = animators[i].bottom_set.walk_ne;
                                        feet_animation = animators[i].feet_set.walk_ne;
                                        back_animation = animators[i].back_set.walk_ne;
                                    },
                                    .w, .e => {
                                        body_animation = animators[i].body_set.walk_e;
                                        top_animation = animators[i].top_set.walk_e;
                                        bottom_animation = animators[i].bottom_set.walk_e;
                                        feet_animation = animators[i].feet_set.walk_e;
                                        back_animation = animators[i].back_set.walk_e;
                                    },
                                    .sw, .se => {
                                        body_animation = animators[i].body_set.walk_se;
                                        top_animation = animators[i].top_set.walk_se;
                                        bottom_animation = animators[i].bottom_set.walk_se;
                                        feet_animation = animators[i].feet_set.walk_se;
                                        back_animation = animators[i].back_set.walk_se;
                                    },
                                    .s => {
                                        body_animation = animators[i].body_set.walk_s;
                                        top_animation = animators[i].top_set.walk_s;
                                        bottom_animation = animators[i].bottom_set.walk_s;
                                        feet_animation = animators[i].feet_set.walk_s;
                                        back_animation = animators[i].back_set.walk_s;
                                    },
                                    else => {},
                                }

                                switch (head_directions[i]) {
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
                                animators[i].fps = 8;

                                // When idle, only allow the 4 angled directions as body directions.
                                body_directions[i] = switch (body_directions[i]) {
                                    .n => .ne,
                                    .s => .se,
                                    .e => .ne,
                                    .w => .sw,
                                    else => body_directions[i],
                                };

                                // Clamp face direction to directions close to the body direction
                                if (temp_head_direction == body_directions[i] or
                                    temp_head_direction == body_directions[i].rotateCW() or
                                    temp_head_direction == body_directions[i].rotateCCW() or
                                    temp_head_direction == body_directions[i].rotateCW().rotateCW() or
                                    temp_head_direction == body_directions[i].rotateCCW().rotateCCW())
                                {
                                    head_directions[i] = temp_head_direction;
                                }

                                // Set relevant animations for the body based on previous body direction
                                switch (body_directions[i]) {
                                    .n => {
                                        body_animation = animators[i].body_set.idle_n;
                                        top_animation = animators[i].top_set.idle_n;
                                        bottom_animation = animators[i].bottom_set.idle_n;
                                        feet_animation = animators[i].feet_set.idle_n;
                                        back_animation = animators[i].back_set.idle_n;
                                    },
                                    .nw, .ne => {
                                        body_animation = animators[i].body_set.idle_ne;
                                        top_animation = animators[i].top_set.idle_ne;
                                        bottom_animation = animators[i].bottom_set.idle_ne;
                                        feet_animation = animators[i].feet_set.idle_ne;
                                        back_animation = animators[i].back_set.idle_ne;
                                    },
                                    .w, .e => {
                                        body_animation = animators[i].body_set.idle_e;
                                        top_animation = animators[i].top_set.idle_e;
                                        bottom_animation = animators[i].bottom_set.idle_e;
                                        feet_animation = animators[i].feet_set.idle_e;
                                        back_animation = animators[i].back_set.idle_e;
                                    },
                                    .sw, .se => {
                                        body_animation = animators[i].body_set.idle_se;
                                        top_animation = animators[i].top_set.idle_se;
                                        bottom_animation = animators[i].bottom_set.idle_se;
                                        feet_animation = animators[i].feet_set.idle_se;
                                        back_animation = animators[i].back_set.idle_se;
                                    },
                                    .s => {
                                        body_animation = animators[i].body_set.idle_s;
                                        top_animation = animators[i].top_set.idle_s;
                                        bottom_animation = animators[i].bottom_set.idle_s;
                                        feet_animation = animators[i].feet_set.idle_s;
                                        back_animation = animators[i].back_set.idle_s;
                                    },
                                    else => {},
                                }

                                switch (head_directions[i]) {
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

                            if (animators[i].elapsed > (1.0 / @as(f32, @floatFromInt(animators[i].fps)))) {
                                animators[i].elapsed = 0.0;

                                if (animators[i].frame < 7) {
                                    animators[i].frame += 1;
                                } else animators[i].frame = 0;
                            }

                            renderers[i].flip_body = body_directions[i].flippedHorizontally();
                            renderers[i].flip_head = head_directions[i].flippedHorizontally();

                            renderers[i].body_index = body_animation[animators[i].frame];
                            renderers[i].head_index = head_animation[animators[i].frame];
                            renderers[i].top_index = top_animation[animators[i].frame];
                            renderers[i].bottom_index = bottom_animation[animators[i].frame];
                            renderers[i].feet_index = feet_animation[animators[i].frame];
                            renderers[i].hair_index = hair_animation[animators[i].frame];
                            renderers[i].back_index = back_animation[animators[i].frame];
                        }
                    }
                }
            }
        }
    }
}
