extends RefCounted

const PATH := "user://game_preferences.cfg"

var volume := 1.0
var render_scale := 1.0
var vsync := true


func load_values() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		volume = clampf(float(config.get_value("audio", "master", 1.0)), 0.0, 1.0)
		render_scale = clampf(float(config.get_value("graphics", "render_scale", 1.0)), 0.6, 1.0)
		vsync = bool(config.get_value("graphics", "vsync", true))


func apply(window: Window) -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, volume <= 0.001)
		AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.001)))
	window.scaling_3d_scale = render_scale
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func save_values() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "master", volume)
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "vsync", vsync)
	return config.save(PATH)
