# hud.gd
extends CanvasLayer

@onready var health_bar = $Control/HealthBar
@onready var mana_bar   = $Control/ManaBar
@onready var gold_label = $Control/GoldLabel
@onready var gems_label = $Control/GemsLabel

func _ready() -> void:
	# Connect signals
	GameState.stats_changed.connect(_update_stats)
	GameState.gold_changed.connect(_update_currency)
	GameState.gems_changed.connect(_update_currency)

	# Refresh after local save data has loaded.
	SaveManager.load_completed.connect(_on_loaded)

	_update_stats()
	_update_currency()

func _on_loaded(_success: bool) -> void:
	_update_stats()
	_update_currency()

func _update_stats() -> void:
	if health_bar:
		health_bar.max_value = GameState.max_hp
		health_bar.value     = GameState.hp
	if mana_bar:
		mana_bar.max_value = GameState.max_mana
		mana_bar.value     = GameState.mana

func _update_currency() -> void:
	if gold_label:
		gold_label.text = "🪙 %d" % int(GameState.gold)
	if gems_label:
		gems_label.text = "💎 %d" % int(GameState.gems)
