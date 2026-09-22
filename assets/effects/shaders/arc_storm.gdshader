shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float progress : hint_range(0.0, 1.0);

float bolt(vec2 p, float phase) {
	float jagged = sin(p.x * 34.0 + phase) * 0.05 + sin(p.x * 73.0 - phase) * 0.018;
	return 1.0 - smoothstep(0.015, 0.065, abs(p.y - jagged));
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float mask = 1.0 - smoothstep(0.05, 0.52, length(p));
	float b = bolt(p, progress * 24.0) + bolt(vec2(p.x, p.y + 0.14), -progress * 19.0) * 0.55;
	float pulse = 0.65 + sin(progress * 45.0) * 0.35;
	vec3 color = mix(primary_color.rgb, secondary_color.rgb, abs(p.y) * 2.0);
	COLOR = vec4(color, b * mask * pulse * (1.0 - progress));
}

