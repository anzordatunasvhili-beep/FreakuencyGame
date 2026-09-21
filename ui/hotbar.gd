# hotbar.gd
# Attach to your Hotbar node
extends HBoxContainer

const SLOT_COUNT := 9

var _slots: Array = []
var _selected := 0

signal slot_selected(index: int)

func _ready() -> void:
	# Collect all slot nodes (B1-B9 in your old project)
	for i in SLOT_COUNT:
		var slot = get_child(i) if i < get_child_count() else null
		_slots.append(slot)

	GameState.hotbar_changed.connect(_refresh)
	GameState.inventory_changed.connect(_refresh)
	_refresh()
	_select_slot(0)

func _unhandled_input(event: InputEvent) -> void:
	# Number keys 1-9 select hotbar slots
	for i in SLOT_COUNT:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			_select_slot(i)

func _select_slot(index: int) -> void:
	_selected = index
	for i in _slots.size():
		if _slots[i] == null:
			continue
		# Highlight selected slot
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		if i == _selected:
			style.bg_color = Color(0.7, 0.6, 0.1, 0.8)
			style.set_border_width_all(2)
			style.border_color = Color(1, 0.85, 0.2)
		else:
			style.bg_color = Color(0.1, 0.1, 0.15, 0.7)
			style.set_border_width_all(1)
			style.border_color = Color(0.3, 0.3, 0.4)
		_slots[i].add_theme_stylebox_override("panel", style)
	slot_selected.emit(_selected)

func _refresh() -> void:
	for i in SLOT_COUNT:
		if _slots[i] == null:
			continue
		var item_id = GameState.hotbar[i] if i < GameState.hotbar.size() else null
		var item_node = _slots[i].get_node_or_null("Item")
		var count_node = _slots[i].get_node_or_null("Count")

		if item_id == null:
			_set_item_display(item_node, {})
			if count_node: count_node.text = ""
			continue

		# Find item in inventory
		var found := false
		for entry in GameState.inventory:
			if entry.get("item_id") == item_id:
				_set_item_display(item_node, entry)
				if count_node:
					count_node.text = str(entry.get("quantity", 1)) if entry.get("quantity", 1) > 1 else ""
				found = true
				break
		if not found:
			_set_item_display(item_node, {})
			if count_node:
				count_node.text = ""

func _set_item_display(item_node: Node, entry: Dictionary) -> void:
	if item_node == null:
		return
	if item_node is Label:
		item_node.text = entry.get("emoji", "")
	elif item_node is TextureRect:
		item_node.texture = entry.get("texture")

func get_selected_item_id():
	if _selected < GameState.hotbar.size():
		return GameState.hotbar[_selected]
	return null
