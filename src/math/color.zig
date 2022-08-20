const zm = @import("zmath");

pub const Color = struct {
    value: zm.F32x4,

    pub fn initFloats (r: f32, g: f32, b: f32, a: f32) Color {
        return .{
            .value = zm.f32x4(r, g, b, a),
        };
    }

    pub fn initBytes (r: u8, g: u8, b: u8, a: u8) Color {
        return .{
            .value = zm.f32x4(@intToFloat(f32, r) / 255, @intToFloat(f32, g) / 255, @intToFloat(f32, b) / 255, @intToFloat(f32, a) / 255),
        };
    }

    pub fn lerp (self: Color, other: Color, t: f32) Color {
        return .{ .value = zm.lerp(self.value, other.value, t)};
    }
};

pub const Colors = struct {
    pub const white = Color.initFloats(1, 1, 1, 1);
    pub const black = Color.initFloats(0, 0, 0, 1);
    pub const red = Color.initFloats(1, 0, 0, 1);
    pub const green = Color.initFloats(0, 1, 0, 1);
    pub const blue = Color.initFloats(0, 0, 1, 1);
    pub const grass = Color.initBytes(110, 138, 92, 255);
};