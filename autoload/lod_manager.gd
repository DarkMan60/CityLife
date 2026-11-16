extends Node

signal lod_level_changed(level: int)
signal performance_warning(message: String)

enum LODLevel {
	HIGH = 0,      # Full detail, all effects
	MEDIUM = 1,    # Reduced detail, some effects
	LOW = 2,       # Minimal detail, no effects
	POTATO = 3     # Absolute minimum for very old devices
}

static var instance: LODManager = null

var current_lod: LODLevel = LODLevel.MEDIUM
var auto_lod: bool = true
var target_fps: int = 30
var performance_history: Array[float] = []
var history_size: int = 60
var last_lod_check: float = 0.0
var lod_check_interval: float = 2.0

# Distance culling settings
var max_draw_distance: float = 1000.0
var lod_distances: Dictionary = {
	LODLevel.HIGH: {"high": 100.0, "medium": 300.0, "low": 600.0, "cull": 1000.0},
	LODLevel.MEDIUM: {"high": 50.0, "medium": 200.0, "low": 400.0, "cull": 800.0},
	LODLevel.LOW: {"high": 30.0, "medium": 150.0, "low": 300.0, "cull": 500.0},
	LODLevel.POTATO: {"high": 20.0, "medium": 100.0, "low": 200.0, "cull": 300.0},
}

# Object tracking for LOD
var tracked_objects: Dictionary = {}  # node_path -> {mesh_instance, distances, current_lod}
var update_interval: float = 0.5
var update_timer: float = 0.0

# Performance monitoring
var frame_time_samples: Array[float] = []
var avg_frame_time: float = 0.0
var low_fps_counter: int = 0
var high_fps_counter: int = 0

func _ready() -> void:
	instance = self
	_load_lod_settings()

	# Connect to graphics settings changes
	if GraphicsSettings:
		GraphicsSettings.setting_changed.connect(_on_graphics_setting_changed)

	# Apply initial LOD based on graphics quality
	_apply_lod_from_quality()

func _process(delta: float) -> void:
	if auto_lod:
		_monitor_performance(delta)

	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_object_lods()

func _monitor_performance(delta: float) -> void:
	var current_fps = Engine.get_frames_per_second()

	performance_history.append(current_fps)
	if performance_history.size() > history_size:
		performance_history.pop_front()

	last_lod_check += delta
	if last_lod_check >= lod_check_interval:
		last_lod_check = 0.0
		_evaluate_lod_adjustment()

func _evaluate_lod_adjustment() -> void:
	if performance_history.is_empty():
		return

	var avg_fps = 0.0
	for fps in performance_history:
		avg_fps += fps
	avg_fps /= performance_history.size()

	# Adjust LOD based on performance
	if avg_fps < target_fps * 0.8:
		low_fps_counter += 1
		high_fps_counter = 0

		if low_fps_counter >= 3 and int(current_lod) < int(LODLevel.POTATO):
			set_lod(LODLevel(int(current_lod) + 1))
			performance_warning.emit("Performance low, reducing LOD to %s" % _get_lod_name(current_lod))
			low_fps_counter = 0

	elif avg_fps > target_fps * 1.1:
		high_fps_counter += 1
		low_fps_counter = 0

		if high_fps_counter >= 5 and int(current_lod) > int(LODLevel.HIGH):
			set_lod(LODLevel(int(current_lod) - 1))
			high_fps_counter = 0

func _apply_lod_from_quality() -> void:
	if not GraphicsSettings:
		return

	var quality = GraphicsSettings.get_current_quality()
	match quality:
		GraphicsSettings.QualityLevel.HIGH:
			set_lod(LODLevel.HIGH)
		GraphicsSettings.QualityLevel.MEDIUM:
			set_lod(LODLevel.MEDIUM)
		GraphicsSettings.QualityLevel.LOW:
			set_lod(LODLevel.LOW)

func _on_graphics_setting_changed(setting: String, value: Variant) -> void:
	if setting == "quality" and auto_lod:
		_apply_lod_from_quality()
	elif setting == "draw_distance":
		max_draw_distance = value
		_update_object_lods()

func set_lod(level: LODLevel) -> void:
	if level == current_lod:
		return

	current_lod = level
	lod_level_changed.emit(int(level))
	_apply_lod_settings()
	_update_object_lods()

func _apply_lod_settings() -> void:
	var distances = lod_distances[current_lod]
	max_draw_distance = distances["cull"]

	# Update camera far plane
	if CameraManager:
		CameraManager.set_max_distance(max_draw_distance)

	# Update world environment fog to match cull distance
	if WorldManager:
		var env = WorldManager.get_environment()
		if env:
			env.fog_enabled = true
			env.fog_density = 0.001 * (1000.0 / max_draw_distance)
			env.fog_height = 0.0
			env.fog_height_density = 0.5

func _update_object_lods() -> void:
	if not GameManager or not GameManager.get_player():
		return

	var player_pos = GameManager.get_player().global_position
	var distances = lod_distances[current_lod]

	for node_path in tracked_objects:
		var obj_data = tracked_objects[node_path]
		var mesh = obj_data.mesh_instance

		if not mesh or not is_instance_valid(mesh):
			continue

		var dist = mesh.global_position.distance_to(player_pos)

		# Determine LOD level for this object
		var new_lod = _get_object_lod_level(dist, distances)

		if new_lod != obj_data.current_lod:
			obj_data.current_lod = new_lod
			_apply_object_lod(mesh, new_lod, obj_data)

func _get_object_lod_level(distance: float, distances: Dictionary) -> int:
	if distance > distances["cull"]:
		return -1  # Culled
	elif distance > distances["low"]:
		return 2   # Low detail
	elif distance > distances["medium"]:
		return 1   # Medium detail
	else:
		return 0   # High detail

func _apply_object_lod(mesh: MeshInstance3D, lod_level: int, obj_data: Dictionary) -> void:
	if lod_level == -1:
		mesh.visible = false
		return

	mesh.visible = true

	# Apply LOD based on level
	match lod_level:
		0:  # High
			mesh.material_override = obj_data.get("material_high")
			mesh.mesh = obj_data.get("mesh_high")
		1:  # Medium
			mesh.material_override = obj_data.get("material_medium", obj_data.get("material_high"))
			mesh.mesh = obj_data.get("mesh_medium", obj_data.get("mesh_high"))
		2:  # Low
			mesh.material_override = obj_data.get("material_low", obj_data.get("material_medium", obj_data.get("material_high")))
			mesh.mesh = obj_data.get("mesh_low", obj_data.get("mesh_medium", obj_data.get("mesh_high")))

func register_object(mesh: MeshInstance3D, lod_meshes: Dictionary = {}, lod_materials: Dictionary = {}) -> void:
	if not mesh or not is_instance_valid(mesh):
		return

	var node_path = mesh.get_path()

	var obj_data = {
		"mesh_instance": mesh,
		"current_lod": 0,
		"mesh_high": lod_meshes.get("high", mesh.mesh),
		"mesh_medium": lod_meshes.get("medium"),
		"mesh_low": lod_meshes.get("low"),
		"material_high": lod_materials.get("high", mesh.material_override),
		"material_medium": lod_materials.get("medium"),
		"material_low": lod_materials.get("low"),
	}

	tracked_objects[node_path] = obj_data

func unregister_object(mesh: MeshInstance3D) -> void:
	if not mesh:
		return
	var node_path = mesh.get_path()
	tracked_objects.erase(node_path)

func set_auto_lod(enabled: bool) -> void:
	auto_lod = enabled
	if not enabled:
		# Restore all objects to high detail
		for node_path in tracked_objects:
			var obj_data = tracked_objects[node_path]
			if obj_data.mesh_instance and is_instance_valid(obj_data.mesh_instance):
				obj_data.mesh_instance.visible = true
				obj_data.current_lod = 0
				_apply_object_lod(obj_data.mesh_instance, 0, obj_data)

func get_current_lod() -> LODLevel:
	return current_lod

func get_lod_name() -> String:
	return _get_lod_name(current_lod)

func _get_lod_name(level: int) -> String:
	match level:
		LODLevel.HIGH: return "HIGH"
		LODLevel.MEDIUM: return "MEDIUM"
		LODLevel.LOW: return "LOW"
		LODLevel.POTATO: return "POTATO"
	return "UNKNOWN"

func force_cull_distance(distance: float) -> void:
	max_draw_distance = distance

	# Update all tracked objects immediately
	if GameManager and GameManager.get_player():
		var player_pos = GameManager.get_player().global_position
		for node_path in tracked_objects:
			var obj_data = tracked_objects[node_path]
			var mesh = obj_data.mesh_instance
			if mesh and is_instance_valid(mesh):
				var dist = mesh.global_position.distance_to(player_pos)
				mesh.visible = dist <= distance

func get_performance_stats() -> Dictionary:
	var avg_fps = 0.0
	if not performance_history.is_empty():
		for fps in performance_history:
			avg_fps += fps
		avg_fps /= performance_history.size()

	return {
		"current_lod": _get_lod_name(current_lod),
		"auto_lod": auto_lod,
		"average_fps": avg_fps,
		"target_fps": target_fps,
		"tracked_objects": tracked_objects.size(),
		"max_draw_distance": max_draw_distance,
		"lod_distances": lod_distances[current_lod],
	}

func _load_lod_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://lod_settings.cfg") == OK:
		auto_lod = config.get_value("lod", "auto_lod", true)
		target_fps = config.get_value("lod", "target_fps", 30)
		current_lod = config.get_value("lod", "current_lod", int(LODLevel.MEDIUM))

func _save_lod_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("lod", "auto_lod", auto_lod)
	config.set_value("lod", "target_fps", target_fps)
	config.set_value("lod", "current_lod", int(current_lod))
	config.save("user://lod_settings.cfg")

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		_save_lod_settings()