const std = @import("std");
const zm = @import("zmath");
const ecs = @import("zflecs");
const imgui = @import("zig-imgui");
const game = @import("../../aftersun.zig");
const components = game.components;

pub fn groupBy(world: *ecs.world_t, table: *ecs.table_t, id: ecs.entity_t, ctx: ?*anyopaque) callconv(.C) ecs.entity_t {
    _ = ctx;
    var match: ecs.entity_t = 0;
    if (ecs.search(world, table, ecs.pair(id, ecs.Wildcard), &match) != -1) {
        return ecs.pair_second(match);
    }
    return 0;
}

pub fn system(world: *ecs.world_t) ecs.system_desc_t {
    var desc: ecs.system_desc_t = .{};
    desc.query.filter.terms[0] = .{ .id = ecs.id(components.Player), .inout = .In };
    desc.query.filter.terms[1] = .{ .id = ecs.id(components.Position), .inout = .In };
    desc.run = run;

    var ctx_desc: ecs.query_desc_t = .{};
    ctx_desc.filter.terms[0] = .{ .id = ecs.pair(ecs.id(components.Cell), ecs.Wildcard), .inout = .In };
    ctx_desc.filter.terms[1] = .{ .id = ecs.id(components.Position), .inout = .In };
    ctx_desc.filter.terms[2] = .{ .id = ecs.pair(ecs.id(components.Ignore), ecs.id(components.Inspect)), .oper = ecs.oper_kind_t.Not, .inout = .In };
    ctx_desc.group_by = groupBy;
    ctx_desc.group_by_id = ecs.id(components.Cell);
    desc.ctx = ecs.query_init(world, &ctx_desc) catch unreachable;

    return desc;
}

var inspect_tile: ?components.Tile = null;
var inspect_time: f32 = 0.0;
var time: f32 = 0.0;
var inspect_target: ecs.entity_t = 0;
var last_width: f32 = 0.0;
var secondary: bool = false;

pub fn run(it: *ecs.iter_t) callconv(.C) void {
    const world = it.world;

    var inspect: bool = false;

    if (game.state.mouse.button(.secondary)) |bt| {
        if (bt.released())
            secondary = !secondary;

        if (secondary) {
            inspect = true;
        }
    }
    if (game.state.hotkeys.hotkey(.inspect)) |hk| {
        if (hk.down()) {
            inspect = true;
        }
    }

    game.state.scanner_state = inspect;

    while (ecs.iter_next(it)) {
        var i: usize = 0;
        while (i < it.count()) : (i += 1) {
            var counter: u64 = 0;
            var target_entity: ?ecs.entity_t = null;

            if (!imgui.isWindowHovered(imgui.HoveredFlags_AnyWindow) and !imgui.isAnyItemHovered()) {
                const mouse = game.state.mouse.tile();
                inspect_tile = .{
                    .x = mouse[0],
                    .y = mouse[1],
                };
            }

            if (ecs.field(it, components.Position, 2)) |player_positions| {
                if (inspect_tile) |*mouse_tile| {
                    mouse_tile.z = player_positions[i].tile.z;

                    if (it.ctx) |ctx| {
                        const query = @as(*ecs.query_t, @ptrCast(ctx));
                        var query_it = ecs.query_iter(world, query);

                        if (game.state.cells.get(mouse_tile.toCell())) |cell_entity| {
                            ecs.query_set_group(&query_it, cell_entity);
                        }

                        while (ecs.iter_next(&query_it)) {
                            var j: usize = 0;
                            while (j < query_it.count()) : (j += 1) {
                                if (ecs.field(&query_it, components.Position, 2)) |positions| {
                                    if (positions[j].tile.x == mouse_tile.x and positions[j].tile.y == mouse_tile.y and positions[j].tile.z == mouse_tile.z) {
                                        if (positions[j].tile.counter > counter) {
                                            counter = positions[j].tile.counter;
                                            target_entity = query_it.entities()[j];
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (target_entity) |target| {
                        if (target == inspect_target and inspect) {
                            if (inspect_time < 1.0) {
                                inspect_time += @min(1.0 - inspect_time, it.delta_time * 3.0);
                            } else {
                                inspect_time = 1.0;
                            }
                        } else if (target == inspect_target and !inspect) {
                            if (inspect_time > 0.0) {
                                inspect_time -= @min(it.delta_time * 3.0, inspect_time);
                            }
                            if (inspect_time <= 0.0) {
                                inspect_time = 0.0;
                                inspect = false;
                            }
                        } else {
                            inspect_target = target;
                            inspect_time = 0.0;
                        }
                    } else {
                        if (inspect_time > 0.0) {
                            inspect_time -= @min(it.delta_time * 3.0, inspect_time);
                        }
                        if (inspect_time <= 0.0) {
                            inspect_time = 0.0;
                            inspect = false;
                            secondary = false;
                        }
                    }
                    if (inspect_time > 0.0) {
                        if (inspect_target != 0 and ecs.is_alive(world, inspect_target)) {
                            if (ecs.get(world, inspect_target, components.Position)) |target_tile_position| {
                                //const target_tile_position = mouse_tile.toPosition(.position).toF32x4();

                                const target_screen_position = game.state.camera.worldToScreen(target_tile_position.toF32x4());

                                const examine_text = createExamineText(game.state.allocator, inspect_target);
                                defer game.state.allocator.free(examine_text);

                                const index: usize = std.math.clamp(@as(usize, @intFromFloat(@as(f32, @floatFromInt(examine_text.len)) * inspect_time)), 1, examine_text.len);

                                const indexed_text = std.fmt.allocPrintZ(game.state.allocator, "{s}", .{examine_text[0..index]}) catch unreachable;
                                defer game.state.allocator.free(indexed_text);

                                var width = imgui.calcTextSize(indexed_text);

                                if (width.x < last_width)
                                    width.x = last_width;

                                const height_offset: f32 = if (inspect_target == game.state.entities.player) 48.0 else 48.0;

                                const window_pos: imgui.Vec2 = .{ .x = @trunc(target_screen_position[0] - width.x / 2.0), .y = @trunc(target_screen_position[1] - height_offset - imgui.getTextLineHeightWithSpacing()) };
                                var bg_color = game.settings.colors.background;
                                bg_color.value *= game.state.environment.ambientColor().value;
                                bg_color.value[3] = std.math.clamp(inspect_time * game.settings.colors.background.value[3], 0.0, 1.0);

                                var text_color = game.settings.colors.text;
                                text_color.value[3] = std.math.clamp(inspect_time * game.settings.colors.text.value[3], 0.0, 1.0);

                                const im_text_color = text_color.toImguiVec4();

                                imgui.pushStyleColorImVec4(imgui.Col_Button, im_text_color);
                                imgui.pushStyleColorImVec4(imgui.Col_ButtonHovered, .{ .x = im_text_color.x, .y = im_text_color.y, .z = im_text_color.z, .w = 1.0 });
                                imgui.pushStyleColorImVec4(imgui.Col_WindowBg, bg_color.toImguiVec4());
                                imgui.pushStyleColorImVec4(imgui.Col_Border, im_text_color);
                                imgui.pushStyleColorImVec4(imgui.Col_Text, bg_color.toImguiVec4());

                                imgui.pushStyleVar(imgui.StyleVar_WindowBorderSize, 1.0);
                                defer imgui.popStyleVar();

                                defer imgui.popStyleColorEx(5);

                                imgui.setNextWindowPos(window_pos, imgui.Cond_Always);
                                const flags: imgui.WindowFlags = imgui.WindowFlags_AlwaysAutoResize | imgui.WindowFlags_NoCollapse;
                                if (imgui.begin("Scan...##InspectWindow", null, flags)) {
                                    defer imgui.end();

                                    imgui.popStyleColor();
                                    imgui.pushStyleColorImVec4(imgui.Col_Text, im_text_color);

                                    last_width = imgui.getWindowWidth();

                                    if (imgui.getForegroundDrawList()) |draw_list| {
                                        draw_list.pushClipRectFullScreen();
                                        defer draw_list.popClipRect();

                                        const window_width = imgui.getWindowWidth();
                                        const window_height = imgui.getWindowHeight();

                                        draw_list.addTriangleFilled(
                                            .{ .x = @trunc(window_pos.x + window_width / 2.0 - 5.0), .y = @trunc(window_pos.y + window_height + 1.5) },
                                            .{ .x = @trunc(window_pos.x + window_width / 2.0), .y = @trunc(window_pos.y + window_height + 8.5 + 1.1) },
                                            .{ .x = @trunc(window_pos.x + 5.0 + window_width / 2.0), .y = @trunc(window_pos.y + window_height + 1.5) },
                                            text_color.toU32(),
                                        );

                                        //drawWindowEdges(window_pos, draw_list, text_color);
                                    }
                                    imgui.text(indexed_text);
                                }

                                imgui.popStyleColor();
                                imgui.pushStyleColorImVec4(imgui.Col_Text, bg_color.toImguiVec4());

                                const useable = ecs.has_id(world, inspect_target, ecs.id(components.Useable));

                                const show_choice_dialog = useable or inspect_target == game.state.entities.player;

                                if (show_choice_dialog) {
                                    // imgui.pushStyleColorImVec4(imgui.Col_WindowBg, .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 });
                                    // defer imgui.popStyleColor();

                                    imgui.pushStyleVarImVec2(imgui.StyleVar_WindowPadding, .{ .x = 10.0, .y = 10.0 });
                                    defer imgui.popStyleVar();

                                    // imgui.pushStyleVar(imgui.StyleVar_WindowBorderSize, 0.0);
                                    // defer imgui.popStyleVar();

                                    //imgui.sameLine();

                                    imgui.setNextWindowSize(.{ .x = 85, .y = 0.0 }, imgui.Cond_None);
                                    imgui.setNextWindowPos(.{ .x = @trunc(target_screen_position[0] + game.settings.pixels_per_unit / 2.0 * game.state.camera.zoom / 2.0), .y = @trunc(target_screen_position[1]) }, imgui.Cond_Always);
                                    if (imgui.begin("Act...##ChoiceDialog", null, flags)) {
                                        defer imgui.end();

                                        // if (imgui.getForegroundDrawList()) |draw_list| {
                                        //     draw_list.pushClipRectFullScreen();
                                        //     defer draw_list.popClipRect();

                                        //     drawWindowEdges(draw_list, text_color);
                                        // }

                                        if (useable) {
                                            if (imgui.buttonEx(if (ecs.has_id(world, inspect_target, ecs.id(components.Consumeable))) "Consume" else "Use", .{ .x = -1.0, .y = 0.0 })) {
                                                _ = ecs.set_pair(world, game.state.entities.player, ecs.id(components.Request), ecs.id(components.Use), components.Use, .{ .target = mouse_tile.* });
                                            }
                                            if (imgui.buttonEx("Use with", .{ .x = -1.0, .y = 0.0 })) {}
                                        }

                                        if (inspect_target == game.state.entities.player) {
                                            if (imgui.buttonEx("Change", .{ .x = -1.0, .y = 0.0 })) {
                                                var prng = std.rand.DefaultPrng.init(@as(u64, @intFromFloat(game.state.game_time * 10000)));
                                                const rand = prng.random();

                                                if (ecs.get_mut(world, game.state.entities.player, components.CharacterAnimator)) |animator| {
                                                    animator.top_set = if (rand.boolean()) game.animation_sets.top_f_01 else game.animation_sets.top_f_02;
                                                    animator.bottom_set = if (rand.boolean()) game.animation_sets.bottom_f_02 else game.animation_sets.bottom_f_01;
                                                }

                                                if (ecs.get_mut(world, game.state.entities.player, components.CharacterRenderer)) |renderer| {
                                                    const top = rand.intRangeAtMost(u8, 1, 12);
                                                    const bottom = rand.intRangeAtMost(u8, 1, 12);
                                                    const hair = rand.intRangeAtMost(u8, 1, 12);

                                                    renderer.top_color = game.math.Color.initBytes(top, 0, 0, 255).toSlice();
                                                    renderer.bottom_color = game.math.Color.initBytes(bottom, 0, 0, 255).toSlice();
                                                    renderer.hair_color = game.math.Color.initBytes(hair, 0, 0, 255).toSlice();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

fn orderBy(_: ecs.entity_t, c1: ?*const anyopaque, _: ecs.entity_t, c2: ?*const anyopaque) callconv(.C) c_int {
    const tile_1 = ecs.cast(components.Position, c1);
    const tile_2 = ecs.cast(components.Position, c2);

    return @as(c_int, @intCast(@intFromBool(tile_1.tile.counter > tile_2.tile.counter))) - @as(c_int, @intCast(@intFromBool(tile_1.tile.counter < tile_2.tile.counter)));
}

fn createExamineText(allocator: std.mem.Allocator, target: ecs.entity_t) [:0]u8 {
    const prefab = ecs.get_target(game.state.world, target, ecs.IsA, 0);

    var name = if (prefab != 0) (if (ecs.get_name(game.state.world, prefab)) |n| n else "error") else if (ecs.get_name(game.state.world, target)) |n| n else "error";
    if (target == game.state.entities.player) name = "myself";

    const prefix = "I see";

    const count = if (ecs.get(game.state.world, target, components.Stack)) |stack| stack.count else 1;

    const n = std.mem.span(name);
    var buffer: [128]u8 = undefined;
    _ = std.mem.replace(u8, n, "_", " ", &buffer);
    const fixed_name = buffer[0..n.len];

    if (count > 1) {
        return std.fmt.allocPrintZ(allocator, "{s} {d} {s}s.", .{ prefix, count, fixed_name }) catch unreachable;
    } else {
        if (target != game.state.entities.player) {
            const quantifier = switch (name[0]) {
                'a', 'e', 'i', 'o', 'u' => "an",
                else => "a",
            };

            return std.fmt.allocPrintZ(allocator, "{s} {s} {s}.", .{ prefix, quantifier, fixed_name }) catch unreachable;
        } else {
            return std.fmt.allocPrintZ(allocator, "{s} {s}.", .{ prefix, fixed_name }) catch unreachable;
        }
    }
}

fn drawWindowEdges(draw_list: *imgui.DrawList, color: game.math.Color) void {
    const window_pos = imgui.getWindowPos();
    const window_width = imgui.getWindowWidth();
    const window_height = imgui.getWindowHeight();

    const length = 8.0;
    const thickness = 2.0;

    const offset = 1.0;

    // TL
    draw_list.addLineEx(
        .{ .x = window_pos.x - offset, .y = window_pos.y - offset },
        .{ .x = window_pos.x + length - offset, .y = window_pos.y - offset },
        color.toU32(),
        thickness,
    );
    draw_list.addLineEx(
        .{ .x = window_pos.x - offset, .y = window_pos.y + length - offset },
        .{ .x = window_pos.x - offset, .y = window_pos.y - offset },
        color.toU32(),
        thickness,
    );

    // BR
    draw_list.addLineEx(
        .{ .x = window_pos.x + window_width - length + offset, .y = window_pos.y + window_height + offset },
        .{ .x = window_pos.x + window_width + offset, .y = window_pos.y + window_height + offset },
        color.toU32(),
        thickness,
    );
    draw_list.addLineEx(
        .{ .x = window_pos.x + window_width + offset, .y = window_pos.y + window_height - length + offset },
        .{ .x = window_pos.x + window_width + offset, .y = window_pos.y + window_height + offset },
        color.toU32(),
        thickness,
    );

    // TR
    draw_list.addLineEx(
        .{ .x = window_pos.x + window_width - length + offset, .y = window_pos.y - offset },
        .{ .x = window_pos.x + window_width + offset, .y = window_pos.y - offset },
        color.toU32(),
        thickness,
    );
    draw_list.addLineEx(
        .{ .x = window_pos.x + window_width + offset, .y = window_pos.y - offset },
        .{ .x = window_pos.x + window_width + offset, .y = window_pos.y + length - offset },
        color.toU32(),
        thickness,
    );

    // BL
    draw_list.addLineEx(
        .{ .x = window_pos.x - offset, .y = window_pos.y + window_height - length + offset },
        .{ .x = window_pos.x - offset, .y = window_pos.y + window_height + offset },
        color.toU32(),
        thickness,
    );
    draw_list.addLineEx(
        .{ .x = window_pos.x - offset, .y = window_pos.y + window_height + offset },
        .{ .x = window_pos.x + length - offset, .y = window_pos.y + window_height + offset },
        color.toU32(),
        thickness,
    );
}
