shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 primary_color : source_color = vec4(0.24, 1.0, 0.86, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.73, 0.26, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float release : hint_range(0.0, 1.0) = 0.0;
uniform float effect_time = 0.0;

const float CIRCLE = 6.28318530718;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ring(float radius, float target, float width) {
	return 1.0 - smoothstep(width, width + 0.008, abs(radius - target));
}

float segment(vec2 p, vec2 a, vec2 b, float width) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return 1.0 - smoothstep(width, width + 0.009, length(pa - ba * h));
}

void fragment() {
	float vertex_alpha = COLOR.a;
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float t = effect_time;
	float formation = mix(0.50, 1.0, smoothstep(0.0, 0.70, charge));
	float lifetime = smoothstep(0.0, 0.04, progress) * (1.0 - smoothstep(0.83, 1.0, progress));
	float remaining = 1.0 - smoothstep(0.12, 0.88, release);
	float normalized_radius = radius / formation;

	// Separate dials tick in opposite directions around a faceted glass field.
	float a_outer = angle + t * 0.19;
	float a_inner = angle - t * 0.32;
	float outer_ticks = pow(max(0.0, cos(a_outer * 48.0)), 22.0)
		* smoothstep(0.70, 0.72, normalized_radius) * (1.0 - smoothstep(0.78, 0.79, normalized_radius));
	float major_ticks = pow(max(0.0, cos(a_outer * 12.0)), 35.0)
		* smoothstep(0.66, 0.67, normalized_radius) * (1.0 - smoothstep(0.81, 0.82, normalized_radius));
	float inner_ticks = pow(max(0.0, cos(a_inner * 24.0)), 26.0)
		* smoothstep(0.48, 0.49, normalized_radius) * (1.0 - smoothstep(0.53, 0.54, normalized_radius));
	float arcs = ring(normalized_radius, 0.83, 0.003) * smoothstep(-0.45, -0.1, sin(a_outer * 4.0));
	arcs += ring(normalized_radius, 0.62, 0.002) * smoothstep(-0.35, -0.1, sin(a_inner * 3.0));
	arcs += ring(normalized_radius, 0.45, 0.002) * 0.48;
	float dial = (outer_ticks * 0.55 + major_ticks + inner_ticks * 0.72 + arcs) * remaining;

	// Voronoi borders provide irregular polygonal cracks rather than radial spokes.
	vec2 glass_uv = p * 4.2 + vec2(t * 0.018, -t * 0.013);
	vec2 tile = floor(glass_uv);
	vec2 local = fract(glass_uv);
	float nearest = 8.0;
	float next_nearest = 8.0;
	vec2 nearest_cell = vec2(0.0);
	for (int yy = -1; yy <= 1; yy++) {
		for (int xx = -1; xx <= 1; xx++) {
			vec2 neighbor = vec2(float(xx), float(yy));
			vec2 cell_id = tile + neighbor;
			vec2 site = vec2(hash21(cell_id), hash21(cell_id + 19.31));
			vec2 offset = neighbor + 0.17 + site * 0.66 - local;
			float distance_squared = dot(offset, offset);
			if (distance_squared < nearest) {
				next_nearest = nearest;
				nearest = distance_squared;
				nearest_cell = cell_id;
			} else if (distance_squared < next_nearest) {
				next_nearest = distance_squared;
			}
		}
	}
	float border = sqrt(next_nearest) - sqrt(nearest);
	float pane_hash = hash21(nearest_cell + 5.19);
	float edge = 1.0 - smoothstep(0.012, 0.045, border);
	float field_mask = (1.0 - smoothstep(0.50, 0.65, normalized_radius)) * smoothstep(0.05, 0.16, radius);
	float crack_reveal = smoothstep(pane_hash * 0.65, pane_hash * 0.65 + 0.20, charge);
	float fractures = edge * field_mask * crack_reveal * (0.23 + pane_hash * 0.58) * remaining;
	float glass = field_mask * crack_reveal * (0.012 + pane_hash * 0.04) * remaining;

	// Offset hands and diamond markers keep the center legible over the world.
	vec2 hand_a = vec2(cos(t * 0.42), sin(t * 0.42));
	vec2 hand_b = vec2(cos(-t * 0.24 + 2.1), sin(-t * 0.24 + 2.1));
	float hands = (segment(p, hand_a * 0.11, hand_a * 0.37, 0.002)
		+ segment(p, hand_b * 0.11, hand_b * 0.26, 0.003)) * remaining * charge;
	float center = (1.0 - smoothstep(0.002, 0.014, abs(abs(p.x) + abs(p.y) - 0.078))) * remaining;
	float shock_radius = 0.25 + sqrt(release) * 0.69;
	float angular_shards = 0.018 * cos(angle * 12.0) * (1.0 - release);
	float shock = ring(radius + angular_shards, shock_radius, 0.008)
		* smoothstep(0.0, 0.06, release) * (1.0 - smoothstep(0.48, 1.0, release));
	float shock_echo = ring(radius, shock_radius * 0.91, 0.002)
		* smoothstep(0.03, 0.15, release) * (1.0 - release) * 0.4;
	vec3 color = primary_color.rgb * (dial + fractures + glass + shock * 1.9 + shock_echo)
		+ secondary_color.rgb * (hands * 1.4 + center * 1.2 + major_ticks * remaining * 0.4)
		+ vec3(0.75, 1.0, 1.0) * fractures * 0.28;
	float alpha = clamp(dial + fractures + glass + hands + center + shock + shock_echo, 0.0, 1.0);
	COLOR = vec4(color, alpha * lifetime * vertex_alpha * (1.0 - smoothstep(0.95, 1.0, radius)));
}
