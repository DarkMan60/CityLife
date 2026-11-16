extends Node

signal quality_changed(quality_level: int)
signal setting_changed(setting: String, value: Variant)

enum QualityLevel {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2
}

var current_quality: QualityLevel = QualityLevel.MEDIUM
var settings: Dictionary = {}

static var instance: GraphicsSettings = null

func _ready() -> void:
	instance = self
	_define_default_settings()
	_load_settings()
	apply_quality(current_quality)

func _define_default_settings() -> void:
	settings = {
		"render_scale": 1.0,
		"shadow_quality": 1,
		"shadow_distance": 100.0,
		"shadow_cascades": 2,
		"ssao_enabled": true,
		"ssao_quality": 1,
		"ssr_enabled": true,
		"ssr_quality": 1,
		"ssil_enabled": true,
		"bloom_enabled": true,
		"bloom_intensity": 1.0,
		"dof_enabled": false,
		"motion_blur_enabled": false,
		"msaa": 1,
		"fxaa_enabled": true,
		"anisotropic_filter": 4,
		"texture_quality": 1,
		"lod_bias": 1.0,
		"particle_quality": 1,
		"reflection_quality": 1,
		"vegetation_density": 1.0,
		"crowd_density": 1.0,
		"traffic_density": 1.0,
		"draw_distance": 500.0,
		"fog_quality": 1,
		"water_quality": 1,
		"v_sync": true,
		"frame_rate_cap": 60,
		"hdr_enabled": true,
		"gamma": 2.2,
		"contrast": 1.0,
		"brightness": 1.0,
		"saturation": 1.0
	}

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://graphics.cfg") == OK:
		current_quality = config.get_value("graphics", "quality", int(QualityLevel.MEDIUM))

		for key in settings:
			if config.has_section_key("graphics", key):
				settings[key] = config.get_value("graphics", key, settings[key])

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("graphics", "quality", int(current_quality))

	for key in settings:
		config.set_value("graphics", key, settings[key])

	config.save("user://graphics.cfg")

func apply_quality(quality: QualityLevel) -> void:
	current_quality = quality

	match quality:
		QualityLevel.LOW:
			_apply_low_preset()
		QualityLevel.MEDIUM:
			_apply_medium_preset()
		QualityLevel.HIGH:
			_apply_high_preset()

	_apply_settings()
	_save_settings()
	quality_changed.emit(int(quality))

func _apply_low_preset() -> void:
	settings["render_scale"] = 0.75
	settings["shadow_quality"] = 0
	settings["shadow_distance"] = 50.0
	settings["shadow_cascades"] = 1
	settings["ssao_enabled"] = false
	settings["ssr_enabled"] = false
	settings["ssil_enabled"] = false
	settings["bloom_enabled"] = false
	settings["dof_enabled"] = false
	settings["motion_blur_enabled"] = false
	settings["msaa"] = 1
	settings["fxaa_enabled"] = true
	settings["anisotropic_filter"] = 1
	settings["texture_quality"] = 0
	settings["lod_bias"] = 0.5
	settings["particle_quality"] = 0
	settings["reflection_quality"] = 0
	settings["vegetation_density"] = 0.3
	settings["crowd_density"] = 0.3
	settings["traffic_density"] = 0.5
	settings["draw_distance"] = 200.0
	settings["fog_quality"] = 0
	settings["water_quality"] = 0

func _apply_medium_preset() -> void:
	settings["render_scale"] = 1.0
	settings["shadow_quality"] = 1
	settings["shadow_distance"] = 100.0
	settings["shadow_cascades"] = 2
	settings["ssao_enabled"] = true
	settings["ssao_quality"] = 1
	settings["ssr_enabled"] = true
	settings["ssr_quality"] = 1
	settings["ssil_enabled"] = true
	settings["bloom_enabled"] = true
	settings["bloom_intensity"] = 0.8
	settings["dof_enabled"] = false
	settings["motion_blur_enabled"] = false
	settings["msaa"] = 1
	settings["fxaa_enabled"] = true
	settings["anisotropic_filter"] = 4
	settings["texture_quality"] = 1
	settings["lod_bias"] = 1.0
	settings["particle_quality"] = 1
	settings["reflection_quality"] = 1
	settings["vegetation_density"] = 0.7
	settings["crowd_density"] = 0.7
	settings["traffic_density"] = 1.0
	settings["draw_distance"] = 500.0
	settings["fog_quality"] = 1
	settings["water_quality"] = 1

func _apply_high_preset() -> void:
	settings["render_scale"] = 1.0
	settings["shadow_quality"] = 2
	settings["shadow_distance"] = 200.0
	settings["shadow_cascades"] = 4
	settings["ssao_enabled"] = true
	settings["ssao_quality"] = 2
	settings["ssr_enabled"] = true
	settings["ssr_quality"] = 2
	settings["ssil_enabled"] = true
	settings["bloom_enabled"] = true
	settings["bloom_intensity"] = 1.0
	settings["dof_enabled"] = true
	settings["motion_blur_enabled"] = true
	settings["msaa"] = 2
	settings["fxaa_enabled"] = true
	settings["anisotropic_filter"] = 8
	settings["texture_quality"] = 2
	settings["lod_bias"] = 1.5
	settings["particle_quality"] = 2
	settings["reflection_quality"] = 2
	settings["vegetation_density"] = 1.0
	settings["crowd_density"] = 1.0
	settings["traffic_density"] = 1.5
	settings["draw_distance"] = 1000.0
	settings["fog_quality"] = 2
	settings["water_quality"] = 2

func _apply_settings() -> void:
	var viewport = get_viewport()
	if viewport:
		viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS

	var env = WorldManager.get_environment() if WorldManager else null
	if env:
		if settings["ssao_enabled"]:
			env.ssao_enabled = true
			env.ssao_quality = int(settings["ssao_quality"])
			env.ssao_radius = 2.0
			env.ssao_intensity = 1.5
		else:
			env.ssao_enabled = false

		if settings["ssr_enabled"]:
			env.ssr_enabled = true
			env.ssr_max_steps = 64 * settings["ssr_quality"]
			env.ssr_roughness_quality = int(settings["ssr_quality"])
		else:
			env.ssr_enabled = false

		if settings["ssil_enabled"]:
			env.ssil_enabled = true
		else:
			env.ssil_enabled = false

		if settings["bloom_enabled"]:
			env.bloom_enabled = true
			env.bloom_intensity = settings["bloom_intensity"]
			env.bloom_threshold = 0.8
			env.bloom_scale = 1.0
		else:
			env.bloom_enabled = false

		if settings["dof_enabled"]:
			env.dof_blur_enabled = true
			env.dof_far_enabled = true
		else:
			env.dof_blur_enabled = false
			env.dof_far_enabled = false

		env.adjustment_enabled = true
		env.adjustment_contrast = settings["contrast"]
		env.adjustment_brightness = settings["brightness"] - 1.0
		env.adjustment_saturation = settings["saturation"]

	# MSAA - set via viewport
	if viewport:
		var msample = settings["msaa"]
		if msample >= 8:
			viewport.render_target_msaa = Viewport.MSAA_8X
		elif msample >= 4:
			viewport.render_target_msaa = Viewport.MSAA_4X
		elif msample >= 2:
			viewport.render_target_msaa = Viewport.MSAA_2X
		else:
			viewport.render_target_msaa = Viewport.MSAA_DISABLED

	# VSync
	if settings["v_sync"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Frame rate cap
	if settings["frame_rate_cap"] > 0:
		Engine.max_fps = settings["frame_rate_cap"]
	else:
		Engine.max_fps = 0

	# Render scale - use ProjectSettings or viewport
	if viewport:
		viewport.render_scale = settings["render_scale"]

	# Anisotropy - use ProjectSettings
	# RenderingServer.set_anisotropy_level(settings["anisotropic_filter"])

func set_setting(setting: String, value: Variant) -> void:
	if settings.has(setting):
		settings[setting] = value
		_apply_single_setting(setting, value)
		_save_settings()
		setting_changed.emit(setting, value)

func _apply_single_setting(setting: String, value: Variant) -> void:
	match setting:
		"v_sync":
			if value:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			else:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		"frame_rate_cap":
			Engine.max_fps = value if value > 0 else 0
		"render_scale":
			var viewport = get_viewport()
			if viewport:
				viewport.render_scale = value
		"gamma":
			var env = WorldManager.get_environment() if WorldManager else null
			if env:
				env.adjustment_enabled = true
		"brightness", "contrast", "saturation":
			var env = WorldManager.get_environment() if WorldManager else null
			if env:
				env.adjustment_enabled = true
				env.adjustment_brightness = settings["brightness"] - 1.0
				env.adjustment_contrast = settings["contrast"]
				env.adjustment_saturation = settings["saturation"]
		"traffic_density":
			if TrafficManager:
				TrafficManager.set_traffic_density(value)
		"crowd_density":
			if PedestrianManager:
				PedestrianManager.max_pedestrians = int(100 * value)
		_:
			_apply_settings()

func get_setting(setting: String) -> Variant:
	return settings.get(setting, null)

func get_all_settings() -> Dictionary:
	return settings.duplicate()

func get_current_quality() -> QualityLevel:
	return current_quality

func get_quality_name() -> String:
	return _get_quality_name(current_quality)

func reset_to_defaults() -> void:
	_define_default_settings()
	apply_quality(current_quality)

func get_performance_estimate() -> Dictionary:
	var score = 0
	match current_quality:
		QualityLevel.LOW: score = 80
		QualityLevel.MEDIUM: score = 50
		QualityLevel.HIGH: score = 20

	return {
		"estimated_fps": 60 - score,
		"gpu_load": score,
		"cpu_load": score * 0.7,
		"memory_usage": "Low" if current_quality == QualityLevel.LOW else ("Medium" if current_quality == QualityLevel.MEDIUM else "High"),
		"recommended_for": "Low-end devices" if current_quality == QualityLevel.LOW else ("Mid-range devices" if current_quality == QualityLevel.MEDIUM else "High-end devices")
	}

func _get_quality_name(quality: int) -> String:
	match quality:
		QualityLevel.LOW: return "LOW"
		QualityLevel.MEDIUM: return "MEDIUM"
		QualityLevel.HIGH: return "HIGH"
	return "UNKNOWN"

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		_save_settings()