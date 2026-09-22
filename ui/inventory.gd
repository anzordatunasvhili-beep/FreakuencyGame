extends Control

@onready var grid: GridContainer = $ScrollContainer/GridContainer
@onready var item_blueprint: PanelContainer = $Blueprint
@onready var power_q_button: Button = $PowerPanel/Equipped/QSlot
@onready var power_r_button: Button = $PowerPanel/Equipped/RSlot
@onready var power_list: VBoxContainer = $PowerPanel/PowerList

var _is_open := false
var _power_target_slot := 0

func _ready() -> void:
	hide()
	GameState.inventory_changed.connect(_refresh)
	power_q_button.pressed.connect(func(): _select_power_slot(0))
	power_r_button.pressed.connect(func(): _select_power_slot(1))
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_is_open = not _is_open
		visible = _is_open
		if _is_open:
			_refresh()

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
	power_q_button.text = "Q: %s%s" % [controller.equipped_powers[0].display_name, "  <" if _power_target_slot == 0 else ""]
	power_r_button.text = "R: %s%s" % [controller.equipped_powers[1].display_name, "  <" if _power_target_slot == 1 else ""]
	for child in power_list.get_children():
		child.queue_free()
	for power in controller.power_library:
		var button := Button.new()
		button.text = "%s  |  DMG %d  CD %.1fs" % [power.display_name, power.damage, power.cooldown]
		button.tooltip_text = "Range %.0f  Arc %.0f degrees" % [power.range, power.arc_degrees]
		button.pressed.connect(func():
			controller.equip_power(_power_target_slot, power)
			_refresh_power_panel()
		)
		power_list.add_child(button)
