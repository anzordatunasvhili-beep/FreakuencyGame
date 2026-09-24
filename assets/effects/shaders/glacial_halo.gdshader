shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float progress : hint_range(0.0, 1.0);
uniform float effect_time;

float ring(float r, float x, float width) { return 1.0 - smoothstep(width, width + 0.008, abs(r - x)); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = effect_time;
	float frost = 0.0;
	float facets = 0.0;
	for (int i = 0; i < 3; i++) {
		float beat_time = (i == 0) ? 0.18 : ((i == 1) ? 0.47 : 0.78);
		float age = (t - beat_time) / 0.55;
		float impact_radius = (i == 0) ? 0.345 : ((i == 1) ? 0.58 : 0.80);
		float radius = impact_radius + clamp(age, 0.0, 1.0) * 0.05;
		float hex = cos(a * 6.0) * 0.026 + cos(a * 12.0) * 0.009;
		float visible = smoothstep(-0.07, 0.08, age) * (1.0 - smoothstep(0.54, 1.0, age));
		frost += ring(r + hex, radius, 0.009) * visible;
		facets += ring(r + hex, radius - 0.028, 0.003) * visible;
	}
	float crystal = pow(max(0.0, cos(a * 6.0)), 70.0) * smoothstep(0.1, 0.25, r) * (1.0 - smoothstep(0.55, 0.86, r));
	float needles = pow(max(0.0, cos(a * 24.0 + t * 0.4)), 80.0) * ring(r, 0.74, 0.08);
	float snow = pow(max(0.0, sin(a * 19.0 + r * 55.0)), 34.0) * (1.0 - smoothstep(0.6, 0.86, r));
	float fade = 1.0 - smoothstep(0.72, 1.0, progress);
	vec3 color = primary_color.rgb * (frost * 1.3 + needles * 0.3 + snow * 0.3)
		+ secondary_color.rgb * (facets + crystal * 0.8 + frost * 0.6);
	float alpha = clamp(frost + facets + crystal * 0.8 + needles * 0.4 + snow * 0.3, 0.0, 1.0) * fade;
	COLOR = vec4(color, alpha * COLOR.a * (1.0 - smoothstep(0.95, 1.0, r)));
}
