extends VehicleBase
class_name PoliceHelicopter

var rotor: MeshInstance3D = null
var searchlight: SpotLight3D = null
var siren_sound: AudioStreamPlayer3D = nil
var rotor_sound: AudioStreamPlayer3D = nil
var rotor_speed: float = 0.0
var target_rotor_speed: float = 0.0
var altitude: float = 80.0
var target_altitude: float = 80.0
var spotlight_target: Node3D = null
var deploy_timer: float = 0.0
var deploy_interval: float = 30.0

@onready var collision_shape: CollisionShape3D = %CollisionShape

func _ready() -> void:
	super._ready()
	_setup_helicopter()

func _setup_helicopter() -> void:
	# Main rotor
	rotor = MeshInstance3D.new()
	rotor.mesh = CylinderMesh.new()
	rotor.mesh.radius = 4.0
	rotor.mesh.height = 0.1
	rotor.position = Vector3(0, 2.5, 0)
	var rotor_mat = StandardMaterial3D.new()
	rotor_mat.albedo_color = Color(0.1, 0.1, 0.1)
	rotor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rotor_mat.alpha_scissor_threshold = 0.5
	rotor.set_surface_override_material(0, rotor_mat)
	add_child(rotor)

	# Tail rotor
	var tail_rotor = MeshInstance3D.new()
	tail_rotor.mesh = CylinderMesh.new()
	tail_rotor.mesh.radius = 0.8
	tail_rotor.mesh.height = 0.05
	tail_rotor.position = Vector3(0, 1.5, -5.5)
	tail_rotor.rotation.x = PI / 2
	add_child(tail_rotor)

	# Searchlight
	searchlight = SpotLight3D.new()
	searchlight.light_color = Color(1, 1, 0.9)
	searchlight.light_energy = 100000.0
	searchlight.spot_angle = 30.0
	searchlight.spot_attenuation = 1.0
	searchlight.range = 200.0
	searchlight.position = Vector3(0, 1.0, 1.0)
	searchlight.rotation.x = -PI / 3
	add_child(searchlight)

	# Sounds
	rotor_sound = AudioStreamPlayer3D.new()
	rotor_sound.stream = preload("res://assets/audio/vehicles/helicopter_rotor.ogg")
	rotor_sound.bus = "SFX"
	rotor_sound.max_distance = 500.0
	rotor_sound.unit_db = 10.0
	add_child(rotor_sound)

	siren_sound = AudioStreamPlayer3D.new()
	siren_sound.stream = preload("res://assets/audio/vehicles/police_siren.ogg")
	siren_sound.bus = "SFX"
	siren_sound.max_distance = 300.0
	siren_sound.unit_db = 8.0
	add_child(siren_sound)

func _physics_process(delta: float) -> void:
	if not is_engine_on:
		return

	_update_rotor(delta)
	_update_flight(delta)
	_update_searchlight(delta)
	_update_deployment(delta)

	super._physics_process(delta)

func _update_rotor(delta: float) -> void:
	rotor_speed = lerp(rotor_speed, target_rotor_speed, delta * 3.0)

	if rotor:
		rotor.rotation.y += rotor_speed * delta * 50.0

	if rotor_sound:
		rotor_sound.pitch_scale = lerp(0.5, 1.5, rotor_speed)
		if not rotor_sound.playing and rotor_speed > 0.1:
			rotor_sound.play()

func _update_flight(delta: float) -> void:
	if not target:
		return

	var target_pos = target.global_position + Vector3(0, altitude, 0)
	var to_target = target_pos - global_position
	var distance = to_target.length()

	# Horizontal movement
	var horizontal_dir = Vector3(to_target.x, 0, to_target.z).normalized()
	var horizontal_speed = min(distance * 0.5, 50.0)
	velocity.x = horizontal_dir.x * horizontal_speed
	velocity.z = horizontal_dir.z * horizontal_speed

	# Vertical movement
	var height_diff = target_pos.y - global_position.y
	velocity.y = height_diff * 2.0

	# Face target
	if horizontal_dir != Vector3.ZERO:
		var target_rot = atan2(horizontal_dir.x, horizontal_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 2.0)

	move_and_slide()

func _update_searchlight(delta: float) -> void:
	if not searchlight or not target:
		return

	var to_target = (target.global_position + Vector3(0, 1.5, 0)) - global_position
	searchlight.look_at(global_position + to_target, Vector3.UP)

func _update_deployment(delta: float) -> void:
	if current_wanted_level < 3:
		return

	deploy_timer += delta
	if deploy_timer >= deploy_interval:
		deploy_timer = 0.0
		_deploy_swat_team()

func _deploy_swat_team() -> void:
	if not target:
		return

	var deploy_pos = global_position + Vector3(0, -altitude + 2, 0)

	if PoliceManager:
		for i in range(4):
			var angle = (i * PI / 2) + randf_range(-0.5, 0.5)
			var pos = deploy_pos + Vector3(cos(angle) * 5.0, 0, sin(angle) * 5.0)

			var scene = PoliceManager.unit_scenes.get(PoliceManager.PoliceUnitType.FOOT_OFFICER)
			if scene:
				var unit = scene.instantiate()
				unit.global_position = pos
				add_child(unit)
				PoliceManager.active_units.append(unit)

				if unit.has_method("initialize"):
					unit.initialize(current_wanted_level, target)

				PoliceManager.police_spawned.emit(unit)

func initialize(level: int, player_target: Node3D) -> void:
	current_wanted_level = level
	target = player_target
	is_engine_on = true
	target_rotor_speed = 1.0
	target_altitude = altitude

	if VehicleManager:
		var def = VehicleManager.get_vehicle_definition("police_helicopter")
		if def:
			super.initialize(def)

	if rotor_sound:
		rotor_sound.play()
	if siren_sound:
		siren_sound.play()

func can_see_player(player_pos: Vector3) -> bool:
	var dist = global_position.distance_to(player_pos)
	if dist > 200.0:
		return false

	# Helicopter has good visibility
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, player_pos + Vector3(0, 1.5, 0))
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]

	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		if collider == target or (collider.is_in_group("player") if collider else false):
			return true
		return false

	return true

func _engage_target() -> void:
	# Helicopter shoots from above
	_shoot_at_target()

func _shoot_at_target() -> void:
	if not target:
		return

	var now = Time.get_ticks_msec() / 1000.0
	if now - last_shot_time < 1.0:
		return

	last_shot_time = now

	if randf() < 0.4:  # Lower accuracy from helicopter
		if target.has_method("take_damage"):
			target.take_damage(25.0, self)

		if AudioManager:
			AudioManager.play_sfx_3d("res://assets/audio/sfx/helicopter_gun.ogg", global_position)

func take_damage(amount: float, source: Node = null) -> void:
	super.take_damage(amount, source)

	if health < max_health * 0.3:
		# Damaged helicopter tries to retreat
		target_altitude = 150.0