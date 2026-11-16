extends Node

signal wanted_level_changed(level: int)
signal police_spawned(unit: Node3D)
signal police_despawned(unit: Node3D)
signal player_arrested()
signal player_evaded()

enum WantedLevel {
	NONE = 0,
	LEVEL_1 = 1,
	LEVEL_2 = 2,
	LEVEL_3 = 3,
	LEVEL_4 = 4,
	LEVEL_5 = 5
}

enum PoliceUnitType {
	PATROL_CAR,
	UNDERCOVER_CAR,
	HELICOPTER,
	SWAT_VAN,
	MOTORCYCLE,
	FOOT_OFFICER,
	SNIPER,
	ROADBLOCK
}

var current_wanted_level: int = 0
var max_wanted_level: int = 5
var wanted_decay_rate: float = 0.5
var wanted_timer: float = 0.0
var search_radius: float = 100.0
var last_known_position: Vector3 = Vector3.ZERO
var is_player_visible: bool = false
var active_units: Array[Node3D] = []
var max_units_per_level: Array[int] = [0, 2, 4, 6, 8, 12]
var unit_spawn_timer: float = 0.0
var unit_spawn_interval: float = 10.0
var helicopter_spawned: bool = false
var roadblocks_active: bool = false

static var instance: PoliceManager = null

var unit_scenes: Dictionary = {}
var spawn_points: Array[Vector3] = []

func _ready() -> void:
	instance = self
	_preload_unit_scenes()
	_generate_spawn_points()

func _preload_unit_scenes() -> void:
	unit_scenes = {
		PoliceUnitType.PATROL_CAR: preload("res://scenes/ai/police_patrol_car.tscn"),
		PoliceUnitType.UNDERCOVER_CAR: preload("res://scenes/ai/police_undercover_car.tscn"),
		PoliceUnitType.HELICOPTER: preload("res://scenes/ai/police_helicopter.tscn"),
		PoliceUnitType.SWAT_VAN: preload("res://scenes/ai/police_swat_van.tscn"),
		PoliceUnitType.MOTORCYCLE: preload("res://scenes/ai/police_motorcycle.tscn"),
		PoliceUnitType.FOOT_OFFICER: preload("res://scenes/ai/police_officer.tscn"),
		PoliceUnitType.SNIPER: preload("res://scenes/ai/police_sniper.tscn"),
		PoliceUnitType.ROADBLOCK: preload("res://scenes/ai/police_roadblock.tscn"),
	}

func _generate_spawn_points() -> void:
	for i in range(50):
		var angle = randf() * TAU
		var distance = randf_range(100.0, 500.0)
		spawn_points.append(Vector3(cos(angle) * distance, 0, sin(angle) * distance))

func _process(delta: float) -> void:
	if current_wanted_level > 0:
		_update_wanted_system(delta)
		_manage_police_units(delta)

func _update_wanted_system(delta: float) -> void:
	if is_player_visible:
		wanted_timer = 0.0
	else:
		wanted_timer += delta
		if wanted_timer >= 5.0:
			wanted_timer = 0.0
			if current_wanted_level > 0:
				current_wanted_level = max(0, current_wanted_level - 1)
				wanted_level_changed.emit(current_wanted_level)
				if current_wanted_level == 0:
					player_evaded.emit()
					_clear_all_units()

	_check_player_visibility()

func _check_player_visibility() -> void:
	if not GameManager or not GameManager.get_player():
		return

	var player = GameManager.get_player()
	is_player_visible = false
	last_known_position = player.global_position

	for unit in active_units:
		if unit and is_instance_valid(unit) and unit.has_method("can_see_player"):
			if unit.can_see_player(player.global_position):
				is_player_visible = true
				break

func _manage_police_units(delta: float) -> void:
	var target_count = max_units_per_level[current_wanted_level]

	unit_spawn_timer += delta
	if unit_spawn_timer >= unit_spawn_interval and active_units.size() < target_count:
		_spawn_police_units(target_count - active_units.size())
		unit_spawn_timer = 0.0

	if current_wanted_level >= 3 and not helicopter_spawned:
		_spawn_helicopter()
		helicopter_spawned = true

	if current_wanted_level >= 4 and not roadblocks_active:
		_spawn_roadblocks()
		roadblocks_active = true

func _spawn_police_units(count: int) -> void:
	if not GameManager or not GameManager.get_player():
		return

	var player = GameManager.get_player()

	for i in range(count):
		var spawn_pos = _find_spawn_position(player.global_position)
		if spawn_pos == Vector3.ZERO:
			continue

		var unit_type = _select_unit_type_for_level(current_wanted_level)
		var scene = unit_scenes.get(unit_type)
		if not scene:
			continue

		var unit = scene.instantiate()
		unit.global_position = spawn_pos
		unit.name = "Police_Unit_%d" % active_units.size()
		add_child(unit)
		active_units.append(unit)

		if unit.has_method("initialize"):
			unit.initialize(current_wanted_level, player)

		police_spawned.emit(unit)

func _find_spawn_position(player_pos: Vector3) -> Vector3:
	var best_pos = Vector3.ZERO
	var best_distance = 0.0

	for pos in spawn_points:
		var dist = pos.distance_to(player_pos)
		if dist > 150.0 and dist < 500.0 and dist > best_distance:
			var viewport = get_viewport()
			if viewport and viewport.world_3d:
				var space_state = viewport.world_3d.direct_space_state
				var query = PhysicsRayQueryParameters3D.create(pos + Vector3(0, 50, 0), pos + Vector3(0, -10, 0))
				var result = space_state.intersect_ray(query)
				if result:
					best_pos = result.position
					best_distance = dist

	if best_pos == Vector3.ZERO:
		var angle = randf() * TAU
		best_pos = player_pos + Vector3(cos(angle) * 200, 0, sin(angle) * 200)

	return best_pos

func _select_unit_type_for_level(level: int) -> PoliceUnitType:
	match level:
		1:
			return PoliceUnitType.PATROL_CAR
		2:
			return PoliceUnitType.PATROL_CAR if randf() < 0.7 else PoliceUnitType.MOTORCYCLE
		3:
			var r = randf()
			if r < 0.4:
				return PoliceUnitType.PATROL_CAR
			elif r < 0.7:
				return PoliceUnitType.UNDERCOVER_CAR
			else:
				return PoliceUnitType.SWAT_VAN
		4:
			var r = randf()
			if r < 0.3:
				return PoliceUnitType.SWAT_VAN
			elif r < 0.6:
				return PoliceUnitType.UNDERCOVER_CAR
			else:
				return PoliceUnitType.FOOT_OFFICER
		5:
			var r = randf()
			if r < 0.4:
				return PoliceUnitType.SWAT_VAN
			elif r < 0.7:
				return PoliceUnitType.SNIPER
			else:
				return PoliceUnitType.FOOT_OFFICER
		_:
			return PoliceUnitType.PATROL_CAR

func _spawn_helicopter() -> void:
	if not GameManager or not GameManager.get_player():
		return

	var player = GameManager.get_player()
	var scene = unit_scenes.get(PoliceUnitType.HELICOPTER)
	if not scene:
		return

	var unit = scene.instantiate()
	unit.global_position = player.global_position + Vector3(0, 100, 100)
	unit.name = "Police_Helicopter"
	add_child(unit)
	active_units.append(unit)

	if unit.has_method("initialize"):
		unit.initialize(current_wanted_level, player)

	police_spawned.emit(unit)

func _spawn_roadblocks() -> void:
	if not GameManager or not GameManager.get_player():
		return

	var player = GameManager.get_player()
	var scene = unit_scenes.get(PoliceUnitType.ROADBLOCK)
	if not scene:
		return

	for i in range(4):
		var angle = (i * PI / 2) + player.global_rotation.y
		var pos = player.global_position + Vector3(cos(angle) * 150, 0, sin(angle) * 150)

		var unit = scene.instantiate()
		unit.global_position = pos
		unit.global_rotation.y = angle + PI
		unit.name = "Roadblock_%d" % i
		add_child(unit)
		active_units.append(unit)

		if unit.has_method("initialize"):
			unit.initialize(current_wanted_level, player)

		police_spawned.emit(unit)

func _clear_all_units() -> void:
	for unit in active_units:
		if unit and is_instance_valid(unit):
			police_despawned.emit(unit)
			unit.queue_free()
	active_units.clear()
	helicopter_spawned = false
	roadblocks_active = false

func on_wanted_level_changed(level: int) -> void:
	current_wanted_level = level
	wanted_level_changed.emit(level)

	if level == 0:
		_clear_all_units()
		player_evaded.emit()
	else:
		wanted_timer = 0.0
		last_known_position = GameManager.get_player().global_position if GameManager.get_player() else Vector3.ZERO

func report_crime(crime_type: String, position: Vector3, severity: int = 1) -> void:
	var old_level = current_wanted_level

	match crime_type:
		"speeding", "traffic_violation":
			if current_wanted_level == 0:
				current_wanted_level = 1
		"hit_and_run", "reckless_driving":
			current_wanted_level = max(current_wanted_level, 2)
		"assault", "weapon_discharge":
			current_wanted_level = max(current_wanted_level, 2)
		"murder", "cop_killing":
			current_wanted_level = max(current_wanted_level, 3)
		"vehicle_theft":
			current_wanted_level = max(current_wanted_level, 2)
		"bank_robbery", "heist":
			current_wanted_level = max(current_wanted_level, 4)
		"terrorism", "mass_destruction":
			current_wanted_level = 5
		_:
			current_wanted_level = max(current_wanted_level, 1)

	current_wanted_level = min(current_wanted_level + severity, max_wanted_level)

	if current_wanted_level > old_level:
		last_known_position = position
		wanted_level_changed.emit(current_wanted_level)
		UIManager.show_notification("Wanted Level: %d" % current_wanted_level, "warning")

func arrest_player() -> void:
	if GameManager and GameManager.get_player():
		var player = GameManager.get_player()
		if player.has_method("arrest"):
			player.arrest()
		player_arrested.emit()
		current_wanted_level = 0
		wanted_level_changed.emit(0)
		_clear_all_units()
		GameManager.remove_money(GameManager.get_money() / 10)

func evade_police() -> void:
	current_wanted_level = 0
	wanted_level_changed.emit(0)
	_clear_all_units()
	player_evaded.emit()

func get_wanted_level() -> int:
	return current_wanted_level

func is_wanted() -> bool:
	return current_wanted_level > 0

func get_search_radius() -> float:
	return search_radius * (1.0 + current_wanted_level * 0.5)

func get_last_known_position() -> Vector3:
	return last_known_position

func get_active_unit_count() -> int:
	var count = 0
	for unit in active_units:
		if unit and is_instance_valid(unit):
			count += 1
	return count

func remove_unit(unit: Node3D) -> void:
	if unit in active_units:
		active_units.erase(unit)
		police_despawned.emit(unit)

func get_save_data() -> Dictionary:
	return {
		"wanted_level": current_wanted_level,
		"wanted_timer": wanted_timer,
		"last_known_position": last_known_position,
		"active_units": active_units.size()
	}

func apply_save_data(data: Dictionary) -> void:
	current_wanted_level = data.get("wanted_level", 0)
	wanted_timer = data.get("wanted_timer", 0.0)
	last_known_position = data.get("last_known_position", Vector3.ZERO)

	if current_wanted_level > 0:
		wanted_level_changed.emit(current_wanted_level)

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		_clear_all_units()