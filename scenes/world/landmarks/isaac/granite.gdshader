shader_type spatial;

varying vec3 stone_position;

float grain(vec3 point) {
	point = fract(point * vec3(0.1031, 0.1137, 0.1379));
	point += dot(point, point.yzx + 19.19);
	return fract((point.x + point.y) * point.z);
}

void vertex() {
	stone_position = VERTEX;
}

void fragment() {
	vec3 grain_cell = stone_position * 47.0;
	float detail = 1.0 - smoothstep(0.38, 1.12, length(fwidth(grain_cell)));
	float speckle = (grain(floor(grain_cell)) - 0.5) * detail;
	vec3 granite_tone = vec3(0.203, 0.116, 0.095);
	ALBEDO = granite_tone * (1.0 + 0.15 * speckle);
	ROUGHNESS = 0.44 + 0.12 * speckle;
	SPECULAR = 0.35;
}
