extends Node3D
class_name PoliceBase

signal player_spotted(position: Vector3)
signal player_lost()
signal target_reached()
signal damaged(amount: float)
signal destroyed()

enum PoliceUnitType {
	PATROL_CAR = 0,
	UNDERCOVER_CAR = 1,
	HELICOPTER = 2,
	SWAT_VAN = 3,
	MOTORCYCLE = 4,
	FOOT_OFFICER = 5,
	SNIPER = 6,
	ROADBLOCK = 7
}

enum PoliceState {
	PATROL = 0,
	PURSUE = 1,
	SEARCH = 2,
	ARREST = 3,
	TAKE_COVER = 4,
	RETURN_TO_STATION = 5
}

@export var unit_type: PoliceUnitType = PoliceUnitType.PATROL_CAR
@export var wanted_level: int = 1

var current_state: PoliceState = PoliceState.PATROL
var target: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var last_known_player_position: Vector3 = Vector3.ZERO
var search_timer: float = 0.0
var search_duration: float = 30.0
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var detection_range: float = 50.0
var engagement_range: float = 30.0
var accuracy: float = 0.7
var reaction_time: float = 0.5
var health: float = 100.0
var max_health: float = 100.0
var armor: float = 0.0

var is_active: bool = true
var has_spotted_player: bool = false
var last_shot_time: float = 0.0
var fire_rate: float = 0.5

func _ready() -> void:
	_setup_unit()

func _setup_unit() -> void:
	match unit_type:
		PoliceUnitType.PATROL_CAR:
			detection_range = 60.0
			engagement_range = 40.0
			accuracy = 0.6
			health = 150.0
			max_health = 150.0
			armor = 20.0
		PoliceUnitType.UNDERCOVER_CAR:
			detection_range = 70.0
			engagement_range = 50.0
			accuracy = 0.7
			health = 120.0
			max_health = 120.0
			armor = 10.0
		PoliceUnitType.HELICOPTER:
			detection_range = 200.0
			engagement_range = 100.0
			accuracy = 0.5
			health = 200.0
			max_health = 200.0
			armor = 50.0
		PoliceUnitType.SWAT_VAN:
			detection_range = 50.0
			engagement_range = 30.0
			accuracy = 0.8
			health = 300.0
			max_health = 300.0
			armor = 100.0
		PoliceUnitType.MOTORCYCLE:
			detection_range = 50.0
			engagement_range = 25.0
			accuracy = 0.65
			health = 80.0
			max_health = 80.0
			armor = 0.0
		PoliceUnitType.FOOT_OFFICER:
			detection_range = 40.0
			engagement_range = 20.0
			accuracy = 0.75
			health = 100.0
			max_health = 100.0
			armor = 30.0
		PoliceUnitType.SNIPER:
			detection_range = 300.0
			engagement_range = 200.0
			accuracy = 0.95
			health = 80.0
			max_health = 80.0
			armor = 20.0
		PoliceUnitType.ROADBLOCK:
			detection_range = 100.0
			engagement_range = 50.0
			accuracy = 0.7
			health = 500.0
			max_health = 500.0
			armor = 200.0

func _process(delta: float) -> void:
	if not is_active or health <= 0:
		return

	_update_ai(delta)
	_update_detection(delta)

func _update_ai(delta: float) -> void:
	if not target:
		return

	match current_state:
		PoliceState.PATROL:
			_handle_patrol(delta)
		PoliceState.PURSUE:
			_handle_pursue(delta)
		PoliceState.SEARCH:
			_handle_search(delta)
		PoliceState.ARREST:
			_handle_arrest(delta)
		PoliceState.TAKE_COVER:
			_handle_take_cover(delta)
		PoliceState.RETURN_TO_STATION:
			_handle_return_to_station(delta)

func _handle_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return

	var target_point = patrol_points[current_patrol_index]
	var distance = global_position.distance_to(target_point)

	if distance < 10.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func _handle_pursue(delta: float) -> void:
	if not target:
		_set_state(PoliceState.SEARCH)
		return

	last_known_player_position = target.global_position

	var dist = global_position.distance_to(target.global_position)
	if dist > detection_range * 2.0:
		_set_state(PoliceState.SEARCH)
		return

	if dist <= engagement_range:
		_engage_target()

func _handle_search(delta: float) -> void:
	search_timer += delta

	if search_timer >= search_duration:
		_set_state(PoliceState.RETURN_TO_STATION)
		return

	var player = GameManager.get_player() if GameManager else null
	if player and global_position.distance_to(player.global_position) < detection_range:
		if can_see_player(player.global_position):
			_set_state(PoliceState.PURSUE)
			return

func _handle_arrest(delta: float) -> void:
	var dist = global_position.distance_to(target.global_position)
	if dist < 2.0:
		if target.has_method("arrest"):
			target.arrest()
		_set_state(PoliceState.PATROL)

func _handle_take_cover(delta: float) -> void:
	# Find cover position
	pass

func _handle_return_to_station(delta: float) -> void:
	# Despawn after returning
	if PoliceManager:
		call_deferred("_despawn_self")

func _despawn_self() -> void:
	if PoliceManager:
		PoliceManager.remove_unit(self)
	queue_free()

func _update_detection(delta: float) -> void:
	if not target:
		return

	var can_see = can_see_player(target.global_position)
	if can_see and not has_spotted_player:
		has_spotted_player = true
		player_spotted.emit(target.global_position)
	elif not can_see and has_spotted_player:
		has_spotted_player = false
		player_lost.emit()

func _engage_target() -> void:
	if unit_type in [PoliceUnitType.PATROL_CAR, PoliceUnitType.UNDERCOVER_CAR, PoliceUnitType.MOTORCYCLE]:
		# Vehicle units ram or block
		_ram_target()
	elif unit_type == PoliceUnitType.HELICOPTER:
		# Helicopter shoots or deploys units
		_shoot_at_target()
	elif unit_type in [PoliceUnitType.FOOT_OFFICER, PoliceUnitType.SWAT_VAN, PoliceUnitType.SNIPER]:
		# Foot units shoot
		_shoot_at_target()
	elif unit_type == PoliceUnitType.ROADBLOCK:
		# Roadblock just blocks
		pass

func _ram_target() -> void:
	if not target:
		return

	var direction = (target.global_position - global_position).normalized()
	# Apply ramming force through physics

func _shoot_at_target() -> void:
	if not target:
		return

	var now = Time.get_ticks_msec() / 1000.0
	if now - last_shot_time < fire_rate:
		return

	last_shot_time = now

	if randf() < accuracy:
		if target.has_method("take_damage"):
			target.take_damage(15.0, self)

		if AudioManager:
			AudioManager.play_sfx_3d("res://assets/audio/sfx/gunshot.ogg", global_position)

func can_see_player(player_pos: Vector3) -> bool:
	var dist = global_position.distance_to(player_pos)
	if dist > detection_range:
		return false

	var to_player = (player_pos - global_position).normalized()
	var forward = -global_transform.basis.z
	var dot = forward.dot(to_player)

	if dot < 0.5:
		return false

	# Raycast to check line of sight
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), player_pos + Vector3(0, 1.5, 0))
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]

	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		if collider == target or (collider.is_in_group("player") if collider else false):
			return true
		return false

	return true

func initialize(level: int, player_target: Node3D) -> void:
	wanted_level = level
	target = player_target
	current_state = PoliceState.PURSUE
	is_active = true

	_setup_patrol_points()

	if unit_type == PoliceUnitType.ROADBLOCK:
		current_state = PoliceState.PATROL
	elif unit_type == PoliceUnitType.HELICOPTER:
		current_state = PoliceState.PURSUE

func _setup_patrol_points() -> void:
	if unit_type == PoliceUnitType.ROADBLOCK:
		return

	patrol_points.clear()
	var center = global_position

	for i in range(4):
		var angle = (i * PI / 2) + randf_range(-0.5, 0.5)
		var distance = randf_range(30.0, 80.0)
		var point = center + Vector3(cos(angle) * distance, 0, sin(angle) * distance)

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(point + Vector3(0, 50, 0), point + Vector3(0, -10, 0))
		var result = space_state.intersect_ray(query)

		if result:
			patrol_points.append(result.position)
		else:
			patrol_points.append(point)

func _set_state(new_state: PoliceState) -> void:
	current_state = new_state
	search_timer = 0.0

func take_damage(amount: float, source: Node = null) -> void:
	if health <= 0:
		return

	var actual_damage = max(0.0, amount - armor)
	health -= actual_damage
	damaged.emit(actual_damage)

	if health <= 0:
		destroy()

func destroy() -> void:
	is_active = false
	destroyed.emit()

	if PoliceManager:
		PoliceManager.remove_unit(self)

	queue_free()

func get_save_data() -> Dictionary:
	return {
		"unit_type": int(unit_type),
		"position": global_position,
		"rotation": global_rotation,
		"health": health,
		"state": int(current_state),
		"wanted_level": wanted_level,
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		global_rotation = data["rotation"]
	if data.has("health"):
		health = data["health"]
	if data.has("state"):
		current_state = PoliceState(data["state"])
	if data.has("wanted_level"):
		wanted_level = data["wanted_level"]