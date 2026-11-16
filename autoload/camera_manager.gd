extends Node

signal camera_mode_changed(mode: int)

enum CameraMode {
	THIRD_PERSON = 0,
	FIRST_PERSON = 1,
	VEHICLE = 2,
	AIM = 3,
	CINEMATIC = 4
}

static var instance: CameraManager = null

var current_mode: CameraMode = CameraMode.THIRD_PERSON
var target: Node3D = null
var player: Node3D = null
var vehicle: Node3D = null

var third_person_distance: float = 5.0
var third_person_height: float = 2.0
var third_person_target_height: float = 1.5
var vehicle_distance: float = 8.0
var vehicle_height: float = 3.0
var vehicle_target_height: float = 1.0

var min_distance: float = 1.5
var max_distance: float = 15.0
var zoom_speed: float = 5.0

var rotation_x: float = 0.0
var rotation_y: float = 0.0
var target_rotation_x: float = 0.0
var target_rotation_y: float = 0.0

var camera: Camera3D = null
var pivot: Node3D = null
var spring_arm: SpringArm3D = null

var collision_layers: int = 1 | 2
var collision_mask: int = 1 | 2

var shake_intensity: float = 0.0
var shake_decay: float = 10.0
var shake_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	instance = self
	_setup_camera()

func _setup_camera() -> void:
	# Create the camera hierarchy: CameraManager -> Pivot -> SpringArm3D -> Camera3D
	pivot = Node3D.new()
	add_child(pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.spring_length = third_person_distance
	spring_arm.margin = 0.1
	spring_arm.collision_mask = collision_layers
	pivot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 2000.0
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_SKY
	camera.position = Vector3(0, 0, 0)
	spring_arm.add_child(camera)

func _process(delta: float) -> void:
	if not target:
		return

	_update_camera(delta)
	_apply_shake(delta)

func _update_camera(delta: float) -> void:
	var target_pos = target.global_position
	var target_rot = target.global_rotation

	match current_mode:
		CameraMode.THIRD_PERSON:
			_update_third_person(delta, target_pos, target_rot)
		CameraMode.FIRST_PERSON:
			_update_first_person(delta, target_pos, target_rot)
		CameraMode.VEHICLE:
			_update_vehicle(delta, target_pos, target_rot)
		CameraMode.AIM:
			_update_aim(delta, target_pos, target_rot)
		CameraMode.CINEMATIC:
			_update_cinematic(delta, target_pos, target_rot)

func _update_third_person(delta: float, target_pos: Vector3, target_rot: Vector3) -> void:
	var desired_pos = target_pos + Vector3(0, third_person_target_height, 0)
	pivot.global_position = lerp(pivot.global_position, desired_pos, delta * 15.0)

	rotation_y = lerp_angle(rotation_y, target_rotation_y, delta * 10.0)
	rotation_x = clamp(lerp(rotation_x, target_rotation_x, delta * 10.0), -PI/2 + 0.1, PI/2 - 0.1)

	pivot.global_rotation = Vector3(rotation_x, rotation_y, 0)

	spring_arm.spring_length = lerp(spring_arm.spring_length, third_person_distance, delta * zoom_speed)

func _update_first_person(delta: float, target_pos: Vector3, target_rot: Vector3) -> void:
	var head_pos = target_pos + Vector3(0, 1.6, 0)
	pivot.global_position = lerp(pivot.global_position, head_pos, delta * 20.0)

	pivot.global_rotation = target_rot
	spring_arm.spring_length = 0.0

func _update_vehicle(delta: float, target_pos: Vector3, target_rot: Vector3) -> void:
	if not vehicle:
		return

	var desired_pos = target_pos + Vector3(0, vehicle_target_height, 0)
	pivot.global_position = lerp(pivot.global_position, desired_pos, delta * 10.0)

	var vehicle_rot = vehicle.global_rotation
	rotation_y = lerp_angle(rotation_y, vehicle_rot.y, delta * 5.0)
	rotation_x = clamp(lerp(rotation_x, target_rotation_x, delta * 10.0), -PI/3, PI/4)

	pivot.global_rotation = Vector3(rotation_x, rotation_y, 0)
	spring_arm.spring_length = lerp(spring_arm.spring_length, vehicle_distance, delta * zoom_speed)

func _update_aim(delta: float, target_pos: Vector3, target_rot: Vector3) -> void:
	var aim_pos = target_pos + Vector3(0, 1.55, 0)
	pivot.global_position = lerp(pivot.global_position, aim_pos, delta * 20.0)

	pivot.global_rotation = target_rot
	spring_arm.spring_length = 0.5

func _update_cinematic(delta: float, target_pos: Vector3, target_rot: Vector3) -> void:
	pass

func _apply_shake(delta: float) -> void:
	if shake_intensity > 0.0:
		shake_offset = Vector3(
			randf_range(-1, 1) * shake_intensity,
			randf_range(-1, 1) * shake_intensity,
			randf_range(-1, 1) * shake_intensity
		)
		camera.position += shake_offset
		shake_intensity = max(0.0, shake_intensity - shake_decay * delta)
	else:
		shake_offset = Vector3.ZERO

func set_target(new_target: Node3D) -> void:
	target = new_target

func set_player(new_player: Node3D) -> void:
	player = new_player
	if current_mode in [CameraMode.THIRD_PERSON, CameraMode.FIRST_PERSON, CameraMode.AIM]:
		target = player

func set_vehicle(new_vehicle: Node3D) -> void:
	vehicle = new_vehicle
	if current_mode == CameraMode.VEHICLE:
		target = vehicle

func set_mode(mode: CameraMode) -> void:
	if current_mode == mode:
		return

	var old_mode = current_mode
	current_mode = mode

	match mode:
		CameraMode.THIRD_PERSON:
			target = player
			spring_arm.spring_length = third_person_distance
		CameraMode.FIRST_PERSON:
			target = player
			spring_arm.spring_length = 0.0
		CameraMode.VEHICLE:
			target = vehicle
			spring_arm.spring_length = vehicle_distance
		CameraMode.AIM:
			target = player
			spring_arm.spring_length = 0.5
		CameraMode.CINEMATIC:
			target = null

	camera_mode_changed.emit(int(mode))

func get_mode() -> CameraMode:
	return current_mode

func toggle_first_person() -> void:
	if current_mode == CameraMode.FIRST_PERSON:
		set_mode(CameraMode.THIRD_PERSON)
	else:
		set_mode(CameraMode.FIRST_PERSON)

func set_distance(dist: float) -> void:
	third_person_distance = clamp(dist, min_distance, max_distance)
	if current_mode == CameraMode.VEHICLE:
		vehicle_distance = clamp(dist, min_distance * 2, max_distance * 2)

func add_shake(intensity: float) -> void:
	shake_intensity = max(shake_intensity, intensity)

func get_camera() -> Camera3D:
	return camera

func get_pivot() -> Node3D:
	return pivot

func get_save_data() -> Dictionary:
	return {
		"mode": int(current_mode),
		"distance": third_person_distance,
		"rotation_x": rotation_x,
		"rotation_y": rotation_y,
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("mode"):
		set_mode(data["mode"])
	if data.has("distance"):
		set_distance(data["distance"])
	if data.has("rotation_x"):
		rotation_x = data["rotation_x"]
	if data.has("rotation_y"):
		rotation_y = data["rotation_y"]

func set_max_distance(distance: float) -> void:
	if camera:
		camera.far = distance
	max_distance = distance