shader_type canvas_item;
render_mode unshaded, blend_mix;

// The mask covers the same world rectangle as the white polygon using this shader.
// R is antialiased water coverage; G is distance from shore, reaching 1 at ~32 px.
uniform sampler2D mask_texture : repeat_disable, filter_linear;
uniform vec2 water_world_size = vec2(1024.0, 512.0);
uniform vec4 shallow_color : source_color = vec4(0.19, 0.62, 0.72, 1.0);
uniform vec4 deep_color : source_color = vec4(0.045, 0.145, 0.31, 1.0);
uniform vec4 foam_color : source_color = vec4(0.77, 0.97, 1.0, 1.0);
uniform float flow_speed : hint_range(0.0, 3.0) = 1.0;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 mask = texture(mask_texture, UV);
	vec4 vertex_color = COLOR;
	if (mask.r < 0.004) {
		COLOR = vec4(0.0);
	} else {
		// World pixel coordinates keep every wave continuous across former tile edges.
		vec2 p = UV * water_world_size;
		float t = TIME * flow_speed;
		float depth = clamp(mask.g, 0.0, 1.0);
		float broad_flow = noise21(p * 0.012 + vec2(t * 0.055, -t * 0.038));
		float cross_flow = noise21(p * 0.016 + vec2(-t * 0.048, t * 0.067) + 37.1);
		vec2 bend = (vec2(broad_flow, cross_flow) - 0.5) * 18.0;

		// Warped noise reveals separate, irregular pools of refracted sunlight.
		// Smooth thresholds keep each pool soft without repeating parallel lines.
		vec2 light_uv = (p + bend * 1.5) * 0.037 + vec2(t * 0.082, -t * 0.051);
		float broad_light = noise21(light_uv);
		float fine_light = noise21(light_uv * 2.13 + vec2(19.4, -8.7) - t * 0.037);
		float light_pools = smoothstep(0.48, 0.79, broad_light)
			* smoothstep(0.20, 0.67, fine_light);
		float stray_light = smoothstep(0.75, 0.94,
			noise21(light_uv * 1.57 + vec2(-12.8, 36.1))) * 0.26;
		float caustics = max(light_pools, stray_light);
		float depth_mix = pow(depth, 0.75);
		vec3 water = mix(shallow_color.rgb, deep_color.rgb, depth_mix);
		water *= 0.94 + broad_flow * 0.10;
		water += vec3(0.48, 0.88, 1.0) * caustics * mix(0.31, 0.11, depth);

		// A wavering, broken ribbon rolls a few pixels into the shore; finer foam
		// clings to the actual diamond boundary supplied by the coverage mask.
		float foam_noise = noise21(p * 0.068 + vec2(t * 0.10, -t * 0.075) + 14.0);
		float runup_depth = 0.16 + 0.050 * sin(p.x * 0.052 + p.y * 0.026 - t * 1.05)
			+ (cross_flow - 0.5) * 0.075;
		float runup = 1.0 - smoothstep(0.025, 0.105, abs(depth - runup_depth));
		float shore = 1.0 - smoothstep(0.08, 0.44, depth);
		float edge = 1.0 - smoothstep(0.0, 0.085, depth);
		float foam = shore * (edge * (0.36 + foam_noise * 0.35)
			+ runup * smoothstep(0.29, 0.76, foam_noise) * 0.76);
		water = mix(water, foam_color.rgb, clamp(foam * 0.86, 0.0, 0.84));

		// Rare, short surface glints travel slowly and fade in and out.
		vec2 glint_grid = (p + vec2(t * 1.8, -t * 0.9)) / vec2(92.0, 68.0);
		vec2 glint_cell = floor(glint_grid);
		vec2 glint_center = vec2(hash21(glint_cell + 9.4), hash21(glint_cell + 28.2)) * 0.7 + 0.15;
		vec2 glint_offset = (fract(glint_grid) - glint_center) * vec2(92.0, 68.0);
		float glint_seed = hash21(glint_cell + 77.0);
		float glint = smoothstep(0.82, 0.98, glint_seed)
			* exp(-abs(glint_offset.x) * 0.37 - abs(glint_offset.y) * 1.8)
			* (0.5 + 0.5 * sin(t * 1.6 + glint_seed * 16.0));
		water += vec3(0.38, 0.78, 0.88) * glint * 0.37;

		// The raster's antialiasing is the shoreline silhouette. It also erases
		// every inland pixel of the large polygon without rectangular bleed.
		COLOR = vec4(water * vertex_color.rgb, mask.r * vertex_color.a);
	}
}
