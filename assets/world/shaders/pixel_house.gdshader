shader_type canvas_item;
render_mode unshaded;

// Keep the generated originals, displaying one crisp texel per world pixel.
uniform vec2 pixel_grid = vec2(180.0);
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec2 pixel_uv = (floor(UV * pixel_grid) + 0.5) / pixel_grid;
	vec4 pixel = texture(TEXTURE, pixel_uv);
	if (pixel.a < 0.5) {
		discard;
	}
	COLOR = vec4(pixel.rgb, 1.0) * sprite_tint;
}
