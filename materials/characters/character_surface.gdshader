shader_type spatial;

uniform vec4 tint : source_color = vec4(1.0);
uniform int finish = 0; // wool, skin, hair, leather
uniform float base_roughness : hint_range(0.0, 1.0) = 0.9;
uniform float base_specular : hint_range(0.0, 1.0) = 0.18;

varying vec3 object_metres;
varying vec3 object_normal;

float grain_hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.11369, 0.13787));
	p += dot(p, p.yxz + 19.19);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	vec3 scale_metres = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	object_metres = VERTEX * scale_metres;
	object_normal = NORMAL;
}

void fragment() {
	vec3 p = object_metres;
	vec3 microcell = p * (finish == 0 ? 410.0 : 570.0);
	float grain_visible = 1.0 - smoothstep(0.48, 1.5, length(fwidth(microcell)));
	float grain = (grain_hash(floor(microcell)) - 0.5) * grain_visible;
	vec3 albedo = tint.rgb;
	float rough = base_roughness;
	if (finish == 0) {
		float yarn = sin((p.y + (p.x + p.z) * 0.72) * 752.0) * grain_visible;
		albedo *= 1.0 + grain * 0.060 + yarn * 0.014;
		rough += grain * 0.10;
	} else if (finish == 1) {
		float front = smoothstep(0.1, 0.85, -object_normal.z);
		vec2 cheek_delta = vec2((abs(p.x) - 0.056) * 32.0, (p.y - 0.145) * 36.0);
		float cheek = exp(-dot(cheek_delta, cheek_delta)) * front;
		float forehead = smoothstep(0.17, 0.24, p.y) * front;
		vec2 nose_delta = vec2(p.x * 55.0, (p.y - 0.155) * 39.0);
		float nose = exp(-dot(nose_delta, nose_delta)) * front;
		albedo *= 1.0 + grain * 0.025 + forehead * 0.063;
		albedo += vec3(0.065, -0.007, -0.008) * (cheek + 0.48 * nose);
		rough += cheek * 0.08 - nose * 0.10 - forehead * 0.043;
	} else if (finish == 2) {
		float strand = sin((p.x * 0.9 + p.y * 0.21 - p.z * 0.6) * 455.0) * grain_visible;
		albedo *= 1.0 + strand * 0.08 + grain * 0.065;
		rough += strand * 0.035;
	} else {
		albedo *= 1.0 + grain * 0.105;
		rough += grain * 0.11;
	}
	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.32, 1.0);
	METALLIC = 0.0;
	SPECULAR = base_specular;
}
