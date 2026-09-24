shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float progress : hint_range(0.0, 1.0);
uniform float effect_time;

float band(float r, float target, float width) {
	return 1.0 - smoothstep(width, width + 0.015, abs(r - target));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = effect_time;
	float flare = 0.0;
	float ash = 0.0;
	for (int i = 0; i < 3; i++) {
		float beat_time = (i == 0) ? 0.12 : ((i == 1) ? 0.50 : 0.91);
		float age = (t - beat_time) / 0.52;
		float impact_radius = (i == 0) ? 0.40 : ((i == 1) ? 0.65 : 0.80);
		float radius = impact_radius + clamp(age, 0.0, 1.0) * 0.09;
		float tongue = sin(a * (10.0 + float(i) * 3.0) - t * (7.0 + float(i)) + r * 27.0) * 0.038;
		float front = band(r + tongue, radius, 0.018 + age * 0.034);
		float heat = smoothstep(-0.07, 0.08, age) * (1.0 - smoothstep(0.40, 0.92, age));
		flare += front * heat;
		ash += front * heat * pow(max(0.0, sin(a * 26.0 + t * 11.0)), 8.0);
	}
	float spiral = pow(max(0.0, sin(a * 7.0 - r * 29.0 + t * 12.0)), 10.0);
	float furnace = exp(-r * 9.0) * (0.45 + spiral * 0.55) * (1.0 - smoothstep(0.60, 1.0, progress));
	float sparks = ash * 0.8 + spiral * (1.0 - smoothstep(0.18, 0.75, r)) * 0.25;
	vec3 color = primary_color.rgb * (flare * 1.35 + furnace * 0.7)
		+ secondary_color.rgb * (sparks + flare * 0.75)
		+ vec3(1.0, 0.96, 0.66) * (flare * flare * 0.55 + furnace * 0.6);
	float alpha = clamp(flare + sparks + furnace, 0.0, 1.0) * (1.0 - smoothstep(0.96, 1.0, r));
	COLOR = vec4(color, alpha * COLOR.a);
}
