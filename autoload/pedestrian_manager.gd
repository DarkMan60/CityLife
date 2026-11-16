extends Node

signal pedestrian_spawned(pedestrian: Node3D)
signal pedestrian_despawned(pedestrian: Node3D)
signal pedestrian_fleeing(pedestrian: Node3D, threat_position: Vector3)

enum PedestrianType {
	CITIZEN = 0,
	BUSINESS = 1,
	GANG = 2,
	POLICE = 3,
	MEDIC = 4,
	FIREFIGHTER = 5,
	CONSTRUCTION = 6,
	HOMELESS = 7,
	TOURIST = 8,
	STUDENT = 9
}

enum PedestrianState {
	IDLE,
	WALKING,
	RUNNING,
	FLEEING,
	FIGHTING,
	DEAD,
	IN_VEHICLE,
	TALKING,
	USING_PHONE,
	SITTING,
	WORKING
}

var max_pedestrians: int = 100
var active_pedestrians: Array[Node3D] = []
var pedestrian_definitions: Dictionary = {}
var spawn_zones: Array[Dictionary] = []
var despawn_distance: float = 150.0
var spawn_distance: float = 100.0
var spawn_timer: float = 0.0
var spawn_interval: float = 2.0
var group_behavior_enabled: bool = true

static var instance: PedestrianManager = null

var pedestrian_scenes: Dictionary = {}
var behavior_trees: Dictionary = {}

func _ready() -> void:
	instance = self
	_register_pedestrian_definitions()
	_preload_pedestrian_scenes()
	_define_spawn_zones()

func _register_pedestrian_definitions() -> void:
	pedestrian_definitions = {
		"citizen_male_01": {
			"id": "citizen_male_01",
			"type": PedestrianType.CITIZEN,
			"gender": "male",
			"model": "res://assets/models/pedestrians/citizen_male_01.glb",
			"animations": ["idle", "walk", "run", "flee", "talk", "phone", "sit"],
			"voice": "male_01",
			"clothing_variants": 5,
			"spawn_weight": 30,
			"behavior": "civilian",
			"fear_level": 0.3,
			"aggression": 0.1,
			"group_chance": 0.2
		},
		"citizen_female_01": {
			"id": "citizen_female_01",
			"type": PedestrianType.CITIZEN,
			"gender": "female",
			"model": "res://assets/models/pedestrians/citizen_female_01.glb",
			"animations": ["idle", "walk", "run", "flee", "talk", "phone", "sit"],
			"voice": "female_01",
			"clothing_variants": 5,
			"spawn_weight": 30,
			"behavior": "civilian",
			"fear_level": 0.4,
			"aggression": 0.05,
			"group_chance": 0.25
		},
		"business_male_01": {
			"id": "business_male_01",
			"type": PedestrianType.BUSINESS,
			"gender": "male",
			"model": "res://assets/models/pedestrians/business_male_01.glb",
			"animations": ["idle", "walk", "run", "flee", "talk", "phone"],
			"voice": "male_02",
			"clothing_variants": 3,
			"spawn_weight": 15,
			"behavior": "business",
			"fear_level": 0.35,
			"aggression": 0.1,
			"group_chance": 0.15
		},
		"business_female_01": {
			"id": "business_female_01",
			"type": PedestrianType.BUSINESS,
			"gender": "female",
			"model": "res://assets/models/pedestrians/business_female_01.glb",
			"animations": ["idle", "walk", "run", "flee", "talk", "phone"],
			"voice": "female_02",
			"clothing_variants": 3,
			"spawn_weight": 15,
			"behavior": "business",
			"fear_level": 0.4,
			"aggression": 0.05,
			"group_chance": 0.2
		},
		"gang_member_01": {
			"id": "gang_member_01",
			"type": PedestrianType.GANG,
			"gender": "male",
			"model": "res://assets/models/pedestrians/gang_member_01.glb",
			"animations": ["idle", "walk", "run", "flee", "fight", "aim", "shoot", "cover"],
			"voice": "male_03",
			"clothing_variants": 4,
			"spawn_weight": 5,
			"behavior": "gang",
			"fear_level": 0.1,
			"aggression": 0.7,
			"group_chance": 0.6,
			"weapon_chance": 0.4
		},
		"gang_member_02": {
			"id": "gang_member_02",
			"type": PedestrianType.GANG,
			"gender": "male",
			"model": "res://assets/models/pedestrians/gang_member_02.glb",
			"animations": ["idle", "walk", "run", "flee", "fight", "aim", "shoot", "cover"],
			"voice": "male_04",
			"clothing_variants": 4,
			"spawn_weight": 5,
			"behavior": "gang",
			"fear_level": 0.1,
			"aggression": 0.6,
			"group_chance": 0.5,
			"weapon_chance": 0.3
		},
		"police_officer": {
			"id": "police_officer",
			"type": PedestrianType.POLICE,
			"gender": "male",
			"model": "res://assets/models/pedestrians/police_officer.glb",
			"animations": ["idle", "walk", "run", "aim", "shoot", "arrest", "radio"],
			"voice": "male_05",
			"clothing_variants": 2,
			"spawn_weight": 0,
			"behavior": "police",
			"fear_level": 0.0,
			"aggression": 0.8,
			"group_chance": 0.3
		},
		"medic": {
			"id": "medic",
			"type": PedestrianType.MEDIC,
			"gender": "male",
			"model": "res://assets/models/pedestrians/medic.glb",
			"animations": ["idle", "walk", "run", "heal", "carry"],
			"voice": "male_06",
			"clothing_variants": 1,
			"spawn_weight": 0,
			"behavior": "medic",
			"fear_level": 0.2,
			"aggression": 0.0,
			"group_chance": 0.1
		},
		"construction_worker": {
			"id": "construction_worker",
			"type": PedestrianType.CONSTRUCTION,
			"gender": "male",
			"model": "res://assets/models/pedestrians/construction_worker.glb",
			"animations": ["idle", "walk", "work", "drink", "talk"],
			"voice": "male_07",
			"clothing_variants": 3,
			"spawn_weight": 8,
			"behavior": "worker",
			"fear_level": 0.3,
			"aggression": 0.2,
			"group_chance": 0.3
		},
		"homeless_01": {
			"id": "homeless_01",
			"type": PedestrianType.HOMELESS,
			"gender": "male",
			"model": "res://assets/models/pedestrians/homeless_01.glb",
			"animations": ["idle", "walk", "sit", "sleep", "beg"],
			"voice": "male_08",
			"clothing_variants": 2,
			"spawn_weight": 3,
			"behavior": "homeless",
			"fear_level": 0.5,
			"aggression": 0.1,
			"group_chance": 0.0
		},
		"tourist_01": {
			"id": "tourist_01",
			"type": PedestrianType.TOURIST,
			"gender": "male",
			"model": "res://assets/models/pedestrians/tourist_01.glb",
			"animations": ["idle", "walk", "photo", "map", "talk"],
			"voice": "male_09",
			"clothing_variants": 3,
			"spawn_weight": 5,
			"behavior": "tourist",
			"fear_level": 0.4,
			"aggression": 0.05,
			"group_chance": 0.4
		},
		"student_01": {
			"id": "student_01",
			"type": PedestrianType.STUDENT,
			"gender": "female",
			"model": "res://assets/models/pedestrians/student_01.glb",
			"animations": ["idle", "walk", "run", "phone", "talk", "sit", "study"],
			"voice": "female_03",
			"clothing_variants": 4,
			"spawn_weight": 10,
			"behavior": "student",
			"fear_level": 0.45,
			"aggression": 0.05,
			"group_chance": 0.5
		},
	}

func _preload_pedestrian_scenes() -> void:
	for id in pedestrian_definitions:
		pedestrian_scenes[id] = preload("res://scenes/ai/pedestrian.tscn")

func _define_spawn_zones() -> void:
	spawn_zones = [
		{"name": "downtown", "center": Vector3(0, 0, 0), "radius": 200, "types": ["citizen", "business", "tourist"], "density": 1.0, "time_modifier": {6: 0.3, 9: 1.5, 12: 1.2, 17: 1.5, 22: 0.5}},
		{"name": "residential_north", "center": Vector3(-300, 0, 300), "radius": 150, "types": ["citizen", "student"], "density": 0.8, "time_modifier": {6: 0.2, 8: 1.0, 15: 0.8, 20: 1.2, 23: 0.3}},
		{"name": "residential_south", "center": Vector3(300, 0, -300), "radius": 150, "types": ["citizen", "student"], "density": 0.8, "time_modifier": {6: 0.2, 8: 1.0, 15: 0.8, 20: 1.2, 23: 0.3}},
		{"name": "industrial", "center": Vector3(-400, 0, -200), "radius": 180, "types": ["construction"], "density": 0.6, "time_modifier": {6: 0.5, 8: 1.2, 17: 0.8, 22: 0.1}},
		{"name": "beach", "center": Vector3(500, 0, 500), "radius": 200, "types": ["citizen", "tourist", "homeless"], "density": 0.7, "time_modifier": {8: 0.5, 10: 1.0, 14: 1.5, 18: 1.2, 22: 0.2}},
		{"name": "park", "center": Vector3(-200, 0, 400), "radius": 100, "types": ["citizen", "student", "homeless"], "density": 0.5, "time_modifier": {6: 0.3, 9: 0.8, 12: 1.0, 16: 1.2, 20: 0.6}},
		{"name": "shopping_district", "center": Vector3(200, 0, 100), "radius": 120, "types": ["citizen", "business", "tourist"], "density": 1.2, "time_modifier": {9: 1.0, 12: 1.5, 14: 1.3, 18: 1.5, 21: 0.8}},
		{"name": "gang_territory_north", "center": Vector3(-500, 0, -100), "radius": 150, "types": ["gang"], "density": 0.4, "time_modifier": {0: 1.0, 6: 0.5, 22: 1.2}},
		{"name": "gang_territory_south", "center": Vector3(400, 0, 200), "radius": 150, "types": ["gang"], "density": 0.4, "time_modifier": {0: 1.0, 6: 0.5, 22: 1.2}},
		{"name": "airport", "center": Vector3(-500, 0, -500), "radius": 200, "types": ["citizen", "business", "tourist"], "density": 0.6, "time_modifier": {5: 0.8, 8: 1.2, 12: 1.0, 18: 1.2, 23: 0.5}},
		{"name": "harbor", "center": Vector3(500, 0, -500), "radius": 180, "types": ["citizen", "construction"], "density": 0.5, "time_modifier": {6: 0.8, 10: 1.0, 16: 1.0, 22: 0.3}},
	]

func _process(delta: float) -> void:
	_update_spawning(delta)
	_update_despawning()
	_update_group_behavior(delta)

func _update_spawning(delta: float) -> void:
	if active_pedestrians.size() >= max_pedestrians:
		return

	spawn_timer += delta
	if spawn_timer < spawn_interval:
		return

	spawn_timer = 0.0

	if not GameManager or not GameManager.get_player():
		return

	var player_pos = GameManager.get_player().global_position
	var current_hour = WorldManager.get_time_of_day() if WorldManager else 12.0

	for zone in spawn_zones:
		var dist = zone["center"].distance_to(player_pos)
		if dist > spawn_distance + zone["radius"] or dist < zone["radius"] * 0.3:
			continue

		var time_mult = 1.0
		for hour in zone["time_modifier"]:
			var mult = zone["time_modifier"][hour]
			if current_hour >= hour:
				time_mult = mult

		var spawn_count = int(zone["density"] * time_mult * 2)
		spawn_count = clamp(spawn_count, 0, 5)

		for i in range(spawn_count):
			if active_pedestrians.size() >= max_pedestrians:
				break
			_try_spawn_in_zone(zone, player_pos)

	spawn_interval = randf_range(1.0, 4.0)

func _try_spawn_in_zone(zone: Dictionary, player_pos: Vector3) -> void:
	var valid_types = []
	var total_weight = 0

	for type_name in zone["types"]:
		for id in pedestrian_definitions:
			var def = pedestrian_definitions[id]
			if def["type"] == PedestrianType[type_name]:
				valid_types.append(id)
				total_weight += def["spawn_weight"]

	if valid_types.is_empty() or total_weight == 0:
		return

	var roll = randi() % total_weight
	var cumulative = 0
	var selected_type = ""

	for id in valid_types:
		cumulative += pedestrian_definitions[id]["spawn_weight"]
		if roll < cumulative:
			selected_type = id
			break

	if selected_type == "":
		return

	var angle = randf() * TAU
	var distance = randf_range(zone["radius"] * 0.3, zone["radius"])
	var spawn_pos = zone["center"] + Vector3(cos(angle) * distance, 0, sin(angle) * distance)

	var viewport = get_viewport()
	var result: Dictionary = {}
	if viewport and viewport.world_3d:
		var space_state = viewport.world_3d.direct_space_state
		var query = PhysicsRayQueryParameters3D.create(spawn_pos + Vector3(0, 10, 0), spawn_pos + Vector3(0, -20, 0))
		result = space_state.intersect_ray(query)

	if result:
		spawn_pos = result.position
		_spawn_pedestrian(selected_type, spawn_pos, zone["name"])

func _spawn_pedestrian(type_id: String, position: Vector3, zone: String) -> void:
	var scene = pedestrian_scenes.get(type_id)
	if not scene:
		return

	var def = pedestrian_definitions[type_id]
	var pedestrian = scene.instantiate()
	pedestrian.global_position = position
	pedestrian.global_rotation.y = randf() * TAU
	pedestrian.name = "Pedestrian_%s_%d" % [type_id, active_pedestrians.size()]
	add_child(pedestrian)
	active_pedestrians.append(pedestrian)

	if pedestrian.has_method("initialize"):
		pedestrian.initialize(def, zone)

	pedestrian_spawned.emit(pedestrian)

func _update_despawning() -> void:
	if not GameManager or not GameManager.get_player():
		return

	var player_pos = GameManager.get_player().global_position
	var to_despawn = []

	for pedestrian in active_pedestrians:
		if not pedestrian or not is_instance_valid(pedestrian):
			to_despawn.append(pedestrian)
			continue

		var dist = pedestrian.global_position.distance_to(player_pos)
		if dist > despawn_distance:
			to_despawn.append(pedestrian)

	for pedestrian in to_despawn:
		_despawn_pedestrian(pedestrian)

func _despawn_pedestrian(pedestrian: Node3D) -> void:
	if pedestrian in active_pedestrians:
		active_pedestrians.erase(pedestrian)
		pedestrian_despawned.emit(pedestrian)
		pedestrian.queue_free()

func _update_group_behavior(delta: float) -> void:
	if not group_behavior_enabled:
		return

	var groups = _find_groups()

	for group in groups:
		if group.size() >= 2:
			_apply_group_behavior(group)

func _find_groups() -> Array:
	var groups = []
	var processed = []

	for pedestrian in active_pedestrians:
		if pedestrian in processed:
			continue

		var group = [pedestrian]
		processed.append(pedestrian)

		for other in active_pedestrians:
			if other in processed:
				continue

			var dist = pedestrian.global_position.distance_to(other.global_position)
			if dist < 5.0 and pedestrian.has_method("get_behavior_type") and other.has_method("get_behavior_type"):
				if pedestrian.get_behavior_type() == other.get_behavior_type():
					group.append(other)
					processed.append(other)

		if group.size() >= 2:
			groups.append(group)

	return groups

func _apply_group_behavior(group: Array[Node3D]) -> void:
	var center = Vector3.ZERO
	for p in group:
		center += p.global_position
	center /= group.size()

	for p in group:
		if p.has_method("set_group_target"):
			p.set_group_target(center)

func spawn_pedestrian_at(type_id: String, position: Vector3, zone: String = "") -> Node3D:
	if not pedestrian_definitions.has(type_id):
		return null

	var scene = pedestrian_scenes.get(type_id)
	if not scene:
		return null

	var def = pedestrian_definitions[type_id]
	var pedestrian = scene.instantiate()
	pedestrian.global_position = position
	pedestrian.name = "Pedestrian_%s_%d" % [type_id, active_pedestrians.size()]
	add_child(pedestrian)
	active_pedestrians.append(pedestrian)

	if pedestrian.has_method("initialize"):
		pedestrian.initialize(def, zone)

	pedestrian_spawned.emit(pedestrian)
	return pedestrian

func make_pedestrians_flee(threat_position: Vector3, radius: float = 50.0) -> void:
	for pedestrian in active_pedestrians:
		if pedestrian and is_instance_valid(pedestrian):
			var dist = pedestrian.global_position.distance_to(threat_position)
			if dist <= radius and pedestrian.has_method("flee"):
				pedestrian.flee(threat_position)
				pedestrian_fleeing.emit(pedestrian, threat_position)

func get_pedestrians_in_radius(position: Vector3, radius: float) -> Array[Node3D]:
	var result = []
	for pedestrian in active_pedestrians:
		if pedestrian and is_instance_valid(pedestrian):
			if pedestrian.global_position.distance_to(position) <= radius:
				result.append(pedestrian)
	return result

func get_pedestrian_count() -> int:
	var count = 0
	for p in active_pedestrians:
		if p and is_instance_valid(p):
			count += 1
	return count

func get_pedestrians_by_type(ped_type: PedestrianType) -> Array[Node3D]:
	var result = []
	for pedestrian in active_pedestrians:
		if pedestrian and is_instance_valid(pedestrian) and pedestrian.has_method("get_pedestrian_type"):
			if pedestrian.get_pedestrian_type() == ped_type:
				result.append(pedestrian)
	return result

func clear_all_pedestrians() -> void:
	for pedestrian in active_pedestrians:
		if pedestrian and is_instance_valid(pedestrian):
			pedestrian.queue_free()
	active_pedestrians.clear()

func get_save_data() -> Dictionary:
	var peds_data = []
	for pedestrian in active_pedestrians:
		if pedestrian and is_instance_valid(pedestrian) and pedestrian.has_method("get_save_data"):
			peds_data.append(pedestrian.get_save_data())

	return {
		"active_pedestrians": peds_data
	}

func apply_save_data(data: Dictionary) -> void:
	clear_all_pedestrians()

	if data.has("active_pedestrians"):
		for ped_data in data["active_pedestrians"]:
			var type_id = ped_data.get("type_id", "")
			var position = ped_data.get("position", Vector3.ZERO)
			var zone = ped_data.get("zone", "")
			if type_id != "":
				spawn_pedestrian_at(type_id, position, zone)

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		clear_all_pedestrians()