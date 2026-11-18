extends SceneTree

## Run with godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_palace_routes.gd
const Visual := preload("res://scripts/player/historical_character_visual.gd")
var player: CharacterBody3D
var errors := 0


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _expect(passed: bool, message: String) -> void:
	if not passed:
		push_error(message)
		errors += 1


func _walk_to(point: Vector3) -> bool:
	for frame in 1000:
		var delta := point - player.global_position
		delta.y = 0
		if delta.length() < 0.15:
			return true
		player.camera_yaw = atan2(-delta.x, -delta.z)
		player._update_camera_pivot()
		await physics_frame
		if player.global_position.y < -0.24:
			return false
	return false


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	player = current_scene.get_node("PlayerSpawn/Player")
	player.set_process_unhandled_input(false)
	var visual: Node3D = player.get_node("CharacterVisual")
	await _frames(10)
	_expect(player.is_on_floor(), "Spawn")
	Input.action_press("move_forward")
	await _frames(20)
	_expect(visual.pose == Visual.Pose.WALK, "Walk pose")
	Input.action_press("sprint")
	await _frames(30)
	_expect(visual.pose == Visual.Pose.RUN, "Run pose")
	var upper := visual.get_node("Body/UpperBody") as Node3D
	_expect(upper.rotation_degrees.x < -8 and upper.rotation_degrees.x > -12, "Natural forward lean: %s" % upper.rotation_degrees.x)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(25)
	_expect(absf(upper.rotation_degrees.x) < 0.4, "Back to neutral")
	var road: Node3D = current_scene.get_node("NevskyProspekt/Avenue")
	var path: PackedVector3Array = road.get_meta(&"route_points")
	Input.action_press("move_forward")
	for i in range(0, path.size(), 8):
		if not await _walk_to(path[i]):
			_expect(false, "Avenue path blocked at %s, player %s" % [path[i], player.global_position])
			break
	var bridge: Node3D = current_scene.get_node("NevskyProspekt/NevaBridge")
	var approach := bridge.to_global(Vector3(0, 0, -2.5))
	_expect(await _walk_to(approach), "Road to bridge seam at %s" % player.global_position)
	_expect(await _walk_to(bridge.to_global(Vector3(0, 0, -46))), "Bridge to the near leaf")
	var yaw := bridge.global_rotation.y
	player.camera_yaw = yaw
	player._update_camera_pivot()
	Input.action_press("sprint")
	await _frames(45)
	Input.action_press("jump")
	await _frames(85)
	Input.action_release("jump")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	var stopped := bridge.to_local(player.global_position)
	_expect(stopped.z > -54 and stopped.z < -48.8 and not player.is_dead, "Raised leaf stops level sprint/jump: %s" % stopped)
	player.global_position = bridge.to_global(Vector3(8.75, 0.25, -2))
	await _frames(8)
	Input.action_press("move_forward")
	_expect(await _walk_to(bridge.to_global(Vector3(8.75, 0, -46))), "Bridge pedestrian sidewalk")
	Input.action_release("move_forward")
	# Sweep both approaches from the land onto the bridge, then run outwards at the seam.
	for side in [-1.0, 1.0]:
		player.global_position = bridge.to_global(Vector3(side * 9.55, 0.12, 4.3))
		await _frames(6)
		Input.action_press("move_forward")
		_expect(await _walk_to(bridge.to_global(Vector3(side * 9.55, 0.13, -0.70))), "Shore footway seam %s" % side)
		Input.action_release("move_forward")
		player.camera_yaw = yaw
		player._update_camera_pivot()
		var out := "move_right" if side > 0 else "move_left"
		Input.action_press(out)
		await _frames(45)
		Input.action_release(out)
		var bank := bridge.to_local(player.global_position)
		_expect(absf(bank.x) < 11.1 and player.is_on_floor(), "Landing rail keeps player on deck %s" % bank)

	var bypass: Node3D = current_scene.get_node("NevskyProspekt/IsaacBypass")
	var loop: PackedVector3Array = bypass.get_meta(&"route_points")
	player.global_position = Vector3(0, 0.10, -103)
	await _frames(8)
	Input.action_press("move_forward")
	for i in range(6, loop.size(), 6):
		if not await _walk_to(loop[i]):
			_expect(false, "Bypass blocked at %s; player at %s" % [loop[i], player.global_position])
			break
	_expect(await _walk_to(loop[-1]), "Bypass reconnects before the bridge")
	Input.action_release("move_forward")
	var gallery: Node3D = current_scene.get_node("Landmarks/SaintIsaacsCathedral/ColonnadeAccess")
	var lower := gallery.get_node("LowerDoor") as Marker3D
	var upper_stop := gallery.get_node("UpperDoor") as Marker3D
	player.global_position = lower.global_position
	await _frames(7)
	var camera_yaw: float = player.camera_yaw
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	root.push_input(event)
	await _frames(9)
	_expect(player.global_position.distance_to(upper_stop.global_position) < 0.20 and player.is_on_floor(), "E reaches the gallery")
	_expect(is_equal_approx(player.camera_yaw, camera_yaw), "Camera azimuth survives ascent")
	event.echo = true
	root.push_input(event)
	await _frames(4)
	_expect(player.global_position.y > 24, "Holding E does not transfer again")
	Input.action_press("move_forward")
	for i in range(1, 33):
		var theta := PI * 0.5 + TAU * i / 32.0
		var point := gallery.to_global(Vector3(cos(theta) * 11.2, 24.06, sin(theta) * 11.2))
		if not await _walk_to(point):
			_expect(false, "Circular gallery blocked at %s; player at %s" % [point, player.global_position])
			break
	Input.action_release("move_forward")
	_expect(player.is_on_floor() and player.global_position.y > 24, "A continuous floor around the dome")
	var arm: SpringArm3D = player.get_node("CameraPivot/SpringArm3D")
	_expect(root.get_camera_3d() == arm.get_node("Camera3D"), "Player camera at altitude")
	event.echo = false
	root.push_input(event)
	await _frames(9)
	_expect(player.global_position.distance_to(lower.global_position) < 0.18 and player.is_on_floor(), "E returns safely to the ground")
	print("PALACE BRIDGE + BYPASS + COLONNADE: %d failures" % errors)
	quit(0 if errors == 0 else 1)
