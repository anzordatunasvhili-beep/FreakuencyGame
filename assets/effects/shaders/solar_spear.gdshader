shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float progress : hint_range(0.0, 1.0);
uniform float effect_time;

float line(float d, float width) { return 1.0 - smoothstep(width, width + 0.012, abs(d)); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float x = p.x;
	float y = abs(p.y);
	float t = effect_time;
	float arrive = smoothstep(0.46, 0.54, t);
	float fade = 1.0 - smoothstep(0.55, 1.08, t);
	float shaft_tail = 0.14 - clamp(t / 0.53, 0.0, 1.0) * 0.61;
	float edge = smoothstep(shaft_tail, shaft_tail + 0.08, x) * (1.0 - smoothstep(0.48, 0.62, x));
	float spearhead = line(y - (0.62 - x) * 0.29, 0.016) * smoothstep(0.08, 0.48, x) * (1.0 - smoothstep(0.57, 0.64, x));
	float shaft = line(y, 0.028) * edge;
	float core = line(y, 0.006) * edge;
	float helix = line(y - abs(sin(x * 27.0 + t * 31.0)) * 0.12, 0.01) * edge;
	float runes = pow(max(0.0, cos(x * 32.0 - t * 16.0)), 20.0) * line(y - 0.18, 0.012) * edge;
	float r = length(p - vec2(0.62, 0.0));
	float impact = (1.0 - smoothstep(0.018, 0.05, abs(r - (t - 0.53) * 1.8))) * arrive * (1.0 - smoothstep(0.74, 1.08, t));
	float sun = exp(-r * 7.0) * arrive * (1.0 - smoothstep(0.58, 0.9, t));
	vec3 color = primary_color.rgb * (shaft + spearhead + helix + impact * 1.4)
		+ secondary_color.rgb * (runes + impact * 0.75)
		+ vec3(1.0, 0.99, 0.78) * (core * 1.8 + sun * 2.1);
	float alpha = clamp((shaft + spearhead + core + helix + runes) * fade + impact + sun, 0.0, 1.0);
	COLOR = vec4(color, alpha * COLOR.a);
}
