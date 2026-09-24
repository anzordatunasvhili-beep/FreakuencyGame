shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float progress : hint_range(0.0, 1.0);
uniform float effect_time;

float blade(vec2 p, float angle, float length, float width) {
	vec2 axis = vec2(cos(angle), sin(angle));
	float forward = dot(p, axis);
	float side = abs(dot(p, vec2(-axis.y, axis.x)));
	float taper = width * sin(clamp(forward / length, 0.0, 1.0) * 3.14159);
	return (1.0 - smoothstep(taper * 0.65, taper + 0.013, side)) * smoothstep(0.0, 0.08, forward) * (1.0 - smoothstep(length - 0.12, length, forward));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = effect_time;
	float bloom = 0.0;
	float veins = 0.0;
	for (int i = 0; i < 7; i++) {
		float theta = float(i) * 0.31 - 0.93 + sin(t * 2.0 + float(i)) * 0.06;
		float wave = float(i % 3) * 0.16;
		float emerge = smoothstep(wave, wave + 0.18, t) * (1.0 - smoothstep(0.9, 1.25, t));
		float petal = blade(p, theta, 0.67 + float(i % 2) * 0.18, 0.11 + 0.02 * sin(t * 12.0));
		bloom += petal * emerge;
		veins += petal * pow(max(0.0, sin(dot(p, vec2(cos(theta), sin(theta))) * 43.0 - t * 17.0)), 11.0) * emerge;
	}
	float eye = exp(-r * 18.0) * (1.0 - smoothstep(0.66, 1.0, progress));
	float dust = pow(max(0.0, sin(a * 17.0 + r * 36.0 - t * 13.0)), 22.0) * smoothstep(0.28, 0.45, r) * (1.0 - smoothstep(0.8, 1.0, r));
	vec3 color = primary_color.rgb * (bloom * 0.65 + veins * 1.7 + dust * 0.6)
		+ secondary_color.rgb * bloom * 0.65 + vec3(0.94, 0.68, 1.0) * (veins * 0.5 + eye * 1.5);
	float alpha = clamp(bloom * 0.65 + veins + eye + dust, 0.0, 1.0) * (1.0 - smoothstep(0.96, 1.0, r));
	COLOR = vec4(color, alpha * COLOR.a);
}
