extends CanvasLayer

const PowerHUD = preload("res://ui/power_hud.gd")

@onready var grid: GridContainer = $ScrollContainer/GridContainer
@onready var item_blueprint: PanelContainer = $Blueprint
@onready var power_q_button: Button = $PowerPanel/Equipped/QSlot
@onready var power_r_button: Button = $PowerPanel/Equipped/RSlot
@onready var power_list: VBoxContainer = $PowerPanel/PowerScroll/PowerList

var _is_open := false
var _power_target_slot := 0

func _ready() -> void:
	hide()
	GameState.inventory_changed.connect(_refresh)
	power_q_button.pressed.connect(func(): _select_power_slot(0))
	power_r_button.pressed.connect(func(): _select_power_slot(1))
	get_viewport().size_changed.connect(_fit_item_grid)
	_fit_item_grid()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_is_open = not _is_open
		visible = _is_open
		if _is_open:
			_refresh()
		get_viewport().set_input_as_handled()

func _fit_item_grid() -> void:
	# Leave the loadout enough room while allowing the item grid to wrap.
	grid.columns = maxi(1, floori((get_viewport().get_visible_rect().size.x - 470.0) / 76.0))

func _refresh() -> void:
	for child in grid.get_children():
		child.queue_free()
	for entry in GameState.inventory:
		var slot := item_blueprint.duplicate() as PanelContainer
		slot.show()
		var item_rect := slot.get_node_or_null("Item") as TextureRect
		var count_label := slot.get_node_or_null("Count/D1") as Label
		var name_label := slot.get_node_or_null("Count/D2") as Label
		var icon_path: String = entry.get("icon_path", "")
		item_rect.texture = load(icon_path) if not icon_path.is_empty() else null
		var quantity: int = entry.get("quantity", 1)
		count_label.text = "x%d" % quantity if quantity > 1 else ""
		name_label.text = entry.get("item_name", "")
		slot.tooltip_text = "%s\n%s\nBuy %d  Sell %d" % [entry.get("item_name", ""), entry.get("description", ""), entry.get("buy_price", 0), entry.get("sell_price", 0)]
		_style_slot(slot, entry.get("rarity", "common"))
		slot.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				_on_slot_clicked(entry)
		)
		grid.add_child(slot)
	_refresh_power_panel()

func _style_slot(slot: PanelContainer, rarity: String) -> void:
	var colors := {"common": Color(0.6, 0.6, 0.6), "uncommon": Color(0.26, 0.86, 0.49), "rare": Color(0.37, 0.53, 0.86), "epic": Color(0.75, 0.5, 0.97), "legendary": Color(0.98, 0.75, 0.14)}
	var color: Color = colors.get(rarity, Color.WHITE)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(color.r, color.g, color.b, 0.18)
	style.set_border_width_all(1)
	style.border_color = Color(color.r, color.g, color.b, 0.75)
	slot.add_theme_stylebox_override("panel", style)

func _on_slot_clicked(entry: Dictionary) -> void:
	for index in GameState.hotbar.size():
		if GameState.hotbar[index] == null:
			GameState.set_hotbar_slot(index, entry.get("item_id"))
			return
	GameState.set_hotbar_slot(0, entry.get("item_id"))

func _get_ability_controller() -> AbilityController:
	var player := get_tree().get_first_node_in_group("player")
	return player.ability_controller if player else null

func _select_power_slot(slot: int) -> void:
	_power_target_slot = slot
	_refresh_power_panel()

func _refresh_power_panel() -> void:
	var controller := _get_ability_controller()
	if controller == null or controller.equipped_powers.size() < 2:
		return
	for slot in 2:
		var equipped := controller.equipped_powers[slot]
		var slot_button := power_q_button if slot == 0 else power_r_button
		var accent: Color = PowerHUD.LEGACY_ACCENTS.get(equipped.ability_id, equipped.accent_color)
		slot_button.text = "%s  %s\n%s" % ["Q" if slot == 0 else "R", "SELECTED" if _power_target_slot == slot else "EQUIPPED", equipped.display_name]
		_style_power_button(slot_button, accent, _power_target_slot == slot)
	for child in power_list.get_children():
		power_list.remove_child(child)
		child.queue_free()
	# Put the new powers first so players can discover them without changing saves.
	var ordered: Array[AbilityDefinition] = []
	for power in controller.power_library:
		if not power.power_kind.is_empty():
			ordered.append(power)
	for power in controller.power_library:
		if power.power_kind.is_empty():
			ordered.append(power)
	for power in ordered:
		var button := Button.new()
		button.custom_minimum_size.y = 92.0 if not power.description.is_empty() else 70.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var accent: Color = PowerHUD.LEGACY_ACCENTS.get(power.ability_id, power.accent_color)
		var is_equipped := controller.equipped_powers[_power_target_slot] == power
		_style_power_button(button, accent, is_equipped)
		var rows := VBoxContainer.new()
		rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(rows)
		rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rows.offset_left = 12
		rows.offset_top = 9
		rows.offset_right = -12
		rows.offset_bottom = -9
		rows.add_theme_constant_override("separation", 4)
		var title := Label.new()
		title.text = "%s%s" % [power.display_name, "  /  EQUIPPED" if is_equipped else ""]
		title.add_theme_color_override("font_color", accent)
		title.add_theme_font_size_override("font_size", 14)
		rows.add_child(title)
		var stats := Label.new()
		stats.text = "%d DMG   /   %.1fs COOLDOWN   /   %d RANGE" % [power.damage, power.cooldown, power.range]
		stats.add_theme_color_override("font_color", Color(0.69, 0.74, 0.83))
		stats.add_theme_font_size_override("font_size", 10)
		rows.add_child(stats)
		if not power.description.is_empty():
			var detail := Label.new()
			detail.text = _power_summary(power)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.add_theme_color_override("font_color", Color(0.84, 0.87, 0.93))
			detail.add_theme_font_size_override("font_size", 12)
			rows.add_child(detail)
		button.tooltip_text = "%s\n%s\nRange %.0f / Cooldown %.1fs" % [power.display_name, power.description, power.range, power.cooldown]
		button.pressed.connect(func():
			controller.equip_power(_power_target_slot, power)
			_refresh_power_panel()
		)
		power_list.add_child(button)

func _power_summary(power: AbilityDefinition) -> String:
	match power.power_kind:
		&"event_horizon":
			return "Aim ahead. Pull enemies in, then collapse the singularity."
		&"astral_lance":
			return "Aim a piercing beam. Fires after a 0.5s charge."
		&"chronostasis":
			return "Freeze enemies around you, then shatter the time field."
	return power.description

func _style_power_button(button: Button, accent: Color, selected: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		var highlighted: bool = selected or state != "normal"
		style.bg_color = Color(0.065, 0.082, 0.12).lerp(Color(accent, 1.0), 0.14 if highlighted else 0.035)
		style.border_color = Color(accent, 0.8 if highlighted else 0.22)
		style.set_border_width_all(1)
		style.border_width_left = 3
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)
