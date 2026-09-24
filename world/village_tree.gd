@tool
class_name VillageTree
extends Node2D

## A ground-anchored, isometric tree. The root sits at the trunk's foot so
## Godot's Y sorting naturally puts actors in front of or behind the crown.
enum Form { ROUND, SPREADING, TALL }

@export var form: Form = Form.ROUND:
	set(value):
		form = value
		queue_redraw()

@export var variation_seed: int = 1:
	set(value):
		variation_seed = value
		queue_redraw()

@export_range(0.7, 1.3, 0.05) var crown_scale: float = 1.0:
	set(value):
		crown_scale = value
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variation_seed
	var palette := _palette()
	var dark: Color = palette[0]
	var middle: Color = palette[1]
	var lit: Color = palette[2]
	var sparkle: Color = palette[3]
	var clusters := _crown_clusters()
	var lean := float(variation_seed % 5 - 2) * 1.4
	for i in range(clusters.size()):
		var cluster := clusters[i]
		cluster.x += lean + rng.randf_range(-3.0, 3.0)
		cluster.y += rng.randf_range(-2.5, 2.5)
		cluster.z *= rng.randf_range(0.91, 1.09)
		cluster.w *= rng.randf_range(0.91, 1.08)
		clusters[i] = cluster

	# The short, skewed shadow reads as a footprint on an isometric tile.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 0), Vector2(-2, -7), Vector2(25, -1),
		Vector2(16, 6), Vector2(-5, 8)
	]), Color(0.07, 0.19, 0.17, 0.26))
	_draw_trunk()

	# Each mass has a dark underside, a broad middle tone and a smaller sunlit
	# upper plane. Uneven lobes and hand-placed highlights avoid round blobs.
	for cluster in clusters:
		var center := Vector2(cluster.x, cluster.y)
		var width := cluster.z * crown_scale
		var height := cluster.w * crown_scale
		_draw_blob(center + Vector2(2, 3), width, height, dark, rng)
		_draw_blob(center + Vector2(-2, -2), width * 0.87, height * 0.78, middle, rng)
		_draw_blob(center + Vector2(-width * 0.14, -height * 0.30), width * 0.58, height * 0.42, lit, rng)

	# Small angular leaf facets break up the masses and suggest clustered
	# foliage like the painted reference, while preserving the big silhouette.
	for cluster in clusters:
		var center := Vector2(cluster.x, cluster.y)
		for i in range(7):
			var x := rng.randf_range(-0.68, 0.58) * cluster.z * crown_scale
			var y := rng.randf_range(-0.63, 0.45) * cluster.w * crown_scale
			var radius := rng.randf_range(2.7, 5.7)
			var color := sparkle if i % 3 == 0 else (lit if i % 3 == 1 else dark)
			_draw_leaf_facet(center + Vector2(x, y), radius, color)


func _palette() -> Array[Color]:
	match posmod(variation_seed, 3):
		0:
			return [Color("#234e4a"), Color("#3a7962"), Color("#66a779"), Color("#8fbd8d")]
		1:
			return [Color("#25484b"), Color("#3b7276"), Color("#5c9e91"), Color("#8cbdac")]
		_:
			return [Color("#3b5142"), Color("#617f53"), Color("#92a965"), Color("#b5c482")]


func _crown_clusters() -> Array[Vector4]:
	match form:
		Form.SPREADING:
			return [
				Vector4(-29, -62, 22, 18), Vector4(28, -64, 22, 19),
				Vector4(-12, -81, 23, 18), Vector4(14, -82, 24, 18),
				Vector4(0, -64, 30, 22)
			]
		Form.TALL:
			return [
				Vector4(-12, -60, 17, 21), Vector4(13, -62, 17, 21),
				Vector4(-9, -85, 17, 20), Vector4(10, -86, 18, 22),
				Vector4(0, -104, 17, 18), Vector4(1, -76, 20, 26)
			]
		_:
			return [
				Vector4(-21, -62, 21, 20), Vector4(22, -64, 20, 20),
				Vector4(-8, -83, 22, 19), Vector4(11, -82, 22, 19),
				Vector4(0, -66, 27, 24)
			]


func _draw_trunk() -> void:
	var bark_shadow := Color("#463b37")
	var bark_middle := Color("#735a45")
	var bark_light := Color("#a07b57")
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -4), Vector2(-7, -20), Vector2(-4, -37),
		Vector2(-18, -51), Vector2(-16, -55), Vector2(0, -42),
		Vector2(4, -45), Vector2(18, -59), Vector2(20, -57),
		Vector2(8, -36), Vector2(7, -18), Vector2(7, -4), Vector2(1, -1)
	]), bark_shadow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -5), Vector2(-6, -19), Vector2(-3, -36),
		Vector2(0, -40), Vector2(2, -37), Vector2(2, -21),
		Vector2(1, -5)
	]), bark_middle)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -7), Vector2(-4, -22), Vector2(-1, -34),
		Vector2(0, -35), Vector2(-1, -17), Vector2(-1, -7)
	]), bark_light)
	draw_line(Vector2(-3, -18), Vector2(-2, -11), Color("#4a3a32"), 1.0)
	draw_line(Vector2(3, -29), Vector2(5, -22), Color("#4a3a32"), 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -10), Vector2(-10, -2), Vector2(-5, -4), Vector2(0, -7)
	]), bark_shadow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, -9), Vector2(11, -2), Vector2(5, -4), Vector2(1, -7)
	]), bark_middle)


func _draw_blob(center: Vector2, rx: float, ry: float, color: Color, rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var irregularity := rng.randf_range(0.87, 1.12)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry) * irregularity)
	draw_colored_polygon(points, color)


func _draw_leaf_facet(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius, -radius * 0.16),
		center + Vector2(-radius * 0.29, -radius * 0.68),
		center + Vector2(radius * 0.81, -radius * 0.45),
		center + Vector2(radius, radius * 0.12),
		center + Vector2(radius * 0.15, radius * 0.55),
		center + Vector2(-radius * 0.77, radius * 0.38)
	]), color)
