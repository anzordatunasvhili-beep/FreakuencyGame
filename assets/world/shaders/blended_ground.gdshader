shader_type canvas_item;
render_mode unshaded;

// One padded texel per map cell: RG = atlas coordinates / 255,
// B = grass (1) or dirt (0), A = land (1) or water/empty (0).
uniform sampler2D tile_lookup : filter_nearest, repeat_disable;
uniform sampler2D terrain_atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 mask_size;
uniform vec2 map_origin;
uniform vec2 map_from_world_x;
uniform vec2 map_from_world_y;
varying vec2 ground_position;
varying float slope_light;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 cell_art(vec2 cell) {
	return texture(tile_lookup, (cell + vec2(1.5)) / mask_size);
}

vec3 sample_tile(vec4 art, vec2 local_grid) {
	// Retain the original, nearest-filtered pixels in the tile interior.
	// Only its outer 2.6 world pixels are reflected inward, extending the
	// painted top over the atlas's baked dark outline and vertical sides.
	vec2 offset = clamp(local_grid, vec2(-0.5), vec2(0.5));
	offset -= sign(offset) * max(abs(offset) - vec2(0.32), vec2(0.0)) * 2.0;
	vec2 pixel = vec2(16.0 + (offset.x - offset.y) * 16.0,
		16.0 + (offset.x + offset.y) * 8.0);
	vec2 atlas_cell = floor(art.rg * 255.0 + vec2(0.5));
	vec2 atlas_pixel = atlas_cell * 32.0 + floor(pixel) + vec2(0.5);
	return texture(terrain_atlas, atlas_pixel / vec2(textureSize(terrain_atlas, 0))).rgb;
}

void vertex() {
	// Mesh UVs retain the logical, unraised ground coordinates.
	ground_position = UV;
	slope_light = COLOR.r * 1.3;
}

void fragment() {
	vec2 p = floor(ground_position) + vec2(0.5);
	vec2 delta = p - map_origin;
	vec2 grid = vec2(dot(delta, map_from_world_x), dot(delta, map_from_world_y));
	vec2 base = floor(grid);
	vec2 within = fract(grid);
	vec4 a = cell_art(base);
	vec4 b = cell_art(base + vec2(1.0, 0.0));
	vec4 c = cell_art(base + vec2(0.0, 1.0));
	vec4 d = cell_art(base + vec2(1.0));
	vec4 own_art = cell_art(floor(grid + vec2(0.5)));
	// Shoreline colors come entirely from land; the water has its own mesh.
	a = mix(own_art, a, step(0.5, a.a));
	b = mix(own_art, b, step(0.5, b.a));
	c = mix(own_art, c, step(0.5, c.a));
	d = mix(own_art, d, step(0.5, d.a));

	// Blend only within two world pixels of a shared diamond edge. A small
	// pixel-stepped offset breaks grass/dirt joins without blurring the art.
	vec2 band = vec2(length(map_from_world_x), length(map_from_world_y)) * 2.0;
	vec2 fringe = (vec2(hash21(floor(p / vec2(2.0, 1.0))),
		hash21(floor(p / vec2(2.0, 1.0)) + vec2(19.0, 73.0))) - vec2(0.5)) * band * 0.65;
	float blend_top = smoothstep(0.5 - band.x, 0.5 + band.x,
		within.x + fringe.x * abs(a.b - b.b));
	float blend_bottom = smoothstep(0.5 - band.x, 0.5 + band.x,
		within.x + fringe.x * abs(c.b - d.b));
	float top_grass = mix(a.b, b.b, blend_top);
	float bottom_grass = mix(c.b, d.b, blend_bottom);
	float blend_y = smoothstep(0.5 - band.y, 0.5 + band.y,
		within.y + fringe.y * abs(top_grass - bottom_grass));
	vec3 top = mix(sample_tile(a, grid - base),
		sample_tile(b, grid - base - vec2(1.0, 0.0)), blend_top);
	vec3 bottom = mix(sample_tile(c, grid - base - vec2(0.0, 1.0)),
		sample_tile(d, grid - base - vec2(1.0)), blend_bottom);
	COLOR = vec4(mix(top, bottom, blend_y) * slope_light, 1.0);
}
