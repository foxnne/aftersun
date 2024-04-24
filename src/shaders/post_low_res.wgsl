struct PostUniforms {
    mvp: mat4x4<f32>,
}
@group(0) @binding(0) var<uniform> uniforms: PostUniforms;

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>
}
@vertex fn vert_main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>
) -> VertexOut {
    var output: VertexOut;
    output.position_clip = vec4(position.xy, 0.0, 1.0) * uniforms.mvp;
    output.uv = uv;
    output.color = color;
    output.data = data;
    return output;
}

@group(0) @binding(1) var texture: texture_2d<f32>;
@group(0) @binding(2) var texture_sampler: sampler;

@fragment fn frag_main(
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>,
) -> @location(0) vec4<f32> {

    var render = crt(texture, texture_sampler, uv);

    return render;
}

fn crt(texture: texture_2d<f32>, sampl: sampler, uv: vec2<f32> ) -> vec4<f32> {
    const CURVATURE = 1.2;

    const BLUR = 0.021;

    const CA_AMT = 1.006;
    //curving
    var crtUV = uv * 2.0 - 1.0;
    var offset = crtUV.yx / CURVATURE;
    crtUV += crtUV * offset * offset;
    crtUV = crtUV * 0.5 + 0.5;
    
    var edge = smoothstep(vec2(0.0, 0.0), vec2(BLUR, BLUR), crtUV) * (vec2(1.0, 1.0) - smoothstep(vec2(1.0 - BLUR, 1.0 - BLUR), vec2(1.0, 1.0), crtUV));
    
    //chromatic abberation
    var output_color = vec4(
        textureSample(texture, sampl, (crtUV - 0.5) * CA_AMT + 0.5).r,
        textureSample(texture, sampl, crtUV).g,
        textureSample(texture, sampl, (crtUV - 0.5) / CA_AMT + 0.5).b,
        1.0
    ) * edge.x * edge.y;

    return output_color;
}
