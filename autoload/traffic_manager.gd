extends Node

signal vehicle_spawned(vehicle: Node3D)
signal vehicle_despawned(vehicle: Node3D)
signal traffic_light_changed(light_id: String, state: int)
signal accident_occurred(position: Vector3, vehicles: Array[Node3D])

enum TrafficLightState {
	RED = 0,
	YELLOW = 1,
	GREEN = 2
}

enum RoadType {
	HIGHWAY = 0,
	ARTERIAL = 1,
	COLLECTOR = 2,
	LOCAL = 3,
	ALLEY = 4
}

var max_traffic_vehicles: int = 80
var active_traffic_vehicles: Array[Node3D] = []
var traffic_nodes: Array[Dictionary] = []
var traffic_lights: Dictionary = {}
var road_network: Dictionary = {}
var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var traffic_density: float = 1.0
var rush_hour_multiplier: float = 2.0
var night_multiplier: float = 0.3
var accident_probability: float = 0.001
var traffic_light_cycle_time: float = 30.0

static var instance: TrafficManager = null

var vehicle_pool: Array[String] = []
var path_cache: Dictionary = {}

func _ready() -> void:
	instance = self
	_build_road_network()
	_setup_traffic_lights()
	_define_traffic_vehicle_pool()

func _define_traffic_vehicle_pool() -> void:
	vehicle_pool = [
		"tailgater", "premier", "baller_le", "schafter_v12", "cognoscenti",
		"taxi", "bus", "hauler", "phantom", "ambulance", "firetruck",
		"rebel", "sanchez", "akuma", "bati_801"
	]

func _build_road_network() -> void:
	road_network = {
		"nodes": [],
		"edges": [],
		"intersections": [],
		"highways": [],
		"spawn_points": [],
		"despawn_points": []
	}

	_generate_city_grid()
	_generate_highways()
	_identify_intersections()
	_create_spawn_despawn_points()

func _generate_city_grid() -> void:
	var block_size = 80.0
	var grid_radius = 8
	var node_id = 0

	for x in range(-grid_radius, grid_radius + 1):
		for z in range(-grid_radius, grid_radius + 1):
			var pos = Vector3(x * block_size, 0, z * block_size)
			var node = {
				"id": "node_%d" % node_id,
				"position": pos,
				"type": RoadType.LOCAL,
				"connections": [],
				"lanes": 1,
				"speed_limit": 50.0
			}
			road_network["nodes"].append(node)
			node_id += 1

	for i in range(road_network["nodes"].size()):
		var node = road_network["nodes"][i]
		var pos = node["position"]
		var x_idx = int(pos.x / block_size + grid_radius)
		var z_idx = int(pos.z / block_size + grid_radius)

		var neighbors = []
		if x_idx > 0:
			neighbors.append("node_%d" % ((x_idx - 1) * (grid_radius * 2 + 1) + z_idx))
		if x_idx < grid_radius * 2:
			neighbors.append("node_%d" % ((x_idx + 1) * (grid_radius * 2 + 1) + z_idx))
		if z_idx > 0:
			neighbors.append("node_%d" % (x_idx * (grid_radius * 2 + 1) + (z_idx - 1)))
		if z_idx < grid_radius * 2:
			neighbors.append("node_%d" % (x_idx * (grid_radius * 2 + 1) + (z_idx + 1)))

		node["connections"] = neighbors

		for neighbor_id in neighbors:
			var edge = {
				"from": node["id"],
				"to": neighbor_id,
				"length": block_size,
				"lanes": 1,
				"speed_limit": 50.0,
				"type": RoadType.LOCAL
			}
			road_network["edges"].append(edge)

func _generate_highways() -> void:
	var highway_nodes = [
		{"start": Vector3(-640, 0, 0), "end": Vector3(640, 0, 0), "name": "east_west_highway"},
		{"start": Vector3(0, 0, -640), "end": Vector3(0, 0, 640), "name": "north_south_highway"},
		{"start": Vector3(-640, 0, -640), "end": Vector3(640, 0, 640), "name": "diagonal_highway_1"},
		{"start": Vector3(640, 0, -640), "end": Vector3(-640, 0, 640), "name": "diagonal_highway_2"},
	]

	for hw in highway_nodes:
		var start = hw["start"]
		var end = hw["end"]
		var length = start.distance_to(end)
		var segments = int(length / 160.0)
		var prev_node_id = ""

		for i in range(segments + 1):
			var t = i / segments
			var pos = start.lerp(end, t)
			var node_id = "hw_%s_%d" % [hw["name"], i]

			var node = {
				"id": node_id,
				"position": pos,
				"type": RoadType.HIGHWAY,
				"connections": [],
				"lanes": 3,
				"speed_limit": 120.0
			}
			road_network["nodes"].append(node)
			road_network["highways"].append(node_id)

			if prev_node_id != "":
				var edge = {
					"from": prev_node_id,
					"to": node_id,
					"length": 160.0,
					"lanes": 3,
					"speed_limit": 120.0,
					"type": RoadType.HIGHWAY
				}
				road_network["edges"].append(edge)

				var reverse_edge = {
					"from": node_id,
					"to": prev_node_id,
					"length": 160.0,
					"lanes": 3,
					"speed_limit": 120.0,
					"type": RoadType.HIGHWAY
				}
				road_network["edges"].append(reverse_edge)

				var prev_node = _find_node(prev_node_id)
				if prev_node:
					prev_node["connections"].append(node_id)
				node["connections"].append(prev_node_id)

			prev_node_id = node_id

func _identify_intersections() -> void:
	for node in road_network["nodes"]:
		if node["connections"].size() >= 3:
			var intersection = {
				"id": "intersection_%s" % node["id"],
				"node_id": node["id"],
				"position": node["position"],
				"roads": node["connections"],
				"has_traffic_light": node["type"] != RoadType.HIGHWAY and randf() < 0.7,
				"light_state": TrafficLightState.GREEN,
				"light_timer": randf() * traffic_light_cycle_time,
				"light_phase": 0
			}
			road_network["intersections"].append(intersection)

			if intersection["has_traffic_light"]:
				traffic_lights[intersection["id"]] = intersection

func _create_spawn_despawn_points() -> void:
	for node in road_network["nodes"]:
		if node["type"] == RoadType.HIGHWAY:
			continue

		var pos = node["position"]
		var dist_from_center = pos.length()

		if dist_from_center > 400.0 and dist_from_center < 550.0:
			road_network["spawn_points"].append({
				"position": pos,
				"node_id": node["id"],
				"directions": node["connections"]
			})

		if dist_from_center > 600.0:
			road_network["despawn_points"].append({
				"position": pos,
				"node_id": node["id"]
			})

func _find_node(node_id: String) -> Dictionary:
	for node in road_network["nodes"]:
		if node["id"] == node_id:
			return node
	return {}

func _find_path(start_node: String, end_node: String) -> Array[String]:
	var cache_key = "%s->%s" % [start_node, end_node]
	if path_cache.has(cache_key):
		return path_cache[cache_key]

	var open_set = [start_node]
	var came_from = {}
	var g_score = {start_node: 0}
	var f_score = {start_node: _heuristic(start_node, end_node)}

	while not open_set.is_empty():
		var current = open_set[0]
		var lowest_f = f_score[current]
		for node in open_set:
			if f_score.has(node) and f_score[node] < lowest_f:
				current = node
				lowest_f = f_score[node]

		if current == end_node:
			var path = []
			while current in came_from:
				path.append(current)
				current = came_from[current]
			path.append(start_node)
			path.reverse()
			path_cache[cache_key] = path
			return path

		open_set.erase(current)

		var current_node = _find_node(current)
		if not current_node:
			continue

		for neighbor in current_node["connections"]:
			var edge = _find_edge(current, neighbor)
			if not edge:
				continue

			var tentative_g = g_score[current] + edge["length"]

			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, end_node)

				if neighbor not in open_set:
					open_set.append(neighbor)

	return []

func _find_edge(from_id: String, to_id: String) -> Dictionary:
	for edge in road_network["edges"]:
		if edge["from"] == from_id and edge["to"] == to_id:
			return edge
	return {}

func _heuristic(node_a: String, node_b: String) -> float:
	var a = _find_node(node_a)
	var b = _find_node(node_b)
	if a and b:
		return a["position"].distance_to(b["position"])
	return 1000.0

func _setup_traffic_lights() -> void:
	for light_id in traffic_lights:
		var light = traffic_lights[light_id]
		light["light_timer"] = randf() * traffic_light_cycle_time

func _process(delta: float) -> void:
	_update_traffic_lights(delta)
	_update_spawning(delta)
	_update_despawning()
	_check_accidents(delta)

func _update_traffic_lights(delta: float) -> void:
	for light_id in traffic_lights:
		var light = traffic_lights[light_id]
		light["light_timer"] += delta

		var cycle = traffic_light_cycle_time
		var green_time = cycle * 0.5
		var yellow_time = cycle * 0.1
		var red_time = cycle * 0.4

		var phase_time = fmod(light["light_timer"], cycle)

		var new_state = light["light_state"]
		if phase_time < green_time:
			new_state = TrafficLightState.GREEN
		elif phase_time < green_time + yellow_time:
			new_state = TrafficLightState.YELLOW
		else:
			new_state = TrafficLightState.RED

		if new_state != light["light_state"]:
			light["light_state"] = new_state
			traffic_light_changed.emit(light_id, new_state)

func _update_spawning(delta: float) -> void:
	if active_traffic_vehicles.size() >= max_traffic_vehicles:
		return

	if not GameManager or not GameManager.get_player():
		return

	var current_hour = WorldManager.get_time_of_day() if WorldManager else 12.0
	var density_mult = traffic_density

	if current_hour >= 7.0 and current_hour <= 9.0:
		density_mult *= rush_hour_multiplier
	elif current_hour >= 17.0 and current_hour <= 19.0:
		density_mult *= rush_hour_multiplier
	elif current_hour >= 22.0 or current_hour <= 5.0:
		density_mult *= night_multiplier

	spawn_timer += delta
	var adjusted_interval = spawn_interval / density_mult

	if spawn_timer >= adjusted_interval:
		spawn_timer = 0.0
		_try_spawn_traffic_vehicle()
		spawn_interval = randf_range(2.0, 6.0)

func _try_spawn_traffic_vehicle() -> void:
	if road_network["spawn_points"].is_empty():
		return

	var player_pos = GameManager.get_player().global_position
	var valid_spawns = []

	for spawn in road_network["spawn_points"]:
		var dist = spawn["position"].distance_to(player_pos)
		if dist > 100.0 and dist < 300.0:
			valid_spawns.append(spawn)

	if valid_spawns.is_empty():
		return

	var spawn = valid_spawns[randi() % valid_spawns.size()]
	var vehicle_id = vehicle_pool[randi() % vehicle_pool.size()]

	var vehicle = VehicleManager.spawn_vehicle(vehicle_id, spawn["position"])
	if vehicle:
		if vehicle.has_method("set_traffic_mode"):
			var path = _generate_random_path(spawn["node_id"])
			vehicle.set_traffic_mode(true, path)
		active_traffic_vehicles.append(vehicle)
		vehicle_spawned.emit(vehicle)

func _generate_random_path(start_node: String) -> Array[String]:
	var path = [start_node]
	var current = start_node
	var steps = randi_range(5, 20)

	for i in range(steps):
		var current_node = _find_node(current)
		if not current_node or current_node["connections"].is_empty():
			break

		var next_node = current_node["connections"][randi() % current_node["connections"].size()]
		path.append(next_node)
		current = next_node

	var end_node = path[-1]
	var despawn_path = _find_path(end_node, _find_nearest_despawn(end_node))
	if despawn_path.size() > 1:
		path.append_array(despawn_path.slice(1))

	return path

func _find_nearest_despawn(node_id: String) -> String:
	var node = _find_node(node_id)
	if not node:
		return ""

	var best = ""
	var best_dist = INF

	for despawn in road_network["despawn_points"]:
		var despawn_node = _find_node(despawn["node_id"])
		if despawn_node:
			var dist = node["position"].distance_to(despawn_node["position"])
			if dist < best_dist:
				best_dist = dist
				best = despawn["node_id"]

	return best

func _update_despawning() -> void:
	if not GameManager or not GameManager.get_player():
		return

	var player_pos = GameManager.get_player().global_position
	var to_despawn = []

	for vehicle in active_traffic_vehicles:
		if not vehicle or not is_instance_valid(vehicle):
			to_despawn.append(vehicle)
			continue

		var dist = vehicle.global_position.distance_to(player_pos)
		if dist > 400.0:
			if vehicle.has_method("is_at_despawn") and vehicle.is_at_despawn():
				to_despawn.append(vehicle)

	for vehicle in to_despawn:
		_despawn_traffic_vehicle(vehicle)

func _despawn_traffic_vehicle(vehicle: Node3D) -> void:
	if vehicle in active_traffic_vehicles:
		active_traffic_vehicles.erase(vehicle)
		vehicle_despawned.emit(vehicle)
		vehicle.queue_free()

func _check_accidents(delta: float) -> void:
	for i in range(active_traffic_vehicles.size()):
		var vehicle_a = active_traffic_vehicles[i]
		if not vehicle_a or not is_instance_valid(vehicle_a):
			continue

		for j in range(i + 1, active_traffic_vehicles.size()):
			var vehicle_b = active_traffic_vehicles[j]
			if not vehicle_b or not is_instance_valid(vehicle_b):
				continue

			var dist = vehicle_a.global_position.distance_to(vehicle_b.global_position)
			if dist < 3.0:
				var speed_a = vehicle_a.get_linear_velocity().length() if vehicle_a.has_method("get_linear_velocity") else 0
				var speed_b = vehicle_b.get_linear_velocity().length() if vehicle_b.has_method("get_linear_velocity") else 0

				if (speed_a + speed_b) > 10.0 and randf() < accident_probability:
					accident_occurred.emit(vehicle_a.global_position, [vehicle_a, vehicle_b])
					if PoliceManager:
						PoliceManager.report_crime("accident", vehicle_a.global_position, 1)

func get_traffic_light_state(light_id: String) -> int:
	return traffic_lights.get(light_id, {"light_state": TrafficLightState.GREEN})["light_state"]

func set_traffic_density(density: float) -> void:
	traffic_density = clamp(density, 0.0, 3.0)

func get_traffic_density() -> float:
	return traffic_density

func get_active_traffic_count() -> int:
	var count = 0
	for v in active_traffic_vehicles:
		if v and is_instance_valid(v):
			count += 1
	return count

func find_path_to_destination(start_pos: Vector3, end_pos: Vector3) -> Array[Vector3]:
	var start_node = _find_nearest_node(start_pos)
	var end_node = _find_nearest_node(end_pos)

	if not start_node or not end_node:
		return []

	var node_path = _find_path(start_node["id"], end_node["id"])
	var world_path = []

	for node_id in node_path:
		var node = _find_node(node_id)
		if node:
			world_path.append(node["position"])

	return world_path

func _find_nearest_node(position: Vector3) -> Dictionary:
	var best = null
	var best_dist = INF

	for node in road_network["nodes"]:
		var dist = node["position"].distance_to(position)
		if dist < best_dist:
			best_dist = dist
			best = node

	return best

func get_road_type_at(position: Vector3) -> RoadType:
	var node = _find_nearest_node(position)
	return node["type"] if node else RoadType.LOCAL

func get_speed_limit_at(position: Vector3) -> float:
	var node = _find_nearest_node(position)
	return node["speed_limit"] if node else 50.0

func clear_all_traffic() -> void:
	for vehicle in active_traffic_vehicles:
		if vehicle and is_instance_valid(vehicle):
			vehicle.queue_free()
	active_traffic_vehicles.clear()

func get_save_data() -> Dictionary:
	return {
		"traffic_density": traffic_density,
		"active_count": active_traffic_vehicles.size()
	}

func apply_save_data(data: Dictionary) -> void:
	traffic_density = data.get("traffic_density", 1.0)

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		clear_all_traffic()