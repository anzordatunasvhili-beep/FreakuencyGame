# inventory.gd
# Attach to your Inventory node
extends Control

@onready var grid         = $ScrollContainer/GridContainer
@onready var item_blueprint = $Blueprint   # hidden template item slot

var _is_open := false

func _ready() -> void:
	hide()
	GameState.inventory_changed.connect(_refresh)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle()

func _toggle() -> void:
	_is_open = not _is_open
	if _is_open:
		show()
		_refresh()
	else:
		hide()

func _refresh() -> void:
	# Clear existing slots (keep blueprint)
	for child in grid.get_children():
		if child != item_blueprint:
			child.queue_free()

	for entry in GameState.inventory:
		var slot = item_blueprint.duplicate()
		slot.show()

		var item_label = slot.get_node_or_null("Item")
		var count_label = slot.get_node_or_null("Count/D1")
		var name_label  = slot.get_node_or_null("Count/D2")

		if item_label:
			item_label.text = entry.get("emoji", "🎁")

		if count_label:
			var qty = entry.get("quantity", 1)
			count_label.text = "x%d" % qty if qty > 1 else ""

		if name_label:
			name_label.text = entry.get("item_name", "")

		# Color by rarity
		var rarity_colors := {
			"common":    Color(0.6, 0.6, 0.6),
			"uncommon":  Color(0.26, 0.86, 0.49),
			"rare":      Color(0.37, 0.53, 0.86),
			"epic":      Color(0.75, 0.5, 0.97),
			"legendary": Color(0.98, 0.75, 0.14),
		}
		var rarity = entry.get("rarity", "common")
		var color = rarity_colors.get(rarity, Color.WHITE)

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.bg_color = Color(color.r, color.g, color.b, 0.15)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(color.r, color.g, color.b, 0.6)
		slot.add_theme_stylebox_override("panel", style)

		# Drag to hotbar on click
		var idx = grid.get_child_count()
		slot.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				_on_slot_clicked(entry)
		)

		grid.add_child(slot)

func _on_slot_clicked(entry: Dictionary) -> void:
	# Put item in first empty hotbar slot
	for i in GameState.hotbar.size():
		if GameState.hotbar[i] == null:
			GameState.set_hotbar_slot(i, entry.get("item_id"))
			return
	# If hotbar full, replace selected slot
	GameState.set_hotbar_slot(0, entry.get("item_id"))
