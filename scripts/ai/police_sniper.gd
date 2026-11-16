extends CharacterBody3D
class_name PoliceSniper

signal player_spotted(position: Vector3)
signal player_lost()
signal damaged(amount: float)
signal destroyed()

enum PoliceState {
	POSITIONING = 0,
	SNIPING = 1,
	REPOSITIONING = 2,
	TAKE_COVER = 3,
	RETURN_TO_STATION = 4
}

@export var unit_type: int = 6  # SNIPER
@export var wanted_level: int = 1

var current_state: PoliceState = PoliceState.POSITIONING
var target: Node3D = null
var sniper_position: Vector3 = Vector3.ZERO
var last_known_player_position: Vector3 = Vector3.ZERO
var reposition_timer: float = 0.0
var reposition_interval: float = 15.0
var detection_range: float = 300.0
var engagement_range: float = 200.0
var min_engagement_range: float = 50.0
var accuracy: float = 0.95
var health: float = 80.0
var max_health: float = 80.0
var armor: float = 20.0

var is_active: bool = true
var has_spotted_player: bool = false
var last_shot_time: float = 0.0
var fire_rate: float = 2.0
var move_speed: float = 2.0

var navigation_agent: NavigationAgent3D = null
var animation_tree: AnimationTree = null
var state_machine: AnimationNodeStateMachinePlayback = null
var raycast_down: RayCast3D = null

@onready var collision_shape: CollisionShape3D = %CollisionShape

func _ready() -> void:
	_setup_nodes()
	_setup_animation()
	_setup_navigation()
	_setup_physics()

func _setup_nodes() -> void:
	navigation_agent = get_node_or_null("NavigationAgent3D")
	animation_tree = get_node_or_null("AnimationTree")
	raycast_down = get_node_or_null("RayCastDown")

	if animation_tree:
		state_machine = animation_tree.get("parameters/playback")

	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)

func _setup_animation() -> void:
	pass

func _setup_navigation() -> void:
	if navigation_agent:
		navigation_agent.target_desired_distance = 2.0
		navigation_agent.path_desired_distance = 1.0

func _setup_physics() -> void:
	move_speed = 2.0

func _physics_process(delta: float) -> void:
	if not is_active or health <= 0:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_update_ai(delta)
	_handle_movement(delta)
	_update_animation(delta)
	_check_environment(delta)

func _update_ai(delta: float) -> void:
	if not target:
		return

	var dist = global_position.distance_to(target.global_position)

	match current_state:
		PoliceState.POSITIONING:
			_handle_positioning(delta)
		PoliceState.SNIPING:
			_handle_sniping(delta, dist)
		PoliceState.REPOSITIONING:
			_handle_repositioning(delta)
		PoliceState.TAKE_COVER:
			_handle_take_cover(delta)
		PoliceState.RETURN_TO_STATION:
			_handle_return_to_station(delta)

func _handle_positioning(delta: float) -> void:
	# Find a good sniping position (elevated, good line of sight)
	if sniper_position == Vector3.ZERO:
		_find_sniper_position()

	if navigation_agent:
		navigation_agent.target_position = sniper_position

	if global_position.distance_to(sniper_position) < 5.0:
		_set_state(PoliceState.SNIPING)

func _handle_sniping(delta: float, dist: float) -> void:
	if dist > engagement_range * 1.5 or dist < min_engagement_range:
		_set_state(PoliceState.REPOSITIONING)
		return

	if not can_see_player(target.global_position):
		_set_state(PoliceState.REPOSITIONING)
		return

	_shoot_at_target()

	reposition_timer += delta
	if reposition_timer >= reposition_interval:
		reposition_timer = 0.0
		_set_state(PoliceState.REPOSITIONING)

func _handle_repositioning(delta: float) -> void:
	_find_sniper_position()

	if navigation_agent:
		navigation_agent.target_position = sniper_position

	if global_position.distance_to(sniper_position) < 5.0:
		_set_state(PoliceState.SNIPING)

func _handle_take_cover(delta: float) -> void:
	pass

func _handle_return_to_station(delta: float) -> void:
	if PoliceManager:
		call_deferred("_despawn_self")

func _despawn_self() -> void:
	if PoliceManager:
		PoliceManager.remove_unit(self)
	queue_free()

func _find_sniper_position() -> void:
	var player_pos = target.global_position
	var best_pos = Vector3.ZERO
	var best_score = -1.0

	# Search for elevated positions with good line of sight
	for i in range(20):
		var angle = randf() * TAU
		var distance = randf_range(min_engagement_range, engagement_range)
		var test_pos = player_pos + Vector3(cos(angle) * distance, 0, sin(angle) * distance)

		# Raycast down to find ground
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(test_pos + Vector3(0, 50, 0), test_pos + Vector3(0, -100, 0))
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)

		if result:
			test_pos = result.position + Vector3(0, 2.0, 0)  # Elevated slightly

			# Check line of sight to player
			var los_query = PhysicsRayQueryParameters3D.create(test_pos + Vector3(0, 1.5, 0), player_pos + Vector3(0, 1.5, 0))
			los_query.collision_mask = 1 | 2
			los_query.exclude = [get_rid()]
			var los_result = space_state.intersect_ray(los_query)

			var has_los = false
			if los_result:
				var collider = los_result.collider
				if collider == target or (collider.is_in_group("player") if collider else false):
					has_los = true

			if has_los:
				var height_bonus = test_pos.y * 0.1
				var dist_score = 1.0 - (test_pos.distance_to(player_pos) / engagement_range) * 0.5
				var score = dist_score + height_bonus

				if score > best_score:
					best_score = score
					best_pos = test_pos

	if best_pos != Vector3.ZERO:
		sniper_position = best_pos
	else:
		# Fallback: just pick a position at engagement range
		var angle = randf() * TAU
		sniper_position = player_pos + Vector3(cos(angle) * engagement_range * 0.8, 10.0, sin(angle) * engagement_range * 0.8)

func _shoot_at_target() -> void:
	if not target:
		return

	var now = Time.get_ticks_msec() / 1000.0
	if now - last_shot_time < fire_rate:
		return

	last_shot_time = now

	# Very high accuracy
	if randf() < accuracy:
		if target.has_method("take_damage"):
			target.take_damage(50.0, self)  # High damage

		if AudioManager:
			AudioManager.play_sfx_3d("res://assets/audio/sfx/sniper_shot.ogg", global_position)

func _handle_movement(delta: float) -> void:
	if current_state in [PoliceState.SNIPING, PoliceState.TAKE_COVER]:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not navigation_agent:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var next_path_pos = navigation_agent.get_next_path_position()
	var direction = (next_path_pos - global_position).normalized()
	direction.y = 0

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if direction != Vector3.ZERO:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)

	velocity.y -= 9.8 * delta
	move_and_slide()

func _update_animation(delta: float) -> void:
	if not animation_tree or not state_machine:
		return

	if health <= 0:
		state_machine.travel("dead")
		return

	match current_state:
		PoliceState.POSITIONING, PoliceState.REPOSITIONING:
			state_machine.travel("walk")
		PoliceState.SNIPING:
			state_machine.travel("aim")
		PoliceState.TAKE_COVER:
			state_machine.travel("cover")

func _check_environment(delta: float) -> void:
	if raycast_down and not raycast_down.is_colliding():
		velocity.y -= 9.8 * delta

func can_see_player(player_pos: Vector3) -> bool:
	var dist = global_position.distance_to(player_pos)
	if dist > detection_range:
		return false

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
	current_state = PoliceState.POSITIONING
	is_active = true

	set_meta("police_unit_type", "sniper")

func _set_state(new_state: PoliceState) -> void:
	current_state = new_state
	reposition_timer = 0.0

func take_damage(amount: float, source: Node = null) -> void:
	if health <= 0:
		return

	var actual_damage = max(0.0, amount - armor)
	health -= actual_damage
	damaged.emit(actual_damage)

	if health <= 0:
		destroy()
	elif health < max_health * 0.5:
		_set_state(PoliceState.REPOSITIONING)

func destroy() -> void:
	is_active = false
	destroyed.emit()

	if PoliceManager:
		PoliceManager.remove_unit(self)

	queue_free()

func get_save_data() -> Dictionary:
	return {
		"unit_type": unit_type,
		"position": global_position,
		"rotation": global_rotation,
		"health": health,
		"state": int(current_state),
		"wanted_level": wanted_level,
		"sniper_position": sniper_position,
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		global_rotation = data["rotation"]
	if data.has("health"):
		health = data["health"]
	if data.has("state"):
		current_state = data["state"]
	if data.has("wanted_level"):
		wanted_level = data["wanted_level"]
	if data.has("sniper_position"):
		sniper_position = data["sniper_position"]