@tool
class_name VillageTree
extends Node2D

## One of sixteen generated pixel plants, anchored at the foot of its roots so
## Y sorting and the existing trunk collision continue to work naturally.

const VARIANT_COUNT := 16
const TREE_SHEETS: Array[Texture2D] = [
	preload("res://assets/world/trees/pixel_sets/tree_set_01_wild_green.png"),
	preload("res://assets/world/trees/pixel_sets/tree_set_02_lush_village.png"),
	preload("res://assets/world/trees/pixel_sets/tree_set_03_ancient_teal.png"),
	preload("res://assets/world/trees/pixel_sets/tree_set_04_crimson_twist.png"),
]
const ART_BOUNDS: Array[Rect2] = [
	Rect2(70, 107, 557, 520), Rect2(627, 25, 484, 602),
	Rect2(84, 627, 543, 579), Rect2(627, 627, 604, 591),
	Rect2(34, 11, 593, 616), Rect2(627, 117, 570, 510),
	Rect2(34, 627, 593, 608), Rect2(627, 627, 610, 606),
	Rect2(32, 36, 595, 591), Rect2(627, 96, 599, 475),
	Rect2(63, 627, 513, 597), Rect2(723, 676, 477, 532),
	Rect2(45, 10, 535, 617), Rect2(639, 239, 601, 388),
	Rect2(78, 627, 519, 601), Rect2(675, 627, 543, 593),
]
const WORLD_HEIGHTS := [
	96.0, 108.0, 92.0, 82.0,
	116.0, 100.0, 92.0, 72.0,
	86.0, 74.0, 106.0, 94.0,
	112.0, 74.0, 90.0, 84.0,
]
@export_range(0, VARIANT_COUNT - 1) var variant := 0:
	set(value):
		variant = posmod(value, VARIANT_COUNT)
		_refresh_sprite()

@export var variation_seed: int = 1

@export_range(0.7, 1.3, 0.05) var crown_scale: float = 1.0:
	set(value):
		crown_scale = value
		_refresh_sprite()

var sprite: Sprite2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.name = "TreeSprite"
	sprite.centered = false
	add_child(sprite)
	_refresh_sprite()


func _refresh_sprite() -> void:
	if sprite == null:
		return
	var current_variant := posmod(variant, VARIANT_COUNT)
	var bounds: Rect2 = ART_BOUNDS[current_variant]
	var atlas := AtlasTexture.new()
	atlas.atlas = TREE_SHEETS[current_variant / 4]
	atlas.region = bounds
	atlas.filter_clip = true
	sprite.texture = atlas

	var art_scale: float = WORLD_HEIGHTS[current_variant] / bounds.size.y * crown_scale
	sprite.scale = Vector2.ONE * art_scale
	sprite.position = -Vector2(bounds.size.x * 0.5, bounds.size.y) * art_scale
