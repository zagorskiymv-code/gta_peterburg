extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_water_respawn.gd

var player: CharacterBody3D
var screen: CanvasLayer
var deaths: Array[StringName] = []
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	player = current_scene.get_node("PlayerSpawn/Player")
	screen = current_scene.get_node("DistrictRespawn/DeathScreen")
	player.died.connect(func(reason: StringName) -> void: deaths.append(reason))
	await _frames(10)
	_expect(player.is_on_floor() and not player.is_dead, "Safe spawn")

	var bridge: Node3D = current_scene.get_node("NevskyProspekt/NevaBridge")
	await _drop(bridge.to_global(Vector3(0, 4, -66)), &"water", false)
	await _drop(Vector3(55, 2.5, -56), &"water", false)
	await _drop(Vector3(3, -17, 12), &"fall", true)
	await _drop(Vector3(55, 2.5, 113), &"water", false)
	await _drop(Vector3(9, 2.5, 95), &"water", false)
	await _drop(Vector3(55, 2.5, 147.5), &"water", false)
	await _drop(Vector3(30, 2.5, 148), &"water", false)

	for position: Vector3 in [Vector3(55, 1.75, -27), Vector3(65.8, 0.11, -44)]:
		player.global_position = position
		player.velocity = Vector3.ZERO
		await _frames(20)
		_expect(player.is_on_floor() and not player.is_dead, "Dry bridge/quay at %s" % position)

	var staff: Node3D = current_scene.get_node("Landmarks/GeneralStaff")
	player.global_position = staff.to_global(Vector3(0, 0.1, -8))
	player.camera_yaw = PI
	player._update_camera_pivot()
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(355)
	Input.action_release("move_forward")
	_expect(staff.to_local(player.global_position).z > 20 and player.is_on_floor(), "Walk through Triumphal Arch into inner courtyard")

	var gallery: Node3D = current_scene.get_node("Landmarks/SaintIsaacsCathedral/ColonnadeAccess")
	player.global_position = gallery.get_node("LowerDoor").global_position
	await _frames(10)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	root.push_input(event)
	await _frames(10)
	_expect(player.global_position.distance_to(gallery.get_node("UpperDoor").global_position) < 0.2, "Colonnade works after respawn")
	print("WATER + RESPAWN + GENERAL STAFF: %d failures" % failures)
	quit(int(failures > 0))

func _drop(from: Vector3, reason: StringName, already_below_world: bool) -> void:
	var previous_count := deaths.size()
	player.global_position = from
	player.velocity = Vector3.ZERO
	for i in 120:
		await physics_frame
		if player.is_dead:
			break
	_expect(player.is_dead and deaths.size() == previous_count + 1 and deaths[-1] == reason, "Death at %s" % from)
	if not player.is_dead:
		return
	if not already_below_world:
		var surface := -2.65 if from.x < 0 else -2.35
		_expect(player.global_position.y < surface + 0.06, "Death only once the capsule reaches actual water")
		_expect(screen.get_node("Words/Lines/Title").text == "УТОНУЛЪ" and screen.visible, "Drowning overlay")
	player.die(reason)
	var stop := player.global_position
	Input.action_press("move_forward")
	await _frames(100)
	Input.action_release("move_forward")
	_expect(stop.is_equal_approx(player.global_position) and player.velocity.is_zero_approx() and deaths.size() == previous_count + 1,
			"Death freezes movement and cannot re-enter respawn")
	await _frames(105)
	var spawn: Marker3D = current_scene.get_node("PlayerSpawn")
	_expect(not player.is_dead and player.global_position.distance_to(spawn.global_position) < 0.16, "Respawn in the existing scene")
	await _frames(18)
	_expect(not screen.visible and player.is_on_floor(), "Fade out and grounded respawn")
	Input.action_press("move_forward")
	await _frames(10)
	Input.action_release("move_forward")
	_expect(player.global_position.distance_to(spawn.global_position) > 0.45, "Movement restored")
