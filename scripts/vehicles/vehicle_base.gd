extends VehicleBody3D
class_name VehicleBase

signal entered(player: Node3D)
signal exited(player: Node3D)
signal destroyed()
signal damaged(amount: float)

@export var vehicle_id: String = ""
@export var vehicle_name: String = "Vehicle"
@export var vehicle_class: VehicleManager.VehicleClass = VehicleManager.VehicleClass.FAMILY
@export var price: int = 0
@export var stats: Dictionary = {"speed": 60, "acceleration": 50, "handling": 50, "braking": 50, "durability": 70}

var engine_force: float = 1000.0
var brake_force: float = 2000.0
var max_speed: float = 50.0
var steering: float = 0.0
var acceleration: float = 0.0
var current_gear: int = 1
var rpm: float = 0.0
var max_rpm: float = 8000.0
var idle_rpm: float = 800.0
var redline_rpm: float = 7500.0

var health: float = 100.0
var max_health: float = 100.0
var fuel: float = 100.0
var max_fuel: float = 100.0
var fuel_consumption_rate: float = 0.1

var is_engine_on: bool = false
var is_player_vehicle: bool = false
var driver: Node3D = null
var passengers: Array[Node3D] = []

var engine_sound: AudioStreamPlayer3D = null
var exhaust_particles: GPUParticles3D = null

@onready var collision_shape: CollisionShape3D = %CollisionShape
@onready var mesh_instance: MeshInstance3D = %MeshInstance
@onready var wheel_fr: VehicleWheel3D = %WheelFR
@onready var wheel_fl: VehicleWheel3D = %WheelFL
@onready var wheel_rr: VehicleWheel3D = %WheelRR
@onready var wheel_rl: VehicleWheel3D = %WheelRL

func _ready() -> void:
	_setup_vehicle()
	_setup_audio()
	_setup_effects()

func _setup_vehicle() -> void:
	max_speed = stats["speed"] * 0.5
	engine_force = stats["acceleration"] * 15.0
	brake_force = stats["braking"] * 20.0

	engine_force = engine_force
	brake_force = brake_force

	health = stats["durability"]
	max_health = stats["durability"]

	set_wheel_properties()

func set_wheel_properties() -> void:
	var wheels = [wheel_fr, wheel_fl, wheel_rr, wheel_rl]
	for wheel in wheels:
		if wheel:
			wheel.friction_slip = stats["handling"] * 0.02
			wheel.suspension_stiffness = 25.0
			wheel.suspension_max_force = 5000.0

func _setup_audio() -> void:
	engine_sound = AudioStreamPlayer3D.new()
	engine_sound.stream = preload("res://assets/audio/vehicles/engine_loop.ogg")
	engine_sound.bus = "SFX"
	engine_sound.unit_db = -10.0
	engine_sound.max_distance = 50.0
	engine_sound.attenuation_filter_cutoff_hz = 5000.0
	add_child(engine_sound)

func _setup_effects() -> void:
	exhaust_particles = GPUParticles3D.new()
	exhaust_particles.amount = 10
	exhaust_particles.lifetime = 0.5
	exhaust_particles.one_shot = false
	exhaust_particles.process_material = ParticleProcessMaterial.new()
	exhaust_particles.process_material.gravity = Vector3(0, -2, 0)
	exhaust_particles.process_material.initial_velocity = Vector3(0, 2, 0)
	exhaust_particles.emitting = false
	add_child(exhaust_particles)

func _physics_process(delta: float) -> void:
	if not is_engine_on:
		return

	_update_engine(delta)
	_handle_input(delta)
	_update_wheels(delta)
	_consume_fuel(delta)
	_check_destruction()

func _update_engine(delta: float) -> void:
	var target_rpm = idle_rpm
	if abs(acceleration) > 0.1:
		target_rpm = lerp(idle_rpm, redline_rpm, abs(acceleration))

	rpm = lerp(rpm, target_rpm, delta * 5.0)

	if engine_sound and engine_sound.stream:
		engine_sound.pitch_scale = lerp(0.5, 2.0, (rpm - idle_rpm) / (redline_rpm - idle_rpm))
		if not engine_sound.playing:
			engine_sound.play()

func _handle_input(delta: float) -> void:
	if is_player_vehicle and InputManager:
		var input_vector = InputManager.get_movement_vector()
		acceleration = input_vector.y
		steering = -input_vector.x

		if Input.is_action_pressed("vehicle_brake"):
			brake(brake_force)
		else:
			brake(0.0)

		if Input.is_action_just_pressed("vehicle_handbrake"):
			brake(brake_force * 2.0, true)
	else:
		acceleration = 0.0
		steering = 0.0

func _update_wheels(delta: float) -> void:
	engine_force = engine_force * acceleration
	steering = steering * 0.5

func _consume_fuel(delta: float) -> void:
	if rpm > idle_rpm:
		fuel = max(0.0, fuel - fuel_consumption_rate * (rpm / redline_rpm) * delta)
		if fuel <= 0.0:
			stall_engine()

func _check_destruction() -> void:
	if health <= 0.0:
		destroy_vehicle()

func start_engine() -> void:
	is_engine_on = true
	rpm = idle_rpm
	if engine_sound:
		engine_sound.play()

func stop_engine() -> void:
	is_engine_on = false
	rpm = 0.0
	if engine_sound:
		engine_sound.stop()
	if exhaust_particles:
		exhaust_particles.emitting = false

func stall_engine() -> void:
	stop_engine()
	UIManager.show_notification("Engine stalled - out of fuel!", "warning")

func initialize(definition: Dictionary) -> void:
	vehicle_id = definition["id"]
	vehicle_name = definition["name"]
	vehicle_class = definition["class"]
	price = definition["price"]
	stats = definition["stats"]

	set_meta("vehicle_id", vehicle_id)
	_setup_vehicle()

func can_enter() -> bool:
	return driver == null and health > 0.0

func enter_vehicle(player: Node3D) -> bool:
	if not can_enter():
		return false

	driver = player
	is_player_vehicle = player == GameManager.get_player() if GameManager else false

	start_engine()

	if is_player_vehicle:
		player.global_position = global_position + Vector3(0, 2, 0)
		player.visible = false
		CameraManager.set_vehicle_camera(self) if CameraManager else null

	entered.emit(player)
	return true

func exit_vehicle(player: Node3D) -> void:
	if driver != player:
		return

	stop_engine()
	driver = null
	is_player_vehicle = false

	if player:
		player.global_position = global_position + Vector3(3, 0, 0)
		player.visible = true
		CameraManager.set_player_camera(player) if CameraManager else null

	exited.emit(player)

func take_damage(amount: float, source: Node = null) -> void:
	health = max(0.0, health - amount)
	damaged.emit(amount)

	if AudioManager:
		AudioManager.play_sfx_3d("res://assets/audio/sfx/vehicle_hit.ogg", global_position)

	if health <= 0.0:
		destroy_vehicle()

func destroy_vehicle() -> void:
	destroyed.emit()

	if exhaust_particles:
		exhaust_particles.emitting = true
		exhaust_particles.process_material.gravity = Vector3(0, 5, 0)
		exhaust_particles.process_material.initial_velocity = Vector3(0, 10, 0)
		exhaust_particles.amount = 100
		exhaust_particles.lifetime = 2.0

	if VehicleManager:
		VehicleManager.despawn_vehicle(self)

	queue_free()

func repair() -> void:
	health = max_health
	if AudioManager:
		AudioManager.play_sfx_3d("res://assets/audio/sfx/repair.ogg", global_position)

func refuel() -> void:
	fuel = max_fuel

func apply_customization(options: Dictionary) -> void:
	if options.has("color") and mesh_instance:
		var material = mesh_instance.get_surface_override_material(0)
		if not material:
			material = StandardMaterial3D.new()
			mesh_instance.set_surface_override_material(0, material)
		material.albedo_color = options["color"]

	if options.has("rims"):
		# Apply rim customization
		pass

	if options.has("spoiler"):
		# Apply spoiler
		pass

func get_save_data() -> Dictionary:
	return {
		"vehicle_id": vehicle_id,
		"position": global_position,
		"rotation": global_rotation,
		"health": health,
		"fuel": fuel,
		"customization": {}
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		global_rotation = data["rotation"]
	if data.has("health"):
		health = data["health"]
	if data.has("fuel"):
		fuel = data["fuel"]