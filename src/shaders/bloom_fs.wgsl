@group(0) @binding(1) var bloom_h: texture_2d<f32>;
@group(0) @binding(2) var bloom_h_sampler: sampler;
@fragment fn main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>,
) -> @location(0) vec4<f32> {
    var weight = array<f32, 10> (0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216, 0.0111343, 0.00849020, 0.0040293, 0.0021293, 0.00011234);

    var tex_size = textureDimensions(bloom_h);
    var tex_offset = vec2(1.0 / f32(tex_size.x), 1.0 / f32(tex_size.y)) * 2.0;

    var bloom_sample = textureSample(bloom_h, bloom_h_sampler, uv);
    var result = (bloom_sample * weight[0]).rgb;

    const multiplier = 1.5;

    for(var i: i32 = 0; i < 10; i++)
    {
        result += textureSample(bloom_h, bloom_h_sampler, uv + vec2(0.0, tex_offset.y * f32(i))).rgb * (weight[i] * multiplier);
        result += textureSample(bloom_h, bloom_h_sampler, uv - vec2(0.0, tex_offset.y * f32(i))).rgb * (weight[i] * multiplier);
    }

    return vec4(result, 1.0);
}