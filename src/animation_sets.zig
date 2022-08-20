const animations = @import("animations.zig");

pub const AnimationSet = struct {
    idle_n: []usize,
    idle_ne: []usize,
    idle_e: []usize,
    idle_se: []usize,
    idle_s: []usize,
    walk_n: []usize,
    walk_ne: []usize,
    walk_e: []usize,
    walk_se: []usize,
    walk_s: []usize,
};

pub const hair_f_01: AnimationSet = .{
    .idle_n = animations.Idle_N_HairF01[0..],
    .idle_ne = animations.Idle_NE_HairF01[0..],
    .idle_e = animations.Idle_E_HairF01[0..],
    .idle_se = animations.Idle_SE_HairF01[0..],
    .idle_s = animations.Idle_S_HairF01[0..],
    .walk_n = animations.Walk_N_HairF01[0..],
    .walk_ne = animations.Walk_NE_HairF01[0..],
    .walk_e = animations.Walk_E_HairF01[0..],
    .walk_se = animations.Walk_SE_HairF01[0..],
    .walk_s = animations.Walk_S_HairF01[0..],
};

pub const head: AnimationSet = .{
    .idle_n = animations.Idle_N_Head[0..],
    .idle_ne = animations.Idle_NE_Head[0..],
    .idle_e = animations.Idle_E_Head[0..],
    .idle_se = animations.Idle_SE_Head[0..],
    .idle_s = animations.Idle_S_Head[0..],
    .walk_n = animations.Walk_N_Head[0..],
    .walk_ne = animations.Walk_NE_Head[0..],
    .walk_e = animations.Walk_E_Head[0..],
    .walk_se = animations.Walk_SE_Head[0..],
    .walk_s = animations.Walk_S_Head[0..],
};

pub const body: AnimationSet = .{
    .idle_n = animations.Idle_NE_Body[0..],
    .idle_ne = animations.Idle_NE_Body[0..],
    .idle_e = animations.Idle_NE_Body[0..],
    .idle_se = animations.Idle_SE_Body[0..],
    .idle_s = animations.Idle_SE_Body[0..],
    .walk_n = animations.Walk_N_Body[0..],
    .walk_ne = animations.Walk_NE_Body[0..],
    .walk_e = animations.Walk_E_Body[0..],
    .walk_se = animations.Walk_SE_Body[0..],
    .walk_s = animations.Walk_S_Body[0..],
};

pub const top_f_01: AnimationSet = .{
    .idle_n = animations.Idle_NE_TopF01[0..],
    .idle_ne = animations.Idle_NE_TopF01[0..],
    .idle_e = animations.Idle_NE_TopF01[0..],
    .idle_se = animations.Idle_SE_TopF01[0..],
    .idle_s = animations.Idle_SE_TopF01[0..],
    .walk_n = animations.Walk_N_TopF01[0..],
    .walk_ne = animations.Walk_NE_TopF01[0..],
    .walk_e = animations.Walk_E_TopF01[0..],
    .walk_se = animations.Walk_SE_TopF01[0..],
    .walk_s = animations.Walk_S_TopF01[0..],
};

pub const top_f_02: AnimationSet = .{
    .idle_n = animations.Idle_NE_TopF02[0..],
    .idle_ne = animations.Idle_NE_TopF02[0..],
    .idle_e = animations.Idle_NE_TopF02[0..],
    .idle_se = animations.Idle_SE_TopF02[0..],
    .idle_s = animations.Idle_SE_TopF02[0..],
    .walk_n = animations.Walk_N_TopF02[0..],
    .walk_ne = animations.Walk_NE_TopF02[0..],
    .walk_e = animations.Walk_E_TopF02[0..],
    .walk_se = animations.Walk_SE_TopF02[0..],
    .walk_s = animations.Walk_S_TopF02[0..],
};

pub const bottom_f_01: AnimationSet = .{
    .idle_n = animations.Idle_NE_BottomF01[0..],
    .idle_ne = animations.Idle_NE_BottomF01[0..],
    .idle_e = animations.Idle_NE_BottomF01[0..],
    .idle_se = animations.Idle_SE_BottomF01[0..],
    .idle_s = animations.Idle_SE_BottomF01[0..],
    .walk_n = animations.Walk_N_BottomF01[0..],
    .walk_ne = animations.Walk_NE_BottomF01[0..],
    .walk_e = animations.Walk_E_BottomF01[0..],
    .walk_se = animations.Walk_SE_BottomF01[0..],
    .walk_s = animations.Walk_S_BottomF01[0..],
};

pub const bottom_f_02: AnimationSet = .{
    .idle_n = animations.Idle_NE_BottomF02[0..],
    .idle_ne = animations.Idle_NE_BottomF02[0..],
    .idle_e = animations.Idle_NE_BottomF02[0..],
    .idle_se = animations.Idle_SE_BottomF02[0..],
    .idle_s = animations.Idle_SE_BottomF02[0..],
    .walk_n = animations.Walk_N_BottomF02[0..],
    .walk_ne = animations.Walk_NE_BottomF02[0..],
    .walk_e = animations.Walk_E_BottomF02[0..],
    .walk_se = animations.Walk_SE_BottomF02[0..],
    .walk_s = animations.Walk_S_BottomF02[0..],
};
