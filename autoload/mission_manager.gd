extends Node

signal mission_started(mission_id: String)
signal mission_updated(mission_id: String, progress: float)
signal mission_completed(mission_id: String, rewards: Dictionary)
signal mission_failed(mission_id: String, reason: String)
signal objective_completed(mission_id: String, objective_id: String)

enum MissionType {
	STORY,
	DELIVERY,
	RACE,
	DRIVING_CHALLENGE,
	EXPLORATION,
	COMBAT,
	ASSASSINATION,
	HEIST,
	SIDE_QUEST
}

enum MissionStatus {
	LOCKED,
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	FAILED
}

var missions: Dictionary = {}
var active_mission: String = ""
var completed_missions: Array[String] = []
var failed_missions: Array[String] = []
var mission_progress: Dictionary = {}

static var instance: MissionManager = null

func _ready() -> void:
	instance = self
	_register_missions()

func _register_missions() -> void:
	_add_mission("story_01", {
		"id": "story_01",
		"name": "Welcome to the City",
		"type": MissionType.STORY,
		"description": "Meet your contact at the downtown café.",
		"level_required": 1,
		"rewards": {"money": 500, "xp": 100, "unlock": "downtown"},
		"objectives": [
			{"id": "obj_1", "description": "Go to the downtown café", "type": "goto", "target": "downtown_cafe", "position": Vector3(100, 0, 50), "radius": 5.0},
			{"id": "obj_2", "description": "Talk to the contact", "type": "interact", "target": "contact_npc"},
			{"id": "obj_3", "description": "Drive to the safehouse", "type": "drive", "target": "safehouse", "position": Vector3(-200, 0, -100), "radius": 10.0},
		]
	})

	_add_mission("delivery_01", {
		"id": "delivery_01",
		"name": "Package Delivery",
		"type": MissionType.DELIVERY,
		"description": "Deliver a package to the industrial district.",
		"level_required": 1,
		"rewards": {"money": 300, "xp": 50},
		"repeatable": true,
		"cooldown": 300,
		"objectives": [
			{"id": "obj_1", "description": "Pick up the package", "type": "pickup", "target": "package_spawn", "position": Vector3(150, 0, 200)},
			{"id": "obj_2", "description": "Deliver to the warehouse", "type": "dropoff", "target": "warehouse", "position": Vector3(-300, 0, -400), "radius": 10.0},
		]
	})

	_add_mission("race_01", {
		"id": "race_01",
		"name": "Downtown Sprint",
		"type": MissionType.RACE,
		"description": "Race through downtown checkpoints.",
		"level_required": 2,
		"rewards": {"money": 1000, "xp": 200, "vehicle_unlock": "sports_car_01"},
		"objectives": [
			{"id": "obj_1", "description": "Reach checkpoint 1", "type": "checkpoint", "position": Vector3(200, 0, 100), "radius": 15.0, "order": 1},
			{"id": "obj_2", "description": "Reach checkpoint 2", "type": "checkpoint", "position": Vector3(400, 0, -50), "radius": 15.0, "order": 2},
			{"id": "obj_3", "description": "Reach checkpoint 3", "type": "checkpoint", "position": Vector3(300, 0, -200), "radius": 15.0, "order": 3},
			{"id": "obj_4", "description": "Finish line", "type": "checkpoint", "position": Vector3(100, 0, 50), "radius": 15.0, "order": 4},
		],
		"time_limit": 180.0
	})

	_add_mission("driving_01", {
		"id": "driving_01",
		"name": "Precision Driving",
		"type": MissionType.DRIVING_CHALLENGE,
		"description": "Complete the driving course without hitting cones.",
		"level_required": 2,
		"rewards": {"money": 800, "xp": 150},
		"objectives": [
			{"id": "obj_1", "description": "Start the course", "type": "trigger", "target": "driving_course_start"},
			{"id": "obj_2", "description": "Complete slalom", "type": "checkpoint", "position": Vector3(0, 0, 100), "radius": 5.0},
			{"id": "obj_3", "description": "Park in the garage", "type": "park", "position": Vector3(0, 0, 200), "rotation": 0, "tolerance": 2.0},
		],
		"max_collisions": 3
	})

	_add_mission("exploration_01", {
		"id": "exploration_01",
		"name": "City Explorer",
		"description": "Discover 5 landmarks in the city.",
		"type": MissionType.EXPLORATION,
		"level_required": 1,
		"rewards": {"money": 500, "xp": 100, "unlock": "map_fast_travel"},
		"objectives": [
			{"id": "obj_1", "description": "Visit City Hall", "type": "discover", "target": "city_hall", "position": Vector3(0, 0, 0), "radius": 20.0},
			{"id": "obj_2", "description": "Visit the Beach", "type": "discover", "target": "beach", "position": Vector3(500, 0, 500), "radius": 30.0},
			{"id": "obj_3", "description": "Visit the Airport", "type": "discover", "target": "airport", "position": Vector3(-500, 0, -500), "radius": 50.0},
			{"id": "obj_4", "description": "Visit the Harbor", "type": "discover", "target": "harbor", "position": Vector3(500, 0, -500), "radius": 40.0},
			{"id": "obj_5", "description": "Visit the Observatory", "type": "discover", "target": "observatory", "position": Vector3(-300, 100, 300), "radius": 15.0},
		]
	})

	_add_mission("combat_01", {
		"id": "combat_01",
		"name": "Gang Territory",
		"type": MissionType.COMBAT,
		"description": "Clear out the gang from the warehouse district.",
		"level_required": 3,
		"rewards": {"money": 1500, "xp": 300, "weapon_unlock": "assault_rifle"},
		"objectives": [
			{"id": "obj_1", "description": "Enter the warehouse district", "type": "goto", "target": "warehouse_district", "position": Vector3(-400, 0, -200), "radius": 30.0},
			{"id": "obj_2", "description": "Eliminate all gang members", "type": "kill", "target": "gang_member", "count": 10},
			{"id": "obj_3", "description": "Destroy the drug stash", "type": "destroy", "target": "drug_stash", "count": 3},
		]
	})

func _add_mission(id: String, data: Dictionary) -> void:
	data["status"] = MissionStatus.AVAILABLE if data.get("level_required", 1) <= 1 else MissionStatus.LOCKED
	data["current_objective"] = 0
	data["objective_progress"] = {}
	missions[id] = data

func start_mission(mission_id: String) -> bool:
	if not missions.has(mission_id):
		return false

	var mission = missions[mission_id]
	if mission["status"] == MissionStatus.COMPLETED and not mission.get("repeatable", false):
		return false
	if mission["status"] == MissionStatus.FAILED and mission.get("cooldown", 0) > 0:
		return false
	if mission["status"] == MissionStatus.LOCKED:
		return false

	mission["status"] = MissionStatus.ACTIVE
	mission["current_objective"] = 0
	mission["objective_progress"] = {}
	mission["start_time"] = Time.get_unix_time_from_system()
	active_mission = mission_id

	for obj in mission["objectives"]:
		mission["objective_progress"][obj["id"]] = 0.0

	mission_started.emit(mission_id)
	UIManager.show_mission_text("Mission Started: %s" % mission["name"])
	return true

func update_mission_progress(mission_id: String, objective_id: String, progress: float = 1.0) -> void:
	if not missions.has(mission_id) or active_mission != mission_id:
		return

	var mission = missions[mission_id]
	if mission["status"] != MissionStatus.ACTIVE:
		return

	if not mission["objective_progress"].has(objective_id):
		return

	mission["objective_progress"][objective_id] = min(mission["objective_progress"][objective_id] + progress, 1.0)

	var current_obj = mission["objectives"][mission["current_objective"]]
	if current_obj["id"] == objective_id and mission["objective_progress"][objective_id] >= 1.0:
		_complete_objective(mission_id, objective_id)

	var total_progress = 0.0
	for obj in mission["objectives"]:
		total_progress += mission["objective_progress"][obj["id"]]
	total_progress /= mission["objectives"].size()

	mission_updated.emit(mission_id, total_progress)

func _complete_objective(mission_id: String, objective_id: String) -> void:
	var mission = missions[mission_id]
	objective_completed.emit(mission_id, objective_id)
	UIManager.show_notification("Objective Complete: %s" % _get_objective_description(mission, objective_id), "success")

	mission["current_objective"] += 1

	if mission["current_objective"] >= mission["objectives"].size():
		_complete_mission(mission_id)
	else:
		var next_obj = mission["objectives"][mission["current_objective"]]
		UIManager.show_mission_text("New Objective: %s" % next_obj["description"])

func _get_objective_description(mission: Dictionary, objective_id: String) -> String:
	for obj in mission["objectives"]:
		if obj["id"] == objective_id:
			return obj["description"]
	return objective_id

func _complete_mission(mission_id: String) -> void:
	var mission = missions[mission_id]
	mission["status"] = MissionStatus.COMPLETED

	if mission_id not in completed_missions:
		completed_missions.append(mission_id)

	var rewards = mission.get("rewards", {})
	if rewards.has("money") and GameManager:
		GameManager.add_money(rewards["money"])
	if rewards.has("unlock") and WorldManager:
		WorldManager.unlock_area(rewards["unlock"])
	if rewards.has("vehicle_unlock") and VehicleManager:
		VehicleManager.unlock_vehicle(rewards["vehicle_unlock"])
	if rewards.has("weapon_unlock"):
		_unlock_weapon(rewards["weapon_unlock"])

	active_mission = ""
	mission_completed.emit(mission_id, rewards)
	UIManager.show_notification("Mission Complete: %s" % mission["name"], "success", 5.0)
	_save_mission_progress()

func fail_mission(mission_id: String, reason: String = "Mission failed") -> void:
	if not missions.has(mission_id):
		return

	var mission = missions[mission_id]
	mission["status"] = MissionStatus.FAILED

	if mission_id not in failed_missions:
		failed_missions.append(mission_id)

	if mission.get("cooldown", 0) > 0:
		mission["cooldown_timer"] = mission["cooldown"]

	active_mission = ""
	mission_failed.emit(mission_id, reason)
	UIManager.show_notification("Mission Failed: %s" % reason, "error", 5.0)
	_save_mission_progress()

func _unlock_weapon(weapon_id: String) -> void:
	if GameManager and GameManager.get_player() and GameManager.get_player().has_method("unlock_weapon"):
		GameManager.get_player().unlock_weapon(weapon_id)

func get_mission(mission_id: String) -> Dictionary:
	return missions.get(mission_id, {})

func get_active_mission() -> String:
	return active_mission

func get_available_missions() -> Array[Dictionary]:
	var available = []
	for mission in missions.values():
		if mission["status"] == MissionStatus.AVAILABLE:
			available.append(mission)
	return available

func get_completed_missions() -> Array[String]:
	return completed_missions

func is_mission_completed(mission_id: String) -> bool:
	return mission_id in completed_missions

func is_mission_active(mission_id: String) -> bool:
	return active_mission == mission_id

func get_mission_progress(mission_id: String) -> float:
	if not missions.has(mission_id):
		return 0.0

	var mission = missions[mission_id]
	var total = 0.0
	for obj in mission["objectives"]:
		total += mission["objective_progress"].get(obj["id"], 0.0)
	return total / mission["objectives"].size() if mission["objectives"].size() > 0 else 0.0

func get_objective_progress(mission_id: String, objective_id: String) -> float:
	if not missions.has(mission_id):
		return 0.0
	return missions[mission_id]["objective_progress"].get(objective_id, 0.0)

func get_current_objective(mission_id: String) -> Dictionary:
	if not missions.has(mission_id):
		return {}

	var mission = missions[mission_id]
	if mission["current_objective"] < mission["objectives"].size():
		return mission["objectives"][mission["current_objective"]]
	return {}

func check_proximity_objectives(player_position: Vector3) -> void:
	if active_mission == "":
		return

	var mission = missions[active_mission]
	var current_obj = mission["objectives"][mission["current_objective"]]

	if current_obj["type"] in ["goto", "checkpoint", "discover", "dropoff"]:
		var target_pos = current_obj["position"]
		var radius = current_obj.get("radius", 5.0)
		var distance = player_position.distance_to(target_pos)

		if distance <= radius:
			update_mission_progress(active_mission, current_obj["id"])

func check_interaction(target: String) -> void:
	if active_mission == "":
		return

	var mission = missions[active_mission]
	var current_obj = mission["objectives"][mission["current_objective"]]

	if current_obj["type"] == "interact" and current_obj["target"] == target:
		update_mission_progress(active_mission, current_obj["id"])
	elif current_obj["type"] == "pickup" and current_obj["target"] == target:
		update_mission_progress(active_mission, current_obj["id"])

func check_kill(target_type: String) -> void:
	if active_mission == "":
		return

	var mission = missions[active_mission]
	var current_obj = mission["objectives"][mission["current_objective"]]

	if current_obj["type"] == "kill" and current_obj["target"] == target_type:
		var progress = mission["objective_progress"][current_obj["id"]]
		var target_count = current_obj.get("count", 1)
		var new_progress = (progress * target_count + 1) / target_count
		update_mission_progress(active_mission, current_obj["id"], new_progress - progress)

func check_destroy(target_type: String) -> void:
	if active_mission == "":
		return

	var mission = missions[active_mission]
	var current_obj = mission["objectives"][mission["current_objective"]]

	if current_obj["type"] == "destroy" and current_obj["target"] == target_type:
		var progress = mission["objective_progress"][current_obj["id"]]
		var target_count = current_obj.get("count", 1)
		var new_progress = (progress * target_count + 1) / target_count
		update_mission_progress(active_mission, current_obj["id"], new_progress - progress)

func check_vehicle_enter(vehicle_id: String) -> void:
	if active_mission == "":
		return

	var mission = missions[active_mission]
	var current_obj = mission["objectives"][mission["current_objective"]]

	if current_obj["type"] == "drive" and current_obj["target"] == vehicle_id:
		update_mission_progress(active_mission, current_obj["id"])

func check_parking(position: Vector3, rotation: float) -> void:
	if active_mission == "":
		return

	var mission = missions[active_mission]
	var current_obj = mission["objectives"][mission["current_objective"]]

	if current_obj["type"] == "park":
		var target_pos = current_obj["position"]
		var target_rot = current_obj.get("rotation", 0)
		var tolerance = current_obj.get("tolerance", 2.0)
		var rot_tolerance = current_obj.get("rotation_tolerance", 0.2)

		var dist = position.distance_to(target_pos)
		var rot_diff = abs(wrapf(rotation - target_rot, -PI, PI))

		if dist <= tolerance and rot_diff <= rot_tolerance:
			update_mission_progress(active_mission, current_obj["id"])

func check_collision() -> void:
	if active_mission == "":
		return

	var mission = missions[active_mission]
	var current_obj = mission["objectives"][mission["current_objective"]]

	if current_obj["type"] == "drive" and current_obj.has("max_collisions"):
		var collisions = mission.get("collision_count", 0) + 1
		mission["collision_count"] = collisions

		if collisions >= current_obj["max_collisions"]:
			fail_mission(active_mission, "Too many collisions")
		else:
			UIManager.show_notification("Collision! %d/%d allowed" % [collisions, current_obj["max_collisions"]], "warning")

func get_save_data() -> Dictionary:
	return {
		"completed_missions": completed_missions,
		"failed_missions": failed_missions,
		"active_mission": active_mission,
		"mission_data": missions
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("completed_missions"):
		completed_missions = data["completed_missions"]
	if data.has("failed_missions"):
		failed_missions = data["failed_missions"]
	if data.has("active_mission"):
		active_mission = data["active_mission"]
	if data.has("mission_data"):
		for id in data["mission_data"]:
			var mission_data = data["mission_data"][id]
			if missions.has(id):
				missions[id]["status"] = mission_data.get("status", missions[id]["status"])
				missions[id]["current_objective"] = mission_data.get("current_objective", 0)
				missions[id]["objective_progress"] = mission_data.get("objective_progress", {})
				missions[id]["collision_count"] = mission_data.get("collision_count", 0)

func _save_mission_progress() -> void:
	var config = ConfigFile.new()
	config.set_value("missions", "completed", completed_missions)
	config.set_value("missions", "failed", failed_missions)
	config.set_value("missions", "active", active_mission)

	var mission_data = {}
	for id in missions:
		var mission = missions[id]
		mission_data[id] = {
			"status": mission["status"],
			"current_objective": mission["current_objective"],
			"objective_progress": mission["objective_progress"],
			"collision_count": mission.get("collision_count", 0)
		}
	config.set_value("missions", "data", mission_data)
	config.save("user://mission_progress.cfg")

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		_save_mission_progress()