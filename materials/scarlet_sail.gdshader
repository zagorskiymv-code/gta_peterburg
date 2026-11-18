shader_type spatial;
render_mode cull_disabled;

void vertex() {
	float pin = sin(PI * UV.x) * UV.y;
	VERTEX.z += sin(TIME * 1.18 + UV.x * 7.0 + UV.y * 2.4) * pin * 0.18;
}

void fragment() {
	float weave = 0.87 + 0.13 * sin(UV.x * 68.0);
	float trim = smoothstep(0.0, 0.028, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	ALBEDO = mix(vec3(0.56, 0.19, 0.075), vec3(0.67, 0.009, 0.022) * weave, trim);
	EMISSION = vec3(0.24, 0.008, 0.018) * (0.6 + 0.4 * trim);
	ROUGHNESS = 0.88;
}
