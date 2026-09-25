class_name VillageBuilding
extends Node2D
## A generated pixel-art house, anchored at the front of its ground footprint.

const HOUSE_NAMES := ["Cottage", "Inn", "Merchant shop", "Village hall", "Herbalist", "Bakery", "Merchant manor", "Riverside cottage"]
const HOUSE_FILES := [1, 2, 3, 5, 6, 7, 9, 10]
const WORLD_WIDTHS := [136.0, 140.0, 140.0, 148.0, 148.0, 140.0, 140.0, 148.0]
# Opaque artwork bounds measured from the original transparent PNGs.
const ART_BOUNDS := [
	Rect2(203, 120, 950, 1020), Rect2(184, 26, 926, 1181),
	Rect2(74, 150, 1116, 982), Rect2(43, 112, 1172, 1001),
	Rect2(86, 73, 1122, 1117), Rect2(129, 138, 999, 954),
	Rect2(138, 41, 984, 1157), Rect2(59, 123, 1136, 1000),
]
const PIXEL_SHADER := preload("res://assets/world/shaders/pixel_house.gdshader")

@export_range(0, 7) var house_index := 0
var variation_seed := 0
var sprite: Sprite2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.name = "HouseSprite"
	sprite.centered = false
	add_child(sprite)
	var body := StaticBody2D.new()
	body.name = "Footprint"
	body.collision_mask = 0
	add_child(body)
	var shape := CollisionPolygon2D.new()
	shape.name = "Shape"
	body.add_child(shape)
	_update_house()


func configure(style_id: int, seed: int = 0) -> void:
	house_index = posmod(style_id, HOUSE_NAMES.size())
	variation_seed = seed
	if is_node_ready():
		_update_house()


func footprint_polygon() -> PackedVector2Array:
	var width: float = WORLD_WIDTHS[house_index]
	var half_width := width * 0.38
	var depth := width * 0.30
	return PackedVector2Array([Vector2(0, -depth), Vector2(half_width, -depth * 0.5), Vector2(0, -3), Vector2(-half_width, -depth * 0.5)])


func _update_house() -> void:
	house_index = posmod(house_index, HOUSE_NAMES.size())
	sprite.texture = load("res://assets/world/buildings/pixel_houses/house_%02d.png" % HOUSE_FILES[house_index]) as Texture2D
	assert(sprite.texture != null, "Missing pixel house sprite")
	var bounds: Rect2 = ART_BOUNDS[house_index]
	var art_scale: float = WORLD_WIDTHS[house_index] / bounds.size.x
	sprite.scale = Vector2.ONE * art_scale
	sprite.position = -Vector2(bounds.get_center().x, bounds.end.y) * art_scale
	var pixels := ShaderMaterial.new()
	pixels.shader = PIXEL_SHADER
	pixels.set_shader_parameter("pixel_grid", (sprite.texture.get_size() * art_scale).round())
	sprite.material = pixels
	($Footprint/Shape as CollisionPolygon2D).polygon = footprint_polygon()
