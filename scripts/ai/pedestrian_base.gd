extends CharacterBody3D
class_name PedestrianBase

signal state_changed(new_state: int)
signal damaged(amount: float)
signal died(killer: Node3D)
signal attacked(target: Node3D)
signal flee_started(threat_position: Vector3)

enum PedestrianState {
	IDLE = 0,
	WALKING = 1,
	RUNNING = 2,
	FLEEING = 3,
	FIGHTING = 4,
	DEAD = 5,
	IN_VEHICLE = 6,
	TALKING = 7,
	USING_PHONE = 8,
	SITTING = 9,
	WORKING = 10
}

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

enum BehaviorType {
	CIVILIAN = 0,
	BUSINESS = 1,
	GANG = 2,
	POLICE = 3,
	MEDIC = 4,
	WORKER = 5,
	HOMELESS = 6,
	TOURIST = 7,
	STUDENT = 8
}

@export var pedestrian_id: String = ""
@export var pedestrian_type: PedestrianType = PedestrianType.CITIZEN
@export var behavior_type: BehaviorType = BehaviorType.CIVILIAN
@export var gender: String = "male"
@export var fear_level: float = 0.3
@export var aggression: float = 0.1
@export var group_chance: float = 0.2

var current_state: PedestrianState = PedestrianState.IDLE
var target_position: Vector3 = Vector3.ZERO
var home_zone: String = ""
var walk_speed: float = 2.0
var run_speed: float = 6.0
var flee_speed: float = 8.0
var detection_radius: float = 20.0
var attack_radius: float = 3.0
var group_target: Vector3 = Vector3.ZERO
var in_group: bool = false
var group_members: Array[Node3D] = []

var health: float = 100.0
var max_health: float = 100.0
var is_dead: bool = false

var animation_player: AnimationPlayer = null
var animation_tree: AnimationTree = null
var state_machine: AnimationNodeStateMachinePlayback = null
var navigation_agent: NavigationAgent3D = null
var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = nil

var state_timer: float = 0.0
var state_duration: float = 0.0
var wander_timer: float = 0.0
var wander_interval: float = 5.0
var last_player_distance: float = 0.0

var current_weapon: Node3D = null
var has_weapon: bool = false

@onready var raycast_down: RayCast3D = %RayCastDown

func _ready() -> void:
	_setup_nodes()
	_setup_animation_tree()
	_setup_navigation()
	_setup_physics()

	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)

func _setup_nodes() -> void:
	animation_player = get_node_or_null("AnimationPlayer")
	animation_tree = get_node_or_null("AnimationTree")
	collision_shape = get_node_or_null("CollisionShape3D")
	mesh_instance = get_node_or_null("MeshInstance3D")
	navigation_agent = get_node_or_null("NavigationAgent3D")

	if animation_tree:
		state_machine = animation_tree.get("parameters/playback")

func _setup_animation_tree() -> void:
	if not animation_tree:
		return

	# Animation tree is set up in the scene
	pass

func _setup_navigation() -> void:
	if navigation_agent:
		navigation_agent.target_desired_distance = 1.0
		navigation_agent.path_desired_distance = 0.5

func _setup_physics() -> void:
	walk_speed = randf_range(1.5, 2.5)
	run_speed = randf_range(5.0, 7.0)
	flee_speed = randf_range(7.0, 9.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_update_state(delta)
	_handle_movement(delta)
	_update_animation(delta)
	_check_environment(delta)

func _update_state(delta: float) -> void:
	state_timer += delta

	var player = GameManager.get_player() if GameManager else null
	var player_dist = 1000.0
	if player:
		player_dist = global_position.distance_to(player.global_position)
		last_player_distance = player_dist

	match current_state:
		PedestrianState.IDLE:
			_handle_idle_state(delta, player_dist)
		PedestrianState.WALKING:
			_handle_walking_state(delta, player_dist)
		PedestrianState.RUNNING:
			_handle_running_state(delta, player_dist)
		PedestrianState.FLEEING:
			_handle_fleeing_state(delta, player_dist)
		PedestrianState.FIGHTING:
			_handle_fighting_state(delta, player_dist)
		PedestrianState.TALKING, PedestrianState.USING_PHONE, PedestrianState.SITTING, PedestrianState.WORKING:
			_handle_activity_state(delta)
		PedestrianState.DEAD:
			velocity = Vector3.ZERO

	move_and_slide()

func _handle_idle_state(delta: float, player_dist: float) -> void:
	wander_timer += delta

	if player_dist < detection_radius * fear_level:
		if behavior_type == BehaviorType.GANG and aggression > randf():
			_set_state(PedestrianState.FIGHTING)
		else:
			_set_state(PedestrianState.FLEEING)
		return

	if wander_timer >= wander_interval:
		wander_timer = 0.0
		wander_interval = randf_range(3.0, 10.0)

		var roll = randf()
		if roll < 0.6:
			_pick_wander_target()
		elif roll < 0.8:
			_set_state(PedestrianState.USING_PHONE)
			state_duration = randf_range(3.0, 8.0)
		elif roll < 0.9:
			_set_state(PedestrianState.TALKING)
			state_duration = randf_range(5.0, 15.0)
		else:
			_set_state(PedestrianState.SITTING)
			state_duration = randf_range(10.0, 30.0)

func _handle_walking_state(delta: float, player_dist: float) -> void:
	if player_dist < detection_radius * fear_level:
		_set_state(PedestrianState.FLEEING)
		return

	if navigation_agent and navigation_agent.is_navigation_finished():
		_set_state(PedestrianState.IDLE)
		wander_timer = 0.0

func _handle_running_state(delta: float, player_dist: float) -> void:
	if navigation_agent and navigation_agent.is_navigation_finished():
		_set_state(PedestrianState.IDLE)

func _handle_fleeing_state(delta: float, player_dist: float) -> void:
	var player = GameManager.get_player() if GameManager else null
	if player:
		var flee_dir = (global_position - player.global_position).normalized()
		var flee_target = global_position + flee_dir * 30.0
		navigation_agent.target_position = flee_target

	if player_dist > detection_radius * 2.0:
		_set_state(PedestrianState.IDLE)

func _handle_fighting_state(delta: float, player_dist: float) -> void:
	var player = GameManager.get_player() if GameManager else null
	if not player:
		_set_state(PedestrianState.IDLE)
		return

	var dist = global_position.distance_to(player.global_position)
	if dist > attack_radius:
		navigation_agent.target_position = player.global_position
	else:
		_attack_target(player)

	if player_dist > detection_radius * 3.0 or health < 30.0:
		_set_state(PedestrianState.FLEEING)

func _handle_activity_state(delta: float) -> void:
	state_timer += delta
	if state_timer >= state_duration:
		_set_state(PedestrianState.IDLE)
		wander_timer = 0.0

func _handle_movement(delta: float) -> void:
	if current_state in [PedestrianState.DEAD, PedestrianState.SITTING, PedestrianState.USING_PHONE, PedestrianState.TALKING, PedestrianState.WORKING]:
		velocity = Vector3.ZERO
		return

	if not navigation_agent:
		return

	var next_path_pos = navigation_agent.get_next_path_position()
	var direction = (next_path_pos - global_position).normalized()

	var target_speed = walk_speed
	match current_state:
		PedestrianState.WALKING:
			target_speed = walk_speed
		PedestrianState.RUNNING, PedestrianState.FLEEING:
			target_speed = flee_speed
		PedestrianState.FIGHTING:
			target_speed = run_speed

	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed

	if direction != Vector3.ZERO:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)

	velocity.y -= 9.8 * delta

func _update_animation(delta: float) -> void:
	if not animation_tree or not state_machine:
		return

	var speed = velocity.length()

	if is_dead:
		state_machine.travel("dead")
		return

	match current_state:
		PedestrianState.IDLE:
			state_machine.travel("idle")
		PedestrianState.WALKING:
			state_machine.travel("walk")
		PedestrianState.RUNNING, PedestrianState.FLEEING:
			state_machine.travel("run")
		PedestrianState.FIGHTING:
			state_machine.travel("fight")
		PedestrianState.USING_PHONE:
			state_machine.travel("phone")
		PedestrianState.TALKING:
			state_machine.travel("talk")
		PedestrianState.SITTING:
			state_machine.travel("sit")
		PedestrianState.WORKING:
			state_machine.travel("work")

func _check_environment(delta: float) -> void:
	if raycast_down and not raycast_down.is_colliding():
		velocity.y -= 9.8 * delta

func _pick_wander_target() -> void:
	if not navigation_agent:
		return

	var angle = randf() * TAU
	var distance = randf_range(5.0, 20.0)
	var target = global_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(target + Vector3(0, 10, 0), target + Vector3(0, -20, 0))
	var result = space_state.intersect_ray(query)

	if result:
		target = result.position
		navigation_agent.target_position = target
		_set_state(PedestrianState.WALKING)

func _set_state(new_state: PedestrianState) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	state_timer = 0.0
	state_changed.emit(int(new_state))

func initialize(definition: Dictionary, zone: String) -> void:
	pedestrian_id = definition["id"]
	pedestrian_type = PedestrianType[definition["type"].name]

	var behavior_map = {
		"civilian": BehaviorType.CIVILIAN,
		"business": BehaviorType.BUSINESS,
		"gang": BehaviorType.GANG,
		"police": BehaviorType.POLICE,
		"medic": BehaviorType.MEDIC,
		"worker": BehaviorType.WORKER,
		"homeless": BehaviorType.HOMELESS,
		"tourist": BehaviorType.TOURIST,
		"student": BehaviorType.STUDENT,
	}

	behavior_type = behavior_map.get(definition["behavior"], BehaviorType.CIVILIAN)
	fear_level = definition["fear_level"]
	aggression = definition["aggression"]
	group_chance = definition["group_chance"]

	gender = definition["gender"]
	home_zone = zone

	_setup_appearance(definition)

	if definition.get("weapon_chance", 0.0) > randf():
		_give_weapon()

func _setup_appearance(definition: Dictionary) -> void:
	if not mesh_instance:
		return

	var variants = definition.get("clothing_variants", 1)
	var variant = randi() % variants

	var material = StandardMaterial3D.new()
	material.albedo_color = _get_random_skin_color()
	mesh_instance.set_surface_override_material(0, material)

	set_meta("pedestrian_id", pedestrian_id)
	set_meta("pedestrian_type", int(pedestrian_type))

func _get_random_skin_color() -> Color:
	var colors = [
		Color(0.9, 0.75, 0.6),
		Color(0.7, 0.5, 0.35),
		Color(0.5, 0.35, 0.25),
		Color(0.35, 0.25, 0.18),
		Color(0.95, 0.8, 0.7),
	]
	return colors[randi() % colors.size()]

func _give_weapon() -> void:
	has_weapon = true
	# Weapon will be attached visually

func _attack_target(target: Node3D) -> void:
	attacked.emit(target)

	if target.has_method("take_damage"):
		target.take_damage(10.0, self)

	if AudioManager:
		AudioManager.play_sfx_3d("res://assets/audio/sfx/punch.ogg", global_position)

func flee(threat_position: Vector3) -> void:
	if current_state == PedestrianState.FLEEING:
		return

	_set_state(PedestrianState.FLEEING)
	flee_started.emit(threat_position)

	if AudioManager:
		AudioManager.play_sfx_3d("res://assets/audio/sfx/scream.ogg", global_position)

func take_damage(amount: float, source: Node = null) -> void:
	if is_dead:
		return

	health -= amount
	damaged.emit(amount)

	if health <= 0.0:
		die(source)
	elif current_state != PedestrianState.FLEEING and current_state != PedestrianState.FIGHTING:
		if fear_level > randf():
			flee(source.global_position if source else global_position)
		elif aggression > randf() and behavior_type == BehaviorType.GANG:
			_set_state(PedestrianState.FIGHTING)

func die(killer: Node = null) -> void:
	is_dead = true
	current_state = PedestrianState.DEAD

	if collision_shape:
		collision_shape.disabled = true

	set_collision_layer_value(3, false)
	set_collision_mask_value(3, false)

	died.emit(killer)

	if PedestrianManager:
		call_deferred("_despawn_later")

func _despawn_later() -> void:
	await get_tree().create_timer(5.0).timeout
	if PedestrianManager:
		PedestrianManager._despawn_pedestrian(self)

func set_group_target(target: Vector3) -> void:
	group_target = target
	in_group = true

func get_behavior_type() -> BehaviorType:
	return behavior_type

func get_pedestrian_type() -> PedestrianType:
	return pedestrian_type

func get_save_data() -> Dictionary:
	return {
		"type_id": pedestrian_id,
		"position": global_position,
		"rotation": global_rotation,
		"health": health,
		"state": int(current_state),
		"zone": home_zone,
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		global_rotation = data["rotation"]
	if data.has("health"):
		health = data["health"]
	if data.has("state"):
		current_state = PedestrianState(data["state"])
	if data.has("zone"):
		home_zone = data["zone"]