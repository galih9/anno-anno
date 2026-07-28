extends SceneTree

func _init():
	print("Testing script loading...")
	var scripts = [
		"res://Lib/building_registry.gd",
		"res://Lib/building_data.gd",
		"res://Lib/ui_manager.gd",
		"res://Lib/main.gd",
		"res://Lib/connection_checker.gd",
		"res://Scenes/Residential/House/house.gd"
	]
	for path in scripts:
		var scr = load(path)
		if scr == null:
			print("FAILED: " + path)
		else:
			print("OK: " + path)
	quit()

