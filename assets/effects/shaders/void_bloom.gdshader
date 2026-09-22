shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float progress : hint_range(0.0, 1.0);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float angle = atan(p.y, p.x);
	float d = length(p) * 2.0;
	float petals = sin(angle * 6.0 + progress * 10.0) * 0.11;
	float shell = 1.0 - smoothstep(0.025, 0.1, abs(d - (0.78 - progress * 0.45 + petals)));
	float eye = 1.0 - smoothstep(0.03, 0.28 + progress * 0.18, d);
	float fade = 1.0 - smoothstep(0.7, 1.0, progress);
	vec3 color = mix(secondary_color.rgb, primary_color.rgb, d);
	COLOR = vec4(color, (shell + eye * 0.8) * fade);
}

