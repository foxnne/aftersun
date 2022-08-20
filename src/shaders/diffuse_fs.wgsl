@group(0) @binding(1) var diffuse: texture_2d<f32>;
@group(0) @binding(2) var diffuse_sampler: sampler;
@group(0) @binding(3) var palette: texture_2d<f32>;
@group(0) @binding(4) var palette_sampler: sampler;

let multiplier = 65025.0;

fn max3(channels: vec3<f32>) -> i32 {
    return i32(max(channels.z, max(channels.y , channels.x)));
}

fn paletteCoord(base: vec3<f32>, vert: vec3<f32>) -> vec2<f32> {
    let channels = vec3(
        clamp(base.x + vert.x * multiplier, 0.0, 1.0),
        clamp(base.y + vert.y * multiplier, 0.0, 1.0) * 2.0,
        clamp(base.z + vert.z * multiplier, 0.0, 1.0) * 3.0,
    );

    let index = max3(channels);

    return vec2(base.brgb[index], vert.brgb[index]);
}

@stage(fragment) fn main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    let frag_mode = i32(data.y);
    var base_color = textureSample(diffuse, diffuse_sampler, uv);

    if (frag_mode == 1) {
        let palette_size = textureDimensions(palette);
        let palette_coord = paletteCoord(base_color.rgb, (color.rgb * 255.0) / f32(palette_size.y - 1));
        return textureSample(palette, palette_sampler, palette_coord) * base_color.a;
    } else {
        return base_color * color;
    }
}