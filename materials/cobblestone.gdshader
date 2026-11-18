shader_type spatial;

varying vec2 ground_position;

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float stone_variation(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 pattern = ground_position / vec2(0.32, 0.22);
	vec2 footprint = fwidth(pattern);
	float distance_blend = smoothstep(0.35, 0.95, max(footprint.x, footprint.y));
	pattern.x += 0.5 * mod(floor(pattern.y), 2.0);
	vec2 cell = floor(pattern);
	vec2 local = abs(fract(pattern) - 0.5);
	vec2 corners = max(local - vec2(0.31, 0.29), vec2(0.0));
	float edge = length(corners) + min(max(local.x - 0.31, local.y - 0.29), 0.0);
	float smoothing = clamp(fwidth(edge), 0.002, 0.16);
	float stone = 1.0 - smoothstep(0.135 - smoothing, 0.135 + smoothing, edge);
	float shade = stone_variation(cell);
	vec3 granite = mix(vec3(0.135, 0.128, 0.121), vec3(0.238, 0.223, 0.204), shade);
	float bevel = 1.0 - smoothstep(0.06, 0.14, edge);
	granite *= mix(0.77, 1.0, bevel);
	vec3 cobblestone = mix(vec3(0.077, 0.071, 0.064), granite, stone);
	ALBEDO = mix(cobblestone, vec3(0.145, 0.135, 0.123), distance_blend);
	ROUGHNESS = 0.91;
}
