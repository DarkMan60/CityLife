extends VehicleBase
class_name PolicePatrolCar

var siren_light: Sprite3D = null
var siren_sound: AudioStreamPlayer3D = null
var siren_active: bool = false
var light_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_setup_police_equipment()

func _setup_police_equipment() -> void:
	# Siren light
	siren_light = Sprite3D.new()
	siren_light.texture = preload("res://assets/textures/siren_light.png")
	siren_light.position = Vector3(0, 2.5, 0)
	siren_light.scale = Vector2(1.5, 1.5)
	siren_light.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(siren_light)
	siren_light.visible = false

	# Siren sound
	siren_sound = AudioStreamPlayer3D.new()
	siren_sound.stream = preload("res://assets/audio/vehicles/police_siren.ogg")
	siren_sound.bus = "SFX"
	siren_sound.max_distance = 100.0
	siren_sound.unit_db = 5.0
	add_child(siren_sound)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if traffic_mode:
		_update_siren(delta)

func _update_siren(delta: float) -> void:
	if not siren_active:
		return

	light_timer += delta
	var flash_speed = 8.0
	siren_light.visible = sin(light_timer * flash_speed) > 0.0
	siren_light.modulate = Color(1.0, 0.0, 0.0) if sin(light_timer * flash_speed * 0.5) > 0.0 else Color(0.0, 0.0, 1.0)

func initialize(level: int, player_target: Node3D) -> void:
	super.initialize(level, player_target)

	if VehicleManager:
		var def = VehicleManager.get_vehicle_definition("police_cruiser")
		if def:
			super.initialize(def)

	siren_active = true
	if siren_sound:
		siren_sound.play()

	# Make police car more aggressive
	target_speed = 120.0 / 3.6
	acceleration_rate = 8.0
	deceleration_rate = 10.0

func set_traffic_mode(enabled: bool, path: Array[String] = []) -> void:
	super.set_traffic_mode(enabled, path)
	if enabled:
		siren_active = true
		if siren_sound:
			siren_sound.play()
	else:
		siren_active = false
		if siren_sound:
			siren_sound.stop()
		if siren_light:
			siren_light.visible = false

func _ram_target() -> void:
	# Override to ram player vehicle
	if target and target.has_method("get_vehicle"):
		var player_vehicle = target.get_vehicle()
		if player_vehicle:
			var direction = (player_vehicle.global_position - global_position).normalized()
			apply_central_impulse(direction * mass * 50.0)