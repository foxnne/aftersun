@group(0) @binding(1) var height: texture_2d<f32>;
@group(0) @binding(2) var diffuse: texture_2d<f32>;
@group(0) @binding(3) var height_sampler: sampler;
@fragment fn frag_main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    var height_sample = textureSample(height, height_sampler, uv);
    var diffuse_sample = textureSample(diffuse, height_sampler, uv);
    var vert_height =  position.z;
    var true_height = (height_sample.r * 255.0) + vert_height;
    var g_height = floor(true_height / 255.0) / 255.0;
    var r_height = (true_height - (g_height * 255.0)) / 255.0;
    var b = diffuse_sample.a - height_sample.a;
    return vec4(r_height, g_height, b, diffuse_sample.a);
}