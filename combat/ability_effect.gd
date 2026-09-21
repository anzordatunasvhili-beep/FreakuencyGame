class_name AbilityEffect
extends Sprite2D

var definition: AbilityDefinition
var _elapsed := 0.0
var _frame := 0

func setup(value: AbilityDefinition, direction: Vector2) -> void:
	definition = value
	texture = definition.effect_texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region_enabled = true
	centered = true
	scale = Vector2.ONE * definition.effect_scale
	if definition.rotate_with_aim:
		rotation = direction.angle()
	_set_frame(0)

func _process(delta: float) -> void:
	if definition == null or texture == null:
		queue_free()
		return
	_elapsed += delta
	var next_frame := int(_elapsed * definition.animation_fps)
	if next_frame >= definition.frame_count:
		queue_free()
		return
	if next_frame != _frame:
		_frame = next_frame
		_set_frame(_frame)

func _set_frame(index: int) -> void:
	region_rect = Rect2(index * definition.frame_size.x, 0, definition.frame_size.x, definition.frame_size.y)

