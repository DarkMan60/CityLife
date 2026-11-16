extends Node

signal action_pressed(action: String)
signal action_released(action: String)
signal axis_changed(axis: String, value: float)
signal touch_began(position: Vector2, index: int)
signal touch_moved(position: Vector2, index: int)
signal touch_ended(position: Vector2, index: int)

var touch_controls_enabled: bool = true
var virtual_joystick_active: bool = false
var virtual_joystick_position: Vector2 = Vector2.ZERO
var virtual_joystick_knob_position: Vector2 = Vector2.ZERO
var virtual_joystick_radius: float = 80.0
var virtual_joystick_deadzone: float = 0.15
var move_input: Vector2 = Vector2.ZERO
var look_input: Vector2 = Vector2.ZERO
var vehicle_input: Vector2 = Vector2.ZERO
var is_mobile: bool = false

static var instance: InputManager = null

func _ready() -> void:
	instance = self
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	_update_keyboard_input()
	_update_virtual_joystick()

func _update_keyboard_input() -> void:
	var move_x = Input.get_axis("move_left", "move_right")
	var move_y = Input.get_axis("move_forward", "move_backward")
	move_input = Vector2(move_x, move_y).limit_length(1.0)

	var look_x = Input.get_axis("camera_horizontal", "camera_horizontal")
	var look_y = Input.get_axis("camera_vertical", "camera_vertical")
	look_input = Vector2(look_x, look_y)

	var vehicle_x = Input.get_axis("vehicle_steer_left", "vehicle_steer_right")
	var vehicle_y = Input.get_axis("vehicle_accelerate", "vehicle_brake")
	vehicle_input = Vector2(vehicle_x, vehicle_y)

func _update_virtual_joystick() -> void:
	if not touch_controls_enabled or not virtual_joystick_active:
		return

	var joystick_vector = (virtual_joystick_knob_position - virtual_joystick_position).limit_length(virtual_joystick_radius)
	var normalized = joystick_vector / virtual_joystick_radius if virtual_joystick_radius > 0 else Vector2.ZERO

	if normalized.length() > virtual_joystick_deadzone:
		move_input = normalized
		axis_changed.emit("move", normalized.length())
	else:
		move_input = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if is_mobile and touch_controls_enabled:
		_handle_touch_input(event)

	if event is InputEventKey:
		if event.pressed and not event.echo:
			action_pressed.emit(event.get_action_name())
		elif not event.pressed:
			action_released.emit(event.get_action_name())

	if event is InputEventMouseButton:
		if event.pressed:
			action_pressed.emit("attack" if event.button_index == MOUSE_BUTTON_LEFT else "aim")
		else:
			action_released.emit("attack" if event.button_index == MOUSE_BUTTON_LEFT else "aim")

	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			look_input = event.relative * 0.002

func _handle_touch_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos = event.position
		var idx = event.index

		if event.pressed:
			touch_began.emit(pos, idx)
			_check_virtual_joystick_touch(pos, idx)
			_check_button_touch(pos, idx)
		else:
			touch_ended.emit(pos, idx)
			_release_virtual_joystick(idx)
			_release_button_touch(pos, idx)

	elif event is InputEventScreenDrag:
		touch_moved.emit(event.position, event.index)
		_update_virtual_joystick_drag(event.position, event.index)
		_update_camera_drag(event.relative)

func _check_virtual_joystick_touch(pos: Vector2, idx: int) -> void:
	var screen_size = get_viewport().size
	var joystick_area = Rect2(50, screen_size.y - 250, 200, 200)

	if joystick_area.has_point(pos):
		virtual_joystick_active = true
		virtual_joystick_position = Vector2(150, screen_size.y - 150)
		virtual_joystick_knob_position = pos
		InputManager.emit_signal("virtual_joystick_activated")

func _update_virtual_joystick_drag(pos: Vector2, idx: int) -> void:
	if virtual_joystick_active:
		virtual_joystick_knob_position = pos

func _release_virtual_joystick(idx: int) -> void:
	virtual_joystick_active = false
	move_input = Vector2.ZERO

func _check_button_touch(pos: Vector2, idx: int) -> void:
	var screen_size = get_viewport().size
	var buttons = {
		"jump": Rect2(screen_size.x - 150, screen_size.y - 150, 100, 100),
		"sprint": Rect2(screen_size.x - 280, screen_size.y - 150, 100, 100),
		"interact": Rect2(screen_size.x - 150, screen_size.y - 280, 100, 100),
		"attack": Rect2(screen_size.x - 150, 50, 100, 100),
		"aim": Rect2(screen_size.x - 280, 50, 100, 100),
		"vehicle_exit": Rect2(screen_size.x - 150, screen_size.y - 410, 100, 100),
		"vehicle_accelerate": Rect2(screen_size.x - 150, screen_size.y - 150, 100, 100),
		"vehicle_brake": Rect2(screen_size.x - 150, screen_size.y - 280, 100, 100),
		"vehicle_handbrake": Rect2(screen_size.x - 280, screen_size.y - 150, 100, 100),
	}

	for action_name in buttons:
		var rect = buttons[action_name]
		if rect.has_point(pos):
			action_pressed.emit(action_name)
			break

func _release_button_touch(pos: Vector2, idx: int) -> void:
	var screen_size = get_viewport().size
	var buttons = {
		"jump": Rect2(screen_size.x - 150, screen_size.y - 150, 100, 100),
		"sprint": Rect2(screen_size.x - 280, screen_size.y - 150, 100, 100),
		"interact": Rect2(screen_size.x - 150, screen_size.y - 280, 100, 100),
		"attack": Rect2(screen_size.x - 150, 50, 100, 100),
		"aim": Rect2(screen_size.x - 280, 50, 100, 100),
		"vehicle_exit": Rect2(screen_size.x - 150, screen_size.y - 410, 100, 100),
		"vehicle_accelerate": Rect2(screen_size.x - 150, screen_size.y - 150, 100, 100),
		"vehicle_brake": Rect2(screen_size.x - 150, screen_size.y - 280, 100, 100),
		"vehicle_handbrake": Rect2(screen_size.x - 280, screen_size.y - 150, 100, 100),
	}

	for action_name in buttons:
		var rect = buttons[action_name]
		if rect.has_point(pos):
			action_released.emit(action_name)
			break

func _update_camera_drag(relative: Vector2) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_input = relative * 0.005

func get_move_input() -> Vector2:
	return move_input

func get_look_input() -> Vector2:
	return look_input

func get_vehicle_input() -> Vector2:
	return vehicle_input

func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)

func is_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)

func is_action_just_released(action: String) -> bool:
	return Input.is_action_just_released(action)

func set_touch_controls_enabled(enabled: bool) -> void:
	touch_controls_enabled = enabled

func get_virtual_joystick_data() -> Dictionary:
	return {
		"active": virtual_joystick_active,
		"position": virtual_joystick_position,
		"knob_position": virtual_joystick_knob_position,
		"radius": virtual_joystick_radius,
		"input_vector": move_input
	}

func get_button_layout() -> Dictionary:
	var screen_size = get_viewport().size
	return {
		"jump": Rect2(screen_size.x - 150, screen_size.y - 150, 100, 100),
		"sprint": Rect2(screen_size.x - 280, screen_size.y - 150, 100, 100),
		"interact": Rect2(screen_size.x - 150, screen_size.y - 280, 100, 100),
		"attack": Rect2(screen_size.x - 150, 50, 100, 100),
		"aim": Rect2(screen_size.x - 280, 50, 100, 100),
		"vehicle_exit": Rect2(screen_size.x - 150, screen_size.y - 410, 100, 100),
		"vehicle_accelerate": Rect2(screen_size.x - 150, screen_size.y - 150, 100, 100),
		"vehicle_brake": Rect2(screen_size.x - 150, screen_size.y - 280, 100, 100),
		"vehicle_handbrake": Rect2(screen_size.x - 280, screen_size.y - 150, 100, 100),
	}