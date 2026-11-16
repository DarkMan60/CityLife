extends Node

signal vehicle_spawned(vehicle: Node3D)
signal vehicle_despawned(vehicle: Node3D)
signal vehicle_entered(vehicle: Node3D, player: Node3D)
signal vehicle_exited(vehicle: Node3D, player: Node3D)
signal vehicle_destroyed(vehicle: Node3D)
signal garage_updated()

enum VehicleClass {
	SPORTS = 0,
	LUXURY = 1,
	FAMILY = 2,
	POLICE = 3,
	TRUCK = 4,
	MOTORCYCLE = 5,
	OFFROAD = 6,
	COMMERCIAL = 7,
	EMERGENCY = 8,
	MILITARY = 9
}

var player_vehicle: Node3D = null
var owned_vehicles: Array[Dictionary] = []
var unlocked_vehicles: Array[String] = []
var active_vehicles: Array[Node3D] = []
var max_active_vehicles: int = 50
var vehicle_definitions: Dictionary = {}
var garage_position: Vector3 = Vector3(-200, 0, -100)

static var instance: VehicleManager = null

func _ready() -> void:
	instance = self
	_register_vehicle_definitions()
	_load_garage()

func _register_vehicle_definitions() -> void:
	vehicle_definitions = {
		"sultan_rs": {
			"id": "sultan_rs",
			"name": "Sultan RS",
			"class": VehicleClass.SPORTS,
			"price": 75000,
			"scene": "res://scenes/vehicles/sultan_rs.tscn",
			"stats": {"speed": 95, "acceleration": 90, "handling": 85, "braking": 80, "durability": 60},
			"spawn_weight": 10
		},
		"comet_sr": {
			"id": "comet_sr",
			"name": "Comet SR",
			"class": VehicleClass.SPORTS,
			"price": 120000,
			"scene": "res://scenes/vehicles/comet_sr.tscn",
			"stats": {"speed": 98, "acceleration": 95, "handling": 88, "braking": 85, "durability": 55},
			"spawn_weight": 5
		},
		"t20": {
			"id": "t20",
			"name": "T20",
			"class": VehicleClass.SPORTS,
			"price": 250000,
			"scene": "res://scenes/vehicles/t20.tscn",
			"stats": {"speed": 100, "acceleration": 98, "handling": 90, "braking": 90, "durability": 50},
			"spawn_weight": 2
		},
		"zentorno": {
			"id": "zentorno",
			"name": "Zentorno",
			"class": VehicleClass.SPORTS,
			"price": 300000,
			"scene": "res://scenes/vehicles/zentorno.tscn",
			"stats": {"speed": 100, "acceleration": 99, "handling": 92, "braking": 92, "durability": 45},
			"spawn_weight": 1
		},
		"schafter_v12": {
			"id": "schafter_v12",
			"name": "Schafter V12",
			"class": VehicleClass.LUXURY,
			"price": 85000,
			"scene": "res://scenes/vehicles/schafter_v12.tscn",
			"stats": {"speed": 80, "acceleration": 75, "handling": 70, "braking": 75, "durability": 80},
			"spawn_weight": 15
		},
		"cognoscenti": {
			"id": "cognoscenti",
			"name": "Cognoscenti",
			"class": VehicleClass.LUXURY,
			"price": 150000,
			"scene": "res://scenes/vehicles/cognoscenti.tscn",
			"stats": {"speed": 75, "acceleration": 70, "handling": 65, "braking": 70, "durability": 85},
			"spawn_weight": 10
		},
		"baller_le": {
			"id": "baller_le",
			"name": "Baller LE",
			"class": VehicleClass.LUXURY,
			"price": 180000,
			"scene": "res://scenes/vehicles/baller_le.tscn",
			"stats": {"speed": 78, "acceleration": 72, "handling": 68, "braking": 72, "durability": 90},
			"spawn_weight": 8
		},
		"tailgater": {
			"id": "tailgater",
			"name": "Tailgater",
			"class": VehicleClass.FAMILY,
			"price": 35000,
			"scene": "res://scenes/vehicles/tailgater.tscn",
			"stats": {"speed": 65, "acceleration": 60, "handling": 60, "braking": 65, "durability": 75},
			"spawn_weight": 25
		},
		"premier": {
			"id": "premier",
			"name": "Premier",
			"class": VehicleClass.FAMILY,
			"price": 25000,
			"scene": "res://scenes/vehicles/premier.tscn",
			"stats": {"speed": 60, "acceleration": 55, "handling": 58, "braking": 60, "durability": 70},
			"spawn_weight": 30
		},
		"police_cruiser": {
			"id": "police_cruiser",
			"name": "Police Cruiser",
			"class": VehicleClass.POLICE,
			"price": 0,
			"scene": "res://scenes/vehicles/police_cruiser.tscn",
			"stats": {"speed": 85, "acceleration": 80, "handling": 75, "braking": 80, "durability": 85},
			"spawn_weight": 0
		},
		"police_interceptor": {
			"id": "police_interceptor",
			"name": "Police Interceptor",
			"class": VehicleClass.POLICE,
			"price": 0,
			"scene": "res://scenes/vehicles/police_interceptor.tscn",
			"stats": {"speed": 95, "acceleration": 90, "handling": 85, "braking": 85, "durability": 80},
			"spawn_weight": 0
		},
		"police_helicopter": {
			"id": "police_helicopter",
			"name": "Police Helicopter",
			"class": VehicleClass.POLICE,
			"price": 0,
			"scene": "res://scenes/vehicles/police_helicopter.tscn",
			"stats": {"speed": 120, "acceleration": 60, "handling": 50, "braking": 40, "durability": 60},
			"spawn_weight": 0
		},
		"hauler": {
			"id": "hauler",
			"name": "Hauler",
			"class": VehicleClass.TRUCK,
			"price": 65000,
			"scene": "res://scenes/vehicles/hauler.tscn",
			"stats": {"speed": 55, "acceleration": 40, "handling": 45, "braking": 50, "durability": 100},
			"spawn_weight": 15
		},
		"phantom": {
			"id": "phantom",
			"name": "Phantom",
			"class": VehicleClass.TRUCK,
			"price": 80000,
			"scene": "res://scenes/vehicles/phantom.tscn",
			"stats": {"speed": 50, "acceleration": 35, "handling": 40, "braking": 45, "durability": 100},
			"spawn_weight": 10
		},
		"akuma": {
			"id": "akuma",
			"name": "Akuma",
			"class": VehicleClass.MOTORCYCLE,
			"price": 45000,
			"scene": "res://scenes/vehicles/akuma.tscn",
			"stats": {"speed": 95, "acceleration": 98, "handling": 90, "braking": 85, "durability": 30},
			"spawn_weight": 10
		},
		"bati_801": {
			"id": "bati_801",
			"name": "Bati 801",
			"class": VehicleClass.MOTORCYCLE,
			"price": 55000,
			"scene": "res://scenes/vehicles/bati_801.tscn",
			"stats": {"speed": 97, "acceleration": 95, "handling": 92, "braking": 88, "durability": 35},
			"spawn_weight": 8
		},
		"sanchez": {
			"id": "sanchez",
			"name": "Sanchez",
			"class": VehicleClass.OFFROAD,
			"price": 15000,
			"scene": "res://scenes/vehicles/sanchez.tscn",
			"stats": {"speed": 75, "acceleration": 70, "handling": 85, "braking": 70, "durability": 50},
			"spawn_weight": 12
		},
		"rebel": {
			"id": "rebel",
			"name": "Rebel",
			"class": VehicleClass.OFFROAD,
			"price": 40000,
			"scene": "res://scenes/vehicles/rebel.tscn",
			"stats": {"speed": 70, "acceleration": 65, "handling": 75, "braking": 65, "durability": 90},
			"spawn_weight": 10
		},
		"bus": {
			"id": "bus",
			"name": "Bus",
			"class": VehicleClass.COMMERCIAL,
			"price": 0,
			"scene": "res://scenes/vehicles/bus.tscn",
			"stats": {"speed": 50, "acceleration": 30, "handling": 40, "braking": 45, "durability": 95},
			"spawn_weight": 20
		},
		"taxi": {
			"id": "taxi",
			"name": "Taxi",
			"class": VehicleClass.COMMERCIAL,
			"price": 0,
			"scene": "res://scenes/vehicles/taxi.tscn",
			"stats": {"speed": 70, "acceleration": 65, "handling": 65, "braking": 70, "durability": 75},
			"spawn_weight": 25
		},
		"ambulance": {
			"id": "ambulance",
			"name": "Ambulance",
			"class": VehicleClass.EMERGENCY,
			"price": 0,
			"scene": "res://scenes/vehicles/ambulance.tscn",
			"stats": {"speed": 80, "acceleration": 75, "handling": 70, "braking": 75, "durability": 85},
			"spawn_weight": 5
		},
		"firetruck": {
			"id": "firetruck",
			"name": "Fire Truck",
			"class": VehicleClass.EMERGENCY,
			"price": 0,
			"scene": "res://scenes/vehicles/firetruck.tscn",
			"stats": {"speed": 55, "acceleration": 40, "handling": 45, "braking": 50, "durability": 95},
			"spawn_weight": 3
		},
	}

	for id in vehicle_definitions:
		if vehicle_definitions[id]["price"] <= 50000:
			unlocked_vehicles.append(id)

func _load_garage() -> void:
	var config = ConfigFile.new()
	if config.load("user://garage.cfg") == OK:
		owned_vehicles = config.get_value("garage", "owned", [])
		unlocked_vehicles = config.get_value("garage", "unlocked", unlocked_vehicles)

func _save_garage() -> void:
	var config = ConfigFile.new()
	config.set_value("garage", "owned", owned_vehicles)
	config.set_value("garage", "unlocked", unlocked_vehicles)
	config.save("user://garage.cfg")

func spawn_vehicle(vehicle_id: String, position: Vector3, rotation: float = 0.0) -> Node3D:
	if not vehicle_definitions.has(vehicle_id):
		push_error("Unknown vehicle: %s" % vehicle_id)
		return null

	if active_vehicles.size() >= max_active_vehicles:
		_despawn_oldest_vehicle()

	var def = vehicle_definitions[vehicle_id]
	var scene = load(def["scene"])
	if not scene:
		push_error("Failed to load vehicle scene: %s" % def["scene"])
		return null

	var vehicle = scene.instantiate()
	vehicle.global_position = position
	vehicle.global_rotation.y = rotation
	vehicle.name = "%s_%d" % [vehicle_id, active_vehicles.size()]
	add_child(vehicle)
	active_vehicles.append(vehicle)

	if vehicle.has_method("initialize"):
		vehicle.initialize(def)

	vehicle_spawned.emit(vehicle)
	return vehicle

func spawn_random_vehicle(position: Vector3, radius: float = 10.0) -> Node3D:
	var total_weight = 0
	for def in vehicle_definitions.values():
		total_weight += def.get("spawn_weight", 0)

	var roll = randi() % total_weight
	var cumulative = 0

	for id in vehicle_definitions:
		var def = vehicle_definitions[id]
		cumulative += def.get("spawn_weight", 0)
		if roll < cumulative:
			var spawn_pos = position + Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius))
			return spawn_vehicle(id, spawn_pos, randf() * TAU)

	return null

func _despawn_oldest_vehicle() -> void:
	if active_vehicles.is_empty():
		return

	var oldest = active_vehicles[0]
	if oldest and oldest != player_vehicle:
		despawn_vehicle(oldest)

func despawn_vehicle(vehicle: Node3D) -> void:
	if vehicle in active_vehicles:
		active_vehicles.erase(vehicle)
		vehicle_despawned.emit(vehicle)
		vehicle.queue_free()

func enter_vehicle(player: Node3D, vehicle: Node3D) -> bool:
	if not vehicle or not vehicle.has_method("can_enter") or not vehicle.can_enter():
		return false

	if vehicle.has_method("enter_vehicle"):
		var success = vehicle.enter_vehicle(player)
		if success:
			player_vehicle = vehicle
			GameManager.set_player_vehicle(vehicle)
			vehicle_entered.emit(vehicle, player)
			UIManager.show_speedometer(true)
			return true
	return false

func exit_vehicle(player: Node3D) -> void:
	if player_vehicle and player_vehicle.has_method("exit_vehicle"):
		player_vehicle.exit_vehicle(player)
		vehicle_exited.emit(player_vehicle, player)
		player_vehicle = null
		GameManager.set_player_vehicle(null)
		UIManager.show_speedometer(false)

func get_player_vehicle() -> Node3D:
	return player_vehicle

func is_player_in_vehicle() -> bool:
	return player_vehicle != null

func buy_vehicle(vehicle_id: String) -> bool:
	if not vehicle_definitions.has(vehicle_id):
		return false

	var def = vehicle_definitions[vehicle_id]
	var price = def["price"]

	if price > 0 and GameManager:
		if not GameManager.remove_money(price):
			UIManager.show_notification("Not enough money!", "error")
			return false

	var owned = {
		"id": vehicle_id,
		"name": def["name"],
		"class": def["class"],
		"customization": {},
		"purchase_time": Time.get_unix_time_from_system()
	}
	owned_vehicles.append(owned)

	if vehicle_id not in unlocked_vehicles:
		unlocked_vehicles.append(vehicle_id)

	_save_garage()
	garage_updated.emit()
	UIManager.show_notification("Purchased: %s" % def["name"], "success")
	return true

func sell_vehicle(vehicle_id: String, index: int) -> bool:
	if index < 0 or index >= owned_vehicles.size():
		return false

	var vehicle = owned_vehicles[index]
	if vehicle["id"] != vehicle_id:
		return false

	var def = vehicle_definitions[vehicle_id]
	var sell_price = int(def["price"] * 0.6)

	if GameManager:
		GameManager.add_money(sell_price)

	owned_vehicles.remove_at(index)
	_save_garage()
	garage_updated.emit()
	UIManager.show_notification("Sold for $%d" % sell_price, "success")
	return true

func get_owned_vehicles() -> Array[Dictionary]:
	return owned_vehicles

func get_unlocked_vehicles() -> Array[String]:
	return unlocked_vehicles

func is_vehicle_unlocked(vehicle_id: String) -> bool:
	return vehicle_id in unlocked_vehicles

func unlock_vehicle(vehicle_id: String) -> void:
	if vehicle_id in vehicle_definitions and vehicle_id not in unlocked_vehicles:
		unlocked_vehicles.append(vehicle_id)
		_save_garage()
		garage_updated.emit()

func get_vehicle_definition(vehicle_id: String) -> Dictionary:
	return vehicle_definitions.get(vehicle_id, {})

func get_all_vehicle_definitions() -> Dictionary:
	return vehicle_definitions

func get_vehicles_by_class(vclass: VehicleClass) -> Array[Dictionary]:
	var result = []
	for id in vehicle_definitions:
		var def = vehicle_definitions[id]
		if def["class"] == vclass:
			result.append(def)
	return result

func repair_vehicle(vehicle: Node3D) -> void:
	if vehicle and vehicle.has_method("repair"):
		vehicle.repair()

func refuel_vehicle(vehicle: Node3D) -> void:
	if vehicle and vehicle.has_method("refuel"):
		vehicle.refuel()

func customize_vehicle(vehicle: Node3D, options: Dictionary) -> void:
	if vehicle and vehicle.has_method("apply_customization"):
		vehicle.apply_customization(options)

	for owned in owned_vehicles:
		if owned["id"] == vehicle.get_meta("vehicle_id", ""):
			owned["customization"] = options
			_save_garage()
			break

func get_save_data() -> Dictionary:
	var vehicles_data = []
	for vehicle in active_vehicles:
		if vehicle and is_instance_valid(vehicle) and vehicle.has_method("get_save_data"):
			vehicles_data.append(vehicle.get_save_data())

	return {
		"owned_vehicles": owned_vehicles,
		"unlocked_vehicles": unlocked_vehicles,
		"active_vehicles": vehicles_data,
		"player_vehicle": player_vehicle.get_meta("vehicle_id", "") if player_vehicle else ""
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("owned_vehicles"):
		owned_vehicles = data["owned_vehicles"]
	if data.has("unlocked_vehicles"):
		unlocked_vehicles = data["unlocked_vehicles"]
	if data.has("player_vehicle") and data["player_vehicle"] != "":
		call_deferred("_spawn_player_vehicle", data["player_vehicle"])

func _spawn_player_vehicle(vehicle_id: String) -> void:
	if GameManager and GameManager.get_player():
		var player = GameManager.get_player()
		var vehicle = spawn_vehicle(vehicle_id, player.global_position + Vector3(3, 0, 0))
		if vehicle:
			enter_vehicle(player, vehicle)

func get_active_vehicle_count() -> int:
	return active_vehicles.size()

func clear_all_vehicles() -> void:
	for vehicle in active_vehicles:
		if vehicle and is_instance_valid(vehicle):
			vehicle.queue_free()
	active_vehicles.clear()
	player_vehicle = null

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		_save_garage()