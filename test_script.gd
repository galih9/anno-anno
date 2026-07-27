extends SceneTree

func _init():
	print("Testing building_registry.gd script loading...")
	var scr = load("res://Lib/building_registry.gd")
	if scr == null:
		print("Failed to load building_registry.gd!")
	else:
		print("Loaded building_registry.gd successfully!")
		
	var bd = load("res://Lib/building_data.gd")
	if bd == null:
		print("Failed to load building_data.gd!")
	else:
		print("Loaded building_data.gd successfully!")
		
	quit()
