extends CanvasLayer

@onready var dialog_panel = $Panel
@onready var messages_box = $Panel/VBox/ScrollContainer/MessagesVBox
@onready var input_field = $Panel/VBox/Bottom/InputField
@onready var send_button = $Panel/VBox/Bottom/SendButton
@onready var close_button = $Panel/VBox/TopBar/CloseButton
@onready var status_label = $Panel/VBox/TopBar/StatusLabel
@onready var scroll_cont = $Panel/VBox/ScrollContainer
@onready var reward_button = $Panel/VBox/RewardButton

var is_open := false
var _player_node: Node = null
var _npc_definition: NpcDefinition = null

signal dialog_closed

func _ready() -> void:
	dialog_panel.hide()
	reward_button.hide()
	close_button.text = "Close"
	send_button.text = "Talk"
	input_field.placeholder_text = "Ask about quests, the world, or supplies..."
	status_label.text = "Local NPC"
	send_button.pressed.connect(_on_send_pressed)
	close_button.pressed.connect(close_dialog)
	input_field.text_submitted.connect(_on_text_submitted)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("interact"):
		close_dialog()
		get_viewport().set_input_as_handled()

func open_dialog(player: Node = null, npc_definition: NpcDefinition = null) -> void:
	_player_node = player
	_npc_definition = npc_definition
	is_open = true
	dialog_panel.show()
	_clear_messages()
	status_label.text = _npc_definition.display_name if _npc_definition else "NPC"
	var greeting: String = _npc_definition.greeting if _npc_definition else "Welcome, traveler."
	_add_bubble(greeting, "npc")
	input_field.grab_focus()

func close_dialog() -> void:
	is_open = false
	dialog_panel.hide()
	if _player_node and _player_node.has_method("set_dialog_open"):
		_player_node.set_dialog_open(false)
	_player_node = null
	dialog_closed.emit()

func _on_text_submitted(_text: String) -> void:
	_on_send_pressed()

func _on_send_pressed() -> void:
	var text: String = input_field.text.strip_edges()
	if text.is_empty():
		return
	input_field.clear()
	_add_bubble(text, "player")
	_add_bubble(_local_reply(text), "npc")
	input_field.grab_focus()

func _local_reply(text: String) -> String:
	var lower := text.to_lower()
	if _npc_definition:
		for topic in _npc_definition.dialogue_topics:
			if String(topic).to_lower() in lower:
				return str(_npc_definition.dialogue_topics[topic])
	if "quest" in lower or "mission" in lower:
		return "There will be local quests here once the quest system is added."
	if "world" in lower or "portal" in lower:
		return "People say another world lies beyond a portal waiting to be discovered."
	if "fish" in lower:
		return "The nearby waters will become a fishing area. Bring a rod when it is ready."
	if "hunt" in lower or "monster" in lower:
		return "Monsters will roam outside town once combat and hunting are built."
	if "weapon" in lower or "spell" in lower:
		return "Weapons and spells are planned, but you are not equipped yet."
	return "I do not know much about that yet, but the world is growing."

func _clear_messages() -> void:
	for child in messages_box.get_children():
		child.queue_free()

func _add_bubble(text: String, sender: String) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(250, 0)
	var color := "#c9a227" if sender == "npc" else "#e2e8f0"
	label.text = "[color=%s]%s[/color]" % [color, text]

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _bubble_style(sender))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.add_child(label)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_FILL
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sender == "npc":
		row.add_child(spacer)
		row.add_child(panel)
	else:
		row.add_child(panel)
		row.add_child(spacer)
	messages_box.add_child(row)
	_scroll_to_bottom()

func _bubble_style(sender: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.bg_color = Color(0.47, 0.27, 0.08, 0.7) if sender == "npc" else Color(0.29, 0.11, 0.49, 0.7)
	return style

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll_cont.scroll_vertical = int(scroll_cont.get_v_scroll_bar().max_value)
