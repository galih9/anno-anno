extends SceneTree

func _init():
	print("Testing script loading...")
	var scripts = [
		"res://Lib/core/building_registry.gd",
		"res://Lib/core/building_data.gd",
		"res://Lib/ui/ui_manager.gd",
		"res://Lib/core/main.gd",
		"res://Lib/placement/connection_checker.gd",
		"res://Scenes/Residential/House/house.gd"
	]
	for path in scripts:
		var scr = load(path)
		if scr == null:
			print("FAILED: " + path)
		else:
			print("OK: " + path)
	quit()
