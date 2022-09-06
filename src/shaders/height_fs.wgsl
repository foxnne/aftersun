@group(0) @binding(1) var height: texture_2d<f32>;
@group(0) @binding(2) var height_sampler: sampler;
@stage(fragment) fn main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    let height_sample = textureSample(height, height_sampler, uv);
    let vert_height =  position.z;
    let true_height = (height_sample.r * 255.0) + vert_height;
    let g_height = floor(true_height / 255.0) / 255.0;
    let r_height = (true_height - (g_height * 255.0)) / 255.0;
    return vec4(r_height, g_height, 0.0, height_sample.a);
}