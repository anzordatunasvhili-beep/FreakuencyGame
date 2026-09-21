class_name MobHealthBar
extends Control

@onready var bar: ProgressBar = $Bar
@onready var name_label: Label = $Name

func setup(display_name: String, current: int, maximum: int) -> void:
	name_label.text = display_name
	set_health(current, maximum)

func set_health(current: int, maximum: int) -> void:
	bar.max_value = maximum
	bar.value = current
	visible = current > 0

