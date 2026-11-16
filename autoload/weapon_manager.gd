extends Node

signal weapon_equipped(weapon: Object)
signal weapon_unequipped(weapon: Object)
signal ammo_changed(current: int, reserve: int, max_ammo: int)
signal weapon_fired(weapon: Object)
signal weapon_reloaded(weapon: Object)
signal no_ammo(weapon: Object)

static var instance: WeaponManager = null

var current_weapon: Object = null
var weapon_slots: Dictionary = {}  # category -> weapon_id
var weapon_instances: Dictionary = {}  # weapon_id -> Object
var owned_weapons: Array[String] = []
var selected_slot: int = 0
var weapon_wheel_open: bool = false

var equip_animation_time: float = 0.3
var is_equipping: bool = false

func _ready() -> void:
	instance = self
	_initialize_default_weapons()
	_load_weapons()

func _initialize_default_weapons() -> void:
	owned_weapons = ["fist"]
	weapon_slots = {
		"melee": "fist",
		"handgun": "",
		"smg": "",
		"rifle": "",
		"shotgun": "",
		"sniper": "",
		"heavy": "",
		"thrown": ""
	}

	_create_weapon_instances()

func _create_weapon_instances() -> void:
	for weapon_id in owned_weapons:
		_create_weapon_instance(weapon_id)

func _create_weapon_instance(weapon_id: String) -> Object:
	var def = WeaponDefinitions.get_weapon_data(weapon_id)
	if def.is_empty():
		push_error("Unknown weapon: %s" % weapon_id)
		return null

	var scene = load("res://scenes/combat/weapon.tscn")
	var weapon = scene.instantiate()
	weapon.initialize(def)
	weapon.owner = get_tree().root.find_node("Player") if get_tree().root else null
	weapon.unequip()
	add_child(weapon)
	weapon_instances[weapon_id] = weapon
	return weapon

func _load_weapons() -> void:
	var config = ConfigFile.new()
	if config.load("user://weapons.cfg") == OK:
		owned_weapons = config.get_value("weapons", "owned", ["fist"])
		weapon_slots = config.get_value("weapons", "slots", weapon_slots)
		selected_slot = config.get_value("weapons", "selected_slot", 0)

	_create_weapon_instances()
	_equip_from_slot(selected_slot)

func _save_weapons() -> void:
	var config = ConfigFile.new()
	config.set_value("weapons", "owned", owned_weapons)
	config.set_value("weapons", "slots", weapon_slots)
	config.set_value("weapons", "selected_slot", selected_slot)
	config.save("user://weapons.cfg")

func give_weapon(weapon_id: String, ammo: int = -1) -> bool:
	if weapon_id in owned_weapons:
		# Add ammo if already owned
		if weapon_id in weapon_instances:
			var weapon = weapon_instances[weapon_id]
			if ammo > 0:
				weapon.add_ammo(ammo)
			elif weapon.max_reserve_ammo > 0:
				weapon.add_ammo(weapon.max_reserve_ammo)
		return true

	if not WeaponDefinitions.get_all_weapons().has(weapon_id):
		push_error("Unknown weapon: %s" % weapon_id)
		return false

	owned_weapons.append(weapon_id)
	_create_weapon_instance(weapon_id)

	# Auto-slot if empty
	var def = WeaponDefinitions.get_weapon_data(weapon_id)
	var category = def.get("category", "")
	if category != "" and weapon_slots.get(category, "") == "":
		weapon_slots[category] = weapon_id

	_save_weapons()
	UIManager.show_notification("Received: %s" % def["name"], "success")
	return true

func remove_weapon(weapon_id: String) -> void:
	if weapon_id == "fist":
		return  # Can't remove fists

	if weapon_id in owned_weapons:
		owned_weapons.erase(weapon_id)

		if weapon_id in weapon_instances:
			var weapon = weapon_instances[weapon_id]
			if weapon == current_weapon:
				unequip_current()
			weapon.queue_free()
			weapon_instances.erase(weapon_id)

		# Clear from slots
		for cat in weapon_slots:
			var wid = weapon_slots[cat]
			if wid == weapon_id:
				weapon_slots[cat] = ""

		_save_weapons()

func buy_weapon(weapon_id: String) -> bool:
	var def = WeaponDefinitions.get_weapon_data(weapon_id)
	if def.is_empty():
		return false

	var price = def.get("price", 0)
	if price > 0 and GameManager:
		if not GameManager.remove_money(price):
			UIManager.show_notification("Not enough money!", "error")
			return false

	return give_weapon(weapon_id)

func buy_ammo(weapon_id: String, amount: int) -> bool:
	if not weapon_instances.has(weapon_id):
		return false

	var def = WeaponDefinitions.get_weapon_data(weapon_id)
	var price_per_round = max(1, def.get("price", 100) / 100)
	var total_price = int(amount * price_per_round)

	if GameManager and not GameManager.remove_money(total_price):
		UIManager.show_notification("Not enough money!", "error")
		return false

	var weapon = weapon_instances[weapon_id]
	weapon.add_ammo(amount)
	_save_weapons()
	UIManager.show_notification("Purchased %d rounds for $%d" % [amount, total_price], "success")
	return true

func equip_weapon(weapon_id: String) -> bool:
	if not owned_weapons.has(weapon_id):
		return false

	if not weapon_instances.has(weapon_id):
		_create_weapon_instance(weapon_id)

	if current_weapon:
		unequip_current()

	var weapon = weapon_instances[weapon_id]
	current_weapon = weapon
	weapon.equip(get_player())

	# Update slot
	var def = WeaponDefinitions.get_weapon_data(weapon_id)
	var category = def.get("category", "")
	if category != "":
		weapon_slots[category] = weapon_id

	weapon_equipped.emit(weapon)
	_update_ammo_ui()
	_save_weapons()
	return true

func unequip_current() -> void:
	if current_weapon:
		current_weapon.unequip()
		weapon_unequipped.emit(current_weapon)
		current_weapon = null
	_update_ammo_ui()

func _equip_from_slot(slot_index: int) -> void:
	var categories = ["melee", "handgun", "smg", "rifle", "shotgun", "sniper", "heavy", "thrown"]
	if slot_index >= 0 and slot_index < categories.size():
		var cat = categories[slot_index]
		var weapon_id = weapon_slots.get(cat, "")
		if weapon_id != "":
			equip_weapon(weapon_id)
			selected_slot = slot_index
		elif cat == "melee":
			equip_weapon("fist")

func select_next_weapon() -> void:
	var categories = ["melee", "handgun", "smg", "rifle", "shotgun", "sniper", "heavy", "thrown"]
	var start = (selected_slot + 1) % categories.size()

	for i in range(categories.size()):
		var idx = (start + i) % categories.size()
		var cat = categories[idx]
		var weapon_id = weapon_slots.get(cat, "")
		if weapon_id != "":
			_equip_from_slot(idx)
			break

func select_previous_weapon() -> void:
	var categories = ["melee", "handgun", "smg", "rifle", "shotgun", "sniper", "heavy", "thrown"]
	var start = (selected_slot - 1 + categories.size()) % categories.size()

	for i in range(categories.size()):
		var idx = (start - i + categories.size()) % categories.size()
		var cat = categories[idx]
		var weapon_id = weapon_slots.get(cat, "")
		if weapon_id != "":
			_equip_from_slot(idx)
			break

func select_slot(slot_index: int) -> void:
	_equip_from_slot(slot_index)

func get_current_weapon() -> Object:
	return current_weapon

func get_current_weapon_id() -> String:
	if current_weapon:
		return current_weapon.weapon_id
	return "fist"

func has_weapon(weapon_id: String) -> bool:
	return weapon_id in owned_weapons

func get_owned_weapons() -> Array[String]:
	return owned_weapons.duplicate()

func get_weapon_instance(weapon_id: String) -> Object:
	return weapon_instances.get(weapon_id)

func fire(start_pos: Vector3, direction: Vector3) -> bool:
	if not current_weapon:
		return false

	if current_weapon.is_reloading:
		return false

	if WeaponDefinitions.is_melee(current_weapon.weapon_id):
		return _do_melee_attack()

	var success = current_weapon.fire(start_pos, direction)
	if success:
		weapon_fired.emit(current_weapon)
		_update_ammo_ui()

		if current_weapon.current_ammo <= 0:
			no_ammo.emit(current_weapon)

	return success

func _do_melee_attack() -> bool:
	if not current_weapon:
		return false

	var player = get_player()
	if not player:
		return false

	var start = player.global_position + Vector3(0, 1.5, 0)
	var direction = -player.global_transform.basis.z

	return current_weapon.fire(start, direction)

func reload() -> bool:
	if not current_weapon:
		return false

	var success = await current_weapon.reload()
	if success:
		weapon_reloaded.emit(current_weapon)
		_update_ammo_ui()
	return success

func can_reload() -> bool:
	if not current_weapon:
		return false
	return current_weapon.can_reload()

func _update_ammo_ui() -> void:
	if current_weapon:
		ammo_changed.emit(
			current_weapon.current_ammo,
			current_weapon.reserve_ammo,
			current_weapon.max_ammo
		)
	else:
		ammo_changed.emit(0, 0, 0)

func toggle_weapon_wheel() -> void:
	weapon_wheel_open = not weapon_wheel_open
	UIManager.show_weapon_wheel(weapon_wheel_open)

func get_weapon_wheel_data() -> Dictionary:
	var data = {}
	var categories = ["melee", "handgun", "smg", "rifle", "shotgun", "sniper", "heavy", "thrown"]

	for cat in categories:
		var weapon_id = weapon_slots.get(cat, "")
		if weapon_id != "" and weapon_instances.has(weapon_id):
			var weapon = weapon_instances[weapon_id]
			data[cat] = {
				"id": weapon_id,
				"name": weapon.weapon_name,
				"ammo": weapon.current_ammo,
				"reserve": weapon.reserve_ammo,
				"max_ammo": weapon.max_ammo,
				"equipped": weapon == current_weapon,
				"icon": WeaponDefinitions.get_weapon_data(weapon_id).get("icon", "")
			}
		else:
			data[cat] = {}

	return data

func get_player() -> Node3D:
	return GameManager.get_player() if GameManager else null

func get_save_data() -> Dictionary:
	var weapons_data = []
	for weapon_id in owned_weapons:
		if weapon_instances.has(weapon_id):
			weapons_data.append(weapon_instances[weapon_id].get_save_data())

	return {
		"owned_weapons": owned_weapons,
		"weapon_slots": weapon_slots,
		"selected_slot": selected_slot,
		"weapons_data": weapons_data,
		"current_weapon": current_weapon.weapon_id if current_weapon else "fist"
	}

func apply_save_data(data: Dictionary) -> void:
	if data.has("owned_weapons"):
		owned_weapons = data["owned_weapons"]
	if data.has("weapon_slots"):
		weapon_slots = data["weapon_slots"]
	if data.has("selected_slot"):
		selected_slot = data["selected_slot"]

	_create_weapon_instances()

	if data.has("weapons_data"):
		for wdata in data["weapons_data"]:
			var wid = wdata.get("weapon_id", "")
			if wid != "" and weapon_instances.has(wid):
				weapon_instances[wid].apply_save_data(wdata)

	if data.has("current_weapon"):
		equip_weapon(data["current_weapon"])
	else:
		_equip_from_slot(selected_slot)

func _notification(what: int) -> void:
	if what == 16: # NOTIFICATION_WM_QUIT_REQUEST
		_save_weapons()