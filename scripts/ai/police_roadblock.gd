extends StaticBody3D
class_name PoliceRoadblock

signal player_spotted(position: Vector3)
signal player_passed()
signal damaged(amount: float)
signal destroyed()

enum RoadblockState {
	ACTIVE = 0,
	BREACHED = 1,
	DESTROYED = 2
}

var current_state: RoadblockState = RoadblockState.ACTIVE
var target: Node3D = null
var wanted_level: int = 1
var health: float = 500.0
var max_health: float = 500.0
var armor: float = 200.0
var spike_strips_deployed: bool = false
var officers: Array[Node3D] = []
var max_officers: int = 4

@onready var collision_shape: CollisionShape3D = %CollisionShape
@onready var barrier_mesh: MeshInstance3D = %BarrierMesh
@onready var light_flasher: Sprite3D = %LightFlasher
@onready var spike_strips: MeshInstance3D = %SpikeStrips

func _ready() -> void:
	_setup_roadblock()

func _setup_roadblock() -> void:
	# Main barrier
	if not barrier_mesh:
		barrier_mesh = MeshInstance3D.new()
		barrier_mesh.mesh = BoxMesh.new()
		barrier_mesh.mesh.size = Vector3(10.0, 1.5, 2.0)
		barrier_mesh.position = Vector3(0, 0.75, 0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.5, 0.5)
		barrier_mesh.set_surface_override_material(0, mat)
		add_child(barrier_mesh)

	# Second barrier (other lane)
	var barrier2 = MeshInstance3D.new()
	barrier2.mesh = BoxMesh.new()
	barrier2.mesh.size = Vector3(10.0, 1.5, 2.0)
	barrier2.position = Vector3(0, 0.75, 4.0)
	barrier2.set_surface_override_material(0, mat)
	add_child(barrier2)

	# Warning lights
	if not light_flasher:
		light_flasher = Sprite3D.new()
		light_flasher.texture = preload("res://assets/textures/siren_light.png")
		light_flasher.position = Vector3(0, 3.0, 1.0)
		light_flasher.scale = Vector2(1.5, 1.5)
		light_flasher.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(light_flasher)

	# Spike strips
	if not spike_strips:
		spike_strips = MeshInstance3D.new()
		spike_strips.mesh = BoxMesh.new()
		spike_strips.mesh.size = Vector3(12.0, 0.1, 0.5)
		spike_strips.position = Vector3(0, 0.1, -5.0)
		var spike_mat = StandardMaterial3D.new()
		spike_mat.albedo_color = Color(0.2, 0.2, 0.2)
		spike_strips.set_surface_override_material(0, spike_mat)
		spike_strips.visible = false
		add_child(spike_strips)

	# Collision shape covering both lanes
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.shape = BoxShape3D.new()
		collision_shape.shape.size = Vector3(12.0, 2.0, 8.0)
		collision_shape.position = Vector3(0, 1.0, 2.0)
		add_child(collision_shape)

	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)

func _process(delta: float) -> void:
	if current_state == RoadblockState.DESTROYED:
		return

	_update_lights(delta)
	_check_breach()
	_manage_officers(delta)

func _update_lights(delta: float) -> void:
	if light_flasher:
		var t = Time.get_ticks_msec() / 1000.0 * 10.0
		light_flasher.visible = sin(t) > 0.0
		light_flasher.modulate = Color(1.0, 0.0, 0.0) if sin(t * 0.5) > 0.0 else Color(0.0, 0.0, 1.0)

func _check_breach() -> void:
	if current_state != RoadblockState.ACTIVE:
		return

	if not target:
		return

	var dist = global_position.distance_to(target.global_position)
	if dist < 15.0:
		# Check if player vehicle is trying to ram through
		if target.has_method("get_vehicle"):
			var vehicle = target.get_vehicle()
			if vehicle and vehicle.has_method("get_linear_velocity"):
				var speed = vehicle.get_linear_velocity().length()
				if speed > 20.0:  # Fast enough to breach
					_breach()

func _breach() -> void:
	current_state = RoadblockState.BREACHED

	# Deploy spike strips
	if not spike_strips_deployed:
		_deploy_spike_strips()

	# Alert officers
	for officer in officers:
		if officer and is_instance_valid(officer) and officer.has_method("on_breach"):
			officer.on_breach()

	if AudioManager:
		AudioManager.play_sfx_3d("res://assets/audio/sfx/barrier_breach.ogg", global_position)

func _deploy_spike_strips() -> void:
	spike_strips_deployed = true
	if spike_strips:
		spike_strips.visible = true
		# Spike strips damage tires of vehicles that drive over them

func _manage_officers(delta: float) -> void:
	# Clean up dead officers
	var alive_officers = []
	for officer in officers:
		if officer and is_instance_valid(officer):
			alive_officers.append(officer)
	officers = alive_officers

	# Spawn replacement officers if needed
	if officers.size() < max_officers and current_state == RoadblockState.ACTIVE:
		if randf() < 0.01:
			_spawn_officer()

func _spawn_officer() -> void:
	if PoliceManager:
		var scene = PoliceManager.unit_scenes.get(PoliceManager.PoliceUnitType.FOOT_OFFICER)
		if scene:
			var angle = randf() * TAU
			var pos = global_position + Vector3(cos(angle) * 8.0, 0, sin(angle) * 8.0)

			var officer = scene.instantiate()
			officer.global_position = pos
			add_child(officer)
			officers.append(officer)

			if officer.has_method("initialize"):
				officer.initialize(wanted_level, target)

			PoliceManager.police_spawned.emit(officer)

func on_body_entered(body: Node3D) -> void:
	# Check for vehicles hitting spike strips
	if spike_strips_deployed and body.has_method("get_vehicle_type"):
		if body.global_position.z < global_position.z:  # Approaching from front
			_damage_tires(body)

func _damage_tires(vehicle: Node3D) -> void:
	if vehicle.has_method("damage_tires"):
		vehicle.damage_tires()

	if AudioManager:
		AudioManager.play_sfx_3d("res://assets/audio/sfx/tire_pop.ogg", global_position)

func initialize(level: int, player_target: Node3D) -> void:
	wanted_level = level
	target = player_target
	current_state = RoadblockState.ACTIVE

	set_meta("police_unit_type", "roadblock")

	# Spawn initial officers
	for i in range(max_officers):
		_spawn_officer()

func take_damage(amount: float, source: Node = null) -> void:
	if current_state == RoadblockState.DESTROYED:
		return

	var actual_damage = max(0.0, amount - armor)
	health -= actual_damage
	damaged.emit(actual_damage)

	if health <= 0:
		destroy()
	elif health < max_health * 0.3:
		# Barriers damaged visually
		if barrier_mesh:
			barrier_mesh.modulate = Color(0.5, 0.3, 0.3)

func destroy() -> void:
	current_state = RoadblockState.DESTROYED
	destroyed.emit()

	# Remove officers
	for officer in officers:
		if officer and is_instance_valid(officer):
			officer.queue_free()
	officers.clear()

	# Visual destruction
	if barrier_mesh:
		barrier_mesh.visible = false
	if collision_shape:
		collision_shape.disabled = true

	# Debris particles
	var debris = GPUParticles3D.new()
	debris.amount = 50
	debris.lifetime = 2.0
	debris.one_shot = true
	debris.process_material = ParticleProcessMaterial.new()
	debris.process_material.gravity = Vector3(0, -9.8, 0)
	debris.process_material.initial_velocity = Vector3(0, 5, 0)
	debris.process_material.spawn_position = Vector3(0, 1, 0)
	debris.emitting = true
	add_child(debris)

	if PoliceManager:
		PoliceManager.remove_unit(self)

	# Despawn after effects
	call_deferred("_despawn_later")

func _despawn_later() -> void:
	await get_tree().create_timer(5.0).timeout
	queue_free()

func get_save_data() -> Dictionary:
	return {
		"unit_type": 7,  # ROADBLOCK
		"position": global_position,
		"rotation": global_rotation,
		"health": health,
		"state": int(current_state),
		"wanted_level": wanted_level,
		"spike_strips_deployed": spike_strips_deployed,
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
	if data.has("spike_strips_deployed"):
		spike_strips_deployed = data["spike_strips_deployed"]
		if spike_strips:
			spike_strips.visible = spike_strips_deployed