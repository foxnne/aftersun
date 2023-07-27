struct EnvironmentUniforms {
    mvp: mat4x4<f32>,
    ambient_xy_angle: f32,
    ambient_z_angle: f32,
    shadow_color: vec3<f32>,
    shadow_steps: i32,
}
@group(0) @binding(0) var<uniform> uniforms: EnvironmentUniforms;

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) data: vec3<f32>
}
@vertex fn main(
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>
) -> VertexOut {
    var output: VertexOut;
    output.position_clip = vec4(position, 1.0) * uniforms.mvp;
    output.uv = uv;
    output.color = color;
    output.data = data;
    return output;
}