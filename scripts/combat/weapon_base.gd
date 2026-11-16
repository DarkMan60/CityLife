extends Node3D
class_name WeaponBase

signal fired(position: Vector3, direction: Vector3)
signal reloaded()
signal ammo_changed(current: int, max: int)
signal weapon_switched()

enum WeaponType {
	MELEE = 0,
	PISTOL = 1,
	SMG = 2,
	RIFLE = 3,
	SHOTGUN = 4,
	SNIPER = 5,
	RPG = 6,
	THROWN = 7
}

enum FireMode {
	SEMI_AUTO = 0,
	FULL_AUTO = 1,
	BURST = 2,
	SINGLE = 3
}

@export var weapon_id: String = ""
@export var weapon_name: String = "Weapon"
@export var weapon_type: WeaponType = WeaponType.PISTOL
@export var fire_mode: FireMode = FireMode.SEMI_AUTO
@export var damage: float = 25.0
@export var range: float = 50.0
@export var fire_rate: float = 0.15
@export var max_ammo: int = 30
@export var max_reserve_ammo: int = 120
@export var reload_time: float = 2.0
@export var spread: float = 0.02
@export var recoil: float = 0.5
@export var projectile_speed: float = 500.0
@export var projectile_gravity: float = 0.0
@export var penetration: float = 0.0
@export var explosion_radius: float = 0.0
@export var price: int = 1000

var current_ammo: int = 30
var reserve_ammo: int = 120
var is_reloading: bool = false
var last_fire_time: float = 0.0
var burst_count: int = 0
var burst_max: int = 3

var muzzle_flash: GPUParticles3D = null
var muzzle_light: OmniLight3D = null
var fire_sound: AudioStreamPlayer3D = null
var reload_sound: AudioStreamPlayer3D = nil
var empty_sound: AudioStreamPlayer3D = null

var owner: Node3D = null
var is_equipped: bool = false

func _ready() -> void:
	_setup_effects()
	_setup_audio()
	current_ammo = max_ammo
	reserve_ammo = max_reserve_ammo

func _setup_effects() -> void:
	# Muzzle flash
	muzzle_flash = GPUParticles3D.new()
	muzzle_flash.amount = 10
	muzzle_flash.lifetime = 0.1
	muzzle_flash.one_shot = true
	muzzle_flash.process_material = ParticleProcessMaterial.new()
	muzzle_flash.process_material.gravity = Vector3(0, 0, 0)
	muzzle_flash.process_material.initial_velocity = Vector3(0, 0, -10)
	muzzle_flash.process_material.scale = Vector3(0.5, 0.5, 0.5)
	muzzle_flash.emitting = false
	add_child(muzzle_flash)

	# Muzzle light
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1, 0.8, 0.4)
	muzzle_light.light_energy = 5.0
	muzzle_light.range = 5.0
	muzzle_light.omni_shadow_mode = OmniLight3D.OMNI_SHADOW_DISABLED
	add_child(muzzle_light)
	muzzle_light.visible = false

func _setup_audio() -> void:
	fire_sound = AudioStreamPlayer3D.new()
	fire_sound.bus = "SFX"
	fire_sound.max_distance = 100.0
	fire_sound.unit_db = 5.0
	add_child(fire_sound)

	reload_sound = AudioStreamPlayer3D.new()
	reload_sound.bus = "SFX"
	reload_sound.max_distance = 20.0
	reload_sound.unit_db = 0.0
	add_child(reload_sound)

	empty_sound = AudioStreamPlayer3D.new()
	empty_sound.stream = preload("res://assets/audio/sfx/weapon_empty.ogg")
	empty_sound.bus = "SFX"
	empty_sound.max_distance = 10.0
	empty_sound.unit_db = -5.0
	add_child(empty_sound)

func fire(start_pos: Vector3, direction: Vector3) -> bool:
	if is_reloading:
		return false

	var now = Time.get_ticks_msec() / 1000.0
	if now - last_fire_time < fire_rate:
		return false

	if current_ammo <= 0:
		if empty_sound:
			empty_sound.play()
		return false

	last_fire_time = now
	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)

	_do_fire(start_pos, direction)
	_play_fire_effects()

	if fire_mode == FireMode.BURST:
		burst_count += 1
		if burst_count >= burst_max:
			burst_count = 0
			# Add small delay after burst
			last_fire_time += 0.2

	fired.emit(start_pos, direction)
	return true

func _do_fire(start_pos: Vector3, direction: Vector3) -> void:
	var space_state = get_world_3d().direct_space_state

	if weapon_type == WeaponType.SHOTGUN:
		# Fire multiple pellets
		for i in range(8):
			var spread_dir = direction + Vector3(
				randf_range(-spread, spread),
				randf_range(-spread, spread),
				randf_range(-spread, spread)
			).normalized()
			_trace_shot(start_pos, spread_dir, damage / 8.0)
	elif weapon_type == WeaponType.RPG or weapon_type == WeaponType.THROWN:
		# Spawn projectile
		_spawn_projectile(start_pos, direction)
	else:
		# Single trace
		_trace_shot(start_pos, direction, damage)

func _trace_shot(start_pos: Vector3, direction: Vector3, dmg: float) -> void:
	var end_pos = start_pos + direction * range

	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.collision_mask = 1 | 2 | 3 | 4
	query.exclude = [owner.get_rid()] if owner else []

	var result = space_state.intersect_ray(query)

	if result:
		var hit_pos = result.position
		var collider = result.collider
		var normal = result.normal

		# Hit effect
		_spawn_hit_effect(hit_pos, normal, collider)

		# Apply damage
		if collider and collider.has_method("take_damage"):
			collider.take_damage(dmg, owner)

		# Penetration
		if penetration > 0.0:
			var remaining_pen = penetration
			var current_pos = hit_pos
			var current_dir = direction

			while remaining_pen > 0.1:
				var pen_end = current_pos + current_dir * remaining_pen
				var pen_query = PhysicsRayQueryParameters3D.create(current_pos + current_dir * 0.1, pen_end)
				pen_query.collision_mask = 1 | 2 | 3 | 4
				pen_query.exclude = [owner.get_rid()] if owner else []

				var pen_result = space_state.intersect_ray(pen_query)
				if not pen_result:
					break

				var pen_collider = pen_result.collider
				if pen_collider and pen_collider.has_method("take_damage"):
					pen_collider.take_damage(dmg * 0.5, owner)

				current_pos = pen_result.position
				remaining_pen -= current_pos.distance_to(current_pos)

		# Explosion
		if explosion_radius > 0.0:
			_explode(hit_pos)
	else:
		# Tracer effect for missed shots
		_spawn_tracer(start_pos, end_pos)

func _spawn_projectile(start_pos: Vector3, direction: Vector3) -> void:
	# For RPG, grenades, etc.
	var projectile = Projectile.new()
	projectile.global_position = start_pos
	projectile.global_rotation = direction.rotated(Vector3.UP, 0)
	projectile.initialize(damage, range, projectile_speed, projectile_gravity, explosion_radius, owner)
	add_child(projectile)

func _spawn_hit_effect(position: Vector3, normal: Vector3, collider: Object) -> void:
	var particles = GPUParticles3D.new()
	particles.amount = 20
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.process_material = ParticleProcessMaterial.new()
	particles.process_material.gravity = Vector3(0, -5, 0)
	particles.process_material.initial_velocity = normal * 5.0
	particles.global_position = position
	add_child(particles)
	particles.emitting = true

	call_deferred("_cleanup_particles", particles)

func _spawn_tracer(start_pos: Vector3, end_pos: Vector3) -> void:
	var tracer = MeshInstance3D.new()
	tracer.mesh = CylinderMesh.new()
	tracer.mesh.radius = 0.02
	tracer.mesh.height = start_pos.distance_to(end_pos)
	tracer.global_position = (start_pos + end_pos) / 2
	tracer.look_at(end_pos, Vector3.UP)
	tracer.rotation.x += PI / 2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 0)
	mat.emission_energy = 5.0
	tracer.set_surface_override_material(0, mat)
	add_child(tracer)

	# Fade out
	var tween = create_tween()
	tween.tween_property(tracer, "modulate:a", 0.0, 0.1)
	tween.finished.connect(func(): tracer.queue_free())

func _explode(position: Vector3) -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(position, position)
	query.collision_mask = 1 | 2 | 3 | 4

	# Use sphere query for explosion
	# Godot 4 doesn't have direct sphere query, so use raycasts in sphere pattern
	var bodies = space_state.get_colliding_bodies(query)

	# Explosion visual
	var explosion = GPUParticles3D.new()
	explosion.amount = 100
	explosion.lifetime = 1.0
	explosion.one_shot = true
	explosion.process_material = ParticleProcessMaterial.new()
	explosion.process_material.gravity = Vector3(0, 5, 0)
	explosion.process_material.initial_velocity = Vector3(0, 10, 0)
	explosion.process_material.scale = Vector3(2, 2, 2)
	explosion.global_position = position
	add_child(explosion)
	explosion.emitting = true

	if AudioManager:
		AudioManager.play_sfx_3d("res://assets/audio/sfx/explosion.ogg", position)

func _cleanup_particles(particles: GPUParticles3D) -> void:
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func _play_fire_effects() -> void:
	# Muzzle flash
	if muzzle_flash:
		muzzle_flash.emitting = true

	# Muzzle light flash
	if muzzle_light:
		muzzle_light.visible = true
		call_deferred("_hide_muzzle_light")

	# Sound
	if fire_sound and fire_sound.stream:
		fire_sound.play()

	# Recoil (handled by owner)

func _hide_muzzle_light() -> void:
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle_light):
		muzzle_light.visible = false

func reload() -> bool:
	if is_reloading or current_ammo >= max_ammo or reserve_ammo <= 0:
		return false

	is_reloading = true

	if reload_sound and reload_sound.stream:
		reload_sound.play()

	var ammo_needed = max_ammo - current_ammo
	var ammo_to_load = min(ammo_needed, reserve_ammo)

	# Simulate reload time
	var timer = get_tree().create_timer(reload_time)
	await timer.timeout

	if not is_instance_valid(self):
		return false

	current_ammo += ammo_to_load
	reserve_ammo -= ammo_to_load
	is_reloading = false

	ammo_changed.emit(current_ammo, max_ammo)
	reloaded.emit()

	return true

func add_ammo(amount: int) -> void:
	reserve_ammo = min(reserve_ammo + amount, max_reserve_ammo)
	ammo_changed.emit(current_ammo, max_ammo)

func can_reload() -> bool:
	return current_ammo < max_ammo and reserve_ammo > 0 and not is_reloading

func get_ammo_ratio() -> float:
	return current_ammo / max_ammo if max_ammo > 0 else 0.0

func get_reserve_ratio() -> float:
	return reserve_ammo / max_reserve_ammo if max_reserve_ammo > 0 else 0.0

func equip(new_owner: Node3D) -> void:
	owner = new_owner
	is_equipped = true
	weapon_switched.emit()

func unequip() -> void:
	owner = null
	is_equipped = false

func initialize(definition: Dictionary) -> void:
	weapon_id = definition["id"]
	weapon_name = definition["name"]
	weapon_type = WeaponType[definition["type"]]
	fire_mode = FireMode[definition["fire_mode"]]
	damage = definition["damage"]
	range = definition["range"]
	fire_rate = definition["fire_rate"]
	max_ammo = definition["max_ammo"]
	max_reserve_ammo = definition["max_reserve_ammo"]
	reload_time = definition["reload_time"]
	spread = definition["spread"]
	recoil = definition["recoil"]
	projectile_speed = definition.get("projectile_speed", 500.0)
	projectile_gravity = definition.get("projectile_gravity", 0.0)
	penetration = definition.get("penetration", 0.0)
	explosion_radius = definition.get("explosion_radius", 0.0)
	price = definition.get("price", 1000)

	current_ammo = max_ammo
	reserve_ammo = max_reserve_ammo

	set_meta("weapon_id", weapon_id)

func get_save_data() -> Dictionary:
	return {
		"weapon_id": weapon_id,
		"current_ammo": current_ammo,
		"reserve_ammo": reserve_ammo,
		"is_equipped": is_equipped,
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("current_ammo"):
		current_ammo = data["current_ammo"]
	if data.has("reserve_ammo"):
		reserve_ammo = data["reserve_ammo"]
	if data.has("is_equipped"):
		is_equipped = data["is_equipped"]