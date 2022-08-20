pub const sqrt2: f32 = 1.414213562373095;

pub const Direction = @import("direction.zig").Direction;
const rect = @import("rect.zig");
pub const Rect = rect.Rect;
pub const RectF = rect.RectF;
const color = @import("color.zig");
pub const Color = color.Color;
pub const Colors = color.Colors;

pub const Point = struct { x: i32, y: i32 };

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}
