extends Node

signal time_changed(hour: int, minute: int)
signal weather_changed(weather: String)
signal area_unlocked(area_name: String)

enum Weather {
	CLEAR,
	CLOUDY,
	RAIN,
	THUNDERSTORM,
	FOG,
	SNOW
}

enum TimeOfDay {
	DAWN = 5,
	MORNING = 8,
	NOON = 12,
	AFTERNOON = 16,
	DUSK = 19,
	NIGHT = 22,
	MIDNIGHT = 0
}

var current_time: float = 12.0
var time_scale: float = 30.0
var current_weather: Weather = Weather.CLEAR
var target_weather: Weather = Weather.CLEAR
var weather_transition: float = 0.0
var weather_duration: float = 300.0
var weather_timer: float = 0.0
var unlocked_areas: Array[String] = ["downtown"]
var current_area: String = "downtown"
var day_length: float = 1440.0
var sun_angle: float = 0.0
var moon_angle: float = 0.0
var ambient_light_color: Color = Color(1, 1, 1)
var ambient_light_energy: float = 1.0
var fog_density: float = 0.0
var fog_color: Color = Color(0.5, 0.5, 0.6)
var rain_intensity: float = 0.0
var wind_strength: float = 0.0
var wind_direction: Vector3 = Vector3(1, 0, 0)

static var instance: WorldManager = null

var CityEnvironment: Node3D = null

var directional_light: DirectionalLight3D = null
var sky_environment: Environment = null
var weather_particles: GPUParticles3D = null

func _ready() -> void:
	instance = self
	_setup_environment()
	_load_world_state()

func _setup_environment() -> void:
	var world_env = WorldEnvironment.new()
	world_env.environment = Environment.new()
	world_env.environment.background_mode = Environment.BG_SKY
	world_env.environment.sky = PhysicalSkyMaterial.new()
	world_env.environment.adjustment_enabled = true
	add_child(world_env)
	sky_environment = world_env.environment

	directional_light = DirectionalLight3D.new()
	directional_light.name = "Sun"
	directional_light.light_color = Color(1, 0.95, 0.8)
	directional_light.light_energy = 2.0
	directional_light.light_size = 0.53
	directional_light.shadow_enabled = true
	directional_light.shadow_max_distance = 200.0
	directional_light.shadow_normal_bias = 0.3
	directional_light.shadow_bias = 0.005
	directional_light.shadow_blur = 1.0
	directional_light.shadow_filter = 2  # SHADOW_FILTER_PCF5
	add_child(directional_light)

	weather_particles = GPUParticles3D.new()
	weather_particles.name = "Weather_Particles"
	weather_particles.emitting = false
	weather_particles.amount = 5000
	weather_particles.lifetime = 5.0
	weather_particles.one_shot = false
	weather_particles.local_coords = false
	add_child(weather_particles)

	_update_environment()

func _load_world_state() -> void:
	var config = ConfigFile.new()
	if config.load("user://world_state.cfg") == OK:
		current_time = config.get_value("world", "time", 12.0)
		current_weather = config.get_value("world", "weather", int(Weather.CLEAR))
		unlocked_areas = config.get_value("world", "unlocked_areas", ["downtown"])
		current_area = config.get_value("world", "current_area", "downtown")

func _save_world_state() -> void:
	var config = ConfigFile.new()
	config.set_value("world", "time", current_time)
	config.set_value("world", "weather", int(current_weather))
	config.set_value("world", "unlocked_areas", unlocked_areas)
	config.set_value("world", "current_area", current_area)
	config.save("user://world_state.cfg")

func _process(delta: float) -> void:
	_update_time(delta)
	_update_weather(delta)
	_update_environment()

func _update_time(delta: float) -> void:
	current_time = fmod(current_time + delta * (24.0 / day_length) * time_scale, 24.0)

	var hour = int(current_time)
	var minute = int(fmod(current_time * 60.0, 60.0))

	sun_angle = (current_time / 24.0) * TAU - PI/2
	moon_angle = sun_angle + PI

	if directional_light:
		directional_light.global_rotation = Vector3(-sun_angle, PI/4, 0)

	_update_lighting_for_time()

	if hour != int(current_time - delta * (24.0 / day_length) * time_scale):
		time_changed.emit(hour, minute)

func _update_lighting_for_time() -> void:
	var time_factor = sin(sun_angle)

	if time_factor > 0.1:
		ambient_light_energy = lerp(0.3, 1.0, time_factor)
		ambient_light_color = Color(1, 0.95, 0.8)
		if directional_light:
			directional_light.light_energy = lerp(0.5, 3.0, time_factor)
			directional_light.light_color = Color(1, 0.95, 0.8)
	else:
		ambient_light_energy = lerp(0.1, 0.3, max(0.0, time_factor + 0.1) / 0.2)
		ambient_light_color = Color(0.3, 0.3, 0.5)
		if directional_light:
			directional_light.light_energy = 0.1
			directional_light.light_color = Color(0.5, 0.5, 0.7)

	if sky_environment and sky_environment.sky:
		var sky = sky_environment.sky
		if sky is PhysicalSkyMaterial:
			sky.sun_latitude = -sun_angle
			sky.sun_longitude = PI/4
			sky.energy_multiplier = max(0.1, time_factor * 2.0)
			sky.ground_color = Color(0.1, 0.1, 0.15) if time_factor < 0 else Color(0.3, 0.25, 0.2)

func _update_weather(delta: float) -> void:
	weather_timer += delta

	if weather_timer >= weather_duration:
		weather_timer = 0.0
		weather_duration = randf_range(180.0, 600.0)
		_set_random_weather()

	if current_weather != target_weather:
		weather_transition = min(weather_transition + delta / 10.0, 1.0)
		if weather_transition >= 1.0:
			current_weather = target_weather
			weather_transition = 0.0
	else:
		weather_transition = max(weather_transition - delta / 10.0, 0.0)

	_apply_weather_effects()

func _set_random_weather() -> void:
	var weights = {
		Weather.CLEAR: 50,
		Weather.CLOUDY: 25,
		Weather.RAIN: 15,
		Weather.THUNDERSTORM: 5,
		Weather.FOG: 3,
		Weather.SNOW: 2
	}

	var total = 0
	for w in weights.values():
		total += w

	var roll = randi() % total
	var cumulative = 0

	for weather in weights:
		var weight = weights[weather]
		cumulative += weight
		if roll < cumulative:
			target_weather = weather
			break

func _apply_weather_effects() -> void:
	var t = weather_transition
	var current = current_weather
	var target = target_weather

	rain_intensity = 0.0
	fog_density = 0.0
	wind_strength = 0.0

	match current:
		Weather.CLEAR:
			fog_density = 0.0
			wind_strength = 0.2
		Weather.CLOUDY:
			fog_density = 0.05
			wind_strength = 0.5
			ambient_light_energy *= 0.7
		Weather.RAIN:
			rain_intensity = 0.7
			fog_density = 0.1
			wind_strength = 1.0
			ambient_light_energy *= 0.5
		Weather.THUNDERSTORM:
			rain_intensity = 1.0
			fog_density = 0.15
			wind_strength = 2.0
			ambient_light_energy *= 0.3
		Weather.FOG:
			fog_density = 0.5
			wind_strength = 0.1
			ambient_light_energy *= 0.4
		Weather.SNOW:
			rain_intensity = 0.3
			fog_density = 0.2
			wind_strength = 0.8
			ambient_light_energy *= 0.6

	if t > 0.0:
		var target_rain = 0.0
		var target_fog = 0.0
		var target_wind = 0.0

		match target:
			Weather.RAIN, Weather.THUNDERSTORM:
				target_rain = 1.0 if target == Weather.THUNDERSTORM else 0.7
			Weather.FOG:
				target_fog = 0.5
			Weather.SNOW:
				target_rain = 0.3
				target_fog = 0.2
				target_wind = 0.8
			Weather.CLOUDY:
				target_fog = 0.05
				target_wind = 0.5
			Weather.CLEAR:
				target_wind = 0.2

		rain_intensity = lerp(rain_intensity, target_rain, t)
		fog_density = lerp(fog_density, target_fog, t)
		wind_strength = lerp(wind_strength, target_wind, t)

	_update_weather_particles()

func _update_weather_particles() -> void:
	if not weather_particles:
		return

	var material = weather_particles.process_material as ParticleProcessMaterial
	if not material:
		material = ParticleProcessMaterial.new()
		weather_particles.process_material = material

	if rain_intensity > 0.1:
		weather_particles.emitting = true
		weather_particles.amount = int(5000 * rain_intensity)
		material.gravity = Vector3(0, -20.0, 0)
		material.initial_velocity = Vector3(0, 0, 0)
		material.velocity_random = 5.0
		material.spread = PI
		material.scale = 0.1
		material.color_ramp = Gradient.new()
		(material.color_ramp as Gradient).set_point(0, Color(0.5, 0.5, 0.7, rain_intensity))
		(material.color_ramp as Gradient).set_point(1, Color(0.5, 0.5, 0.7, 0.0))
	else:
		weather_particles.emitting = false

func _update_environment() -> void:
	if sky_environment:
		sky_environment.fog_enabled = fog_density > 0.01
		sky_environment.fog_density = fog_density
		sky_environment.fog_light_color = fog_color
		sky_environment.fog_aerial_perspective = true
		sky_environment.fog_height = 0.0
		sky_environment.fog_height_density = 0.5

	if weather_particles:
		weather_particles.global_position = Vector3(0, 50, 0) + (GameManager.get_player().global_position if GameManager.get_player() else Vector3.ZERO)

func set_time_of_day(hour: float) -> void:
	current_time = fmod(hour, 24.0)
	_update_lighting_for_time()

func get_time_of_day() -> float:
	return current_time

func get_time_string() -> String:
	var hour = int(current_time)
	var minute = int(fmod(current_time * 60.0, 60.0))
	return "%02d:%02d" % [hour, minute]

func set_weather(weather: Weather) -> void:
	target_weather = weather
	weather_transition = 0.0
	weather_changed.emit(_get_weather_name(weather))

func get_current_weather() -> Weather:
	return current_weather

func get_weather_name() -> String:
	return _get_weather_name(current_weather)

func force_weather(weather: Weather) -> void:
	current_weather = weather
	target_weather = weather
	weather_transition = 1.0
	weather_changed.emit(_get_weather_name(weather))

func _get_weather_name(weather: int) -> String:
	match weather:
		Weather.CLEAR: return "CLEAR"
		Weather.CLOUDY: return "CLOUDY"
		Weather.RAIN: return "RAIN"
		Weather.THUNDERSTORM: return "THUNDERSTORM"
		Weather.FOG: return "FOG"
		Weather.SNOW: return "SNOW"
	return "UNKNOWN"

func unlock_area(area_name: String) -> void:
	if area_name not in unlocked_areas:
		unlocked_areas.append(area_name)
		area_unlocked.emit(area_name)
		_save_world_state()

func is_area_unlocked(area_name: String) -> bool:
	return area_name in unlocked_areas

func get_unlocked_areas() -> Array[String]:
	return unlocked_areas

func set_unlocked_areas(areas: Array[String]) -> void:
	unlocked_areas = areas
	_save_world_state()

func set_current_area(area: String) -> void:
	current_area = area
	_save_world_state()

func get_current_area() -> String:
	return current_area

func get_sun_direction() -> Vector3:
	return Vector3(cos(sun_angle), sin(sun_angle), 0).normalized()

func get_moon_direction() -> Vector3:
	return Vector3(cos(moon_angle), sin(moon_angle), 0).normalized()

func get_ambient_light() -> Color:
	return ambient_light_color * ambient_light_energy

func get_wind() -> Vector3:
	return wind_direction.normalized() * wind_strength

func set_time_scale(scale: float) -> void:
	time_scale = clamp(scale, 0.1, 100.0)

func get_time_scale() -> float:
	return time_scale

func get_environment() -> Environment:
	return sky_environment

func get_spawn_position() -> Vector3:
	# Delegate to city environment if available
	if CityEnvironment and CityEnvironment.has_method("get_random_spawn_position"):
		return CityEnvironment.get_random_spawn_position()
	return Vector3(-200, 5, -100)

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		_save_world_state()