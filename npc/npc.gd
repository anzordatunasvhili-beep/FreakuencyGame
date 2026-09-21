# npc.gd
# Attach to Area2D
extends Area2D

@export var dialog_path: NodePath
@export var definition: NpcDefinition

@onready var hint_label = $HintLabel
@onready var sprite: Sprite2D = $Sprite2D

var _dialog_node: Node = null
var _player_nearby := false
var _player_node: Node = null

func _ready() -> void:
	_apply_definition()
	hint_label.hide()
	if dialog_path.is_empty():
		push_warning("NPC: dialog_path is not set! Drag NPCDialog into the Inspector.")
		return
	_dialog_node = get_node(dialog_path)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if _dialog_node == null:
		return
	if _player_nearby and event.is_action_pressed("interact"):
		if not _dialog_node.is_open:
			_dialog_node.open_dialog(_player_node, definition)
			if _player_node and _player_node.has_method("set_dialog_open"):
				_player_node.set_dialog_open(true)
			get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_player_node = body
		hint_label.show()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_player_node = null
		hint_label.hide()

func _apply_definition() -> void:
	if definition == null:
		return
	hint_label.text = definition.interaction_prompt
	if definition.sprite_sheet:
		sprite.texture = definition.sprite_sheet
		sprite.hframes = definition.animation_columns
		sprite.vframes = definition.animation_rows
		sprite.frame = definition.default_frame
		sprite.scale = Vector2.ONE * definition.sprite_scale
		sprite.position = definition.sprite_offset
