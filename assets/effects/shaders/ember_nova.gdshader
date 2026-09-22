shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float progress : hint_range(0.0, 1.0);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	float wobble = sin(atan(p.y, p.x) * 9.0 + progress * 18.0) * 0.035;
	float ring = 1.0 - smoothstep(0.035, 0.12, abs(d - progress * 0.92 - wobble));
	float core = (1.0 - smoothstep(0.0, 0.55, d)) * (1.0 - progress);
	float fade = 1.0 - smoothstep(0.72, 1.0, progress);
	vec3 color = mix(primary_color.rgb, secondary_color.rgb, d);
	COLOR = vec4(color, (ring + core * 0.65) * fade);
}

