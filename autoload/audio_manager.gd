extends Node

signal music_changed(track: String)
signal sfx_played(sound: String)

var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var current_music: AudioStreamPlayer3D = null
var music_crossfade_time: float = 2.0
var is_music_fading: bool = false
var music_playlist: Array[String] = []
var current_track_index: int = 0
var is_shuffle: bool = false
var is_repeat: bool = true

static var instance: AudioManager = null

var sfx_pool: Array[AudioStreamPlayer3D] = []
var max_sfx_channels: int = 32
var sfx_pool_index: int = 0

func _ready() -> void:
	instance = self
	_create_sfx_pool()
	_load_audio_settings()

func _create_sfx_pool() -> void:
	for i in range(max_sfx_channels):
		var player = AudioStreamPlayer3D.new()
		player.name = "SFX_Channel_%d" % i
		player.bus = "SFX"
		add_child(player)
		sfx_pool.append(player)

func _load_audio_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 0.7)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		_apply_volumes()

func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume * master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume * master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(sfx_volume * master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(music_volume * master_volume * 0.5))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Radio"), linear_to_db(music_volume * master_volume * 0.7))

func play_music(track_path: String, crossfade: bool = true) -> void:
	var new_music = AudioStreamPlayer3D.new()
	new_music.name = "Music_Player"
	new_music.stream = load(track_path)
	new_music.bus = "Music"
	new_music.volume_db = linear_to_db(music_volume * master_volume)
	add_child(new_music)

	if current_music and crossfade:
		is_music_fading = true
		var tween = create_tween()
		tween.tween_property(current_music, "volume_db", linear_to_db(-80.0), music_crossfade_time)
		tween.tween_callback(_on_music_fade_out_complete.bind(new_music))
	else:
		if current_music:
			current_music.queue_free()
		current_music = new_music
		current_music.play()
		music_changed.emit(track_path)

func _on_music_fade_out_complete(new_music: AudioStreamPlayer3D) -> void:
	if current_music:
		current_music.queue_free()
	current_music = new_music
	current_music.play()
	is_music_fading = false
	music_changed.emit(current_music.stream.get_path() if current_music.stream else "")

func stop_music(fade_out: bool = true) -> void:
	if current_music:
		if fade_out:
			var tween = create_tween()
			tween.tween_property(current_music, "volume_db", linear_to_db(-80.0), music_crossfade_time)
			tween.tween_callback(_on_stop_music_complete)
		else:
			_on_stop_music_complete()

func _on_stop_music_complete() -> void:
	if current_music:
		current_music.queue_free()
		current_music = null

func play_sfx(sound_path: String, position: Vector3 = Vector3.ZERO, volume_db: float = 0.0, pitch: float = 1.0, max_distance: float = 50.0) -> AudioStreamPlayer3D:
	var player = sfx_pool[sfx_pool_index]
	sfx_pool_index = (sfx_pool_index + 1) % max_sfx_channels

	player.stream = load(sound_path)
	player.global_position = position
	player.volume_db = linear_to_db(sfx_volume * master_volume) + volume_db
	player.pitch_scale = pitch
	player.max_distance = max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.play()

	sfx_played.emit(sound_path)
	return player

func play_sfx_2d(sound_path: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.stream = load(sound_path)
	player.bus = "SFX"
	player.volume_db = linear_to_db(sfx_volume * master_volume) + volume_db
	player.pitch_scale = pitch
	player.play()
	add_child(player)
	player.finished.connect(player.queue_free.bind())
	sfx_played.emit(sound_path)
	return player

func play_vehicle_engine(vehicle: Node3D, engine_sound: String, rpm: float, load: float) -> void:
	var player = vehicle.get_node_or_null("EngineSound") as AudioStreamPlayer3D
	if not player:
		player = AudioStreamPlayer3D.new()
		player.name = "EngineSound"
		player.bus = "SFX"
		vehicle.add_child(player)
		player.stream = load(engine_sound)
		player.max_distance = 80.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

	player.pitch_scale = lerp(0.5, 2.0, rpm)
	player.volume_db = linear_to_db(sfx_volume * master_volume) + lerp(-20.0, 0.0, load)

	if not player.playing:
		player.play()

func play_vehicle_tire_screech(vehicle: Node3D, intensity: float) -> void:
	if intensity > 0.3:
		play_sfx("res://assets/audio/sfx/vehicle/tire_screech.ogg", vehicle.global_position, linear_to_db(intensity), 1.0, 30.0)

func play_vehicle_crash(vehicle: Node3D, impact_velocity: float) -> void:
	var volume = clamp(impact_velocity / 50.0, 0.0, 1.0)
	play_sfx("res://assets/audio/sfx/vehicle/crash_%d.ogg" % randi_range(1, 3), vehicle.global_position, linear_to_db(volume), 1.0, 50.0)

func play_footstep(position: Vector3, surface_type: String = "concrete", volume: float = 1.0) -> void:
	var sound_path = "res://assets/audio/sfx/footsteps/%s_%d.ogg" % [surface_type, randi_range(1, 4)]
	play_sfx(sound_path, position, linear_to_db(volume * 0.5), 1.0, 10.0)

func play_weapon_sound(weapon_type: String, position: Vector3) -> void:
	var sound_path = "res://assets/audio/sfx/weapons/%s_fire.ogg" % weapon_type
	play_sfx(sound_path, position, 0.0, 1.0, 100.0)

func play_radio_station(station_name: String) -> void:
	var station_path = "res://assets/audio/radio/%s.ogg" % station_name
	play_music(station_path, true)

func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	_apply_volumes()
	_save_audio_settings()

func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	_apply_volumes()
	_save_audio_settings()

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	_apply_volumes()
	_save_audio_settings()

func _save_audio_settings() -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save("user://settings.cfg")

func get_master_volume() -> float:
	return master_volume

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

func set_music_playlist(tracks: Array[String]) -> void:
	music_playlist = tracks
	current_track_index = 0
	if music_playlist.size() > 0:
		play_music(music_playlist[0])

func play_next_track() -> void:
	if music_playlist.is_empty():
		return

	if is_shuffle:
		current_track_index = randi() % music_playlist.size()
	else:
		current_track_index = (current_track_index + 1) % music_playlist.size()

	play_music(music_playlist[current_track_index])

func play_previous_track() -> void:
	if music_playlist.is_empty():
		return

	current_track_index = (current_track_index - 1 + music_playlist.size()) % music_playlist.size()
	play_music(music_playlist[current_track_index])

func toggle_shuffle() -> void:
	is_shuffle = not is_shuffle

func toggle_repeat() -> void:
	is_repeat = not is_repeat

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		_save_audio_settings()