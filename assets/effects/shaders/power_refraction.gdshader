shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.65;
uniform float effect_time = 0.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int mode : hint_range(0, 2) = 0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float vertex_alpha = COLOR.a;
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float t = effect_time;
	float envelope = smoothstep(0.0, 0.07, progress) * (1.0 - smoothstep(0.76, 1.0, progress));
	float mask = (1.0 - smoothstep(0.62, 0.96, radius)) * smoothstep(0.05, 0.20, radius);
	vec2 displacement = vec2(0.0);
	// Derivatives orient refraction with the actual transformed effect rectangle.
	vec2 screen_axis_x = normalize(dFdx(UV) + vec2(0.000001));
	vec2 screen_axis_y = normalize(dFdy(UV) + vec2(0.000001));
	if (mode == 0) {
		vec2 radial = p / max(radius, 0.05);
		vec2 tangent = vec2(-radial.y, radial.x);
		float lens = exp(-abs(radius - 0.30) * 6.0);
		displacement = (radial * -0.012 + tangent * 0.005 * sin(radius * 16.0 - t * 2.0)) * lens;
	} else if (mode == 1) {
		mask = (1.0 - smoothstep(0.12, 0.80, abs(p.y))) * (1.0 - smoothstep(0.85, 1.0, abs(p.x)));
		displacement = vec2(sin(p.x * 23.0 - t * 12.0) * 0.002,
			sin(p.x * 47.0 - t * 17.0 + p.y * 9.0) * 0.009) * mask;
	} else {
		vec2 cell = floor(p * 8.0);
		vec2 facets = vec2(hash21(cell), hash21(cell + 7.3)) - 0.5;
		float ring_wave = sin(radius * 31.0 - t * 1.4);
		displacement = facets * 0.014 + p * ring_wave * 0.002;
	}
	vec2 screen_displacement = vec2(dot(displacement, screen_axis_x), dot(displacement, screen_axis_y));
	screen_displacement *= strength * envelope;
	vec2 sample_uv = clamp(SCREEN_UV + screen_displacement, vec2(0.001), vec2(0.999));
	vec2 split = screen_displacement * 0.24;
	vec3 refracted;
	refracted.r = texture(screen_texture, clamp(sample_uv + split, vec2(0.001), vec2(0.999))).r;
	refracted.g = texture(screen_texture, sample_uv).g;
	refracted.b = texture(screen_texture, clamp(sample_uv - split, vec2(0.001), vec2(0.999))).b;
	COLOR = vec4(refracted, mask * envelope * strength * vertex_alpha);
}
