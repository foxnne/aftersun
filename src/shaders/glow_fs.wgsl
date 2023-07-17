@group(0) @binding(1) var height: texture_2d<f32>;
@group(0) @binding(2) var diffuse: texture_2d<f32>;
@group(0) @binding(3) var height_sampler: sampler;
@stage(fragment) fn main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    let height_sample = textureSample(height, height_sampler, uv);
    let diffuse_sample = textureSample(diffuse, height_sampler, uv);
    return diffuse_sample * height_sample.bbbb;
}