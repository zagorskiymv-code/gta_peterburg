shader_type spatial;

uniform vec3 festival_glimmer = vec3(0.0);

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float wide_ripple = sin(world_position.y * 2.1 + world_position.x * 0.7 - TIME * 0.65);
	float cross_ripple = sin(world_position.x * 4.0 - world_position.y * 1.1 + TIME * 0.85);
	float ripple = wide_ripple * cross_ripple;
	vec3 deep = vec3(0.075, 0.15, 0.15);
	vec3 shallow = vec3(0.19, 0.29, 0.26);
	ALBEDO = mix(deep, shallow, 0.48 + ripple * 0.16);
	// A local colour wash, broken into bands by the same ripples as the water.
	vec2 distance_to_ship = (world_position - festival_glimmer.xy) / vec2(22.0, 30.0);
	float glimmer = exp(-dot(distance_to_ship, distance_to_ship) * 2.4) * festival_glimmer.z;
	glimmer *= 0.38 + 0.62 * smoothstep(-0.1, 0.8, wide_ripple);
	EMISSION = vec3(0.22, 0.025, 0.012) * glimmer;
	ROUGHNESS = 0.67;
	SPECULAR = 0.28;
}
