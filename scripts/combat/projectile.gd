extends RigidBody3D
class_name Projectile

signal exploded(position: Vector3)
signal hit(target: Node3D, position: Vector3, normal: Vector3)

var damage: float = 50.0
var max_range: float = 200.0
var speed: float = 100.0
var gravity: float = 9.8
var explosion_radius: float = 5.0
var owner: Node3D = null
var traveled_distance: float = 0.0
var has_exploded: bool = false

var trail_particles: GPUParticles3D = null

func _ready() -> void:
	_setup_projectile()

func _setup_projectile() -> void:
	# Rocket/grenade mesh
	var mesh = MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	mesh.mesh.radius = 0.1
	mesh.mesh.height = 0.5
	mesh.rotation.x = PI / 2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)
	mesh.set_surface_override_material(0, mat)
	add_child(mesh)

	# Trail particles
	trail_particles = GPUParticles3D.new()
	trail_particles.amount = 20
	trail_particles.lifetime = 0.5
	trail_particles.one_shot = false
	trail_particles.process_material = ParticleProcessMaterial.new()
	trail_particles.process_material.gravity = Vector3(0, -2, 0)
	trail_particles.process_material.initial_velocity = Vector3(0, 0, 0)
	trail_particles.emitting = true
	add_child(trail_particles)

	# Collision
	var collision = CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	collision.shape.radius = 0.15
	add_child(collision)

	set_collision_layer_value(4, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)

	# Physics
	mass = 1.0
	gravity_scale = gravity / 9.8
	angular_damp = 0.1
	linear_damp = 0.01

func initialize(dmg: float, range: float, spd: float, grav: float, exp_radius: float, proj_owner: Node3D) -> void:
	damage = dmg
	max_range = range
	speed = spd
	gravity = grav
	explosion_radius = exp_radius
	owner = proj_owner

	# Launch
	apply_central_impulse(-global_transform.basis.z * speed)

func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	traveled_distance += linear_velocity.length() * delta

	if traveled_distance >= max_range:
		explode()

	# Orient to velocity
	if linear_velocity.length() > 1.0:
		var target_rot = linear_velocity.normalized()
		look_at(global_position + target_rot, Vector3.UP)
		rotation.x += PI / 2

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Custom gravity
	if gravity != 9.8:
		state.apply_force(Vector3(0, -gravity * mass, 0))

func _on_body_entered(body: Node3D) -> void:
	if has_exploded:
		return

	if body == owner:
		return

	if body.is_in_group("projectile"):
		return

	hit.emit(body, global_position, Vector3.UP)

	if explosion_radius > 0.5:
		explode()
	else:
		# Direct hit
		if body.has_method("take_damage"):
			body.take_damage(damage, owner)
		queue_free()

func explode() -> void:
	if has_exploded:
		return

	has_exploded = true

	# Explosion damage
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position)

	# Find bodies in radius (using multiple raycasts approximation)
	var bodies_hit = []

	# Simple area damage - check nearby bodies
	var shapes_query = PhysicsShapeQueryParameters3D.create(SphereShape3D.new())
	shapes_query.shape.radius = explosion_radius
	shapes_query.transform = Transform3D.IDENTITY.translated(global_position)
	shapes_query.collision_mask = 1 | 2 | 3 | 4
	shapes_query.exclude = [owner.get_rid()] if owner else []
	shapes_query.collide_with_bodies = true

	var results = space_state.intersect_shape(shapes_query, 32)

	for result in results:
		var body = result.collider
		if body and body != owner and body.has_method("take_damage"):
			var dist = global_position.distance_to(body.global_position)
			var falloff = 1.0 - (dist / explosion_radius)
			var dmg = damage * falloff
			body.take_damage(dmg, owner)
			bodies_hit.append(body)

	# Explosion effects
	_create_explosion_effect()

	exploded.emit(global_position)

	# Remove after effect
	call_deferred("queue_free")

func _create_explosion_effect() -> void:
	var explosion = GPUParticles3D.new()
	explosion.amount = 150
	explosion.lifetime = 1.5
	explosion.one_shot = true
	explosion.process_material = ParticleProcessMaterial.new()
	explosion.process_material.gravity = Vector3(0, 10, 0)
	explosion.process_material.initial_velocity = Vector3(0, 15, 0)
	explosion.process_material.scale = Vector3(explosion_radius, explosion_radius, explosion_radius)
	explosion.global_position = global_position
	get_tree().root.add_child(explosion)
	explosion.emitting = true

	# Shockwave
	var shockwave = MeshInstance3D.new()
	shockwave.mesh = CylinderMesh.new()
	shockwave.mesh.radius = 0.5
	shockwave.mesh.height = 0.1
	shockwave.global_position = global_position
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.5, 0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.alpha_scissor_threshold = 0.1
	shockwave.set_surface_override_material(0, mat)
	get_tree().root.add_child(shockwave)

	# Animate shockwave
	var tween = create_tween()
	tween.tween_property(shockwave, "scale", Vector3(explosion_radius * 2, 0.1, explosion_radius * 2), 0.3)
	tween.parallel().tween_property(shockwave, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): shockwave.queue_free())

	if AudioManager:
		AudioManager.play_sfx_3d("res://assets/audio/sfx/explosion.ogg", global_position)

func get_save_data() -> Dictionary:
	return {
		"position": global_position,
		"rotation": global_rotation,
		"velocity": linear_velocity,
		"traveled_distance": traveled_distance,
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		global_rotation = data["rotation"]
	if data.has("velocity"):
		linear_velocity = data["velocity"]
	if data.has("traveled_distance"):
		traveled_distance = data["traveled_distance"]