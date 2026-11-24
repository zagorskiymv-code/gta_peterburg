extends SceneTree
## Run with --script res://scripts/tools/capture_infill.gd -- before (or after).

const DISTRICT := "res://scenes/world/petersburg_district.tscn"
const OUTPUT := "res://docs/infill-v2/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var phase := "after"
	if "before" in OS.get_cmdline_user_args():
		phase = "before"
	if change_scene_to_file(DISTRICT) != OK:
		quit(1)
		return
	await scene_changed
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in current_scene.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.make_current()
	camera.far = 4500
	var world_environment := current_scene.get_node("Lighting/WorldEnvironment") as WorldEnvironment
	var daylight := world_environment.environment
	var clear_air := daylight.duplicate() as Environment
	clear_air.fog_enabled = false
	camera.environment = clear_air
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2280
	camera.position = Vector3(-194, 1700, -110)
	camera.rotation_degrees.x = -90
	await _save(phase + "-map")
	camera.size = 720
	camera.position = Vector3(52, 850, -75)
	await _save(phase + "-district")
	camera.size = 85
	camera.position = Vector3(21, 240, -193)
	await _save(phase + "-palace-corner")
	camera.environment = daylight
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	for shot in [
		["quay", Vector3(41, 1.7, 16), Vector3(34.5, 4, 26)],
		["west", Vector3(-84, 1.7, -22), Vector3(-84, 4, -5)],
		["south", Vector3(-25, 1.7, 73), Vector3(-23, 4, 89)],
		["east", Vector3(84, 1.7, -27), Vector3(140, 5, -27)],
	]:
		camera.position = shot[1]
		camera.look_at(shot[2])
		await _save(phase + "-" + shot[0])
	quit()


func _save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	print(label, " draw calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			" primitives=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var options := OS.get_cmdline_user_args()
	var destination := options[1].path_join(label + ".png") if options.size() > 1 else OUTPUT + label + ".png"
	if image.save_png(destination) != OK:
		printerr("Screenshot failed: ", label)
		quit(1)
