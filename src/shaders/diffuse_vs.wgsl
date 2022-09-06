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
@stage(vertex) fn main(
    @builtin(vertex_index) in_vertex_index: u32,
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) data: vec3<f32>
) -> VertexOut {
    var output: VertexOut;
    let vert_mode = i32(data[0]);
    let time = data[2];
    var pos = position;

    // Top sway
    if (vert_mode == 1) {
        let vert_ind = i32(in_vertex_index) % 4;
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