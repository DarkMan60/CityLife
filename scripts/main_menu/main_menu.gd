extends Node3D

var menu_camera: Camera3D = null
var background_city: Node3D = nil
var rotation_speed: float = 0.02

func _ready() -> void:
	menu_camera = get_node("MenuCamera")
	background_city = get_node("BackgroundCity")

	_setup_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _setup_ui() -> void:
	var ui_canvas = get_node("UICanvas")
	var vbox = ui_canvas.get_node("MenuPanel/VBoxContainer")

	vbox.get_node("NewGameBtn").pressed.connect(_on_new_game_pressed)
	vbox.get_node("LoadGameBtn").pressed.connect(_on_load_game_pressed)
	vbox.get_node("SettingsBtn").pressed.connect(_on_settings_pressed)
	vbox.get_node("GarageBtn").pressed.connect(_on_garage_pressed)
	vbox.get_node("MissionsBtn").pressed.connect(_on_missions_pressed)
	vbox.get_node("MapBtn").pressed.connect(_on_map_pressed)
	vbox.get_node("QuitBtn").pressed.connect(_on_quit_pressed)

func _process(delta: float) -> void:
	if background_city:
		background_city.global_rotation.y += rotation_speed * delta

	if menu_camera:
		menu_camera.global_position = Vector3(
			sin(Time.get_ticks_msec() / 5000.0) * 100,
			50 + sin(Time.get_ticks_msec() / 3000.0) * 10,
			80 + cos(Time.get_ticks_msec() / 4000.0) * 15
		)
		menu_camera.look_at(Vector3(0, 0, 0))

func _on_new_game_pressed() -> void:
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	get_tree().change_scene_to_file("res://scenes/main/main_game.tscn")

func _on_load_game_pressed() -> void:
	UIManager.show_load_menu()

func _on_settings_pressed() -> void:
	UIManager.show_settings_menu()

func _on_garage_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/garage/garage.tscn")

func _on_missions_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/missions/mission_select.tscn")

func _on_map_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map_view.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()