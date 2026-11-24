shader_type spatial;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 sclera : source_color = vec4(0.847, 0.827, 0.788, 1.0);
uniform int finish = 0;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.9;
uniform float base_specular : hint_range(0.0, 1.0) = 0.18;

varying vec3 object_metres;
varying vec3 object_normal;
varying vec3 anatomy;

float grain_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloth_grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 weight = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	float lower = mix(grain_hash(cell), grain_hash(cell + vec2(1, 0)), weight.x);
	float upper = mix(grain_hash(cell + vec2(0, 1)), grain_hash(cell + vec2(1, 1)), weight.x);
	return (mix(lower, upper, weight.y) - 0.5)
		* (1.0 - smoothstep(0.45, 1.35, length(fwidth(p))));
}

float spot(vec2 point, vec2 center, vec2 radius) {
	vec2 delta = (point - center) / radius;
	return exp(-dot(delta, delta));
}

void vertex() {
	vec3 dimensions = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	object_metres = VERTEX * dimensions;
	anatomy = VERTEX;
	object_normal = NORMAL;
}

void fragment() {
	vec3 albedo = tint.rgb;
	float rough = base_roughness;
	if (finish == 6) {
		float radius = length((UV - 0.5) * 0.024);
		float width = max(fwidth(radius), 0.00015);
		vec3 iris = mix(tint.rgb, tint.rgb * 0.50, smoothstep(0.0036, 0.00575, radius));
		iris = mix(vec3(0.018), iris, smoothstep(0.002 - width, 0.002 + width, radius));
		albedo = mix(iris, sclera.rgb, smoothstep(0.00575 - width, 0.00575 + width, radius));
	} else if (finish == 7) {
		vec2 face = vec2(abs(anatomy.x), anatomy.y);
		float front = smoothstep(0.15, 0.75, -object_normal.z);
		float cheek = spot(face, vec2(.054, .151), vec2(.020, .024)) * front;
		float nose = spot(face, vec2(.011, .143), vec2(.018, .016)) * front;
		albedo += vec3(.034, -.006, -.008) * (cheek + nose * .62);
		rough += cheek * .03 - nose * .035;
		float lip = spot(face, vec2(.0, .110), vec2(.023, .007)) * front;
		float mouth_height = .111 + .0011 * smoothstep(.009, .022, face.x);
		float mouth = spot(face, vec2(.0, mouth_height), vec2(.020, .0010)) * front;
		float corner = spot(face, vec2(.020, .112), vec2(.0032, .0023)) * front;
		float nostril = spot(face, vec2(.011, .139), vec2(.0043, .0027)) * front;
		float orbit = spot(face, vec2(.037, .176), vec2(.011, .0025)) * front;
		albedo *= 1.0 - mouth * .30 - nostril * .24 - corner * .12 - orbit * .16;
		albedo = mix(albedo, albedo * vec3(1.04, .84, .86), lip * .78);
	} else if (finish == 2) {
		float sweep = anatomy.x + .49 * anatomy.z + .26 * anatomy.y;
		float flow = sweep * 1260.0 + 3.4 * sin(anatomy.y * 36.0 + anatomy.z * 19.0);
		float strands = cos(flow) * (1.0 - smoothstep(.35, 2.7, fwidth(flow)));
		float tone = .015 * sin(sweep * 94.0);
		albedo *= 1.0 + strands * .019 + tone;
		rough += strands * .014;
	} else if (finish != 1) {
		vec3 p = object_metres;
		vec2 grain_uv = vec2(p.x + p.z * .71, p.y + p.z * .55);
		float scale = finish == 5 ? 320.0 : (finish == 3 ? 170.0 : 235.0);
		float grain = cloth_grain(grain_uv * scale);
		albedo *= 1.0 + grain * (finish == 0 ? .034 : .017);
		rough += grain * (finish == 3 ? .055 : .035);
	}
	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.15, 1.0);
	METALLIC = 0.0;
	SPECULAR = base_specular;
}
