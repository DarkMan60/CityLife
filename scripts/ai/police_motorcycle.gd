extends VehicleBase
class_name PoliceMotorcycle

var siren_light: Sprite3D = null
var siren_sound: AudioStreamPlayer3D = null
var siren_active: bool = false
var light_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_setup_police_equipment()

func _setup_police_equipment() -> void:
	# Small light on handlebars
	siren_light = Sprite3D.new()
	siren_light.texture = preload("res://assets/textures/siren_light.png")
	siren_light.position = Vector3(0, 1.5, 1.0)
	siren_light.scale = Vector2(0.6, 0.6)
	siren_light.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(siren_light)
	siren_light.visible = false

	# Siren sound
	siren_sound = AudioStreamPlayer3D.new()
	siren_sound.stream = preload("res://assets/audio/vehicles/police_siren.ogg")
	siren_sound.bus = "SFX"
	siren_sound.max_distance = 60.0
	siren_sound.unit_db = 2.0
	add_child(siren_sound)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if traffic_mode:
		_update_siren(delta)

func _update_siren(delta: float) -> void:
	if not siren_active:
		return

	light_timer += delta
	var flash_speed = 12.0
	siren_light.visible = sin(light_timer * flash_speed) > 0.0
	siren_light.modulate = Color(1.0, 0.0, 0.0) if sin(light_timer * flash_speed * 0.5) > 0.0 else Color(0.0, 0.0, 1.0)

func initialize(level: int, player_target: Node3D) -> void:
	super.initialize(level, player_target)

	if VehicleManager:
		var def = VehicleManager.get_vehicle_definition("bati_801")
		if def:
			super.initialize(def)

	siren_active = true
	if siren_sound:
		siren_sound.play()

	# Very fast and agile
	target_speed = 160.0 / 3.6
	acceleration_rate = 12.0
	deceleration_rate = 15.0
	steering_sensitivity = 3.0

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

func _engage_target() -> void:
	# Motorcycle tries to pull alongside and officer shoots
	if not target:
		return

	var dist = global_position.distance_to(target.global_position)
	if dist < 10.0:
		# Close enough for officer to shoot
		_shoot_at_target()