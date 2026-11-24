extends SceneTree

const DISTRICT := preload("res://scenes/world/petersburg_district.tscn")
const VIEWS := [
	[Vector2(23, -184), 49.0, Vector3(0, 1.7, -174), Vector3(15, 6, -183)],
	[Vector2(-42, 2), 57.0, Vector3(-57, 1.7, 19), Vector3(-43, 7, 6)],
	[Vector2(-15, 2), 58.0, Vector3(-2, 1.7, 18), Vector3(-14, 8, 4)],
	[Vector2(-69, 25), 32.0, Vector3(-57, 1.7, 33), Vector3(-69, 6, 23)],
]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var phase := "before" if "before" in OS.get_cmdline_user_args() else "after"
	var world := DISTRICT.instantiate()
	root.add_child(world)
	current_scene = world
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in world.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var daylight: Environment = world.get_node("Lighting/WorldEnvironment").environment
	var plan_light := daylight.duplicate() as Environment
	plan_light.fog_enabled = false
	for index in VIEWS.size():
		var view: Array = VIEWS[index]
		var center: Vector2 = view[0]
		camera.environment = plan_light
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = view[1]
		camera.position = Vector3(center.x, 210, center.y)
		camera.rotation_degrees = Vector3(-90, 0, 0)
		await _save("%s-zone-%02d-plan" % [phase, index + 1])
		camera.environment = daylight
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.position = view[2]
		camera.look_at(view[3])
		await _save("%s-zone-%02d-street" % [phase, index + 1])
	quit()


func _save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://docs/targeted-reconstruction/" + label + ".png") != OK:
		push_error("Could not save " + label)
		quit(1)
