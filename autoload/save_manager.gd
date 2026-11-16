extends Node

signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)
signal save_deleted(slot: int)

var max_save_slots: int = 5
var current_slot: int = 1
var auto_save_interval: float = 300.0
var auto_save_timer: float = 0.0
var save_version: int = 1

static var instance: SaveManager = null

func _ready() -> void:
	instance = self

func _process(delta: float) -> void:
	if GameManager and GameManager.get_game_state() == GameManager.GameState.PLAYING:
		auto_save_timer += delta
		if auto_save_timer >= auto_save_interval:
			auto_save()
			auto_save_timer = 0.0

func auto_save() -> void:
	if GameManager:
		save_game(GameManager.save_slot, true)

func save_game(slot: int, is_auto: bool = false) -> bool:
	if slot < 1 or slot > max_save_slots:
		push_error("Invalid save slot: ", slot)
		return false

	var save_data = _collect_save_data()
	save_data["slot"] = slot
	save_data["is_auto"] = is_auto
	save_data["timestamp"] = Time.get_unix_time_from_system()
	save_data["version"] = save_version
	save_data["playtime"] = _get_total_playtime()

	var file = FileAccess.open("user://save_slot_%d.save" % slot, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file for writing")
		save_completed.emit(slot, false)
		return false

	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()

	save_completed.emit(slot, true)
	return true

func load_game(slot: int) -> bool:
	if slot < 1 or slot > max_save_slots:
		push_error("Invalid save slot: ", slot)
		return false

	var file = FileAccess.open("user://save_slot_%d.save" % slot, FileAccess.READ)
	if not file:
		push_error("Save file not found: slot %d" % slot)
		load_completed.emit(slot, false)
		return false

	var json_string = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(json_string)
	if parse_result.error != OK:
		push_error("Failed to parse save file: ", parse_result.error_string)
		load_completed.emit(slot, false)
		return false

	var save_data = parse_result.value
	if not _validate_save_data(save_data):
		push_error("Invalid save data format")
		load_completed.emit(slot, false)
		return false

	_apply_save_data(save_data)
	current_slot = slot
	if GameManager:
		GameManager.save_slot = slot

	load_completed.emit(slot, true)
	return true

func delete_save(slot: int) -> bool:
	if slot < 1 or slot > max_save_slots:
		return false

	var file_path = "user://save_slot_%d.save" % slot
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		save_deleted.emit(slot)
		return true
	return false

func get_save_info(slot: int) -> Dictionary:
	if slot < 1 or slot > max_save_slots:
		return {}

	var file_path = "user://save_slot_%d.save" % slot
	if not FileAccess.file_exists(file_path):
		return {"empty": true}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {"empty": true, "error": "Cannot read file"}

	var json_string = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(json_string)
	if parse_result.error != OK:
		return {"empty": true, "error": "Corrupted save"}

	var data = parse_result.value
	return {
		"empty": false,
		"slot": data.get("slot", slot),
		"timestamp": data.get("timestamp", 0),
		"playtime": data.get("playtime", 0),
		"money": data.get("player_data", {}).get("money", 0),
		"position": data.get("player_data", {}).get("position", Vector3.ZERO),
		"wanted_level": data.get("player_data", {}).get("wanted_level", 0),
		"current_mission": data.get("player_data", {}).get("current_mission", ""),
		"is_auto": data.get("is_auto", false),
		"version": data.get("version", 0)
	}

func has_save(slot: int) -> bool:
	return FileAccess.file_exists("user://save_slot_%d.save" % slot)

func _collect_save_data() -> Dictionary:
	var data = {
		"player_data": {},
		"world_data": {},
		"vehicle_data": {},
		"mission_data": {},
		"police_data": {},
		"inventory_data": {},
		"settings_data": {}
	}

	if GameManager:
		data["player_data"] = {
			"money": GameManager.get_money(),
			"wanted_level": GameManager.get_wanted_level(),
			"current_mission": GameManager.get_current_mission(),
			"graphics_quality": GameManager.get_graphics_quality()
		}

		if GameManager.get_player():
			var player = GameManager.get_player()
			data["player_data"]["position"] = player.global_position
			data["player_data"]["rotation"] = player.global_rotation
			if player.has_method("get_health"):
				data["player_data"]["health"] = player.get_health()
			if player.has_method("get_armor"):
				data["player_data"]["armor"] = player.get_armor()

	if WorldManager:
		data["world_data"] = {
			"time_of_day": WorldManager.get_time_of_day(),
			"weather": WorldManager.get_current_weather(),
			"unlocked_areas": WorldManager.get_unlocked_areas()
		}

	if VehicleManager:
		data["vehicle_data"] = VehicleManager.get_save_data()

	if MissionManager:
		data["mission_data"] = MissionManager.get_save_data()

	if PoliceManager:
		data["police_data"] = PoliceManager.get_save_data()

	return data

func _apply_save_data(data: Dictionary) -> void:
	if GameManager and data.has("player_data"):
		var player_data = data["player_data"]
		GameManager.money = player_data.get("money", 5000)
		GameManager.set_wanted_level(player_data.get("wanted_level", 0))

		if player_data.has("current_mission") and player_data["current_mission"] != "":
			GameManager.current_mission = player_data["current_mission"]

		if player_data.has("graphics_quality"):
			GameManager.set_graphics_quality(player_data["graphics_quality"])

		if GameManager.get_player() and player_data.has("position"):
			var player = GameManager.get_player()
			player.global_position = player_data["position"]
			if player_data.has("rotation"):
				player.global_rotation = player_data["rotation"]
			if player.has_method("set_health") and player_data.has("health"):
				player.set_health(player_data["health"])
			if player.has_method("set_armor") and player_data.has("armor"):
				player.set_armor(player_data["armor"])

	if WorldManager and data.has("world_data"):
		var world_data = data["world_data"]
		if world_data.has("time_of_day"):
			WorldManager.set_time_of_day(world_data["time_of_day"])
		if world_data.has("weather"):
			WorldManager.set_weather(world_data["weather"])
		if world_data.has("unlocked_areas"):
			WorldManager.set_unlocked_areas(world_data["unlocked_areas"])

	if VehicleManager and data.has("vehicle_data"):
		VehicleManager.apply_save_data(data["vehicle_data"])

	if MissionManager and data.has("mission_data"):
		MissionManager.apply_save_data(data["mission_data"])

	if PoliceManager and data.has("police_data"):
		PoliceManager.apply_save_data(data["police_data"])

func _validate_save_data(data: Dictionary) -> bool:
	if not data.has("version") or not data.has("slot"):
		return false
	if data["version"] > save_version:
		push_warning("Save version newer than game version")
		return false
	return true

func _get_total_playtime() -> float:
	if GameManager and GameManager.has_method("get_playtime"):
		return GameManager.get_playtime()
	return 0.0

func get_max_slots() -> int:
	return max_save_slots

func get_current_slot() -> int:
	return current_slot