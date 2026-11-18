shader_type spatial;

uniform vec4 brick_color : source_color = vec4(0.55, 0.33, 0.26, 1.0);

varying vec3 brick_position;
varying vec3 brick_normal;

void vertex() {
	brick_position = VERTEX;
	brick_normal = abs(NORMAL);
}

void fragment() {
	// BoxMesh faces share the same metre-scale bond, regardless of building yaw.
	float horizontal = brick_normal.z > 0.5 ? brick_position.x : brick_position.z;
	vec2 tile = vec2(horizontal / 0.33, brick_position.y / 0.12);
	tile.x += mod(floor(tile.y), 2.0) * 0.5;
	vec2 edge = abs(fract(tile) - 0.5);
	vec2 aa = max(fwidth(tile), vec2(0.001));
	vec2 inside = 1.0 - smoothstep(vec2(0.465, 0.420) - aa, vec2(0.465, 0.420) + aa, edge);
	float variation = fract(sin(dot(floor(tile), vec2(71.3, 17.1))) * 4375.82);
	float near_bond = 1.0 - smoothstep(31.0, 55.0, length(VERTEX));
	float bond = inside.x * inside.y;
	vec3 mortar = brick_color.rgb * 0.63;
	vec3 bricks = brick_color.rgb * mix(0.82, 1.13, variation);
	ALBEDO = mix(brick_color.rgb, mix(mortar, bricks, bond), near_bond * (1.0 - brick_normal.y));
	ROUGHNESS = 0.94;
}
