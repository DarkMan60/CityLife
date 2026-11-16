extends Control

var mission_list_container: VBoxContainer = null

func _ready() -> void:
	mission_list_container = get_node("Container/MissionList/VBoxContainer")
	_populate_mission_list()

func _populate_mission_list() -> void:
	for child in mission_list_container.get_children():
		child.queue_free()

	var available_missions = MissionManager.get_available_missions()
	var completed_missions = MissionManager.get_completed_missions()

	if available_missions.is_empty() and completed_missions.is_empty():
		var no_missions = Label.new()
		no_missions.text = "No missions available"
		no_missions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_missions.add_theme_font_size_override("font_size", 20)
		no_missions.add_theme_color_override("font_color", Color.GRAY)
		mission_list_container.add_child(no_missions)
		return

	for mission in available_missions:
		_add_mission_button(mission, false)

	for mission_id in completed_missions:
		var mission = MissionManager.get_mission(mission_id)
		if mission:
			_add_mission_button(mission, true)

func _add_mission_button(mission: Dictionary, completed: bool) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 20)

	if completed:
		btn.text = "[COMPLETED] %s" % mission["name"]
		btn.add_theme_color_override("font_color", Color.GREEN)
		btn.disabled = true
	else:
		btn.text = "%s - $%d" % [mission["name"], mission.get("rewards", {}).get("money", 0)]
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.pressed.connect(_on_mission_selected.bind(mission["id"]))

	mission_list_container.add_child(btn)

func _on_mission_selected(mission_id: String) -> void:
	if MissionManager.start_mission(mission_id):
		get_tree().change_scene_to_file("res://scenes/main/main_game.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")