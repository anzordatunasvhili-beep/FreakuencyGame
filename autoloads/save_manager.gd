# save_manager.gd
# Autoload as "SaveManager"
extends Node

const SAVE_PATH := "user://save_slot_%d.json"
const AUTO_SAVE_INTERVAL := 60.0   # seconds

var _auto_save_timer := 0.0

signal save_completed
signal load_completed(success: bool)

# ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_local(0)   # slot 0 = auto save

# ── Local save (JSON file on disk) ───────────────────────────

func save_local(slot: int = 1) -> void:
	var data := _build_save_data()
	var path := SAVE_PATH % slot
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open file for writing: " + path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("SaveManager: saved to slot %d" % slot)
	save_completed.emit()

func load_local(slot: int = 1) -> bool:
	var path := SAVE_PATH % slot
	if not FileAccess.file_exists(path):
		print("SaveManager: no save file at slot %d" % slot)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var raw := file.get_as_text()
	file.close()
	var data = JSON.parse_string(raw)
	if data == null:
		push_error("SaveManager: corrupt save file at slot %d" % slot)
		return false
	_apply_save_data(data)
	load_completed.emit(true)
	print("SaveManager: loaded slot %d" % slot)
	return true

func delete_local(slot: int) -> void:
	var path := SAVE_PATH % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func get_save_info(slot: int) -> Dictionary:
	var path := SAVE_PATH % slot
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return {}
	return {
		"slot": slot,
		"player_name": data.get("player_name", "Unknown"),
		"level": data.get("level", 1),
		"timestamp": data.get("timestamp", ""),
		"map": data.get("last_map", "main"),
	}

# ── Helpers ───────────────────────────────────────────────────

func _build_save_data() -> Dictionary:
	var data := GameState.to_dict()
	data["timestamp"] = Time.get_datetime_string_from_system()
	return data

func _apply_save_data(data: Dictionary) -> void:
	GameState.from_dict(data)
