extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_bicycle_controls.gd
const Ride = preload("res://scripts/vehicles/riding_horse.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	await _frames(16)
	var riding := current_scene.get_node("DistrictRiding")
	var bike := riding.get_node("ParkedBicycles").get_child(0) as Ride
	var player := current_scene.get_node("PlayerSpawn/Player") as CharacterBody3D
	bike.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 42))
	player.global_position = Vector3(1.4, 0.05, 42)
	await _frames(10)
	_interact()
	await _frames(8)
	_expect(riding._mounted == bike, "E mounts a bicycle")

	Input.action_press("move_forward")
	await _frames(45)
	var initial_yaw := bike.rotation.y
	Input.action_press("move_left")
	await _frames(18)
	Input.action_release("move_left")
	var left_yaw := bike.rotation.y
	_expect(angle_difference(initial_yaw, left_yaw) > 0.25, "W+A steers left while moving")
	Input.action_press("move_right")
	await _frames(18)
	Input.action_release("move_right")
	_expect(angle_difference(left_yaw, bike.rotation.y) < -0.25, "W+D steers right while moving")

	Input.action_press("jump")
	await _frames(100)
	_expect(bike.velocity.slide(Vector3.UP).length() < 0.08, "Space brakes even while W is held")
	Input.action_release("move_forward")
	Input.action_release("jump")
	var stopped := bike.global_position
	Input.action_press("move_backward")
	await _frames(24)
	Input.action_release("move_backward")
	_expect((bike.global_position - stopped).dot(bike.global_basis.z) > 0.15, "S reverses")
	_interact()
	await _frames(12)
	_expect(riding._mounted == null and player.is_on_floor() and player.is_physics_processing(), "E restores walking")
	print("BICYCLE CONTROLS: %d failures" % failures)
	quit(int(failures > 0))


func _interact() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	root.push_input(event)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _expect(passed: bool, message: String) -> void:
	if not passed:
		printerr(message)
		failures += 1
