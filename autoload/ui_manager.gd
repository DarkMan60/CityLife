extends Node

signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)
signal hud_updated(data: Dictionary)
signal notification_showed(message: String, type: String, duration: float)

var current_menu: String = ""
var is_paused: bool = false
var hud_visible: bool = true
var minimap_visible: bool = true
var crosshair_visible: bool = true
var subtitles_enabled: bool = true

static var instance: UIManager = null

var hud_canvas: CanvasLayer = null
var menu_canvas: CanvasLayer = null
var notification_queue: Array[Dictionary] = []
var current_notification: Dictionary = {}
var notification_timer: float = 0.0

func _ready() -> void:
	instance = self
	_create_ui_layers()

func _create_ui_layers() -> void:
	hud_canvas = CanvasLayer.new()
	hud_canvas.name = "HUD_Canvas"
	hud_canvas.layer = 10
	add_child(hud_canvas)

	menu_canvas = CanvasLayer.new()
	menu_canvas.name = "Menu_Canvas"
	menu_canvas.layer = 20
	add_child(menu_canvas)

	_create_hud()
	_create_virtual_controls()

func _create_hud() -> void:
	var hud_container = Control.new()
	hud_container.name = "HUD_Container"
	hud_container.anchors_preset = Control.PRESET_FULL_RECT
	hud_canvas.add_child(hud_container)

	var health_bar = _create_status_bar("Health", Color.RED, Vector2(20, 20), Vector2(200, 25))
	health_bar.name = "Health_Bar"
	hud_container.add_child(health_bar)

	var armor_bar = _create_status_bar("Armor", Color.BLUE, Vector2(20, 50), Vector2(200, 15))
	armor_bar.name = "Armor_Bar"
	hud_container.add_child(armor_bar)

	var stamina_bar = _create_status_bar("Stamina", Color.YELLOW, Vector2(20, 70), Vector2(200, 15))
	stamina_bar.name = "Stamina_Bar"
	hud_container.add_child(stamina_bar)

	var money_label = Label.new()
	money_label.name = "Money_Label"
	money_label.position = Vector2(20, 95)
	money_label.text = "$0"
	money_label.add_theme_font_size_override("font_size", 24)
	money_label.add_theme_color_override("font_color", Color.GOLD)
	money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_container.add_child(money_label)

	var wanted_container = HBoxContainer.new()
	wanted_container.name = "Wanted_Container"
	wanted_container.position = Vector2(20, 130)
	wanted_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_container.add_child(wanted_container)

	for i in range(5):
		var star = TextureRect.new()
		star.name = "Star_%d" % i
		star.custom_minimum_size = Vector2(24, 24)
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wanted_container.add_child(star)

	var weapon_info = VBoxContainer.new()
	weapon_info.name = "Weapon_Info"
	weapon_info.position = Vector2(20, 170)
	weapon_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_container.add_child(weapon_info)

	var weapon_name = Label.new()
	weapon_name.name = "Weapon_Name"
	weapon_name.text = "Fists"
	weapon_name.add_theme_font_size_override("font_size", 18)
	weapon_name.add_theme_color_override("font_color", Color.WHITE)
	weapon_info.add_child(weapon_name)

	var ammo_label = Label.new()
	ammo_label.name = "Ammo_Label"
	ammo_label.text = "--"
	ammo_label.add_theme_font_size_override("font_size", 16)
	ammo_label.add_theme_color_override("font_color", Color.GRAY)
	weapon_info.add_child(ammo_label)

	var minimap = _create_minimap()
	minimap.name = "Minimap"
	hud_container.add_child(minimap)

	var crosshair = TextureRect.new()
	crosshair.name = "Crosshair"
	crosshair.anchors_preset = Control.PRESET_CENTER
	crosshair.custom_minimum_size = Vector2(48, 48)
	crosshair.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud_container.add_child(crosshair)

	var mission_text = Label.new()
	mission_text.name = "Mission_Text"
	mission_text.anchors_preset = Control.PRESET_TOP_WIDE
	mission_text.position = Vector2(0, 100)
	mission_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_text.add_theme_font_size_override("font_size", 20)
	mission_text.add_theme_color_override("font_color", Color.WHITE)
	mission_text.add_theme_color_override("font_outline_color", Color.BLACK)
	mission_text.add_theme_constant_override("font_outline_size", 2)
	mission_text.visible = false
	hud_container.add_child(mission_text)

	var speedometer = _create_speedometer()
	speedometer.name = "Speedometer"
	hud_container.add_child(speedometer)

func _create_status_bar(name: String, color: Color, pos: Vector2, size: Vector2) -> Control:
	var container = Control.new()
	container.name = name
	container.position = pos
	container.custom_minimum_size = size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = Panel.new()
	bg.name = "BG"
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0.5)
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom = 2
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(0, 0, 0, 0.8)
	container.add_child(bg)

	var fill = ProgressBar.new()
	fill.name = "Fill"
	fill.anchors_preset = Control.PRESET_FULL_RECT
	fill.custom_minimum_size = size
	fill.min_value = 0
	fill.max_value = 100
	fill.value = 100
	fill.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	(fill.get_theme_stylebox("progress") as StyleBoxFlat).bg_color = color
	(fill.get_theme_stylebox("progress") as StyleBoxFlat).corner_radius_top_left = 4
	(fill.get_theme_stylebox("progress") as StyleBoxFlat).corner_radius_bottom_left = 4
	container.add_child(fill)

	var label = Label.new()
	label.name = "Label"
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	return container

func _create_minimap() -> Control:
	var minimap = Control.new()
	minimap.name = "Minimap"
	minimap.anchors_preset = Control.PRESET_TOP_RIGHT
	minimap.position = Vector2(-220, 20)
	minimap.custom_minimum_size = Vector2(200, 200)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = Panel.new()
	bg.name = "BG"
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0.6)
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_left = 10
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_right = 10
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_bottom_left = 10
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_bottom_right = 10
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom = 2
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(0.2, 0.2, 0.2, 1)
	minimap.add_child(bg)

	var map_view = TextureRect.new()
	map_view.name = "Map_View"
	map_view.anchors_preset = Control.PRESET_FULL_RECT
	map_view.margins = Vector4(5, 5, 5, 5)
	map_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	minimap.add_child(map_view)

	var player_marker = TextureRect.new()
	player_marker.name = "Player_Marker"
	player_marker.anchors_preset = Control.PRESET_CENTER
	player_marker.custom_minimum_size = Vector2(16, 16)
	player_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_marker.modulate = Color.GREEN
	minimap.add_child(player_marker)

	var north_indicator = Label.new()
	north_indicator.name = "North_Indicator"
	north_indicator.position = Vector2(10, 10)
	north_indicator.text = "N"
	north_indicator.add_theme_font_size_override("font_size", 14)
	north_indicator.add_theme_color_override("font_color", Color.RED)
	north_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.add_child(north_indicator)

	return minimap

func _create_speedometer() -> Control:
	var speedometer = Control.new()
	speedometer.name = "Speedometer"
	speedometer.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	speedometer.position = Vector2(-220, -120)
	speedometer.custom_minimum_size = Vector2(200, 100)
	speedometer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speedometer.visible = false

	var bg = Panel.new()
	bg.name = "BG"
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0.6)
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_left = 10
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_right = 10
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_bottom_left = 10
	(bg.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_bottom_right = 10
	speedometer.add_child(bg)

	var speed_label = Label.new()
	speed_label.name = "Speed_Label"
	speed_label.anchors_preset = Control.PRESET_TOP_WIDE
	speed_label.position = Vector2(0, 10)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.text = "0 km/h"
	speed_label.add_theme_font_size_override("font_size", 28)
	speed_label.add_theme_color_override("font_color", Color.WHITE)
	speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speedometer.add_child(speed_label)

	var gear_label = Label.new()
	gear_label.name = "Gear_Label"
	gear_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
	gear_label.position = Vector2(0, -10)
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_label.text = "N"
	gear_label.add_theme_font_size_override("font_size", 20)
	gear_label.add_theme_color_override("font_color", Color.YELLOW)
	gear_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speedometer.add_child(gear_label)

	var fuel_bar = ProgressBar.new()
	fuel_bar.name = "Fuel_Bar"
	fuel_bar.anchors_preset = Control.PRESET_BOTTOM_WIDE
	fuel_bar.position = Vector2(20, -40)
	fuel_bar.custom_minimum_size = Vector2(160, 10)
	fuel_bar.min_value = 0
	fuel_bar.max_value = 100
	fuel_bar.value = 100
	(speedometer.get_theme_stylebox("progress") as StyleBoxFlat).bg_color = Color.GREEN
	speedometer.add_child(fuel_bar)

	return speedometer

func _create_virtual_controls() -> void:
	var controls_layer = CanvasLayer.new()
	controls_layer.name = "Virtual_Controls"
	controls_layer.layer = 15
	add_child(controls_layer)

	var controls_container = Control.new()
	controls_container.name = "Controls_Container"
	controls_container.anchors_preset = Control.PRESET_FULL_RECT
	controls_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_layer.add_child(controls_container)

	var joystick_bg = TextureRect.new()
	joystick_bg.name = "Joystick_BG"
	joystick_bg.position = Vector2(50, 0)
	joystick_bg.anchors_preset = Control.PRESET_BOTTOM_LEFT
	joystick_bg.custom_minimum_size = Vector2(200, 200)
	joystick_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	joystick_bg.modulate = Color(1, 1, 1, 0.3)
	joystick_bg.visible = false
	controls_container.add_child(joystick_bg)

	var joystick_knob = TextureRect.new()
	joystick_knob.name = "Joystick_Knob"
	joystick_knob.anchors_preset = Control.PRESET_CENTER
	joystick_knob.custom_minimum_size = Vector2(80, 80)
	joystick_knob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	joystick_knob.modulate = Color(1, 1, 1, 0.5)
	joystick_bg.add_child(joystick_knob)

	var buttons = {
		"jump": Vector2(-150, -150),
		"sprint": Vector2(-280, -150),
		"interact": Vector2(-150, -280),
		"attack": Vector2(-150, 50),
		"aim": Vector2(-280, 50),
		"vehicle_exit": Vector2(-150, -410),
		"vehicle_accelerate": Vector2(-150, -150),
		"vehicle_brake": Vector2(-150, -280),
		"vehicle_handbrake": Vector2(-280, -150),
	}

	for btn_name in buttons:
		var pos = buttons[btn_name]
		var btn = TextureButton.new()
		btn.name = btn_name.capitalize() + "_Btn"
		btn.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		btn.position = pos
		btn.custom_minimum_size = Vector2(100, 100)
		btn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btn.visible = false
		controls_container.add_child(btn)

func _process(delta: float) -> void:
	_update_notifications(delta)
	_update_hud()

func _update_notifications(delta: float) -> void:
	if current_notification:
		notification_timer -= delta
		if notification_timer <= 0:
			_hide_notification()

	if not current_notification and notification_queue.size() > 0:
		_show_next_notification()

func _update_hud() -> void:
	if not hud_visible or not GameManager:
		return

	var hud = hud_canvas.get_node("HUD_Container")
	if not hud:
		return

	if GameManager.get_player():
		var player = GameManager.get_player()
		if player.has_method("get_health"):
			var health_bar = hud.get_node("Health_Bar")
			if health_bar:
				(health_bar.get_node("Fill") as ProgressBar).value = player.get_health()
				(health_bar.get_node("Label") as Label).text = "%d HP" % player.get_health()

		if player.has_method("get_armor"):
			var armor_bar = hud.get_node("Armor_Bar")
			if armor_bar:
				(armor_bar.get_node("Fill") as ProgressBar).value = player.get_armor()

		if player.has_method("get_stamina"):
			var stamina_bar = hud.get_node("Stamina_Bar")
			if stamina_bar:
				(stamina_bar.get_node("Fill") as ProgressBar).value = player.get_stamina()

	var money_label = hud.get_node("Money_Label")
	if money_label:
		money_label.text = "$%d" % GameManager.get_money()

	var wanted_level = GameManager.get_wanted_level()
	var wanted_container = hud.get_node("Wanted_Container")
	if wanted_container:
		for i in range(5):
			var star = wanted_container.get_node("Star_%d" % i)
			if star:
				star.modulate = Color.WHITE if i < wanted_level else Color(0.3, 0.3, 0.3, 0.5)

	var minimap = hud.get_node("Minimap")
	if minimap and minimap_visible and GameManager.get_player():
		var player = GameManager.get_player()
		var map_view = minimap.get_node("Map_View")
		var player_marker = minimap.get_node("Player_Marker")
		if map_view and player_marker:
			player_marker.rotation = -player.global_rotation.y

func show_hud() -> void:
	hud_visible = true
	if hud_canvas:
		hud_canvas.visible = true

func hide_hud() -> void:
	hud_visible = false
	if hud_canvas:
		hud_canvas.visible = false

func show_minimap() -> void:
	minimap_visible = true
	var hud = hud_canvas.get_node("HUD_Container")
	if hud:
		hud.get_node("Minimap").visible = true

func hide_minimap() -> void:
	minimap_visible = false
	var hud = hud_canvas.get_node("HUD_Container")
	if hud:
		hud.get_node("Minimap").visible = false

func set_crosshair_visible(visible: bool) -> void:
	crosshair_visible = visible
	var hud = hud_canvas.get_node("HUD_Container")
	if hud:
		hud.get_node("Crosshair").visible = visible

func show_speedometer(show: bool) -> void:
	var hud = hud_canvas.get_node("HUD_Container")
	if hud:
		hud.get_node("Speedometer").visible = show

func update_speedometer(speed: float, gear: int, fuel: float) -> void:
	var hud = hud_canvas.get_node("HUD_Container")
	if not hud:
		return

	var speedo = hud.get_node("Speedometer")
	if not speedo:
		return

	(speedo.get_node("Speed_Label") as Label).text = "%d km/h" % abs(int(speed * 3.6))
	(speedo.get_node("Gear_Label") as Label).text = "R" if gear < 0 else ("N" if gear == 0 else str(gear))
	(speedo.get_node("Fuel_Bar") as ProgressBar).value = fuel

func update_weapon_info(weapon_name: String, current_ammo: int, reserve_ammo: int) -> void:
	var hud = hud_canvas.get_node("HUD_Container")
	if not hud:
		return

	var weapon_info = hud.get_node("Weapon_Info")
	if not weapon_info:
		return

	(weapon_info.get_node("Weapon_Name") as Label).text = weapon_name
	(weapon_info.get_node("Ammo_Label") as Label).text = "%d / %d" % [current_ammo, reserve_ammo] if reserve_ammo >= 0 else "--"

func show_mission_text(text: String, duration: float = 5.0) -> void:
	var hud = hud_canvas.get_node("HUD_Container")
	if not hud:
		return

	var mission_text = hud.get_node("Mission_Text")
	mission_text.text = text
	mission_text.visible = true

	var tween = create_tween()
	tween.tween_property(mission_text, "modulate:a", 1.0, 0.5)
	tween.tween_callback(_hide_mission_text.bind(mission_text), duration)

func _hide_mission_text(label: Label) -> void:
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.hide.bind())

func show_notification(message: String, type: String = "info", duration: float = 3.0) -> void:
	notification_queue.append({
		"message": message,
		"type": type,
		"duration": duration
	})

func _show_next_notification() -> void:
	if notification_queue.is_empty():
		return

	current_notification = notification_queue.pop_front()
	notification_timer = current_notification["duration"]

	var notification = _create_notification_ui(current_notification)
	menu_canvas.add_child(notification)

	var tween = create_tween()
	tween.tween_property(notification, "position:x", 20, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_notification_fade_out.bind(notification), notification_timer)

func _create_notification_ui(data: Dictionary) -> Control:
	var notif = Panel.new()
	notif.name = "Notification"
	notif.anchors_preset = Control.PRESET_TOP_LEFT
	notif.position = Vector2(-400, 20)
	notif.custom_minimum_size = Vector2(380, 80)
	notif.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_bottom = 3
	match data["type"]:
		"success": style.border_color = Color.GREEN
		"warning": style.border_color = Color.YELLOW
		"error": style.border_color = Color.RED
		_: style.border_color = Color.BLUE
	notif.add_theme_stylebox_override("panel", style)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	notif.add_child(icon)

	var label = Label.new()
	label.text = data["message"]
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.margins = Vector4(50, 10, 10, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	notif.add_child(label)

	return notif

func _notification_fade_out(notification: Control) -> void:
	var tween = create_tween()
	tween.tween_property(notification, "position:x", -400, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(notification.queue_free.bind())
	current_notification = {}

func _hide_notification() -> void:
	current_notification = {}

func show_pause_menu() -> void:
	is_paused = true
	var pause_menu = _create_pause_menu()
	menu_canvas.add_child(pause_menu)
	menu_opened.emit("pause")

func hide_pause_menu() -> void:
	is_paused = false
	var pause_menu = menu_canvas.get_node_or_null("Pause_Menu")
	if pause_menu:
		pause_menu.queue_free()
	menu_closed.emit("pause")

func _create_pause_menu() -> Control:
	var panel = Panel.new()
	panel.name = "Pause_Menu"
	panel.anchors_preset = Control.PRESET_FULL_RECT
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	panel.add_theme_stylebox_override("panel", style)

	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.custom_minimum_size = Vector2(400, 500)
	panel.add_child(container)

	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(title)

	var buttons = ["Resume", "Settings", "Save Game", "Load Game", "Main Menu", "Quit Game"]
	for btn_text in buttons:
		var btn = Button.new()
		btn.text = btn_text
		btn.custom_minimum_size = Vector2(300, 60)
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(_on_pause_button_pressed.bind(btn_text))
		container.add_child(btn)

	return panel

func _on_pause_button_pressed(button_text: String) -> void:
	match button_text:
		"Resume":
			GameManager.resume_game()
		"Settings":
			show_settings_menu()
		"Save Game":
			SaveManager.save_game(GameManager.save_slot)
		"Load Game":
			show_load_menu()
		"Main Menu":
			GameManager.quit_to_main_menu()
		"Quit Game":
			get_tree().quit()

func show_settings_menu() -> void:
	var settings_menu = _create_settings_menu()
	menu_canvas.add_child(settings_menu)
	menu_opened.emit("settings")

func _create_settings_menu() -> Control:
	var panel = Panel.new()
	panel.name = "Settings_Menu"
	panel.anchors_preset = Control.PRESET_FULL_RECT
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	panel.add_theme_stylebox_override("panel", style)

	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.custom_minimum_size = Vector2(500, 600)
	panel.add_child(container)

	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(title)

	var graphics_section = _create_section("GRAPHICS")
	container.add_child(graphics_section)

	var quality_hbox = HBoxContainer.new()
	var quality_label = Label.new()
	quality_label.text = "Graphics Quality:"
	quality_label.custom_minimum_size = Vector2(200, 40)
	quality_label.add_theme_font_size_override("font_size", 20)
	quality_hbox.add_child(quality_label)

	var quality_option = OptionButton.new()
	quality_option.add_item("Low")
	quality_option.add_item("Medium")
	quality_option.add_item("High")
	quality_option.selected = GameManager.get_graphics_quality()
	quality_option.custom_minimum_size = Vector2(200, 40)
	quality_option.item_selected.connect(GameManager.set_graphics_quality.bind())
	quality_hbox.add_child(quality_option)
	graphics_section.add_child(quality_hbox)

	var audio_section = _create_section("AUDIO")
	container.add_child(audio_section)

	var volumes = [
		["Master Volume", GameManager.master_volume, GameManager.set_master_volume.bind()],
		["Music Volume", GameManager.music_volume, GameManager.set_music_volume.bind()],
		["SFX Volume", GameManager.sfx_volume, GameManager.set_sfx_volume.bind()],
	]

	for vol in volumes:
		var name = vol[0]
		var value = vol[1]
		var callback = vol[2]
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = name
		label.custom_minimum_size = Vector2(200, 40)
		label.add_theme_font_size_override("font_size", 20)
		hbox.add_child(label)

		var slider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = value
		slider.custom_minimum_size = Vector2(200, 40)
		slider.value_changed.connect(callback)
		hbox.add_child(slider)
		audio_section.add_child(hbox)

	var controls_section = _create_section("CONTROLS")
	container.add_child(controls_section)

	var touch_toggle = CheckButton.new()
	touch_toggle.text = "Touch Controls"
	touch_toggle.button_pressed = InputManager.touch_controls_enabled
	touch_toggle.toggled.connect(InputManager.set_touch_controls_enabled.bind())
	touch_toggle.add_theme_font_size_override("font_size", 20)
	controls_section.add_child(touch_toggle)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(panel.queue_free.bind())
	container.add_child(back_btn)

	return panel

func _create_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()

	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.YELLOW)
	section.add_child(label)

	var separator = HSeparator.new()
	section.add_child(separator)

	return section

func show_load_menu() -> void:
	var load_menu = _create_load_menu()
	menu_canvas.add_child(load_menu)
	menu_opened.emit("load")

func _create_load_menu() -> Control:
	var panel = Panel.new()
	panel.name = "Load_Menu"
	panel.anchors_preset = Control.PRESET_FULL_RECT
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	panel.add_theme_stylebox_override("panel", style)

	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.custom_minimum_size = Vector2(600, 700)
	panel.add_child(container)

	var title = Label.new()
	title.text = "LOAD GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(title)

	for slot in range(1, SaveManager.max_save_slots + 1):
		var info = SaveManager.get_save_info(slot)
		var slot_btn = _create_save_slot_button(slot, info)
		container.add_child(slot_btn)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(panel.queue_free.bind())
	container.add_child(back_btn)

	return panel

func _create_save_slot_button(slot: int, info: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(500, 100)

	if info.get("empty", true):
		var label = Label.new()
		label.text = "Slot %d - Empty" % slot
		label.custom_minimum_size = Vector2(400, 100)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color.GRAY)
		container.add_child(label)
	else:
		var info_label = Label.new()
		var time_str = Time.get_datetime_string_from_unix_time(info["timestamp"])
		info_label.text = "Slot %d - $%d - %s - %s" % [slot, info["money"], time_str, "Auto" if info["is_auto"] else "Manual"]
		info_label.custom_minimum_size = Vector2(400, 100)
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info_label.add_theme_font_size_override("font_size", 18)
		info_label.add_theme_color_override("font_color", Color.WHITE)
		container.add_child(info_label)

		var load_btn = Button.new()
		load_btn.text = "Load"
		load_btn.custom_minimum_size = Vector2(100, 50)
		load_btn.pressed.connect(SaveManager.load_game.bind(slot))
		container.add_child(load_btn)

	return container

func show_main_menu() -> void:
	var main_menu = _create_main_menu()
	menu_canvas.add_child(main_menu)
	menu_opened.emit("main")

func _create_main_menu() -> Control:
	var panel = Panel.new()
	panel.name = "Main_Menu"
	panel.anchors_preset = Control.PRESET_FULL_RECT
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 1)
	panel.add_theme_stylebox_override("panel", style)

	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.custom_minimum_size = Vector2(500, 700)
	panel.add_child(container)

	var logo = Label.new()
	logo.text = "CITY LIFE"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 72)
	logo.add_theme_color_override("font_color", Color.GOLD)
	container.add_child(logo)

	var subtitle = Label.new()
	subtitle.text = "GTA 5 Inspired Open World"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	container.add_child(subtitle)

	var buttons = [
		["New Game", GameManager.set_game_state.bind(GameManager.GameState.PLAYING)],
		["Load Game", show_load_menu.bind()],
		["Settings", show_settings_menu.bind()],
		["Garage", _open_garage.bind()],
		["Missions", _open_missions.bind()],
		["Map", _open_map.bind()],
		["Quit", get_tree().quit.bind()],
	]

	for btn_data in buttons:
		var text = btn_data[0]
		var callback = btn_data[1]
		var btn = Button.new()
		btn.text = text
		btn.custom_minimum_size = Vector2(400, 60)
		btn.add_theme_font_size_override("font_size", 28)
		btn.pressed.connect(callback)
		container.add_child(btn)

	var version = Label.new()
	version.text = "v1.0.0 - Godot 4.3"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	container.add_child(version)

	return panel

func _open_garage() -> void:
	if GameManager:
		GameManager.set_game_state(GameManager.GameState.PLAYING)
		call_deferred("_deferred_open_garage")

func _deferred_open_garage() -> void:
	get_tree().change_scene_to_file("res://scenes/garage/garage.tscn")

func _open_missions() -> void:
	if GameManager:
		GameManager.set_game_state(GameManager.GameState.PLAYING)
		call_deferred("_deferred_open_missions")

func _deferred_open_missions() -> void:
	get_tree().change_scene_to_file("res://scenes/missions/mission_select.tscn")

func _open_map() -> void:
	if GameManager:
		GameManager.set_game_state(GameManager.GameState.PLAYING)
		call_deferred("_deferred_open_map")

func _deferred_open_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map_view.tscn")

func set_virtual_controls_visible(visible: bool) -> void:
	var controls = get_node_or_null("Virtual_Controls/Controls_Container")
	if controls:
		for child in controls.get_children():
			if child is TextureButton or child is TextureRect:
				child.visible = visible