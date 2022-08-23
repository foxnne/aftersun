const std = @import("std");
const zm = @import("zmath");

pub const design_width: u32 = 1280;
pub const design_height: u32 = 720;
pub const design_size = zm.f32x4(@intToFloat(f32, design_width), @intToFloat(f32, design_height), 0, 0);
pub const max_zoom_offset: f32 = 3.0;

pub const pixels_per_unit: f32 = 32.0;

pub const batcher_max_sprites = 1000;

pub const zgui_font_size = 12;