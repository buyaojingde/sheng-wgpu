// Vertex shader
struct CameraUniform {
    view_proj: mat4x4<f32>,
    view: mat4x4<f32>,
};
@group(1) @binding(0)
var<uniform> camera_uniform: CameraUniform;

struct LineUniform {
    
    pos1: vec2<f32>,
    pos2: vec2<f32>,
    size: vec2<f32>,
    cpt1: vec2<f32>,
    cpt2: vec2<f32>,
    cpt3: vec2<f32>,
    cpt4: vec2<f32>,
}
@group(0) @binding(0)
var<uniform> line_uniform:LineUniform;

struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) color: vec3<f32>,
};

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) color: vec3<f32>,
};

@vertex
fn vs_main(
    model: VertexInput,
) -> VertexOutput {
    var out: VertexOutput;
    out.color = model.color;
    out.clip_position = camera_uniform.view_proj * vec4<f32>(model.position, 1.0);
    return out;
}
fn get_bezeir_point(point1: vec2<f32>, point2: vec2<f32>, point3: vec2<f32>, point4: vec2<f32>, param_t: f32) -> vec2<f32> {
    var res_pt = point1 * pow((1.0 - param_t), 3.0) + 3.0 * point2 * param_t * pow((1.0 - param_t), 2.0) + 3.0 * point3 * param_t * param_t * (1.0 - param_t) + point4 * pow(param_t, 3.0);
    return res_pt;
}
fn get_view_point(pt: vec2<f32>) -> vec2<f32> {
    let real_pt = camera_uniform.view_proj * vec4(pt, 0.0, 1.0);
    return vec2((real_pt.x / real_pt.w) * line_uniform.size.x * 0.5, (real_pt.y / real_pt.w) * line_uniform.size.y * 0.5);
}
//the bezeir curve 
fn bezeir_line(pt: vec2<f32>, line_width: f32) -> f32 {
    var res = 0.0;
    let m = 0.025;
    let final_pt1 = get_view_point(line_uniform.cpt1);
    let final_pt2 = get_view_point(line_uniform.cpt2);
    let final_pt3 = get_view_point(line_uniform.cpt3);
    let final_pt4 = get_view_point(line_uniform.cpt4);
    for (var seg: f32 = 1.0; seg <= 40.0; seg += 1.0) {
        let t = seg * m;
        var line_1 = get_bezeir_point(final_pt1, final_pt2, final_pt3, final_pt4, t - m);
        var line_2 = get_bezeir_point(final_pt1, final_pt2, final_pt3, final_pt4, t + 0.001);
        let expect_res = line_segment_with_two_point(pt, line_1, line_2, line_width);
        if expect_res > res {
            res = expect_res;
        }
    }
    return res;
}
fn line_segment_with_two_point(st: vec2<f32>, start: vec2<f32>, end: vec2<f32>, line_width: f32) -> f32 {
    let line_vector_from_end = normalize(vec2(start.x, start.y) - vec2(end.x, end.y));
    let line_vector_from_start = -line_vector_from_end;
    let st_vector_from_end = st - vec2(end.x, end.y);
    let st_vector_from_start = st - vec2(start.x, start.y);

    let proj1 = dot(line_vector_from_end, st_vector_from_end);
    let proj2 = dot(line_vector_from_start, st_vector_from_start);

    if proj1 > 0.0 && proj2 > 0.0 {


        let angle = acos(dot(line_vector_from_end, st_vector_from_end) / (length(st_vector_from_end) * length(line_vector_from_end)));

        let dist = sin(angle) * length(st_vector_from_end);

        return pow(1.0 - smoothstep(0.0, line_width / 2.0, dist), 3.0);
    } else {
        return 0.0;
    }
}

fn arc(pt: vec2<f32>, pos: vec2<f32>, center: vec2<f32>, angle: f32, line_width: f32) -> f32 {
    var result = 0.0;
    let center_start = pos - center;
    let len_start = length(center_start);
    var init_angle = atan2(center_start.y, center_start.x);
    if init_angle < 0.0 {init_angle += 6.28318530718;}
    let max_angle = init_angle + angle;
    var current_pt_angle = atan2(pt.y - center.y, pt.x - center.x);
    if current_pt_angle < 0.0 {current_pt_angle += 6.28318530718;}
    if current_pt_angle >= init_angle && current_pt_angle <= max_angle {
        let len = length(pt - center);
        let distance = abs(len_start - len);
        result = pow(1.0 - smoothstep(0.0, line_width * 0.5, distance), 1.0);
        return result;
    } else if current_pt_angle < init_angle && current_pt_angle + 6.28318530718 < max_angle {
        let len = length(pt - center);
        let distance = abs(len_start - len);
        result = pow(1.0 - smoothstep(0.0, line_width * 0.5, distance), 1.0);
        return result;
    } else {
        return result;
    }
}
// Fragment shader

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let st = vec2(in.clip_position.x, in.clip_position.y) ;
    let pt1 = camera_uniform.view_proj * vec4(line_uniform.pos1, 0.0, 1.0);
    let pt2 = camera_uniform.view_proj * vec4(line_uniform.pos2, 0.0, 1.0);


    let real_pt1 = vec2((pt1.x / pt1.w) * line_uniform.size.x * 0.5, (pt1.y / pt1.w) * line_uniform.size.y * 0.5);
    let real_pt2 = vec2((pt2.x / pt2.w) * line_uniform.size.x * 0.5, (pt2.y / pt2.w) * line_uniform.size.y * 0.5);
    var pct = line_segment_with_two_point(st, real_pt1, real_pt2, 10.0);
    if pct < 0.2 {pct = bezeir_line(st, 15.0);}
    if pct < 0.2 {
        pct = arc(st, vec2(500.0, 400.0), vec2(500.0, 490.0), 5.0, 12.0);
    }
    var final_color = mix(vec3(0.0), in.color, pct);


    if pct > 0.2 {
        return vec4<f32>(final_color, 1.0);
    } else {discard;}
}