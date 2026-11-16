#!/usr/bin/env -S godot --headless --script
# Validation script for CITY LIFE project
# Run with: godot --headless --script validate.gd

extends SceneTree

# Test results
var tests_passed = 0
var tests_failed = 0
var test_results = []

func _init():
	print("=== CITY LIFE Validation Script ===")
	print("Godot version: " + Engine.get_version_info()["string"])

func _initialize():
	# Run all validation tests
	_run_test("Project settings", _test_project_settings)
	_run_test("Autoload singletons", _test_autoload_singletons)
	_run_test("Main scenes exist", _test_main_scenes)
	_run_test("Script syntax", _test_script_syntax)
	_run_test("Resource loading", _test_resource_loading)
	_run_test("Class names", _test_class_names)
	_run_test("Export preset", _test_export_preset)

	# Print summary
	print("\n=== VALIDATION SUMMARY ===")
	print("Passed: " + str(tests_passed))
	print("Failed: " + str(tests_failed))

	for result in test_results:
		var status = "✅" if result.passed else "❌"
		print(status + " " + result.name + ": " + result.message)

	if tests_failed > 0:
		print("\n❌ VALIDATION FAILED")
		quit(1)
	else:
		print("\n✅ ALL TESTS PASSED")
		quit(0)

func _run_test(name: String, test_func: Callable) -> void:
	print("\n--- Testing: " + name + " ---")
	try:
		var result = test_func.call()
		if result:
			tests_passed += 1
			test_results.append({"name": name, "passed": true, "message": "OK"})
			print("✅ " + name + ": PASSED")
		else:
			tests_failed += 1
			test_results.append({"name": name, "passed": false, "message": "Test returned false"})
			print("❌ " + name + ": FAILED")
	except Exception as e:
		tests_failed += 1
		test_results.append({"name": name, "passed": false, "message": str(e)})
		print("❌ " + name + ": EXCEPTION - " + str(e))

func _test_project_settings() -> bool:
	var config = ConfigFile.new()
	var err = config.load("project.godot")
	if err != OK:
		print("Failed to load project.godot: " + str(err))
		return false

	# Check critical settings
	if not config.has_section_key("application", "config/name"):
		print("Missing application name")
		return false

	if not config.has_section_key("application", "config/main_scene"):
		print("Missing main_scene")
		return false

	# Check autoload entries
	var required_autoloads = [
		"GameManager", "InputManager", "SaveManager", "AudioManager",
		"UIManager", "WorldManager", "MissionManager", "PoliceManager",
		"VehicleManager", "PedestrianManager", "TrafficManager",
		"GraphicsSettings", "WeaponManager", "CameraManager", "LODManager"
	]

	for autoload in required_autoloads:
		if not config.has_section_key("autoload", autoload):
			print("Missing autoload: " + autoload)
			return false

	print("Project settings OK - all 15 autoloads present")
	return true

func _test_autoload_singletons() -> bool:
	# Test that all autoload scripts can be loaded
	var autoload_scripts = [
		"res://autoload/game_manager.gd",
		"res://autoload/input_manager.gd",
		"res://autoload/save_manager.gd",
		"res://autoload/audio_manager.gd",
		"res://autoload/ui_manager.gd",
		"res://autoload/world_manager.gd",
		"res://autoload/mission_manager.gd",
		"res://autoload/police_manager.gd",
		"res://autoload/vehicle_manager.gd",
		"res://autoload/pedestrian_manager.gd",
		"res://autoload/traffic_manager.gd",
		"res://autoload/graphics_settings.gd",
		"res://autoload/weapon_manager.gd",
		"res://autoload/camera_manager.gd",
		"res://autoload/lod_manager.gd",
	]

	for script_path in autoload_scripts:
		var script = load(script_path)
		if not script:
			print("Failed to load: " + script_path)
			return false
		# Try to instantiate to check for syntax errors
		var instance = script.new()
		if not instance:
			print("Failed to instantiate: " + script_path)
			return false
		instance.free()

	print("All 15 autoload scripts load and instantiate successfully")
	return true

func _test_main_scenes() -> bool:
	var main_scenes = [
		"res://scenes/main_menu/main_menu.tscn",
		"res://scenes/main/main_game.tscn",
		"res://scenes/player/player.tscn",
		"res://scenes/city/city_environment.tscn",
		"res://scenes/missions/mission_select.tscn",
		"res://scenes/map/map_view.tscn",
	]

	for scene_path in main_scenes:
		var scene = load(scene_path)
		if not scene:
			print("Failed to load scene: " + scene_path)
			return false
		# Try to instantiate
		var instance = scene.instantiate()
		if not instance:
			print("Failed to instantiate scene: " + scene_path)
			return false
		instance.queue_free()

	print("All " + str(main_scenes.size()) + " main scenes load and instantiate successfully")
	return true

func _test_script_syntax() -> bool:
	# Get all GDScript files
	var dir = DirAccess.open("res://scripts")
	if not dir:
		print("Could not open scripts directory")
		return false

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var script_count = 0
	var error_count = 0

	while file_name != "":
		if file_name.ends_with(".gd") and not file_name.begins_with("."):
			var script_path = "res://scripts/" + file_name
			var script = load(script_path)
			if not script:
				print("Syntax error in: " + script_path)
				error_count += 1
			else:
				script_count += 1
		file_name = dir.get_next()

	dir.list_dir_end()

	if error_count > 0:
		print("Found " + str(error_count) + " script syntax errors")
		return false

	print("All " + str(script_count) + " GDScript files have valid syntax")
	return true

func _test_resource_loading() -> bool:
	# Test critical resources
	var resources = [
		"res://assets/environments/default_env.tres",
	]

	for res_path in resources:
		var res = load(res_path)
		if not res:
			print("Failed to load resource: " + res_path)
			return false

	# Test audio directory structure
	var audio_dir = DirAccess.open("res://assets/audio")
	if not audio_dir:
		print("Audio directory not found")
		return false

	var audio_count = 0
	audio_dir.list_dir_begin()
	var fname = audio_dir.get_next()
	while fname != "":
		if fname.ends_with(".ogg") or fname.ends_with(".wav"):
			audio_count += 1
		fname = audio_dir.get_next()
	audio_dir.list_dir_end()

	if audio_count == 0:
		print("WARNING: No audio files found")
	else:
		print("Found " + str(audio_count) + " audio files")

	return true

func _test_class_names() -> bool:
	# Test that class_name scripts can be referenced
	var class_scripts = [
		"res://scripts/player/player_character.gd",
		"res://scripts/vehicles/vehicle_base.gd",
		"res://scripts/ai/pedestrian_base.gd",
		"res://scripts/ai/police_officer.gd",
		"res://scripts/ai/police_sniper.gd",
		"res://scripts/ai/police_roadblock.gd",
		"res://scripts/ai/police_patrol_car.gd",
		"res://scripts/ai/police_undercover_car.gd",
		"res://scripts/ai/police_motorcycle.gd",
		"res://scripts/ai/police_swat_van.gd",
		"res://scripts/ai/police_helicopter.gd",
		"res://scripts/combat/weapon_base.gd",
		"res://scripts/combat/projectile.gd",
	]

	for script_path in class_scripts:
		var script = load(script_path)
		if not script:
			print("Failed to load class script: " + script_path)
			return false

	print("All " + str(class_scripts.size()) + " class_name scripts load successfully")
	return true

func _test_export_preset() -> bool:
	var config = ConfigFile.new()
	var err = config.load("export_presets.cfg")
	if err != OK:
		print("export_presets.cfg not found or invalid: " + str(err))
		return false

	if not config.has_section("preset.0"):
		print("No preset.0 found in export_presets.cfg")
		return false

	if config.get_value("preset.0", "name") != "Android":
		print("Preset name is not 'Android'")
		return false

	if config.get_value("preset.0", "platform") != "Android":
		print("Preset platform is not 'Android'")
		return false

	print("Export preset configured correctly for Android")
	return true