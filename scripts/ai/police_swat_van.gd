extends VehicleBase
class_name PoliceSWATVan

var siren_light: Sprite3D = null
var siren_sound: AudioStreamPlayer3D = null
var siren_active: bool = false
var light_timer: float = 0.0
var swat_deployed: bool = false
var deploy_cooldown: float = 0.0

func _ready() -> void:
	super._ready()
	_setup_police_equipment()

func _setup_police_equipment() -> void:
	# Roof-mounted light bar
	siren_light = Sprite3D.new()
	siren_light.texture = preload("res://assets/textures/siren_light.png")
	siren_light.position = Vector3(0, 3.0, 0)
	siren_light.scale = Vector2(2.0, 1.0)
	siren_light.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(siren_light)
	siren_light.visible = false

	# Siren sound
	siren_sound = AudioStreamPlayer3D.new()
	siren_sound.stream = preload("res://assets/audio/vehicles/police_siren.ogg")
	siren_sound.bus = "SFX"
	siren_sound.max_distance = 150.0
	siren_sound.unit_db = 8.0
	add_child(siren_sound)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if traffic_mode:
		_update_siren(delta)

	if deploy_cooldown > 0:
		deploy_cooldown -= delta

func _update_siren(delta: float) -> void:
	if not siren_active:
		return

	light_timer += delta
	var flash_speed = 6.0
	siren_light.visible = sin(light_timer * flash_speed) > 0.0
	siren_light.modulate = Color(1.0, 0.0, 0.0) if sin(light_timer * flash_speed * 0.5) > 0.0 else Color(0.0, 0.0, 1.0)

func initialize(level: int, player_target: Node3D) -> void:
	super.initialize(level, player_target)

	if VehicleManager:
		# Use hauler as base for SWAT van
		var def = VehicleManager.get_vehicle_definition("hauler")
		if def:
			# Override stats for SWAT van
			def["stats"]["speed"] = 70
			def["stats"]["acceleration"] = 50
			def["stats"]["handling"] = 55
			def["stats"]["braking"] = 60
			def["stats"]["durability"] = 120
			super.initialize(def)

	siren_active = true
	if siren_sound:
		siren_sound.play()

	# Slower but more durable
	target_speed = 80.0 / 3.6
	acceleration_rate = 4.0
	deceleration_rate = 8.0

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
	# SWAT van deploys officers and rams
	if deploy_cooldown <= 0 and not swat_deployed and target:
		_deploy_swat_team()
		deploy_cooldown = 20.0

	# Ram if close
	var dist = global_position.distance_to(target.global_position)
	if dist < 15.0:
		_ram_target()

func _deploy_swat_team() -> void:
	if not target:
		return

	swat_deployed = true

	var deploy_positions = [
		global_position + global_transform.basis.x * 3.0 + Vector3(0, 0, 2.0),
		global_position - global_transform.basis.x * 3.0 + Vector3(0, 0, 2.0),
		global_position + global_transform.basis.x * 3.0 + Vector3(0, 0, -2.0),
		global_position - global_transform.basis.x * 3.0 + Vector3(0, 0, -2.0),
	]

	for i, pos in deploy_positions:
		var scene = PoliceManager.unit_scenes.get(PoliceManager.PoliceUnitType.FOOT_OFFICER)
		if scene:
			var unit = scene.instantiate()
			unit.global_position = pos
			add_child(unit)
			PoliceManager.active_units.append(unit)

			if unit.has_method("initialize"):
				unit.initialize(current_wanted_level, target)

			PoliceManager.police_spawned.emit(unit)

	if AudioManager:
		AudioManager.play_sfx_3d("res://assets/audio/sfx/van_doors.ogg", global_position)

func _ram_target() -> void:
	if not target:
		return

	var direction = (target.global_position - global_position).normalized()
	apply_central_impulse(direction * mass * 30.0)