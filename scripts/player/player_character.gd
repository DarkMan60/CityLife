extends CharacterBody3D

class_name PlayerCharacter

signal health_changed(current: float, max: float)
signal armor_changed(current: float, max: float)
signal stamina_changed(current: float, max: float)
signal weapon_changed(weapon_id: String)
signal ammo_changed(current: int, reserve: int)
signal entered_vehicle(vehicle: Node3D)
signal exited_vehicle(vehicle: Node3D)
signal died()
signal arrested()
signal wanted_level_changed(level: int)
signal money_changed(amount: int)

enum PlayerState {
	ON_FOOT,
	IN_VEHICLE,
	SWIMMING,
	CLIMBING,
	RAGDOLL,
	ARRESTED,
	DEAD
}

enum MovementMode {
	WALK,
	RUN,
	SPRINT,
	CROUCH,
	PRONE
}

var max_health: float = 100.0
var current_health: float = 100.0
var max_armor: float = 100.0
var current_armor: float = 0.0
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_regen_rate: float = 15.0
var stamina_drain_rate: float = 25.0

var walk_speed: float = 3.0
var run_speed: float = 6.0
var sprint_speed: float = 10.0
var crouch_speed: float = 1.5
var swim_speed: float = 2.5
var jump_velocity: float = 7.0
var gravity: float = 9.81 * 2.0
var air_control: float = 0.3
var turn_speed: float = 10.0

var current_state: PlayerState = PlayerState.ON_FOOT
var movement_mode: MovementMode = MovementMode.WALK
var is_sprinting: bool = false
var is_crouching: bool = false
var is_aiming: bool = false
var is_reloading: bool = false
var is_in_cover: bool = false

var current_weapon: String = "fists"
var weapons: Dictionary = {}
var weapon_slots: Array[String] = ["fists"]
var current_weapon_index: int = 0

var camera_pivot: Node3D = null
var camera: Camera3D = null
var collision_shape: CollisionShape3D = null
var animation_player: AnimationPlayer = null
var animation_tree: AnimationTree = null
var state_machine: AnimationNodeStateMachinePlayback = null

var vehicle: Node3D = null
var vehicle_entry_point: Node3D = null

var last_damage_time: float = 0.0
var invulnerability_time: float = 0.5
var ragdoll_timer: float = 0.0
var swim_timer: float = 0.0

var mouse_sensitivity: float = 0.002
var camera_distance: float = 4.0
var camera_height: float = 1.5
var camera_target_height: float = 1.0
var camera_min_distance: float = 1.5
var camera_max_distance: float = 10.0

static var instance: PlayerCharacter = null

func _ready() -> void:
	instance = self
	_setup_nodes()
	_setup_physics()
	_setup_animations()
	_setup_weapons()
	_setup_input()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_nodes() -> void:
	camera_pivot = get_node("CameraPivot")
	camera = camera_pivot.get_node("Camera3D")
	collision_shape = get_node("CollisionShape3D")
	animation_player = get_node("AnimationPlayer")
	animation_tree = get_node("AnimationTree")

	if animation_tree:
		state_machine = animation_tree.get("parameters/playback")

func _setup_physics() -> void:
	mass = 80.0
	collision_layer = 1
	collision_mask = 1 | 2 | 4 | 8

func _setup_animations() -> void:
	if animation_tree:
		animation_tree.active = true

func _setup_weapons() -> void:
	weapons = {
		"fists": {
			"id": "fists",
			"name": "Fists",
			"type": "melee",
			"damage": 15.0,
			"range": 1.5,
			"fire_rate": 1.0,
			"ammo_type": "none",
			"max_ammo": -1,
			"current_ammo": -1,
			"reserve_ammo": -1,
			"reload_time": 0.0,
			"spread": 0.0,
			"recoil": 0.0,
			"animation": "melee"
		},
		"pistol": {
			"id": "pistol",
			"name": "Pistol",
			"type": "handgun",
			"damage": 25.0,
			"range": 50.0,
			"fire_rate": 0.15,
			"ammo_type": "9mm",
			"max_ammo": 12,
			"current_ammo": 12,
			"reserve_ammo": 120,
			"reload_time": 1.5,
			"spread": 0.02,
			"recoil": 0.5,
			"animation": "pistol"
		},
		"smg": {
			"id": "smg",
			"name": "SMG",
			"type": "smg",
			"damage": 20.0,
			"range": 75.0,
			"fire_rate": 0.08,
			"ammo_type": "9mm",
			"max_ammo": 30,
			"current_ammo": 30,
			"reserve_ammo": 150,
			"reload_time": 2.0,
			"spread": 0.05,
			"recoil": 0.3,
			"animation": "rifle"
		},
		"assault_rifle": {
			"id": "assault_rifle",
			"name": "Assault Rifle",
			"type": "rifle",
			"damage": 30.0,
			"range": 200.0,
			"fire_rate": 0.1,
			"ammo_type": "5.56mm",
			"max_ammo": 30,
			"current_ammo": 30,
			"reserve_ammo": 180,
			"reload_time": 2.5,
			"spread": 0.03,
			"recoil": 0.7,
			"animation": "rifle"
		},
		"shotgun": {
			"id": "shotgun",
			"name": "Shotgun",
			"type": "shotgun",
			"damage": 12.0,
			"range": 25.0,
			"fire_rate": 0.8,
			"ammo_type": "12ga",
			"max_ammo": 8,
			"current_ammo": 8,
			"reserve_ammo": 32,
			"reload_time": 3.0,
			"spread": 0.15,
			"recoil": 1.5,
			"animation": "shotgun",
			"pellets": 8
		},
		"sniper_rifle": {
			"id": "sniper_rifle",
			"name": "Sniper Rifle",
			"type": "sniper",
			"damage": 100.0,
			"range": 500.0,
			"fire_rate": 1.5,
			"ammo_type": "7.62mm",
			"max_ammo": 5,
			"current_ammo": 5,
			"reserve_ammo": 20,
			"reload_time": 3.5,
			"spread": 0.001,
			"recoil": 2.0,
			"animation": "sniper"
		},
		"rpg": {
			"id": "rpg",
			"name": "RPG",
			"type": "explosive",
			"damage": 200.0,
			"range": 300.0,
			"fire_rate": 3.0,
			"ammo_type": "rocket",
			"max_ammo": 1,
			"current_ammo": 1,
			"reserve_ammo": 3,
			"reload_time": 4.0,
			"spread": 0.01,
			"recoil": 3.0,
			"animation": "heavy"
		}
	}

	current_weapon = "fists"
	weapon_slots = ["fists"]

func _setup_input() -> void:
	InputManager.action_pressed.connect(_on_action_pressed)
	InputManager.action_released.connect(_on_action_released)

func _on_action_pressed(action: String) -> void:
	match action:
		"jump":
			_try_jump()
		"sprint":
			_set_sprinting(true)
		"crouch":
			_toggle_crouch()
		"interact":
			_try_interact()
		"attack":
			_attack()
		"aim":
			_set_aiming(true)
		"vehicle_exit":
			_try_exit_vehicle()
		"next_weapon":
			_next_weapon()
		"prev_weapon":
			_prev_weapon()
		"pause":
			GameManager.pause_game()
		_:
			pass

func _on_action_released(action: String) -> void:
	match action:
		"sprint":
			_set_sprinting(false)
		"aim":
			_set_aiming(false)
		_:
			pass

func _physics_process(delta: float) -> void:
	if current_state == PlayerState.DEAD or current_state == PlayerState.ARRESTED:
		return

	if current_state == PlayerState.IN_VEHICLE:
		_process_vehicle_controls(delta)
		return

	if current_state == PlayerState.SWIMMING:
		_process_swimming(delta)
		return

	if current_state == PlayerState.RAGDOLL:
		_process_ragdoll(delta)
		return

	_process_movement(delta)
	_process_stamina(delta)
	_process_camera(delta)
	_process_health_regen(delta)

func _process_movement(delta: float) -> void:
	var input_dir = InputManager.get_move_input()
	var is_moving = input_dir.length() > 0.1

	var target_speed = walk_speed
	var anim_state = "idle"

	if is_sprinting and current_stamina > 10.0 and not is_crouching:
		target_speed = sprint_speed
		anim_state = "sprint"
		movement_mode = MovementMode.SPRINT
	elif is_moving:
		if is_crouching:
			target_speed = crouch_speed
			anim_state = "crouch_walk"
			movement_mode = MovementMode.CROUCH
		else:
			target_speed = run_speed
			anim_state = "run"
			movement_mode = MovementMode.RUN
	else:
		if is_crouching:
			anim_state = "crouch_idle"
			movement_mode = MovementMode.CROUCH
		else:
			anim_state = "idle"
			movement_mode = MovementMode.WALK

	if is_aiming and not is_sprinting:
		target_speed *= 0.5
		anim_state = "aim_" + anim_state

	var camera_forward = -camera.global_transform.basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	var camera_right = camera.global_transform.basis.x
	camera_right.y = 0
	camera_right = camera_right.normalized()

	var move_dir = (camera_forward * input_dir.y + camera_right * input_dir.x).normalized()

	var target_velocity = move_dir * target_speed

	if not is_on_floor():
		target_velocity.y = velocity.y
		target_velocity.x *= air_control
		target_velocity.z *= air_control
	else:
		target_velocity.y = velocity.y

	velocity = velocity.lerp(target_velocity, 15.0 * delta)

	if is_on_floor() and velocity.length() > 0.1:
		var target_rot = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rot, turn_speed * delta)

	move_and_slide()

	_update_animation(anim_state, target_speed)

func _process_swimming(delta: float) -> void:
	var input_dir = InputManager.get_move_input()
	var is_moving = input_dir.length() > 0.1

	var target_speed = swim_speed
	var anim_state = "swim_idle"

	if is_moving:
		anim_state = "swim"

	var camera_forward = -camera.global_transform.basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	var camera_right = camera.global_transform.basis.x
	camera_right.y = 0
	camera_right = camera_right.normalized()

	var move_dir = (camera_forward * input_dir.y + camera_right * input_dir.x).normalized()

	if Input.is_action_pressed("jump"):
		move_dir.y = 1.0
	elif Input.is_action_pressed("crouch"):
		move_dir.y = -1.0

	var target_velocity = move_dir * target_speed
	velocity = velocity.lerp(target_velocity, 10.0 * delta)

	move_and_slide()

	_update_animation(anim_state, target_speed)

	swim_timer += delta
	if swim_timer > 30.0:
		take_damage(5.0, "drowning")
		swim_timer = 0.0

func _process_vehicle_controls(delta: float) -> void:
	if not vehicle or not is_instance_valid(vehicle):
		_exit_vehicle()
		return

	var input = InputManager.get_vehicle_input()

	if vehicle.has_method("set_driver_input"):
		vehicle.set_driver_input(input)

	if vehicle.has_method("get_speed"):
		UIManager.update_speedometer(vehicle.get_speed(), vehicle.get_gear() if vehicle.has_method("get_gear") else 0, vehicle.get_fuel() if vehicle.has_method("get_fuel") else 100)

func _process_ragdoll(delta: float) -> void:
	ragdoll_timer += delta
	if ragdoll_timer > 3.0:
		_get_up_from_ragdoll()

func _process_stamina(delta: float) -> void:
	if is_sprinting and movement_mode == MovementMode.SPRINT:
		current_stamina = max(current_stamina - stamina_drain_rate * delta, 0.0)
		if current_stamina <= 0.0:
			_set_sprinting(false)
	else:
		current_stamina = min(current_stamina + stamina_regen_rate * delta, max_stamina)

	stamina_changed.emit(current_stamina, max_stamina)

func _process_camera(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	var look_input = InputManager.get_look_input()

	camera_pivot.rotation.y -= look_input.x * mouse_sensitivity
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - look_input.y * mouse_sensitivity, -PI/2.5, PI/4)

	var desired_pos = camera_pivot.global_position + Vector3(0, camera_height, 0) - camera_pivot.global_transform.basis.z * camera_distance
	var ray_from = camera_pivot.global_position + Vector3(0, camera_height, 0)
	var ray_to = desired_pos

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to, [get_rid()])
	var result = space_state.intersect_ray(query)

	if result:
		var hit_pos = result.position
		var dist = ray_from.distance_to(hit_pos)
		camera_distance = max(dist - 0.5, camera_min_distance)
	else:
		camera_distance = lerp(camera_distance, camera_distance, 10.0 * delta)

	camera_distance = clamp(camera_distance, camera_min_distance, camera_max_distance)
	camera.global_position = camera_pivot.global_position + Vector3(0, camera_height, 0) - camera_pivot.global_transform.basis.z * camera_distance
	camera.look_at(camera_pivot.global_position + Vector3(0, camera_target_height, 0))

func _process_health_regen(delta: float) -> void:
	if current_health < max_health and Time.get_ticks_msec() / 1000.0 - last_damage_time > 10.0:
		current_health = min(current_health + 1.0 * delta, max_health)
		health_changed.emit(current_health, max_health)

func _try_jump() -> void:
	if current_state != PlayerState.ON_FOOT:
		return

	if is_on_floor() and current_stamina >= 10.0:
		velocity.y = jump_velocity
		current_stamina -= 10.0
		stamina_changed.emit(current_stamina, max_stamina)
		_play_animation("jump")

func _toggle_crouch() -> void:
	if current_state != PlayerState.ON_FOOT:
		return

	is_crouching = not is_crouching

	if is_crouching:
		(collision_shape.shape as CapsuleShape3D).height = 1.0
		camera_height = 0.8
	else:
		(collision_shape.shape as CapsuleShape3D).height = 1.8
		camera_height = 1.5

func _set_sprinting(enabled: bool) -> void:
	if current_state != PlayerState.ON_FOOT:
		return

	is_sprinting = enabled and current_stamina > 10.0 and not is_crouching

func _set_aiming(enabled: bool) -> void:
	if current_state != PlayerState.ON_FOOT or is_reloading:
		return

	is_aiming = enabled

	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.fov = 50.0
	else:
		camera.fov = 75.0

func _try_interact() -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position + camera.global_transform.basis.z * -3.0,
		[get_rid()]
	)
	var result = space_state.intersect_ray(query)

	if result:
		var obj = result.collider
		if obj and obj.has_method("interact"):
			obj.interact(self)

		if obj and obj.is_in_group("vehicle"):
			_try_enter_vehicle(obj)

		if obj and obj.is_in_group("npc"):
			MissionManager.check_interaction(obj.get_name())

func _try_enter_vehicle(vehicle_node: Node3D) -> void:
	if vehicle_node.has_method("can_enter") and vehicle_node.can_enter():
		if VehicleManager.enter_vehicle(self, vehicle_node):
			current_state = PlayerState.IN_VEHICLE
			vehicle = vehicle_node
			entered_vehicle.emit(vehicle_node)
			visible = false
			collision_layer = 0
			collision_mask = 0
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _try_exit_vehicle() -> void:
	if current_state == PlayerState.IN_VEHICLE and vehicle:
		var exit_pos = vehicle.global_position + vehicle.global_transform.basis.x * 2.5

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(exit_pos + Vector3(0, 2, 0), exit_pos + Vector3(0, -2, 0))
		var result = space_state.intersect_ray(query)

		if result:
			exit_pos = result.position

		VehicleManager.exit_vehicle(self)
		current_state = PlayerState.ON_FOOT
		global_position = exit_pos
		visible = true
		collision_layer = 1
		collision_mask = 1 | 2 | 4 | 8
		exited_vehicle.emit(vehicle)
		vehicle = null

func _exit_vehicle() -> void:
	current_state = PlayerState.ON_FOOT
	vehicle = null
	visible = true
	collision_layer = 1
	collision_mask = 1 | 2 | 4 | 8

func _attack() -> void:
	if current_state != PlayerState.ON_FOOT or is_reloading:
		return

	var weapon_data = weapons[current_weapon]
	if not weapon_data:
		return

	if weapon_data["type"] == "melee":
		_melee_attack()
	else:
		_shoot()

func _melee_attack() -> void:
	_play_animation("melee_attack")

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position + camera.global_transform.basis.z * -weapons[current_weapon]["range"],
		[get_rid()]
	)
	var result = space_state.intersect_ray(query)

	if result:
		var target = result.collider
		if target and target.has_method("take_damage"):
			target.take_damage(weapons[current_weapon]["damage"], "melee", self)

func _shoot() -> void:
	var weapon_data = weapons[current_weapon]

	if weapon_data["current_ammo"] <= 0:
		if weapon_data["reserve_ammo"] > 0:
			_reload()
		else:
			_play_sound("empty_click")
		return

	var fire_rate = weapon_data["fire_rate"]
	var current_time = Time.get_ticks_msec() / 1000.0

	if hasattr(self, "_last_shot_time") and current_time - _last_shot_time < fire_rate:
		return

	_last_shot_time = current_time

	weapon_data["current_ammo"] -= 1
	ammo_changed.emit(weapon_data["current_ammo"], weapon_data["reserve_ammo"])

	_play_animation("shoot")
	_play_sound("weapon_fire")

	var spread = weapon_data["spread"]
	if is_aiming:
		spread *= 0.3
	if movement_mode == MovementMode.SPRINT:
		spread *= 2.0
	elif movement_mode == MovementMode.CROUCH:
		spread *= 0.5

	var recoil = weapon_data["recoil"]
	if is_aiming:
		recoil *= 0.5

	camera_pivot.rotation.x -= recoil * 0.01 * randf_range(0.5, 1.0)
	camera_pivot.rotation.y += randf_range(-recoil, recoil) * 0.005

	if weapon_data["type"] == "shotgun":
		for i in range(weapon_data.get("pellets", 8)):
			_fire_raycast(spread)
	else:
		_fire_raycast(spread)

func _fire_raycast(spread: float) -> void:
	var direction = -camera.global_transform.basis.z
	direction = direction.rotated(Vector3(1, 0, 0), randf_range(-spread, spread))
	direction = direction.rotated(Vector3(0, 1, 0), randf_range(-spread, spread))

	var range = weapons[current_weapon]["range"]
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position + direction * range,
		[get_rid()]
	)
	var result = space_state.intersect_ray(query)

	if result:
		var hit_pos = result.position
		var target = result.collider

		_spawn_impact_effect(hit_pos, result.normal)

		if target and target.has_method("take_damage"):
			var damage = weapons[current_weapon]["damage"]
			if target.has_method("get_hitbox_multiplier"):
				damage *= target.get_hitbox_multiplier(result.collision_face)
			target.take_damage(damage, "bullet", self)

func _reload() -> void:
	var weapon_data = weapons[current_weapon]

	if weapon_data["current_ammo"] >= weapon_data["max_ammo"] or weapon_data["reserve_ammo"] <= 0:
		return

	is_reloading = true
	_play_animation("reload")

	var reload_time = weapon_data["reload_time"]
	var needed = weapon_data["max_ammo"] - weapon_data["current_ammo"]
	var available = min(needed, weapon_data["reserve_ammo"])

	await get_tree().create_timer(reload_time).timeout

	weapon_data["current_ammo"] += available
	weapon_data["reserve_ammo"] -= available
	ammo_changed.emit(weapon_data["current_ammo"], weapon_data["reserve_ammo"])
	is_reloading = false

func _next_weapon() -> void:
	if weapon_slots.size() <= 1:
		return

	current_weapon_index = (current_weapon_index + 1) % weapon_slots.size()
	_switch_weapon(weapon_slots[current_weapon_index])

func _prev_weapon() -> void:
	if weapon_slots.size() <= 1:
		return

	current_weapon_index = (current_weapon_index - 1 + weapon_slots.size()) % weapon_slots.size()
	_switch_weapon(weapon_slots[current_weapon_index])

func _switch_weapon(weapon_id: String) -> void:
	if not weapons.has(weapon_id) or weapon_id == current_weapon:
		return

	if is_reloading:
		return

	current_weapon = weapon_id
	weapon_changed.emit(weapon_id)

	var weapon_data = weapons[weapon_id]
	ammo_changed.emit(weapon_data["current_ammo"], weapon_data["reserve_ammo"])
	UIManager.update_weapon_info(weapon_data["name"], weapon_data["current_ammo"], weapon_data["reserve_ammo"])

func give_weapon(weapon_id: String, ammo: int = -1) -> void:
	if not weapons.has(weapon_id):
		return

	if weapon_id not in weapon_slots:
		weapon_slots.append(weapon_id)

	if ammo >= 0:
		weapons[weapon_id]["reserve_ammo"] = ammo
		weapons[weapon_id]["current_ammo"] = min(weapons[weapon_id]["max_ammo"], ammo)

func unlock_weapon(weapon_id: String) -> void:
	if weapons.has(weapon_id) and weapon_id not in weapon_slots:
		weapon_slots.append(weapon_id)
		UIManager.show_notification("Unlocked: %s" % weapons[weapon_id]["name"], "success")

func take_damage(amount: float, damage_type: String = "generic", source: Node = null) -> void:
	if current_state == PlayerState.DEAD or current_state == PlayerState.ARRESTED:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_damage_time < invulnerability_time:
		return

	last_damage_time = current_time

	var actual_damage = amount

	if current_armor > 0.0:
		var armor_absorb = min(actual_damage * 0.8, current_armor)
		current_armor -= armor_absorb
		actual_damage -= armor_absorb
		armor_changed.emit(current_armor, max_armor)

	current_health = max(current_health - actual_damage, 0.0)
	health_changed.emit(current_health, max_health)

	_play_hurt_animation()
	UIManager.show_notification("Health: %d" % current_health, "warning" if current_health < 30 else "info")

	if current_health <= 0.0:
		die()

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func add_armor(amount: float) -> void:
	current_armor = min(current_armor + amount, max_armor)
	armor_changed.emit(current_armor, max_armor)

func die() -> void:
	current_state = PlayerState.DEAD
	died.emit()

	_enter_ragdoll()

	UIManager.show_notification("WASTED", "error", 3.0)

	var tween = create_tween()
	tween.tween_callback(_respawn.bind()).set_delay(5.0)

func _respawn() -> void:
	if WorldManager:
		var spawn_pos = WorldManager.get_spawn_position() if WorldManager.has_method("get_spawn_position") else Vector3(-200, 0, -100)
		global_position = spawn_pos
	else:
		global_position = Vector3(-200, 0, -100)

	current_health = max_health
	current_armor = 0.0
	current_state = PlayerState.ON_FOOT
	health_changed.emit(current_health, max_health)
	armor_changed.emit(current_armor, max_armor)

	visible = true
	collision_layer = 1
	collision_mask = 1 | 2 | 4 | 8

	if GameManager:
		GameManager.remove_money(GameManager.get_money() / 10)

func arrest() -> void:
	current_state = PlayerState.ARRESTED
	arrested.emit()

	velocity = Vector3.ZERO
	visible = false
	collision_layer = 0
	collision_mask = 0

	UIManager.show_notification("BUSTED", "error", 3.0)

	var tween = create_tween()
	tween.tween_callback(_release_from_jail.bind()).set_delay(5.0)

func _release_from_jail() -> void:
	if WorldManager:
		var spawn_pos = WorldManager.get_spawn_position() if WorldManager.has_method("get_spawn_position") else Vector3(-200, 0, -100)
		global_position = spawn_pos
	else:
		global_position = Vector3(-200, 0, -100)

	current_state = PlayerState.ON_FOOT
	visible = true
	collision_layer = 1
	collision_mask = 1 | 2 | 4 | 8

	if GameManager:
		GameManager.remove_money(GameManager.get_money() / 10)

func _enter_ragdoll() -> void:
	current_state = PlayerState.RAGDOLL
	ragdoll_timer = 0.0

	if animation_tree:
		animation_tree.active = false

	if collision_shape:
		collision_shape.disabled = true

func _get_up_from_ragdoll() -> void:
	if current_state != PlayerState.RAGDOLL:
		return

	current_state = PlayerState.ON_FOOT

	if animation_tree:
		animation_tree.active = true

	if collision_shape:
		collision_shape.disabled = false

func _play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func _update_animation(state: String, speed: float) -> void:
	if not animation_tree or not state_machine:
		return

	animation_tree.set("parameters/Idle/blend_position", 0.0)
	animation_tree.set("parameters/Walk/blend_position", speed / walk_speed)
	animation_tree.set("parameters/Run/blend_position", speed / run_speed)
	animation_tree.set("parameters/Sprint/blend_position", speed / sprint_speed)
	animation_tree.set("parameters/Crouch/blend_position", 1.0 if is_crouching else 0.0)
	animation_tree.set("parameters/Aim/blend_position", 1.0 if is_aiming else 0.0)

	if state_machine.get_current_node() != state:
		state_machine.travel(state)

func _play_sound(sound_name: String) -> void:
	if AudioManager:
		AudioManager.play_sfx_2d("res://assets/audio/sfx/ui/%s.ogg" % sound_name)

func _play_hurt_animation() -> void:
	_play_animation("hurt")

func _spawn_impact_effect(position: Vector3, normal: Vector3) -> void:
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.5
	particles.global_position = position
	particles.global_rotation = normal.get_rotation()
	add_child(particles)
	particles.finished.connect(particles.queue_free.bind())

func get_health() -> float:
	return current_health

func get_max_health() -> float:
	return max_health

func set_health(value: float) -> void:
	current_health = clamp(value, 0.0, max_health)
	health_changed.emit(current_health, max_health)

func get_armor() -> float:
	return current_armor

func get_max_armor() -> float:
	return max_armor

func set_armor(value: float) -> void:
	current_armor = clamp(value, 0.0, max_armor)
	armor_changed.emit(current_armor, max_armor)

func get_stamina() -> float:
	return current_stamina

func get_max_stamina() -> float:
	return max_stamina

func add_money(amount: int) -> void:
	if GameManager:
		GameManager.add_money(amount)
	money_changed.emit(GameManager.get_money() if GameManager else amount)

func get_current_weapon() -> String:
	return current_weapon

func get_weapon_data(weapon_id: String) -> Dictionary:
	return weapons.get(weapon_id, {})

func get_weapons() -> Array[String]:
	return weapon_slots.duplicate()

func is_in_vehicle() -> bool:
	return current_state == PlayerState.IN_VEHICLE

func get_vehicle() -> Node3D:
	return vehicle

func get_save_data() -> Dictionary:
	return {
		"health": current_health,
		"armor": current_armor,
		"stamina": current_stamina,
		"position": global_position,
		"rotation": global_rotation,
		"current_weapon": current_weapon,
		"weapon_slots": weapon_slots,
		"weapons": weapons,
		"money": GameManager.get_money() if GameManager else 0,
		"wanted_level": GameManager.get_wanted_level() if GameManager else 0
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("health"):
		current_health = data["health"]
		health_changed.emit(current_health, max_health)
	if data.has("armor"):
		current_armor = data["armor"]
		armor_changed.emit(current_armor, max_armor)
	if data.has("stamina"):
		current_stamina = data["stamina"]
		stamina_changed.emit(current_stamina, max_stamina)
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		global_rotation = data["rotation"]
	if data.has("current_weapon"):
		current_weapon = data["current_weapon"]
	if data.has("weapon_slots"):
		weapon_slots = data["weapon_slots"]
	if data.has("weapons"):
		weapons = data["weapons"]

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		InputManager.action_pressed.disconnect(_on_action_pressed)
		InputManager.action_released.disconnect(_on_action_released)