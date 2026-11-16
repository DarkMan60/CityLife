extends Node3D

signal game_ready()
signal player_spawned(player: Node3D)

var player: PlayerCharacter = null
var city_environment: Node3D = null
var is_initialized: bool = false

func _ready() -> void:
	_initialize_game()

func _initialize_game() -> void:
	GraphicsSettings.apply_quality(GameManager.get_graphics_quality())

	city_environment = get_node("CityEnvironment")

	# Register city environment with WorldManager for spawn positions
	WorldManager.CityEnvironment = city_environment

	player = get_node("Player") as PlayerCharacter
	if player:
		GameManager.set_player(player)
		player_spawned.emit(player)
		GameManager.set_game_state(GameManager.GameState.PLAYING)

	WorldManager.set_time_of_day(12.0)

	TrafficManager.set_traffic_density(GraphicsSettings.get_setting("traffic_density"))
	PedestrianManager.max_pedestrians = int(100 * GraphicsSettings.get_setting("crowd_density"))

	is_initialized = true
	game_ready.emit()

	UIManager.show_hud()
	UIManager.show_minimap()
	UIManager.set_crosshair_visible(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not is_initialized:
		return

	if Input.is_action_just_pressed("pause"):
		if GameManager.get_game_state() == GameManager.GameState.PLAYING:
			GameManager.pause_game()
		elif GameManager.get_game_state() == GameManager.GameState.PAUSED:
			GameManager.resume_game()

func get_player() -> PlayerCharacter:
	return player

func get_city_environment() -> Node3D:
	return city_environment