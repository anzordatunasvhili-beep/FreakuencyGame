shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float progress : hint_range(0.0, 1.0);
uniform float effect_time;

float line(float d, float width) {
	return 1.0 - smoothstep(width, width + 0.013, abs(d));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = effect_time;
	float fade = 1.0 - smoothstep(0.62, 1.0, progress);
	float angular = sin(a * 9.0 + t * 23.0) * 0.045 + sin(a * 23.0 - t * 29.0) * 0.015;
	float cage = line(r - 0.51 - angular, 0.010) * pow(max(0.0, cos(a * 8.0 + t * 12.0)), 5.0);
	float coil_a = line(p.y - sin(p.x * 31.0 - t * 36.0) * 0.10, 0.006) * smoothstep(-0.7, 0.1, p.x) * (1.0 - smoothstep(0.65, 0.95, p.x));
	float coil_b = line(p.y + sin(p.x * 27.0 + t * 31.0) * 0.12, 0.006) * smoothstep(-0.7, 0.1, p.x) * (1.0 - smoothstep(0.65, 0.95, p.x));
	float strobe = 0.60 + 0.40 * sin(t * 57.0);
	float core = exp(-r * 12.0) * strobe;
	float forks = pow(max(0.0, sin(a * 16.0 + r * 33.0 - t * 21.0)), 24.0) * (1.0 - smoothstep(0.39, 0.85, r));
	vec3 color = primary_color.rgb * (coil_a + cage + forks * 0.55)
		+ secondary_color.rgb * (coil_b + cage * 0.6)
		+ vec3(0.82, 0.96, 1.0) * (core * 2.0 + (coil_a + coil_b) * 0.58);
	float alpha = clamp((coil_a + coil_b + cage + forks + core) * fade, 0.0, 1.0);
	COLOR = vec4(color, alpha * COLOR.a * (1.0 - smoothstep(0.94, 1.0, r)));
}
