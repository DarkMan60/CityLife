extends CharacterBody3D
class_name PoliceOfficer

signal player_spotted(position: Vector3)
signal player_lost()
signal damaged(amount: float)
signal destroyed()

enum PoliceState {
	PATROL = 0,
	PURSUE = 1,
	SEARCH = 2,
	ARREST = 3,
	TAKE_COVER = 4,
	RETURN_TO_STATION = 5
}

@export var unit_type: int = 5  # FOOT_OFFICER
@export var wanted_level: int = 1

var current_state: PoliceState = PoliceState.PATROL
var target: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var last_known_player_position: Vector3 = Vector3.ZERO
var search_timer: float = 0.0
var search_duration: float = 30.0
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var detection_range: float = 40.0
var engagement_range: float = 20.0
var arrest_range: float = 2.0
var accuracy: float = 0.75
var reaction_time: float = 0.3
var health: float = 100.0
var max_health: float = 100.0
var armor: float = 30.0

var is_active: bool = true
var has_spotted_player: bool = false
var last_shot_time: float = 0.0
var fire_rate: float = 0.8
var move_speed: float = 3.0
var run_speed: float = 6.0

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
	# Animation tree setup
	pass

func _setup_navigation() -> void:
	if navigation_agent:
		navigation_agent.target_desired_distance = 1.0
		navigation_agent.path_desired_distance = 0.5

func _setup_physics() -> void:
	move_speed = randf_range(2.5, 3.5)
	run_speed = randf_range(5.5, 7.0)

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

	if distance < 5.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

	if navigation_agent:
		navigation_agent.target_position = target_point

func _handle_pursue(delta: float) -> void:
	if not target:
		_set_state(PoliceState.SEARCH)
		return

	last_known_player_position = target.global_position

	var dist = global_position.distance_to(target.global_position)
	if dist > detection_range * 2.0:
		_set_state(PoliceState.SEARCH)
		return

	if navigation_agent:
		navigation_agent.target_position = target.global_position

	if dist <= arrest_range:
		_set_state(PoliceState.ARREST)
	elif dist <= engagement_range:
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

	# Search around last known position
	if navigation_agent and not navigation_agent.is_navigation_finished():
		return

	if search_timer > 5.0 and randf() < 0.02:
		var search_pos = last_known_player_position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		if navigation_agent:
			navigation_agent.target_position = search_pos

func _handle_arrest(delta: float) -> void:
	var dist = global_position.distance_to(target.global_position)
	if dist < arrest_range:
		if target.has_method("arrest"):
			target.arrest()
		_set_state(PoliceState.PATROL)
	elif dist < engagement_range:
		_engage_target()

func _handle_take_cover(delta: float) -> void:
	# Find nearby cover
	pass

func _handle_return_to_station(delta: float) -> void:
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

func _handle_movement(delta: float) -> void:
	if current_state in [PoliceState.ARREST, PoliceState.TAKE_COVER]:
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

	var target_speed = move_speed
	if current_state in [PoliceState.PURSUE, PoliceState.SEARCH]:
		target_speed = run_speed

	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed

	if direction != Vector3.ZERO:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)

	velocity.y -= 9.8 * delta
	move_and_slide()

func _update_animation(delta: float) -> void:
	if not animation_tree or not state_machine:
		return

	if health <= 0:
		state_machine.travel("dead")
		return

	var speed = Vector2(velocity.x, velocity.z).length()

	match current_state:
		PoliceState.PATROL:
			if speed > 0.5:
				state_machine.travel("walk")
			else:
				state_machine.travel("idle")
		PoliceState.PURSUE, PoliceState.SEARCH:
			if speed > 0.5:
				state_machine.travel("run")
			else:
				state_machine.travel("aim")
		PoliceState.ARREST:
			state_machine.travel("arrest")
		PoliceState.TAKE_COVER:
			state_machine.travel("cover")

func _check_environment(delta: float) -> void:
	if raycast_down and not raycast_down.is_colliding():
		velocity.y -= 9.8 * delta

func can_see_player(player_pos: Vector3) -> bool:
	var dist = global_position.distance_to(player_pos)
	if dist > detection_range:
		return false

	var to_player = (player_pos - global_position).normalized()
	var forward = -global_transform.basis.z
	var dot = forward.dot(to_player)

	if dot < 0.5:
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
	current_state = PoliceState.PURSUE
	is_active = true

	_setup_patrol_points()

	set_meta("police_unit_type", "foot_officer")

func _setup_patrol_points() -> void:
	patrol_points.clear()
	var center = global_position

	for i in range(4):
		var angle = (i * PI / 2) + randf_range(-0.5, 0.5)
		var distance = randf_range(15.0, 40.0)
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
	elif health < max_health * 0.3 and current_state != PoliceState.TAKE_COVER:
		if randf() < 0.5:
			_set_state(PoliceState.TAKE_COVER)

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