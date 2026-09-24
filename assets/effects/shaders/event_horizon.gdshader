shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 primary_color : source_color = vec4(0.64, 0.26, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.16, 0.86, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float release : hint_range(0.0, 1.0) = 0.0;
uniform float effect_time = 0.0;

const float CIRCLE = 6.28318530718;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), u.x), u.y);
}

float turbulence(vec2 p) {
	float n = noise21(p) * 0.57;
	p = mat2(vec2(1.62, 1.17), vec2(-1.17, 1.62)) * p;
	n += noise21(p + 7.1) * 0.28;
	n += noise21(p * 2.03 + 13.7) * 0.15;
	return n;
}

float ring(float radius, float target, float width) {
	return 1.0 - smoothstep(width, width + 0.011, abs(radius - target));
}

void fragment() {
	float vertex_alpha = COLOR.a;
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float t = effect_time;
	float formation = mix(0.32, 1.0, smoothstep(0.0, 0.83, charge));
	float collapse = 1.0 - smoothstep(0.0, 0.36, release) * 0.90;
	float horizon_radius = 0.185 * formation * collapse;
	float lifetime = smoothstep(0.0, 0.045, progress) * (1.0 - smoothstep(0.84, 1.0, progress));
	float remaining = 1.0 - smoothstep(0.13, 0.62, release);

	// A tilted, differentially rotating disk wraps around the opaque center.
	vec2 tilted = mat2(vec2(0.955, 0.296), vec2(-0.296, 0.955)) * p;
	tilted.y *= 1.88;
	float disk_radius = length(tilted);
	float disk_angle = atan(tilted.y, tilted.x);
	float flow = turbulence(vec2(cos(disk_angle) * 2.3 + t * 0.3,
		sin(disk_angle) * 2.3 + disk_radius * 8.0 - t * 1.3));
	float spiral = sin(disk_radius * 73.0 - disk_angle * 5.0 - t * 8.0 + flow * 8.0);
	float filaments = pow(max(0.0, spiral), 5.0);
	float disk = smoothstep(horizon_radius * 0.80, horizon_radius + 0.10, disk_radius)
		* (1.0 - smoothstep(0.49 * formation, 0.89 * formation, disk_radius));
	float disk_light = disk * (0.15 + flow * 0.30 + filaments * 0.90) * remaining;
	float lens = ring(radius, horizon_radius + 0.033, 0.009) * remaining;
	float corona = exp(-abs(radius - horizon_radius - 0.045) * 35.0) * 0.43 * remaining;
	float orbital_flow = angle + t * 0.8 + radius * 8.0;
	float broken = smoothstep(-0.4, 0.22, sin(orbital_flow * 3.0))
		* smoothstep(-0.75, 0.2, sin(angle * 11.0 - t * 2.4));
	float orbits = (ring(radius, 0.64 * formation, 0.002)
		+ ring(radius, 0.79 * formation, 0.001) * 0.56) * broken * remaining;
	float infall = pow(max(0.0, sin(angle * 7.0 + radius * 22.0 - t * 6.0)), 18.0)
		* smoothstep(0.24, 0.42, radius) * (1.0 - smoothstep(0.45, 0.75, radius)) * 0.23 * remaining;

	// Detonation travels outward while the disk collapses inward.
	float shock_radius = 0.14 + sqrt(release) * 0.80;
	float shock_visibility = smoothstep(0.0, 0.055, release) * (1.0 - smoothstep(0.45, 1.0, release));
	float shock = ring(radius, shock_radius, mix(0.018, 0.003, release)) * shock_visibility;
	float shock_echo = ring(radius, shock_radius * 0.89, 0.002) * shock_visibility * 0.30;
	float flare = exp(-radius * 13.0) * sin(clamp(release * 6.0, 0.0, 3.14159)) * 2.0;
	float black_disk = (1.0 - smoothstep(horizon_radius - 0.009, horizon_radius + 0.006, radius)) * remaining;

	vec3 disk_color = mix(primary_color.rgb, secondary_color.rgb, clamp(flow * 0.7 + filaments * 0.4, 0.0, 1.0));
	vec3 emission = disk_color * (disk_light + infall) * 1.8
		+ mix(primary_color.rgb, vec3(1.0), 0.56) * (lens * 1.65 + corona)
		+ secondary_color.rgb * (orbits + shock * 2.3 + shock_echo + flare * 2.5);
	float light_alpha = clamp(disk_light * 1.65 + lens + corona + orbits + infall + shock + shock_echo + flare, 0.0, 1.0);
	vec3 color = mix(emission, vec3(0.003, 0.001, 0.009), black_disk);
	float alpha = max(light_alpha, black_disk) * lifetime * vertex_alpha;
	alpha *= 1.0 - smoothstep(0.95, 1.0, radius);
	COLOR = vec4(color, alpha);
}
