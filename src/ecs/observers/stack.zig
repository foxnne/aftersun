const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn observer() ecs.observer_desc_t {
    var observer_desc = std.mem.zeroes(ecs.observer_desc_t);
    observer_desc.filter.terms[0] = std.mem.zeroInit(ecs.term_t, .{ .id = ecs.id(components.Stack) });
    observer_desc.events[0] = ecs.OnSet;
    observer_desc.run = run;
    return observer_desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;
    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities()[i];
            if (ecs.field(it, components.Stack, 1)) |stacks| {
                if (stacks[i].count == 0) {
                    ecs.delete(world, entity);
                    continue;
                }
                if (ecs.get(world, entity, components.StackAnimator)) |animator| {
                    if (ecs.get_mut(world, entity, components.SpriteRenderer)) |renderer| {
                        var index: usize = 0;
                        for (animator.counts, 0..) |count, j| {
                            if (stacks[i].count >= count) {
                                index = j;
                            }
                        }
                        renderer.index = animator.animation[index];
                    }
                }
            }
        }
    }
}
