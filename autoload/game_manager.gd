extends Node

signal game_state_changed(state: String)
signal player_spawned(player: Node3D)
signal player_died()
signal mission_started(mission_id: String)
signal mission_completed(mission_id: String)
signal mission_failed(mission_id: String)
signal money_changed(amount: int)
signal wanted_level_changed(level: int)

enum GameState {
	MAIN_MENU,
	LOADING,
	PLAYING,
	PAUSED,
	GAME_OVER,
	MISSION_ACTIVE
}

var current_state: GameState = GameState.MAIN_MENU
var player: Node3D = null
var player_vehicle: Node3D = null
var current_mission: String = ""
var money: int = 5000
var wanted_level: int = 0
var max_wanted_level: int = 5
var is_player_in_vehicle: bool = false
var graphics_quality: int = 1
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var master_volume: float = 1.0
var save_slot: int = 1

static var instance: GameManager = null

func _ready() -> void:
	instance = self
	_load_settings()
	_connect_signals()

func _connect_signals() -> void:
	pass

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		graphics_quality = config.get_value("graphics", "quality", 1)
		music_volume = config.get_value("audio", "music_volume", 0.7)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		master_volume = config.get_value("audio", "master_volume", 1.0)
		save_slot = config.get_value("game", "save_slot", 1)

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("graphics", "quality", graphics_quality)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("game", "save_slot", save_slot)
	config.save("user://settings.cfg")

func set_game_state(state: GameState) -> void:
	current_state = state
	game_state_changed.emit(_get_enum_name(state))
	match state:
		GameState.PLAYING:
			Engine.time_scale = 1.0
		GameState.PAUSED:
			Engine.time_scale = 0.0
		GameState.GAME_OVER:
			_handle_game_over()
		_:
			pass

func get_game_state() -> GameState:
	return current_state

func set_player(new_player: Node3D) -> void:
	player = new_player
	player_spawned.emit(player)

func get_player() -> Node3D:
	return player

func set_player_vehicle(vehicle: Node3D) -> void:
	player_vehicle = vehicle
	is_player_in_vehicle = vehicle != null

func get_player_vehicle() -> Node3D:
	return player_vehicle

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func remove_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		money_changed.emit(money)
		return true
	return false

func get_money() -> int:
	return money

func set_wanted_level(level: int) -> void:
	wanted_level = clamp(level, 0, max_wanted_level)
	wanted_level_changed.emit(wanted_level)
	if PoliceManager:
		PoliceManager.on_wanted_level_changed(wanted_level)

func get_wanted_level() -> int:
	return wanted_level

func increase_wanted_level(amount: int = 1) -> void:
	set_wanted_level(wanted_level + amount)

func decrease_wanted_level(amount: int = 1) -> void:
	set_wanted_level(wanted_level - amount)

func start_mission(mission_id: String) -> void:
	current_mission = mission_id
	mission_started.emit(mission_id)
	set_game_state(GameState.MISSION_ACTIVE)

func complete_mission(mission_id: String) -> void:
	if current_mission == mission_id:
		mission_completed.emit(mission_id)
		current_mission = ""
		set_game_state(GameState.PLAYING)

func fail_mission(mission_id: String) -> void:
	if current_mission == mission_id:
		mission_failed.emit(mission_id)
		current_mission = ""
		set_game_state(GameState.PLAYING)

func get_current_mission() -> String:
	return current_mission

func set_graphics_quality(quality: int) -> void:
	graphics_quality = clamp(quality, 0, 2)
	if GraphicsSettings:
		GraphicsSettings.apply_quality(graphics_quality)
	_save_settings()

func get_graphics_quality() -> int:
	return graphics_quality

func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	if AudioManager:
		AudioManager.set_music_volume(music_volume * master_volume)
	_save_settings()

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	if AudioManager:
		AudioManager.set_sfx_volume(sfx_volume * master_volume)
	_save_settings()

func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	if AudioManager:
		AudioManager.set_master_volume(master_volume)
	_save_settings()

func _handle_game_over() -> void:
	player_died.emit()

func pause_game() -> void:
	if current_state == GameState.PLAYING or current_state == GameState.MISSION_ACTIVE:
		set_game_state(GameState.PAUSED)
		if UIManager:
			UIManager.show_pause_menu()

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		set_game_state(GameState.PLAYING)
		if UIManager:
			UIManager.hide_pause_menu()

func quit_to_main_menu() -> void:
	set_game_state(GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		_save_settings()

func _get_enum_name(value: int) -> String:
	# Helper to get enum name from value
	match value:
		0: return "MAIN_MENU"
		1: return "LOADING"
		2: return "PLAYING"
		3: return "PAUSED"
		4: return "GAME_OVER"
		5: return "MISSION_ACTIVE"
	return "UNKNOWN"