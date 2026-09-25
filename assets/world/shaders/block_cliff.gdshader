shader_type canvas_item;
render_mode unshaded;

varying vec2 face_pixel;

void vertex() {
	face_pixel = UV;
}

void fragment() {
	vec2 pixel = floor(face_pixel);
	float grain = fract(sin(dot(pixel, vec2(127.1, 311.7))) * 43758.5453);
	float band = floor(pixel.y / 5.0);
	float seams = step(0.85, fract(pixel.y / 5.0));
	float rim = 1.0 - step(2.0, pixel.y);
	COLOR.rgb *= 1.03 - band * 0.055 - seams * 0.13 - rim * 0.24 + (grain - 0.5) * 0.10;
}
