const std = @import("std");
const zmath = @import("zmath");

const core = @import("mach").core;

pub const Color = struct {
    value: zmath.F32x4,

    pub fn initFloats(r: f32, g: f32, b: f32, a: f32) Color {
        return .{
            .value = zmath.f32x4(r, g, b, a),
        };
    }

    pub fn initBytes(r: u8, g: u8, b: u8, a: u8) Color {
        return .{
            .value = zmath.f32x4(@as(f32, @floatFromInt(r)) / 255, @as(f32, @floatFromInt(g)) / 255, @as(f32, @floatFromInt(b)) / 255, @as(f32, @floatFromInt(a)) / 255),
        };
    }

    pub fn lerp(self: Color, other: Color, t: f32) Color {
        return .{ .value = zmath.lerp(self.value, other.value, t) };
    }

    pub fn toSlice(self: Color) [4]f32 {
        var slice: [4]f32 = undefined;
        zmath.storeArr4(&slice, self.value);
        return slice;
    }

    pub fn toU32(self: Color) u32 {
        const Packed = packed struct(u32) {
            r: u8,
            g: u8,
            b: u8,
            a: u8,
        };

        const p = Packed{
            .r = @as(u8, @intFromFloat(self.value[0] * 255.0)),
            .g = @as(u8, @intFromFloat(self.value[1] * 255.0)),
            .b = @as(u8, @intFromFloat(self.value[2] * 255.0)),
            .a = @as(u8, @intFromFloat(self.value[3] * 255.0)),
        };

        return @as(u32, @bitCast(p));
    }

    pub fn toGpuColor(self: Color) core.gpu.Color {
        return .{
            .r = self.value[0],
            .g = self.value[1],
            .b = self.value[2],
            .a = self.value[3],
        };
    }
};

pub const Colors = struct {
    pub const white = Color.initFloats(1, 1, 1, 1);
    pub const black = Color.initFloats(0, 0, 0, 1);
    pub const red = Color.initFloats(1, 0, 0, 1);
    pub const green = Color.initFloats(0, 1, 0, 1);
    pub const blue = Color.initFloats(0, 0, 1, 1);
    pub const grass = Color.initBytes(110, 138, 92, 255);
    pub const clear = Color.initBytes(0, 0, 0, 0);
    pub const water = Color.initBytes(35, 100, 255, 255);
};
