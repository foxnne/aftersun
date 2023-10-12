const std = @import("std");
const zmath = @import("zmath");
const ecs = @import("zflecs");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn system() ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Stack) };
    desc.query.filter.terms[1] = .{ .id = ecs.pair(ecs.id(components.Request), ecs.id(components.Stack)) };
    desc.query.filter.terms[2] = .{ .id = ecs.pair(ecs.id(components.RequestZeroOther), ecs.id(components.Stack)), .oper = ecs.oper_kind_t.Optional };
    desc.query.filter.terms[3] = .{ .id = ecs.pair(ecs.id(components.Cooldown), ecs.id(components.Movement)), .oper = ecs.oper_kind_t.Not };

    desc.run = run;
    return desc;
}

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            const entity = it.entities()[i];
            if (ecs.field(it, components.Stack, 1)) |stacks| {
                if (ecs.field(it, components.Stack, 2)) |requests| {
                    if (ecs.field(it, components.RequestZeroOther, 3)) |request_others| {
                        if (ecs.get_mut(world, request_others[i].target, components.Stack)) |stack| {
                            stack.count = 0;
                            ecs.modified_id(world, request_others[i].target, ecs.id(components.Stack));
                        }
                        ecs.remove_pair(world, entity, ecs.id(components.RequestZeroOther), ecs.id(components.Stack));
                    }

                    stacks[i].count = requests[i].count;
                    stacks[i].max = requests[i].max;
                    ecs.modified_id(world, entity, ecs.id(components.Stack));
                    ecs.remove_pair(world, entity, ecs.id(components.Request), ecs.id(components.Stack));
                }
            }
        }
    }
}
