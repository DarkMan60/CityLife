extends VehicleBase
class_name TrafficVehicle

signal reached_waypoint(waypoint_index: int)
signal reached_destination()
signal collision_imminent(obstacle: Node3D)

var traffic_mode: bool = false
var waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var target_speed: float = 50.0
var current_speed: float = 0.0
var acceleration_rate: float = 5.0
var deceleration_rate: float = 8.0
var steering_sensitivity: float = 2.0
var follow_distance: float = 10.0
var lane_offset: float = 0.0
var current_lane: int = 0
var target_lane: int = 0
var lane_change_timer: float = 0.0
var lane_change_duration: float = 2.0
var is_changing_lane: bool = false

var traffic_light_stop: bool = false
var stop_timer: float = 0.0
var max_stop_time: float = 10.0

var obstacle_check_distance: float = 15.0
var obstacle_check_timer: float = 0.0

@onready var raycast_forward: RayCast3D = %RayCastForward
@onready var raycast_left: RayCast3D = %RayCastLeft
@onready var raycast_right: RayCast3D = %RayCastRight

func _ready() -> void:
	super._ready()
	_setup_traffic_rays()

func _setup_traffic_rays() -> void:
	raycast_forward = RayCast3D.new()
	raycast_forward.target_position = Vector3(0, 0, -obstacle_check_distance)
	raycast_forward.collision_mask = 1 | 2 | 4
	add_child(raycast_forward)

	raycast_left = RayCast3D.new()
	raycast_left.target_position = Vector3(-3, 0, -obstacle_check_distance * 0.7)
	raycast_left.collision_mask = 1 | 2 | 4
	add_child(raycast_left)

	raycast_right = RayCast3D.new()
	raycast_right.target_position = Vector3(3, 0, -obstacle_check_distance * 0.7)
	raycast_right.collision_mask = 1 | 2 | 4
	add_child(raycast_right)

func _physics_process(delta: float) -> void:
	if not traffic_mode:
		super._physics_process(delta)
		return

	if is_dead or health <= 0:
		return

	_update_traffic_ai(delta)
	_handle_steering(delta)
	_handle_speed(delta)
	_check_traffic_lights(delta)
	_check_obstacles(delta)

	super._physics_process(delta)

func _update_traffic_ai(delta: float) -> void:
	if waypoints.is_empty():
		return

	var target_waypoint = waypoints[current_waypoint_index]
	var to_target = target_waypoint - global_position
	to_target.y = 0
	var distance = to_target.length()

	if distance < 5.0:
		current_waypoint_index += 1
		reached_waypoint.emit(current_waypoint_index - 1)

		if current_waypoint_index >= waypoints.size():
			reached_destination.emit()
			queue_free()
			return

	_check_lane_change(delta)

func _handle_steering(delta: float) -> void:
	if waypoints.is_empty() or current_waypoint_index >= waypoints.size():
		steering = 0.0
		return

	var target_waypoint = waypoints[current_waypoint_index]
	var to_target = target_waypoint - global_position
	to_target.y = 0

	var forward = -global_transform.basis.z
	var target_direction = to_target.normalized()

	var angle_to_target = atan2(target_direction.x, target_direction.z)
	var current_angle = atan2(forward.x, forward.z)
	var angle_diff = lerp_angle(angle_to_target, current_angle, 0.0) - current_angle

	if angle_diff > PI:
		angle_diff -= TAU
	elif angle_diff < -PI:
		angle_diff += TAU

	steering = clamp(angle_diff * steering_sensitivity, -1.0, 1.0)

	if is_changing_lane:
		var lane_target = target_lane * 3.5 + lane_offset
		var current_lane_pos = global_transform.basis.x.dot(global_position)
		var lane_diff = lane_target - current_lane_pos
		steering += clamp(lane_diff * 0.5, -0.5, 0.5)

func _handle_speed(delta: float) -> void:
	var target = target_speed

	if traffic_light_stop:
		target = 0.0

	if raycast_forward.is_colliding():
		var obstacle = raycast_forward.get_collider()
		var dist = global_position.distance_to(raycast_forward.get_collision_point())

		if obstacle and obstacle.is_in_group("vehicle"):
			var obstacle_speed = obstacle.get_linear_velocity().length() if obstacle.has_method("get_linear_velocity") else 0
			if obstacle_speed < current_speed * 0.5:
				target = obstacle_speed * 0.8
				if dist < follow_distance * 0.5:
					target = 0.0
		elif dist < 5.0:
			target = 0.0

	if current_speed < target:
		current_speed = min(current_speed + acceleration_rate * delta, target)
	else:
		current_speed = max(current_speed - deceleration_rate * delta, target)

	engine_force = current_speed / max_speed
	acceleration = engine_force

func _check_lane_change(delta: float) -> void:
	if is_changing_lane:
		lane_change_timer += delta
		if lane_change_timer >= lane_change_duration:
			is_changing_lane = false
			current_lane = target_lane
			lane_change_timer = 0.0
		return

	lane_change_timer += delta
	if lane_change_timer < 5.0:
		return

	if randf() < 0.02:
		var can_change_left = _can_change_lane(-1)
		var can_change_right = _can_change_lane(1)

		if can_change_left and can_change_right:
			target_lane = current_lane + (1 if randf() < 0.5 else -1)
			is_changing_lane = true
		elif can_change_left:
			target_lane = current_lane - 1
			is_changing_lane = true
		elif can_change_right:
			target_lane = current_lane + 1
			is_changing_lane = true

		if is_changing_lane:
			lane_change_timer = 0.0

func _can_change_lane(direction: int) -> bool:
	var target_lane_idx = current_lane + direction
	var road_type = TrafficManager.get_road_type_at(global_position) if TrafficManager else TrafficManager.RoadType.LOCAL
	var max_lanes = 1

	match road_type:
		TrafficManager.RoadType.HIGHWAY:
			max_lanes = 3
		TrafficManager.RoadType.ARTERIAL:
			max_lanes = 2
		TrafficManager.RoadType.COLLECTOR:
			max_lanes = 2
		_:
			max_lanes = 1

	if target_lane_idx < 0 or target_lane_idx >= max_lanes:
		return false

	var check_ray = direction < 0 ? raycast_left : raycast_right
	if check_ray.is_colliding():
		var obstacle = check_ray.get_collider()
		if obstacle and obstacle.is_in_group("vehicle"):
			return false

	return true

func _check_traffic_lights(delta: float) -> void:
	if not TrafficManager:
		traffic_light_stop = false
		return

	var intersections = TrafficManager.road_network.get("intersections", [])
	var nearest_light = null
	var nearest_dist = INF

	for intersection in intersections:
		if not intersection["has_traffic_light"]:
			continue

		var dist = global_position.distance_to(intersection["position"])
		if dist < 30.0 and dist < nearest_dist:
			nearest_dist = dist
			nearest_light = intersection

	if nearest_light:
		var light_state = TrafficManager.get_traffic_light_state(nearest_light["id"])
		var to_intersection = nearest_light["position"] - global_position
		to_intersection.y = 0
		var forward = -global_transform.basis.z
		var dot = forward.dot(to_intersection.normalized())

		if dot > 0.5 and nearest_dist < 20.0:
			if light_state == TrafficManager.TrafficLightState.RED:
				traffic_light_stop = true
				stop_timer += delta
				if stop_timer > max_stop_time:
					traffic_light_stop = false
					stop_timer = 0.0
			elif light_state == TrafficManager.TrafficLightState.YELLOW and nearest_dist < 10.0:
				traffic_light_stop = true
			else:
				traffic_light_stop = false
				stop_timer = 0.0
	else:
		traffic_light_stop = false
		stop_timer = 0.0

func _check_obstacles(delta: float) -> void:
	obstacle_check_timer += delta
	if obstacle_check_timer < 0.1:
		return
	obstacle_check_timer = 0.0

	if raycast_forward.is_colliding():
		var obstacle = raycast_forward.get_collider()
		var dist = global_position.distance_to(raycast_forward.get_collision_point())

		if dist < 8.0 and obstacle and not obstacle.is_in_group("vehicle"):
			collision_imminent.emit(obstacle)
			target_speed = 0.0

func set_traffic_mode(enabled: bool, path: Array[String] = []) -> void:
	traffic_mode = enabled
	if enabled and not path.is_empty() and TrafficManager:
		waypoints = []
		for node_id in path:
			var node = TrafficManager._find_node(node_id)
			if node:
				waypoints.append(node["position"])

		if waypoints.size() > 1:
			current_waypoint_index = 0
			target_speed = TrafficManager.get_speed_limit_at(global_position) / 3.6
			set_physics_process(true)

func is_at_despawn() -> bool:
	return waypoints.is_empty() or current_waypoint_index >= waypoints.size()

func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["traffic_mode"] = traffic_mode
	data["waypoints"] = waypoints
	data["current_waypoint"] = current_waypoint_index
	data["target_speed"] = target_speed
	return data

func apply_save_data(data: Dictionary) -> void:
	super.apply_save_data(data)
	traffic_mode = data.get("traffic_mode", false)
	waypoints = data.get("waypoints", [])
	current_waypoint_index = data.get("current_waypoint", 0)
	target_speed = data.get("target_speed", 50.0)