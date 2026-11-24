shader_type spatial;

varying vec3 stone_position;
varying vec3 stone_normal;

float block_tone(vec2 block) {
	return fract(sin(dot(block, vec2(37.3, 91.7))) * 14631.74);
}

void vertex() {
	stone_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	stone_normal = mat3(MODEL_MATRIX) * NORMAL;
}

void fragment() {
	float across = abs(stone_normal.z) > abs(stone_normal.x) ? stone_position.x : stone_position.z;
	float course = (stone_position.y - 0.15) / 0.97;
	float along = across / 2.43 + 0.5 * mod(floor(course), 2.0);
	vec2 layout = vec2(along, course);
	vec2 edge = min(fract(layout), 1.0 - fract(layout));
	vec2 width = max(fwidth(layout), vec2(0.001));
	vec2 faces = smoothstep(vec2(0.0), width + vec2(0.004, 0.008), edge);
	float seam = (1.0 - faces.x * faces.y) * (1.0 - smoothstep(0.033, 0.14, max(width.x, width.y)));
	float variation = block_tone(floor(layout)) - 0.5;
	vec3 stone_tone = vec3(0.351, 0.335, 0.309);
	ALBEDO = stone_tone * (1.0 + variation * 0.061 - seam * 0.075);
	ROUGHNESS = 0.86;
}
