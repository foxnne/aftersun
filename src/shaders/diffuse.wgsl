struct Uniforms {
    mvp: mat4x4<f32>,
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>
}
@vertex fn vert_main(
    @builtin(vertex_index) in_vertex_index: u32,
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>
) -> VertexOut {
    var output: VertexOut;
    var vert_mode = i32(data[0]);
    var time = data[2];
    var pos = position;

    // Top sway
    if (vert_mode == 1) {
        var vert_ind = i32(in_vertex_index) % 4;
        if (vert_ind == 0) {
            pos.x += sin(time) * 5.0;
        } else if (vert_ind == 1) {
            pos.x += sin(time) * 2.5;
        }
    }
    
    output.position_clip = vec4(pos.xy, 0.0, 1.0) * uniforms.mvp;
    output.position = pos;
    output.uv = uv;
    output.color = color;
    output.data = data;
    return output;
}

@group(0) @binding(1) var diffuse: texture_2d<f32>;
@group(0) @binding(2) var palette: texture_2d<f32>;
@group(0) @binding(3) var diffuse_sampler: sampler;

const multiplier = 65025.0;

fn max3(channels: vec3<f32>) -> i32 {
    return i32(max(channels.z, max(channels.y , channels.x)));
}

fn paletteCoord(base: vec3<f32>, vert: vec3<f32>) -> vec2<f32> {
    var channels = vec3(
        clamp(base.x + vert.x * multiplier, 0.0, 1.0),
        clamp(base.y + vert.y * multiplier, 0.0, 1.0) * 2.0,
        clamp(base.z + vert.z * multiplier, 0.0, 1.0) * 3.0,
    );

    var index = max3(channels);

    let b = base.brgb;
    let v = vert.brgb;

    return vec2(b[index], v[index]);
}

@fragment fn frag_main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    var frag_mode = i32(data.y);
    var base_color = textureSample(diffuse, diffuse_sampler, uv);

    var palette_size = textureDimensions(palette);
    var palette_coord = paletteCoord(base_color.rgb, (color.rgb * 255.0) / f32(palette_size.y - 1));
    var sample = textureSample(palette, diffuse_sampler, palette_coord) * base_color.a;

    if (frag_mode == 1) {
        return sample;
    }

    return base_color * color;
}