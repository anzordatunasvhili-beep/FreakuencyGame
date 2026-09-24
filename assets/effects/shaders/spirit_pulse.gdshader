shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float progress : hint_range(0.0, 1.0);
uniform float effect_time;

float ring(float r, float x, float width) { return 1.0 - smoothstep(width, width + 0.011, abs(r - x)); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = effect_time;
	float outward = smoothstep(-0.2, 0.18, p.x);
	float crescent = ring(r, 0.15 + t * 0.56, 0.017) * outward;
	float second = ring(r, 0.05 + max(t - 0.28, 0.0) * 0.6, 0.012) * outward * smoothstep(0.25, 0.36, t);
	float feather = pow(max(0.0, sin(a * 13.0 + t * 4.0)), 25.0) * ring(r, 0.25 + t * 0.47, 0.07) * outward;
	float heartbeat = exp(-r * 11.0) * sin(min(t * 7.0, 3.14159)) * 0.9;
	float glyph = ring(r, 0.30, 0.003) * pow(max(0.0, cos(a * 8.0)), 20.0) * (1.0 - smoothstep(0.28, 0.7, t));
	float fade = 1.0 - smoothstep(0.68, 1.0, progress);
	vec3 color = primary_color.rgb * (crescent * 1.3 + second * 0.8 + feather * 0.65 + heartbeat * 0.7)
		+ secondary_color.rgb * (glyph + second * 0.35)
		+ vec3(0.82, 1.0, 0.84) * (crescent * 0.45 + heartbeat * 0.5);
	float alpha = clamp(crescent + second + feather + heartbeat + glyph, 0.0, 1.0) * fade;
	COLOR = vec4(color, alpha * COLOR.a * (1.0 - smoothstep(0.94, 1.0, r)));
}
