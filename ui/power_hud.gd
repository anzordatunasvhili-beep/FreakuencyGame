extends CanvasLayer
## A separate canvas keeps power readiness visible without moving the item hotbar.

const LEGACY_ACCENTS := {
	&"ember_nova": Color(1.0, 0.48, 0.24),
	&"arc_storm": Color(0.53, 0.69, 1.0),
	&"void_bloom": Color(0.79, 0.48, 1.0),
	&"glacial_halo": Color(0.48, 0.88, 1.0),
	&"solar_spear": Color(1.0, 0.81, 0.34),
	&"spirit_pulse": Color(0.45, 1.0, 0.73),
}

var _controller: AbilityController
var _cards: Array[PanelContainer] = []
var _names: Array[Label] = []
var _states: Array[Label] = []
var _meters: Array[ProgressBar] = []
var _flashes: Array[float] = [0.0, 0.0]

func _ready() -> void:
	_controller = get_parent().get_node_or_null("AbilityController") as AbilityController
	if _controller == null:
		hide()
		return
	_build_hud()
	_controller.power_equipped.connect(_on_power_equipped)
	_controller.ability_cast.connect(_on_ability_cast)
	_refresh_loadout()

func _build_hud() -> void:
	var root := VBoxContainer.new()
	root.name = "PowerReadiness"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	root.offset_left = -354.0
	root.offset_top = 18.0
	root.offset_right = -18.0
	root.add_theme_constant_override("separation", 6)
	var slots := HBoxContainer.new()
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots.add_theme_constant_override("separation", 8)
	root.add_child(slots)
	for index in 2:
		var card := PanelContainer.new()
		card.name = "Q" if index == 0 else "R"
		card.custom_minimum_size = Vector2(164, 68)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		slots.add_child(card)
		_cards.append(card)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 3)
		card.add_child(content)
		var heading := HBoxContainer.new()
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_theme_constant_override("separation", 8)
		content.add_child(heading)
		var key := Label.new()
		key.text = "Q" if index == 0 else "R"
		key.add_theme_font_size_override("font_size", 17)
		key.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
		heading.add_child(key)
		var title := Label.new()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_theme_font_size_override("font_size", 13)
		heading.add_child(title)
		_names.append(title)
		var state := Label.new()
		state.add_theme_font_size_override("font_size", 10)
		content.add_child(state)
		_states.append(state)
		var meter := ProgressBar.new()
		meter.custom_minimum_size.y = 3.0
		meter.max_value = 1.0
		meter.show_percentage = false
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.2, 0.23, 0.31, 0.8)
		background.set_corner_radius_all(2)
		meter.add_theme_stylebox_override("background", background)
		content.add_child(meter)
		_meters.append(meter)
	var hint := Label.new()
	hint.text = "AIM WITH MOUSE   /   I  EQUIP POWERS"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.72, 0.79, 0.87))
	root.add_child(hint)

func _process(delta: float) -> void:
	if not is_instance_valid(_controller):
		return
	for index in mini(2, _controller.equipped_powers.size()):
		var ability := _controller.equipped_powers[index]
		if ability == null:
			continue
		var remaining := _controller.cooldown_remaining(ability)
		var ready := remaining <= 0.0
		_meters[index].value = 1.0 - _controller.cooldown_fraction(ability)
		_states[index].text = "READY" if ready else "RECHARGING  %.1fs" % remaining
		_states[index].modulate.a = 1.0 if ready else 0.7
		_flashes[index] = maxf(0.0, _flashes[index] - delta * 2.5)
		_cards[index].self_modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.45, 1.45, 1.45), _flashes[index])

func _refresh_loadout() -> void:
	for index in mini(2, _controller.equipped_powers.size()):
		var ability := _controller.equipped_powers[index]
		if ability == null:
			_names[index].text = "No power"
			continue
		var accent: Color = LEGACY_ACCENTS.get(ability.ability_id, ability.accent_color)
		_names[index].text = ability.display_name
		_names[index].add_theme_color_override("font_color", accent)
		_states[index].add_theme_color_override("font_color", accent)
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.035, 0.045, 0.075, 0.92)
		panel.border_color = Color(accent, 0.65)
		panel.set_border_width_all(1)
		panel.border_width_top = 2
		panel.set_corner_radius_all(7)
		panel.content_margin_left = 12
		panel.content_margin_right = 12
		panel.content_margin_top = 7
		panel.content_margin_bottom = 9
		_cards[index].add_theme_stylebox_override("panel", panel)
		var fill := StyleBoxFlat.new()
		fill.bg_color = accent
		fill.set_corner_radius_all(2)
		_meters[index].add_theme_stylebox_override("fill", fill)
		_cards[index].tooltip_text = "%s\n%s\n%d damage / %.1fs cooldown\nPress I to change your loadout." % [ability.display_name, ability.description, ability.damage, ability.cooldown]

func _on_power_equipped(_slot: int, _ability: AbilityDefinition) -> void:
	_refresh_loadout()

func _on_ability_cast(ability: AbilityDefinition) -> void:
	for index in mini(2, _controller.equipped_powers.size()):
		if _controller.equipped_powers[index] == ability:
			_flashes[index] = 1.0
