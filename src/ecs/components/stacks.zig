const flecs = @import("flecs");

pub const Stack = struct {
    count: u32 = 1,
    max: u32,
};

pub const StackAnimator = struct {
    animation: []usize,
    counts: []const usize,
};
