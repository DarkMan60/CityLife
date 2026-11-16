extends Control

func _ready() -> void:
	_setup_ui()
	_refresh_vehicle_list()

func _setup_ui() -> void:
	get_node("BuyBtn").pressed.connect(_on_buy_pressed)
	get_node("SellBtn").pressed.connect(_on_sell_pressed)
	get_node("BackBtn").pressed.connect(_on_back_pressed)

func _refresh_vehicle_list() -> void:
	var list = get_node("VehicleList")
	list.clear()

	if VehicleManager:
		for vehicle in VehicleManager.get_all_vehicle_definitions().values():
			var status = "Locked"
			if VehicleManager.is_vehicle_unlocked(vehicle["id"]):
				status = "Available"
			if VehicleManager.is_vehicle_owned(vehicle["id"]):
				status = "Owned"
			list.add_item("%s - $%d [%s]" % [vehicle["name"], vehicle["price"], status])

func _on_buy_pressed() -> void:
	var list = get_node("VehicleList")
	var selected = list.get_selected_items()
	if selected.size() > 0:
		var idx = selected[0]
		var vehicles = VehicleManager.get_all_vehicle_definitions()
		var keys = vehicles.keys()
		if idx < keys.size():
			var vehicle_id = keys[idx]
			VehicleManager.buy_vehicle(vehicle_id)
			_refresh_vehicle_list()
			_update_money()

func _on_sell_pressed() -> void:
	var list = get_node("VehicleList")
	var selected = list.get_selected_items()
	if selected.size() > 0:
		var idx = selected[0]
		var owned = VehicleManager.get_owned_vehicles()
		if idx < owned.size():
			VehicleManager.sell_vehicle(owned[idx]["id"], idx)
			_refresh_vehicle_list()
			_update_money()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _update_money() -> void:
	get_node("MoneyLabel").text = "Money: $%d" % GameManager.get_money()