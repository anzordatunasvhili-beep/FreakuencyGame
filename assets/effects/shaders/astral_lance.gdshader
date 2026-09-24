shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 primary_color : source_color = vec4(0.08, 0.73, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.26, 0.65, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float release : hint_range(0.0, 1.0) = 0.0;
uniform float effect_time = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float line(float distance_to_line, float width, float softness) {
	return 1.0 - smoothstep(width, width + softness, abs(distance_to_line));
}

void fragment() {
	float vertex_alpha = COLOR.a;
	float x = UV.x;
	float y = (UV.y - 0.5) * 2.0;
	float t = effect_time;
	float lifetime = smoothstep(0.0, 0.025, progress) * (1.0 - smoothstep(0.87, 1.0, progress));
	float fire = smoothstep(0.86, 1.0, charge);
	float remaining = 1.0 - smoothstep(0.06, 0.95, release);
	float ends = smoothstep(0.0, 0.018, x) * (1.0 - smoothstep(0.92, 1.0, x));
	float taper = pow(max(0.0, sin(x * 3.14159)), 0.30);
	float wave = sin(x * 53.0 - t * 16.0);
	float wave_secondary = sin(x * 37.0 + t * 12.0);
	float aim_width = mix(0.29, 0.04, charge);
	float aim = line(y, 0.003, 0.009) * 0.22;
	float aim_dashes = step(0.38, fract(x * 27.0 - t * 0.7));
	aim += (line(y - aim_width, 0.003, 0.009) + line(y + aim_width, 0.003, 0.009)) * aim_dashes * 0.35;
	aim *= (1.0 - fire * 0.85) * (0.3 + charge * 0.7);

	// Two braided plasma strands wrap a needle-bright continuous core.
	float amplitude = 0.115 * taper * (0.6 + 0.4 * remaining);
	float braid_a = line(y - wave * amplitude, 0.010 * taper, 0.025);
	float braid_b = line(y + wave * amplitude, 0.010 * taper, 0.023);
	float sheath = line(y - wave_secondary * 0.014, 0.018 * taper, 0.15 * taper + 0.001);
	float core = line(y - wave_secondary * 0.003, 0.009 * taper, 0.021);
	float hairline = line(y, 0.003, 0.008);
	float diamond_x = abs(fract(x * 10.0 - t * 1.6) - 0.5) * 2.0;
	float diamonds = line(abs(y) + diamond_x * 0.19 - 0.19, 0.005, 0.013);
	float needle = line(abs(y) - (1.0 - x) * 0.28, 0.002, 0.012) * smoothstep(0.55, 0.90, x);

	// Dissolution breaks the ribbons into escaping rectangular ion flecks.
	vec2 cell = floor(vec2(x * 92.0 - t * 13.0, y * 24.0));
	float speckle = step(0.94, hash21(cell));
	speckle *= smoothstep(0.12, 0.19, abs(y)) * (1.0 - smoothstep(0.19, 0.65, abs(y)));
	float dissolve = smoothstep(release * 1.25 - 0.25, release * 1.25 + 0.08,
		hash21(floor(vec2(x * 80.0, y * 38.0))));
	float ribbons = (braid_a + braid_b) * fire * remaining * dissolve;
	float diamonds_light = diamonds * fire * remaining * 0.48;
	float plasma = sheath * fire * remaining;
	float spine = (core * 1.7 + hairline * 0.8) * fire * remaining * dissolve;
	float scatter = speckle * fire * remaining * (0.22 + release * 1.5);
	vec3 color = primary_color.rgb * (aim + plasma * 0.65 + braid_a * fire * remaining * dissolve)
		+ secondary_color.rgb * (braid_b * fire * remaining * dissolve + diamonds_light + scatter)
		+ mix(primary_color.rgb, vec3(1.0), 0.86) * (spine + needle * fire * remaining * 0.5);
	float alpha = clamp(aim + plasma + ribbons + diamonds_light + spine + scatter, 0.0, 1.0);
	COLOR = vec4(color, alpha * ends * lifetime * vertex_alpha);
}
