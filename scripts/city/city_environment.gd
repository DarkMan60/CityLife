extends Node3D

signal city_loaded()

var buildings_generated: bool = false
var roads_generated: bool = false
var props_generated: bool = false

func _ready() -> void:
	generate_city()

func generate_city() -> void:
	_generate_ground()
	_generate_buildings()
	_generate_roads()
	_generate_props()
	_setup_spawn_points()
	city_loaded.emit()

func _generate_ground() -> void:
	var ground = get_node("Ground")
	if ground:
		var mesh = ground.get_node("MeshInstance3D")
		if mesh:
			var material = mesh.surface_get_material(0) as StandardMaterial3D
			if not material:
				material = StandardMaterial3D.new()
				mesh.surface_set_material(0, material)
			material.albedo_color = Color(0.15, 0.25, 0.15)
			material.roughness = 0.9
			material.metallic = 0.0

func _generate_buildings() -> void:
	var buildings_parent = get_node("Buildings")
	if not buildings_parent:
		return

	_build_downtown(buildings_parent)
	_build_residential(buildings_parent)
	_build_industrial(buildings_parent)
	_build_commercial(buildings_parent)
	_build_landmarks(buildings_parent)

	buildings_generated = true

func _build_downtown(parent: Node3D) -> void:
	var center = Vector3(0, 0, 0)
	var block_size = 80
	var building_count = 50

	for i in range(building_count):
		var angle = randf() * TAU
		var distance = randf_range(20.0, 200.0)
		var pos = center + Vector3(cos(angle) * distance, 0, sin(angle) * distance)

		var height = randf_range(30.0, 150.0)
		var width = randf_range(20.0, 40.0)
		var depth = randf_range(20.0, 40.0)

		var building = _create_building(pos, Vector3(width, height, depth), "skyscraper")
		building.name = "Skyscraper_%d" % i
		parent.add_child(building)

func _build_residential(parent: Node3D) -> void:
	var areas = [
		Vector3(-300, 0, 300),
		Vector3(300, 0, -300),
		Vector3(-400, 0, -100)
	]

	for area_center in areas:
		for x in range(-3, 4):
			for z in range(-3, 4):
				if randf() < 0.7:
					var pos = area_center + Vector3(x * 50, 0, z * 50)
					var height = randf_range(8.0, 25.0)
					var width = randf_range(12.0, 20.0)
					var depth = randf_range(12.0, 20.0)

					var building = _create_building(pos, Vector3(width, height, depth), "residential")
					building.name = "House_%s_%d_%d" % [area_center, x, z]
					parent.add_child(building)

func _build_industrial(parent: Node3D) -> void:
	var center = Vector3(-400, 0, -200)

	for x in range(-4, 5):
		for z in range(-3, 4):
			if randf() < 0.6:
				var pos = center + Vector3(x * 80, 0, z * 80)
				var height = randf_range(10.0, 30.0)
				var width = randf_range(40.0, 80.0)
				var depth = randf_range(40.0, 80.0)

				var building = _create_building(pos, Vector3(width, height, depth), "industrial")
				building.name = "Factory_%d_%d" % [x, z]
				parent.add_child(building)

func _build_commercial(parent: Node3D) -> void:
	var center = Vector3(200, 0, 100)

	for x in range(-2, 3):
		for z in range(-2, 3):
			if randf() < 0.8:
				var pos = center + Vector3(x * 60, 0, z * 60)
				var height = randf_range(15.0, 50.0)
				var width = randf_range(25.0, 50.0)
				var depth = randf_range(25.0, 50.0)

				var building = _create_building(pos, Vector3(width, height, depth), "commercial")
				building.name = "Commercial_%d_%d" % [x, z]
				parent.add_child(building)

func _build_landmarks(parent: Node3D) -> void:
	var landmarks = [
		{"name": "CityHall", "pos": Vector3(0, 0, 0), "size": Vector3(80, 60, 80), "type": "landmark"},
		{"name": "AirportTerminal", "pos": Vector3(-500, 0, -500), "size": Vector3(200, 30, 150), "type": "airport"},
		{"name": "HarborWarehouse", "pos": Vector3(500, 0, -500), "size": Vector3(150, 20, 100), "type": "harbor"},
		{"name": "Observatory", "pos": Vector3(-300, 100, 300), "size": Vector3(40, 50, 40), "type": "landmark"},
		{"name": "Stadium", "pos": Vector3(400, 0, 200), "size": Vector3(150, 40, 150), "type": "landmark"},
		{"name": "Hospital", "pos": Vector3(-200, 0, 100), "size": Vector3(80, 30, 60), "type": "commercial"},
		{"name": "PoliceHQ", "pos": Vector3(100, 0, -200), "size": Vector3(60, 40, 60), "type": "commercial"},
		{"name": "Bank", "pos": Vector3(50, 0, 50), "size": Vector3(30, 50, 30), "type": "commercial"},
	]

	for lm in landmarks:
		var building = _create_building(lm["pos"], lm["size"], lm["type"])
		building.name = lm["name"]
		parent.add_child(building)

func _create_building(position: Vector3, size: Vector3, building_type: String) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size

	var building = MeshInstance3D.new()
	building.mesh = mesh
	building.global_position = position + Vector3(0, size.y / 2, 0)

	var material = StandardMaterial3D.new()
	material.roughness = 0.7
	material.metallic = 0.1

	match building_type:
		"skyscraper":
			material.albedo_color = Color(0.3, 0.3, 0.35)
			material.metallic = 0.3
			material.roughness = 0.4
		"residential":
			material.albedo_color = Color(randf_range(0.4, 0.7), randf_range(0.3, 0.6), randf_range(0.2, 0.5))
			material.roughness = 0.8
		"industrial":
			material.albedo_color = Color(0.25, 0.25, 0.3)
			material.roughness = 0.9
		"commercial":
			material.albedo_color = Color(0.35, 0.35, 0.4)
			material.metallic = 0.2
			material.roughness = 0.5
		"landmark":
			material.albedo_color = Color(0.5, 0.45, 0.4)
			material.metallic = 0.1
			material.roughness = 0.6
		"airport":
			material.albedo_color = Color(0.7, 0.7, 0.75)
			material.roughness = 0.5
		"harbor":
			material.albedo_color = Color(0.3, 0.3, 0.35)
			material.roughness = 0.8
		_:
			material.albedo_color = Color(0.4, 0.4, 0.45)

	building.surface_set_material(0, material)

	var collision = StaticBody3D.new()
	collision.collision_layer = 1
	collision.collision_mask = 1
	var col_shape = CollisionShape3D.new()
	col_shape.shape = BoxShape3D.new()
	(col_shape.shape as BoxShape3D).size = size
	col_shape.position = Vector3(0, size.y / 2, 0)
	collision.add_child(col_shape)
	building.add_child(collision)

	# Register with LODManager for distance-based rendering optimization
	if LODManager:
		# Create lower detail materials for LOD
		var material_medium = material.duplicate()
		material_medium.roughness = min(material_medium.roughness + 0.1, 1.0)

		var material_low = material.duplicate()
		material_low.roughness = min(material_low.roughness + 0.2, 1.0)
		material_low.metallic = 0.0

		# Create simpler meshes for lower LODs (fewer vertices)
		var mesh_medium = BoxMesh.new()
		mesh_medium.size = size

		var mesh_low = BoxMesh.new()
		mesh_low.size = size

		LODManager.register_object(building, {
			"high": mesh,
			"medium": mesh_medium,
			"low": mesh_low,
		}, {
			"high": material,
			"medium": material_medium,
			"low": material_low,
		})

	return building

func _generate_roads() -> void:
	var roads_parent = get_node("Roads")
	if not roads_parent:
		return

	_create_grid_roads(roads_parent)
	_create_highways(roads_parent)

	roads_generated = true

func _create_grid_roads(parent: Node3D) -> void:
	var block_size = 80.0
	var road_width = 12.0
	var grid_radius = 8

	var road_material = StandardMaterial3D.new()
	road_material.albedo_color = Color(0.15, 0.15, 0.15)
	road_material.roughness = 0.9

	for i in range(-grid_radius, grid_radius + 1):
		var x_pos = i * block_size
		var z_pos = i * block_size

		var road_x = _create_road_segment(Vector3(x_pos, 0.05, 0), Vector3(road_width, 0.1, grid_radius * 2 * block_size), road_material)
		road_x.name = "Road_X_%d" % i
		parent.add_child(road_x)

		var road_z = _create_road_segment(Vector3(0, 0.05, z_pos), Vector3(grid_radius * 2 * block_size, 0.1, road_width), road_material)
		road_z.name = "Road_Z_%d" % i
		parent.add_child(road_z)

func _create_highways(parent: Node3D) -> void:
	var highway_width = 24.0
	var highway_material = StandardMaterial3D.new()
	highway_material.albedo_color = Color(0.1, 0.1, 0.12)
	highway_material.roughness = 0.8

	var highways = [
		{"start": Vector3(-640, 0.05, -highway_width/2), "end": Vector3(640, 0.05, highway_width/2)},
		{"start": Vector3(-highway_width/2, 0.05, -640), "end": Vector3(highway_width/2, 0.05, 640)},
	]

	for hw in highways:
		var road = _create_road_segment(
			(hw["start"] + hw["end"]) / 2,
			Vector3(highway_width, 0.1, hw["start"].distance_to(hw["end"])),
			highway_material
		)
		var angle = atan2(hw["end"].x - hw["start"].x, hw["end"].z - hw["start"].z)
		road.global_rotation.y = angle
		road.name = "Highway_%s" % road.get_instance_id()
		parent.add_child(road)

func _create_road_segment(position: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size

	var road = MeshInstance3D.new()
	road.mesh = mesh
	road.global_position = position
	road.surface_set_material(0, material)

	# Register road with LODManager
	if LODManager:
		var material_low = material.duplicate()
		material_low.roughness = min(material_low.roughness + 0.1, 1.0)

		LODManager.register_object(road, {
			"high": mesh,
			"medium": mesh,
			"low": mesh,
		}, {
			"high": material,
			"medium": material,
			"low": material_low,
		})

	var collision = StaticBody3D.new()
	collision.collision_layer = 1
	collision.collision_mask = 1
	var col_shape = CollisionShape3D.new()
	col_shape.shape = BoxShape3D.new()
	(col_shape.shape as BoxShape3D).size = size
	collision.add_child(col_shape)
	road.add_child(collision)

	return road

func _generate_props() -> void:
	var props_parent = get_node("Props")
	if not props_parent:
		return

	_add_street_lights(props_parent)
	_add_traffic_lights(props_parent)
	_add_park_elements(props_parent)
	_add_vegetation(props_parent)

	props_generated = true

func _add_street_lights(parent: Node3D) -> void:
	var block_size = 80.0
	var grid_radius = 8

	for x in range(-grid_radius, grid_radius + 1):
		for z in range(-grid_radius, grid_radius + 1):
			if randf() < 0.3:
				var pos = Vector3(x * block_size + randf_range(-10, 10), 0, z * block_size + randf_range(-10, 10))
				var light = _create_street_light(pos)
				light.name = "StreetLight_%d_%d" % [x, z]
				parent.add_child(light)

func _create_street_light(position: Vector3) -> Node3D:
	var light_node = Node3D.new()
	light_node.global_position = position

	var pole = MeshInstance3D.new()
	pole.mesh = CylinderMesh.new()
	(pole.mesh as CylinderMesh).height = 10.0
	(pole.mesh as CylinderMesh).top_radius = 0.1
	(pole.mesh as CylinderMesh).bottom_radius = 0.2
	pole.position = Vector3(0, 5, 0)

	var pole_material = StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.2, 0.2, 0.2)
	pole_material.roughness = 0.5
	pole_material.metallic = 0.8
	pole.surface_set_material(0, pole_material)
	light_node.add_child(pole)

	# Register pole with LODManager
	if LODManager:
		var pole_material_low = pole_material.duplicate()
		pole_material_low.metallic = 0.5
		pole_material_low.roughness = 0.8

		var pole_mesh_low = CylinderMesh.new()
		pole_mesh_low.height = 10.0
		pole_mesh_low.top_radius = 0.1
		pole_mesh_low.bottom_radius = 0.2

		LODManager.register_object(pole, {
			"high": pole.mesh,
			"medium": pole.mesh,
			"low": pole_mesh_low,
		}, {
			"high": pole_material,
			"medium": pole_material,
			"low": pole_material_low,
		})

	var light_head = MeshInstance3D.new()
	light_head.mesh = SphereMesh.new()
	(light_head.mesh as SphereMesh).radius = 0.5
	light_head.position = Vector3(0, 10, 0)

	var light_material = StandardMaterial3D.new()
	light_material.albedo_color = Color(1, 0.9, 0.7)
	light_material.emission_enabled = true
	light_material.emission = Color(1, 0.9, 0.7)
	light_material.emission_energy_multiplier = 2.0
	light_head.surface_set_material(0, light_material)
	light_node.add_child(light_head)

	var omni_light = OmniLight3D.new()
	omni_light.light_color = Color(1, 0.9, 0.7)
	omni_light.light_energy = 5.0
	omni_light.omni_range = 15.0
	omni_light.omni_attenuation = 2.0
	omni_light.position = Vector3(0, 10, 0)
	light_node.add_child(omni_light)

	return light_node

func _add_traffic_lights(parent: Node3D) -> void:
	var intersections = [
		Vector3(0, 0, 0),
		Vector3(80, 0, 0),
		Vector3(-80, 0, 0),
		Vector3(0, 0, 80),
		Vector3(0, 0, -80),
		Vector3(160, 0, 160),
		Vector3(-160, 0, -160),
	]

	for i, pos in intersections:
		var light = _create_traffic_light(pos)
		light.name = "TrafficLight_%d" % i
		parent.add_child(light)

func _create_traffic_light(position: Vector3) -> Node3D:
	var light_node = Node3D.new()
	light_node.global_position = position

	var pole = MeshInstance3D.new()
	pole.mesh = CylinderMesh.new()
	(pole.mesh as CylinderMesh).height = 8.0
	(pole.mesh as CylinderMesh).top_radius = 0.15
	(pole.mesh as CylinderMesh).bottom_radius = 0.2
	pole.position = Vector3(0, 4, 0)

	var pole_material = StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.1, 0.1, 0.1)
	pole_material.roughness = 0.3
	pole_material.metallic = 0.9
	pole.surface_set_material(0, pole_material)
	light_node.add_child(pole)

	# Register pole with LODManager
	if LODManager:
		var pole_material_low = pole_material.duplicate()
		pole_material_low.metallic = 0.5
		pole_material_low.roughness = 0.6

		var pole_mesh_low = CylinderMesh.new()
		pole_mesh_low.height = 8.0
		pole_mesh_low.top_radius = 0.15
		pole_mesh_low.bottom_radius = 0.2

		LODManager.register_object(pole, {
			"high": pole.mesh,
			"medium": pole.mesh,
			"low": pole_mesh_low,
		}, {
			"high": pole_material,
			"medium": pole_material,
			"low": pole_material_low,
		})

	var box = MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	(box.mesh as BoxMesh).size = Vector3(1.0, 2.5, 0.3)
	box.position = Vector3(0, 6.5, 1.5)

	var box_material = StandardMaterial3D.new()
	box_material.albedo_color = Color(0.05, 0.05, 0.05)
	box.surface_set_material(0, box_material)
	light_node.add_child(box)

	# Register box with LODManager
	if LODManager:
		var box_material_low = box_material.duplicate()
		box_material_low.roughness = 1.0

		LODManager.register_object(box, {
			"high": box.mesh,
			"medium": box.mesh,
			"low": box.mesh,
		}, {
			"high": box_material,
			"medium": box_material,
			"low": box_material_low,
		})

	var red_light = OmniLight3D.new()
	red_light.light_color = Color(1, 0, 0)
	red_light.light_energy = 2.0
	red_light.omni_range = 10.0
	red_light.position = Vector3(0, 6.5, 1.5)
	light_node.add_child(red_light)

	return light_node

func _add_park_elements(parent: Node3D) -> void:
	var park_center = Vector3(-200, 0, 400)
	var park_radius = 100.0

	for i in range(50):
		var angle = randf() * TAU
		var dist = randf_range(10.0, park_radius)
		var pos = park_center + Vector3(cos(angle) * dist, 0.1, sin(angle) * dist)

		if randf() < 0.6:
			var tree = _create_tree(pos)
			tree.name = "Tree_%d" % i
			parent.add_child(tree)
		else:
			var bench = _create_bench(pos)
			bench.name = "Bench_%d" % i
			parent.add_child(bench)

func _create_tree(position: Vector3) -> Node3D:
	var tree = Node3D.new()
	tree.global_position = position

	var trunk = MeshInstance3D.new()
	trunk.mesh = CylinderMesh.new()
	(trunk.mesh as CylinderMesh).height = 4.0
	(trunk.mesh as CylinderMesh).top_radius = 0.2
	(trunk.mesh as CylinderMesh).bottom_radius = 0.3
	trunk.position = Vector3(0, 2, 0)

	var trunk_material = StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.3, 0.2, 0.1)
	trunk_material.roughness = 0.9
	trunk.surface_set_material(0, trunk_material)
	tree.add_child(trunk)

	# Register trunk with LODManager
	if LODManager:
		var trunk_material_low = trunk_material.duplicate()
		trunk_material_low.roughness = 1.0

		var trunk_mesh_low = CylinderMesh.new()
		trunk_mesh_low.height = 4.0
		trunk_mesh_low.top_radius = 0.2
		trunk_mesh_low.bottom_radius = 0.3

		LODManager.register_object(trunk, {
			"high": trunk.mesh,
			"medium": trunk.mesh,
			"low": trunk_mesh_low,
		}, {
			"high": trunk_material,
			"medium": trunk_material,
			"low": trunk_material_low,
		})

	var leaves = MeshInstance3D.new()
	leaves.mesh = SphereMesh.new()
	(leaves.mesh as SphereMesh).radius = 2.5
	leaves.position = Vector3(0, 5.5, 0)

	var leaves_material = StandardMaterial3D.new()
	leaves_material.albedo_color = Color(0.1, 0.4, 0.1)
	leaves_material.roughness = 0.8
	leaves.surface_set_material(0, leaves_material)
	tree.add_child(leaves)

	# Register leaves with LODManager
	if LODManager:
		var leaves_material_low = leaves_material.duplicate()
		leaves_material_low.roughness = 1.0

		var leaves_mesh_low = SphereMesh.new()
		leaves_mesh_low.radius = 2.0  # Slightly smaller for LOD

		LODManager.register_object(leaves, {
			"high": leaves.mesh,
			"medium": leaves.mesh,
			"low": leaves_mesh_low,
		}, {
			"high": leaves_material,
			"medium": leaves_material,
			"low": leaves_material_low,
		})

	return tree

func _create_bench(position: Vector3) -> Node3D:
	var bench = Node3D.new()
	bench.global_position = position
	bench.global_rotation.y = randf() * TAU

	var seat = MeshInstance3D.new()
	seat.mesh = BoxMesh.new()
	(seat.mesh as BoxMesh).size = Vector3(2.0, 0.1, 0.5)
	seat.position = Vector3(0, 0.45, 0)

	var seat_material = StandardMaterial3D.new()
	seat_material.albedo_color = Color(0.3, 0.3, 0.3)
	seat_material.roughness = 0.7
	seat.surface_set_material(0, seat_material)
	bench.add_child(seat)

	# Register seat with LODManager
	if LODManager:
		var seat_material_low = seat_material.duplicate()
		seat_material_low.roughness = 1.0

		LODManager.register_object(seat, {
			"high": seat.mesh,
			"medium": seat.mesh,
			"low": seat.mesh,
		}, {
			"high": seat_material,
			"medium": seat_material,
			"low": seat_material_low,
		})

	var back = MeshInstance3D.new()
	back.mesh = BoxMesh.new()
	(back.mesh as BoxMesh).size = Vector3(2.0, 0.8, 0.1)
	back.position = Vector3(0, 0.85, -0.25)
	back.surface_set_material(0, seat_material)
	bench.add_child(back)

	var leg1 = MeshInstance3D.new()
	leg1.mesh = BoxMesh.new()
	(leg1.mesh as BoxMesh).size = Vector3(0.1, 0.5, 0.1)
	leg1.position = Vector3(-0.9, 0.2, 0.2)
	leg1.surface_set_material(0, seat_material)
	bench.add_child(leg1)

	var leg2 = MeshInstance3D.new()
	leg2.mesh = BoxMesh.new()
	(leg2.mesh as BoxMesh).size = Vector3(0.1, 0.5, 0.1)
	leg2.position = Vector3(0.9, 0.2, 0.2)
	leg2.surface_set_material(0, seat_material)
	bench.add_child(leg2)

	var leg3 = MeshInstance3D.new()
	leg3.mesh = BoxMesh.new()
	(leg3.mesh as BoxMesh).size = Vector3(0.1, 0.5, 0.1)
	leg3.position = Vector3(-0.9, 0.2, -0.2)
	leg3.surface_set_material(0, seat_material)
	bench.add_child(leg3)

	var leg4 = MeshInstance3D.new()
	leg4.mesh = BoxMesh.new()
	(leg4.mesh as BoxMesh).size = Vector3(0.1, 0.5, 0.1)
	leg4.position = Vector3(0.9, 0.2, -0.2)
	leg4.surface_set_material(0, seat_material)
	bench.add_child(leg4)

	return bench

func _add_vegetation(parent: Node3D) -> void:
	for i in range(200):
		var angle = randf() * TAU
		var dist = randf_range(200.0, 800.0)
		var pos = Vector3(cos(angle) * dist, 0.1, sin(angle) * dist)

		if pos.distance_to(Vector3.ZERO) > 150.0:
			var tree = _create_tree(pos)
			tree.name = "WildTree_%d" % i
			parent.add_child(tree)

func _setup_spawn_points() -> void:
	var spawn_parent = get_node("SpawnPoints")
	if not spawn_parent:
		return

	var spawn_locations = [
		Vector3(-200, 5, -100),
		Vector3(0, 5, 0),
		Vector3(100, 5, 50),
		Vector3(-300, 5, 300),
		Vector3(300, 5, -300),
		Vector3(-400, 5, -200),
		Vector3(500, 5, 500),
		Vector3(-500, 5, -500),
		Vector3(500, 5, -500),
		Vector3(200, 5, 100),
	]

	for i, pos in spawn_locations:
		var marker = Node3D.new()
		marker.name = "SpawnPoint_%d" % i
		marker.global_position = pos
		spawn_parent.add_child(marker)

func get_spawn_positions() -> Array[Vector3]:
	var spawn_parent = get_node("SpawnPoints")
	if not spawn_parent:
		return [Vector3(-200, 5, -100)]

	var positions = []
	for child in spawn_parent.get_children():
		if child is Node3D:
			positions.append(child.global_position)

	return positions if not positions.is_empty() else [Vector3(-200, 5, -100)]

func get_random_spawn_position() -> Vector3:
	var positions = get_spawn_positions()
	return positions[randi() % positions.size()]