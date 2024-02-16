struct Uniforms {
    mvp: mat4x4<f32>,
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;

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

    var render = tiltshift(texture, texture_sampler, uv);

    render = desaturate(render, 0.2);

    return render;
}

fn desaturate(color: vec4<f32>, factor: f32) -> vec4<f32> {
    var lum = vec3( 0.299, 0.587, 0.114);
    var gray = vec3(dot(lum, color.rgb));
    return vec4(mix(color.rgb, gray ,factor), 1.0);
}

fn tiltshift(texture: texture_2d<f32>, sampl: sampler, uv: vec2<f32> ) -> vec4<f32> {
    var bluramount  = 1.0;
    var center      = 1.0;
    var stepSize    = 0.004;
    var steps       = 6.0;

    var minOffs     = (steps-1.0) / -2.0;
    var maxOffs     = (steps-1.0) / 2.0;
        
    // Work out how much to blur based on the mid point 
    var amount = pow((uv.y * center) * 2.0 - 1.0, 2.0) * bluramount;
        
    // This is the accumulation of color from the surrounding pixels in the texture
    var blurred = vec3(0.0, 0.0, 0.0);
    var alpha = textureSample(texture, sampl, uv).a;
        
    // From minimum offset to maximum offset
    for (var offsX: i32 = i32(minOffs); offsX < i32(maxOffs) || offsX == i32(maxOffs); offsX++) {
        for (var offsY: i32 = i32(minOffs); offsY < i32(maxOffs) || offsY == i32(maxOffs); offsY++) {

            // copy the coord so we can mess with it
            var temp_tcoord = uv.xy;

            // work out which uv we want to sample now
            temp_tcoord.x += f32(offsX) * amount * stepSize;
            temp_tcoord.y += f32(offsY) * amount * stepSize;

            // accumulate the sample 
            blurred += textureSample(texture, sampl, temp_tcoord).rgb;
        
        } // for y
    } // for x 
        
    // because we are doing an average, we divide by the amount (x AND y, hence steps * steps)
    blurred /= vec3(steps * steps - 10);
    return vec4(blurred, alpha);
}