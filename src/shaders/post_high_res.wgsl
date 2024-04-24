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

    var render = tiltshift(texture, texture_sampler, uv);

    render = desaturate(render, 0.0);
    render = vignette(render, uv);
    //render = crt(render, uv, texture);

    return render;
}

fn crt(color: vec4<f32>, uv: vec2<f32>, texture: texture_2d<f32>) -> vec4<f32> {

    var line_color = color;
    var resolution = textureDimensions(texture);
    var res_x = i32(f32(resolution.x) * uv.x);
    var res_y = i32(f32(resolution.y) * uv.y);

    //lines
    if(i32(res_x) % 2 < 1 || i32(res_x) % 3 < 1) { line_color *= vec4(0.8, 0.8, 0.8, 1.0); }
    else { line_color *= vec4(1.2, 1.2, 1.2, 1.0); }

    return line_color;
}

fn vignette(color: vec4<f32>, uv: vec2<f32>) -> vec4<f32> {
    // Inner radius
    var inner = 0.5;
    // Outer radius
    var outer = 1.4;
    // Vignette strength/intensity
    var strength = 0.6;
    // Vignette roundness, higher = smoother, lower = sharper
    var curvature = 0.3;
    
    // Calculate edge curvature
    var curve = pow(abs(uv * 2.0 - 1.0), vec2(1.0 / curvature));
    // Compute distance to edge
    var edge = pow(length(curve), curvature);
    // Compute vignette gradient and intensity
    var vignette = 1.0 - strength * smoothstep(inner,outer,edge);

    return color * vignette;
}

fn desaturate(color: vec4<f32>, factor: f32) -> vec4<f32> {
    var lum = vec3( 0.299, 0.587, 0.114);
    var gray = vec3(dot(lum, color.rgb));
    return vec4(mix(color.rgb, gray ,factor), 1.0);
}

fn tiltshift(texture: texture_2d<f32>, sampl: sampler, uv: vec2<f32> ) -> vec4<f32> {
    var bluramount  = 0.5;
    var center      = 1.0;
    var stepSize    = 0.002;
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