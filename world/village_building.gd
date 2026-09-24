class_name VillageBuilding
extends Node2D
## Draws a reusable isometric village building from facade, roof, and trim modules.
## The origin is the front point of its roughly 128 x 54 px ground footprint.

const BACK := Vector2(0, -54)
const LEFT := Vector2(-64, -27)
const FRONT := Vector2.ZERO
const RIGHT := Vector2(64, -27)

@export var recipe: VillageBuildingRecipe = VillageBuildingRecipe.new()
@export var variation_seed := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var body := StaticBody2D.new()
	body.name = "Footprint"
	add_child(body)
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([BACK + Vector2(0, 5), RIGHT + Vector2(-5, 0), FRONT + Vector2(0, -4), LEFT + Vector2(5, 0)])
	body.add_child(shape)
	queue_redraw()


func configure(style_id: int, seed: int = 0) -> void:
	variation_seed = seed
	var parts := VillageBuildingRecipe.new()
	match posmod(style_id, 5):
		0: # Low cottage with a simple, steep slate roof.
			parts.stories = 1
			parts.roof_shape = VillageBuildingRecipe.RoofShape.GABLE
			parts.dormers = 1
			parts.entry_style = VillageBuildingRecipe.EntryStyle.COTTAGE
			parts.roof_color = Color("#4d8b87")
		1: # Taller inn, with the dormers and porch from the reference.
			parts.stories = 2
			parts.roof_shape = VillageBuildingRecipe.RoofShape.CROSS_GABLE
			parts.dormers = 2
			parts.entry_style = VillageBuildingRecipe.EntryStyle.PORCH
			parts.balcony = true
			parts.roof_color = Color("#3c777b")
		2: # Broad shop under a hipped roof and striped awning.
			parts.stories = 1
			parts.roof_shape = VillageBuildingRecipe.RoofShape.HIP
			parts.dormers = 0
			parts.entry_style = VillageBuildingRecipe.EntryStyle.SHOP
			parts.chimney = false
			parts.roof_color = Color("#668d78")
			parts.accent_color = Color("#d4ac72")
		3: # Narrow-feeling three-storey house with a raised roof.
			parts.stories = 3
			parts.roof_shape = VillageBuildingRecipe.RoofShape.GABLE
			parts.dormers = 2
			parts.entry_style = VillageBuildingRecipe.EntryStyle.COTTAGE
			parts.roof_color = Color("#467a82")
		4: # A two-storey hall, with its roof corners folded down.
			parts.stories = 2
			parts.roof_shape = VillageBuildingRecipe.RoofShape.HIP
			parts.dormers = 1
			parts.entry_style = VillageBuildingRecipe.EntryStyle.PORCH
			parts.roof_color = Color("#567d73")
			parts.plaster_color = Color("#e0cfb4")
			parts.stone_color = Color("#78746f")
	recipe = parts
	queue_redraw()


func apply_recipe(parts: VillageBuildingRecipe, seed: int = 0) -> void:
	recipe = parts
	variation_seed = seed
	queue_redraw()


func _draw() -> void:
	if recipe == null:
		return
	var wall_height := 10.0 + 36.0 * recipe.stories
	var roof_rise := 29.0 + (5.0 if recipe.roof_shape == VillageBuildingRecipe.RoofShape.CROSS_GABLE else 0.0)
	_draw_shadow()
	_draw_stone_base()
	_draw_facades(wall_height)
	_draw_wall_texture(wall_height)
	_draw_timber(wall_height)
	_draw_windows_and_door()
	if recipe.balcony:
		_draw_balcony()
	if recipe.chimney:
		_draw_chimney(wall_height, roof_rise)
	_draw_roof(wall_height, roof_rise)
	_draw_dormers(wall_height, roof_rise)
	if recipe.entry_style == VillageBuildingRecipe.EntryStyle.SHOP:
		_draw_shop_awning()
	elif recipe.entry_style == VillageBuildingRecipe.EntryStyle.PORCH:
		_draw_porch()


func _draw_shadow() -> void:
	_poly([BACK + Vector2(0, 7), RIGHT + Vector2(9, 4), FRONT + Vector2(0, 10), LEFT + Vector2(-9, 4)], Color(0.11, 0.18, 0.15, 0.30))


func _draw_stone_base() -> void:
	var stone := recipe.stone_color
	_poly([LEFT, FRONT, FRONT + Vector2(0, -13), LEFT + Vector2(0, -13)], stone.lightened(0.12))
	_poly([FRONT, RIGHT, RIGHT + Vector2(0, -13), FRONT + Vector2(0, -13)], stone.darkened(0.12))
	for side in 2:
		for i in 6:
			var t := (float(i) + 0.2) / 6.0
			var p := _face_point(side, t, 5.0)
			draw_line(p, p + Vector2(0, -6), stone.darkened(0.25), 1.0)
		for h in [4.0, 10.0]:
			draw_line(_face_point(side, 0.0, h), _face_point(side, 1.0, h), stone.darkened(0.18), 1.0)


func _draw_facades(wall_height: float) -> void:
	var plaster := recipe.plaster_color
	_poly([_face_point(0, 0, 13), _face_point(0, 1, 13), _face_point(0, 1, wall_height), _face_point(0, 0, wall_height)], plaster)
	_poly([_face_point(1, 0, 13), _face_point(1, 1, 13), _face_point(1, 1, wall_height), _face_point(1, 0, wall_height)], plaster.darkened(0.14))
	# Corners and a bevel keep the stone/plaster silhouette legible at game zoom.
	draw_line(_face_point(0, 0, 13), _face_point(0, 0, wall_height), plaster.lightened(0.16), 2.0)
	draw_line(_face_point(1, 1, 13), _face_point(1, 1, wall_height), plaster.darkened(0.28), 2.0)


func _draw_wall_texture(wall_height: float) -> void:
	for side in 2:
		for i in 40:
			var t := 0.04 + _hash(i * 17 + side * 500) * 0.92
			var h := 16.0 + _hash(i * 23 + side * 700) * (wall_height - 22.0)
			var p := _face_point(side, t, h)
			var shade := recipe.plaster_color.darkened(0.09 if side == 0 else 0.24)
			draw_line(p, p + Vector2(2.0, -0.5), shade, 1.0)


func _draw_timber(wall_height: float) -> void:
	var timber := recipe.timber_color
	for side in 2:
		for t in [0.0, 0.33, 0.67, 1.0]:
			draw_line(_face_point(side, t, 13), _face_point(side, t, wall_height), timber.darkened(0.1), 4.0)
			draw_line(_face_point(side, t, 15), _face_point(side, t, wall_height - 2), timber.lightened(0.20), 1.0)
		for level in range(1, recipe.stories):
			var h := 10.0 + float(level) * 36.0
			draw_line(_face_point(side, 0, h), _face_point(side, 1, h), timber.darkened(0.12), 4.0)
			draw_line(_face_point(side, 0, h - 1), _face_point(side, 1, h - 1), timber.lightened(0.2), 1.0)
		for t in [0.0, 0.67]:
			var a := _face_point(side, t, wall_height - 4)
			var b := _face_point(side, t + 0.20, wall_height - 20)
			draw_line(a, b, timber, 2.0)
		draw_line(_face_point(side, 0, wall_height), _face_point(side, 1, wall_height), timber.darkened(0.18), 5.0)
		draw_line(_face_point(side, 0, 14), _face_point(side, 1, 14), timber.lightened(0.05), 3.0)


func _draw_windows_and_door() -> void:
	for level in recipe.stories:
		var bottom := 18.0 + float(level) * 36.0
		if level == 0:
			_draw_window(0, 0.13, bottom, 0.19, recipe.entry_style == VillageBuildingRecipe.EntryStyle.SHOP)
			_draw_door(0, 0.49, 0.29)
		else:
			_draw_window(0, 0.13, bottom, 0.19)
			_draw_window(0, 0.59, bottom, 0.19)
		_draw_window(1, 0.13, bottom, 0.18)
		_draw_window(1, 0.59, bottom, 0.18)


func _draw_window(side: int, t: float, bottom: float, width: float, large: bool = false) -> void:
	var height := 24.0 if large else 18.0
	var frame := recipe.timber_color.darkened(0.23)
	var t1 := t + width
	_poly(_face_quad(side, t - 0.035, t1 + 0.035, bottom - 3, bottom + height + 3), frame)
	_poly(_face_quad(side, t, t1, bottom, bottom + height), Color("#6c9fa5"))
	_poly(_face_quad(side, t + 0.015, t1 - 0.02, bottom + 2, bottom + height - 2), Color("#b6d4c6"))
	_poly(_face_quad(side, t + width * 0.47, t1 - 0.02, bottom + 2, bottom + height - 2), Color("#5b8a92"))
	draw_line(_face_point(side, t + width * 0.5, bottom), _face_point(side, t + width * 0.5, bottom + height), frame, 2.0)
	draw_line(_face_point(side, t, bottom + height * 0.50), _face_point(side, t1, bottom + height * 0.50), frame, 2.0)
	_poly(_face_quad(side, t - 0.055, t - 0.025, bottom - 1, bottom + height + 2), recipe.timber_color.lightened(0.1))
	_poly(_face_quad(side, t1 + 0.025, t1 + 0.055, bottom - 1, bottom + height + 2), recipe.timber_color.lightened(0.1))
	draw_line(_face_point(side, t - 0.055, bottom - 4), _face_point(side, t1 + 0.055, bottom - 4), recipe.timber_color.lightened(0.33), 3.0)
	if _hash(int(t * 99.0) + int(bottom)) > 0.30:
		_draw_flower_box(side, t - 0.02, t1 + 0.02, bottom - 5)


func _draw_flower_box(side: int, t0: float, t1: float, h: float) -> void:
	_poly(_face_quad(side, t0, t1, h - 5, h), recipe.timber_color.darkened(0.08))
	for i in 4:
		var t := lerpf(t0 + 0.02, t1 - 0.02, float(i) / 3.0)
		var p := _face_point(side, t, h + 1)
		draw_circle(p, 2.5, Color("#3c7a4c"))
		draw_circle(p + Vector2(0, -2), 1.0, Color("#ef9d76") if i % 2 == 0 else Color("#f0cf78"))


func _draw_door(side: int, t: float, width: float) -> void:
	var frame := recipe.timber_color.darkened(0.28)
	_poly(_face_quad(side, t - 0.025, t + width + 0.025, 12, 45), frame)
	_poly(_face_quad(side, t, t + width, 12, 42), recipe.timber_color.lightened(0.08))
	_poly(_face_quad(side, t + 0.04, t + width - 0.04, 14, 39), Color("#684637"))
	draw_line(_face_point(side, t + 0.04, 27), _face_point(side, t + width - 0.04, 27), recipe.timber_color.lightened(0.24), 1.0)
	var knob := _face_point(side, t + width * 0.74, 25)
	draw_circle(knob, 1.5, Color("#e9c67d"))
	_poly([_face_point(side, t - 0.05, 12), _face_point(side, t + width + 0.05, 12), _face_point(side, t + width + 0.10, 7), _face_point(side, t - 0.08, 7)], Color("#a39a82"))


func _draw_balcony() -> void:
	var h := 46.0
	var a := _face_point(0, 0.05, h)
	var b := _face_point(0, 0.98, h)
	var out := Vector2(-5, 7)
	_poly([a, b, b + out, a + out], recipe.timber_color.darkened(0.2))
	for i in 6:
		var t := float(i) / 5.0
		var p := a.lerp(b, t) + out
		draw_line(p, p + Vector2(0, -11), recipe.timber_color, 2.0)
	draw_line(a + out + Vector2(0, -11), b + out + Vector2(0, -11), recipe.timber_color.lightened(0.13), 3.0)


func _draw_chimney(wall_height: float, rise: float) -> void:
	# Sink the stack into the roof plane so its base cannot read as floating.
	var p := Vector2(-24, -53 - wall_height - rise * 0.08)
	_poly([p + Vector2(-6, 0), p + Vector2(6, 2), p + Vector2(6, -28), p + Vector2(-6, -30)], Color("#777576"))
	_poly([p + Vector2(6, 2), p + Vector2(10, -1), p + Vector2(10, -32), p + Vector2(6, -28)], Color("#555b5b"))
	_poly([p + Vector2(-8, -29), p + Vector2(7, -27), p + Vector2(11, -31), p + Vector2(-4, -34)], Color("#a19b90"))
	for i in 3:
		var y := -5.0 - float(i) * 8.0
		draw_line(p + Vector2(-5, y), p + Vector2(5, y + 1), Color("#555757"), 1.0)


func _draw_roof(wall_height: float, rise: float) -> void:
	var n := BACK + Vector2(0, -wall_height - 5)
	var w := LEFT + Vector2(-5, -wall_height - 4)
	var s := FRONT + Vector2(0, -wall_height + 5)
	var e := RIGHT + Vector2(5, -wall_height - 4)
	var rn := (n + w) * 0.5 + Vector2(0, -rise)
	var rs := (e + s) * 0.5 + Vector2(0, -rise)
	if recipe.roof_shape == VillageBuildingRecipe.RoofShape.HIP:
		rn = rn.lerp(rs, 0.23)
		rs = rs.lerp(rn, 0.23)
		_poly([n, w, rn], recipe.roof_color.darkened(0.06))
		_poly([s, e, rs], recipe.roof_color.darkened(0.16))
	else:
		_draw_gable([n, w, rn], false)
		_draw_gable([s, e, rs], true)
	# Far pitch catches the light; the nearer pitch is deeper teal.
	_draw_roof_plane(n, e, rs, rn, recipe.roof_color.lightened(0.10), true)
	_draw_roof_plane(w, s, rs, rn, recipe.roof_color, false)
	draw_line(rn, rs, recipe.roof_color.lightened(0.36), 2.0)
	draw_line(w, s, recipe.roof_color.darkened(0.33), 3.0)
	draw_line(n, e, recipe.roof_color.darkened(0.20), 2.0)
	if recipe.roof_shape == VillageBuildingRecipe.RoofShape.CROSS_GABLE:
		_draw_cross_gable(w.lerp(s, 0.77).lerp(rn.lerp(rs, 0.77), 0.55), rise)


func _draw_roof_plane(a: Vector2, b: Vector2, ridge_b: Vector2, ridge_a: Vector2, color: Color, far: bool) -> void:
	_poly([a, b, ridge_b, ridge_a], color.darkened(0.12))
	var rows := 5
	var columns := 9
	for row in rows:
		var top_t := float(row) / float(rows)
		var bottom_t := float(row + 1) / float(rows)
		for col in columns:
			var u0 := float(col) / float(columns)
			var u1 := float(col + 1) / float(columns)
			var top0 := ridge_a.lerp(a, top_t).lerp(ridge_b.lerp(b, top_t), u0)
			var top1 := ridge_a.lerp(a, top_t).lerp(ridge_b.lerp(b, top_t), u1)
			var bottom0 := ridge_a.lerp(a, bottom_t).lerp(ridge_b.lerp(b, bottom_t), u0)
			var bottom1 := ridge_a.lerp(a, bottom_t).lerp(ridge_b.lerp(b, bottom_t), u1)
			var shade := _hash(row * 71 + col * 13 + (200 if far else 0))
			var tile_color := color.lightened((shade - 0.42) * 0.25)
			_poly([top0 + Vector2(0, 1), top1 + Vector2(0, 1), bottom1, bottom0], tile_color)
			draw_line(bottom0, bottom1, color.darkened(0.21), 1.0)
			if shade > 0.70:
				draw_line(top0.lerp(bottom0, 0.40), top0.lerp(bottom0, 0.68), color.lightened(0.33), 1.0)


func _draw_gable(points: Array, front: bool) -> void:
	_poly(points, recipe.plaster_color.darkened(0.18 if front else 0.05))
	var beam := recipe.timber_color.darkened(0.12)
	draw_line(points[0], points[2], beam, 3.0)
	draw_line(points[1], points[2], beam, 3.0)
	draw_line(points[0].lerp(points[1], 0.5), points[2], beam, 3.0)
	draw_line(points[0].lerp(points[2], 0.47), points[1].lerp(points[2], 0.47), beam, 2.0)
	if front:
		var center: Vector2 = points[0].lerp(points[2], 0.55)
		_poly([center + Vector2(-4, 3), center + Vector2(4, 3), center + Vector2(4, -5), center + Vector2(-4, -5)], Color("#83b1b2"))


func _draw_cross_gable(center: Vector2, rise: float) -> void:
	var timber := recipe.timber_color
	var l := center + Vector2(-13, 8)
	var r := center + Vector2(13, 8)
	var peak := center + Vector2(0, -rise * 0.52)
	_poly([l, r, peak], recipe.plaster_color.darkened(0.09))
	_poly([peak + Vector2(-2, -3), l + Vector2(-4, 3), l + Vector2(0, 6), peak], recipe.roof_color.darkened(0.22))
	_poly([peak, r + Vector2(0, 6), r + Vector2(5, 3), peak + Vector2(2, -3)], recipe.roof_color.lightened(0.19))
	draw_line(l, peak, timber, 3.0)
	draw_line(peak, r, timber, 3.0)
	_poly([center + Vector2(-4, 4), center + Vector2(4, 4), center + Vector2(4, -5), center + Vector2(-4, -5)], Color("#7caab0"))
	draw_line(center + Vector2(0, -5), center + Vector2(0, 4), timber, 1.0)


func _draw_dormers(wall_height: float, rise: float) -> void:
	if recipe.dormers == 0:
		return
	var n := BACK + Vector2(0, -wall_height - 5)
	var w := LEFT + Vector2(-5, -wall_height - 4)
	var s := FRONT + Vector2(0, -wall_height + 5)
	var e := RIGHT + Vector2(5, -wall_height - 4)
	var rn := (n + w) * 0.5 + Vector2(0, -rise)
	var rs := (e + s) * 0.5 + Vector2(0, -rise)
	for i in recipe.dormers:
		var u := (float(i) + 1.0) / (float(recipe.dormers) + 1.0)
		var center := rn.lerp(rs, u).lerp(w.lerp(s, u), 0.62)
		if recipe.roof_shape == VillageBuildingRecipe.RoofShape.CROSS_GABLE and i == recipe.dormers - 1:
			continue
		_draw_dormer(center)


func _draw_dormer(center: Vector2) -> void:
	var l := center + Vector2(-8, 2)
	var r := center + Vector2(8, 2)
	var top := center + Vector2(0, -14)
	_poly([l, r, r + Vector2(0, -9), top, l + Vector2(0, -9)], recipe.plaster_color.lightened(0.08))
	_poly([top + Vector2(-1, -4), l + Vector2(-4, -5), l, top], recipe.roof_color.darkened(0.2))
	_poly([top, r, r + Vector2(4, -5), top + Vector2(1, -4)], recipe.roof_color.lightened(0.12))
	_poly([center + Vector2(-3, 0), center + Vector2(3, 0), center + Vector2(3, -8), center + Vector2(-3, -8)], Color("#8fbfc0"))
	draw_line(center + Vector2(0, -8), center, recipe.timber_color.darkened(0.2), 1.0)
	draw_line(l, top, recipe.timber_color, 2.0)
	draw_line(top, r, recipe.timber_color, 2.0)


func _draw_shop_awning() -> void:
	var a := _face_point(0, 0.03, 42)
	var b := _face_point(0, 0.98, 42)
	var overhang := Vector2(-4, 14)
	_poly([a, b, b + overhang, a + overhang], recipe.roof_color.darkened(0.08))
	for i in 6:
		var t0 := float(i) / 6.0
		var t1 := float(i + 1) / 6.0
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		_poly([p0, p1, p1 + overhang, p0 + overhang], recipe.accent_color if i % 2 == 0 else recipe.roof_color)
	draw_line(a + overhang, b + overhang, recipe.timber_color.darkened(0.2), 3.0)
	_draw_hanging_sign(b + Vector2(-5, -8))


func _draw_hanging_sign(p: Vector2) -> void:
	draw_line(p, p + Vector2(9, 1), recipe.timber_color.darkened(0.3), 2.0)
	draw_line(p + Vector2(8, 1), p + Vector2(8, 7), recipe.timber_color.darkened(0.3), 1.0)
	_poly([p + Vector2(3, 7), p + Vector2(16, 8), p + Vector2(16, 18), p + Vector2(3, 17)], recipe.accent_color)
	draw_circle(p + Vector2(10, 12), 2.5, Color("#f1dda6"))


func _draw_porch() -> void:
	var a := _face_point(0, 0.45, 48)
	var b := _face_point(0, 0.86, 48)
	var out := Vector2(-7, 8)
	_poly([a, b, b + out, a + out], recipe.roof_color.darkened(0.16))
	draw_line(a + out, _face_point(0, 0.45, 7) + out, recipe.timber_color.darkened(0.12), 3.0)
	draw_line(b + out, _face_point(0, 0.86, 7) + out, recipe.timber_color.darkened(0.12), 3.0)
	draw_line(a + out, b + out, recipe.roof_color.lightened(0.22), 2.0)


func _face_point(side: int, t: float, height: float) -> Vector2:
	var edge := LEFT.lerp(FRONT, t) if side == 0 else FRONT.lerp(RIGHT, t)
	return edge + Vector2(0, -height)


func _face_quad(side: int, t0: float, t1: float, bottom: float, top: float) -> Array:
	return [_face_point(side, t0, bottom), _face_point(side, t1, bottom), _face_point(side, t1, top), _face_point(side, t0, top)]


func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)


func _hash(value: int) -> float:
	var n := int((value + variation_seed * 31) * 1103515245 + 12345) & 0x7fffffff
	return float(n % 997) / 997.0
