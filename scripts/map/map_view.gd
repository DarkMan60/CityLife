extends Control

var map_camera: Camera3D = nil
var map_viewport: SubViewport = nil
var map_texture: TextureRect = nil

func _ready() -> void:
	map_camera = get_node("MapContainer/MapViewport/MapCamera")
	map_viewport = get_node("MapContainer/MapViewport")
	map_texture = get_node("MapContainer/MapTexture")

	_setup_map()
	get_node("MapContainer/BackBtn").pressed.connect(_on_back_pressed)

func _setup_map() -> void:
	var viewport_texture = map_viewport.get_texture()
	map_texture.texture = viewport_texture

	if WorldManager:
		map_camera.position = Vector3(0, 500, 0)
		map_camera.fov = 45

func _process(delta: float) -> void:
	_update_map_markers()

func _update_map_markers() -> void:
	if GameManager and GameManager.get_player():
		var player = GameManager.get_player()
		var player_pos = player.global_position
		var map_pos = Vector2(player_pos.x, -player_pos.z) + map_texture.size / 2

	if MissionManager and MissionManager.get_active_mission() != "":
		var mission = MissionManager.get_mission(MissionManager.get_active_mission())
		if mission and mission["objectives"].size() > 0:
			var current_obj = mission["objectives"][mission["current_objective"]]
			if current_obj.has("position"):
				var obj_pos = current_obj["position"]

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")