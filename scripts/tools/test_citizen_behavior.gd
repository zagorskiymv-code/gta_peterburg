extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_citizen_behavior.gd

const Citizen = preload("res://scripts/npc/citizen_npc.gd")
const SCENE := preload("res://scenes/npc/citizen_npc.tscn")

var failures := 0
var player: CharacterBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	player = current_scene.get_node("PlayerSpawn/Player")
	var square := current_scene.get_node("PalaceSquarePopulation")
	var lady: Citizen = square.get_node("Nobles/ConversationLady")
	var gentleman: Citizen = square.get_node("Nobles/ConversationGentleman")
	var sentry: Citizen = square.get_node("Soldiers/GeneralStaffSentry")
	player.global_position = Vector3(12, 0.06, -224)
	var talking := false
	var looking := false
	for frame in 60 * 24:
		await physics_frame
		if lady.state == Citizen.State.TALK and gentleman.state == Citizen.State.TALK:
			var direction := lady.global_position.direction_to(gentleman.global_position)
			talking = talking or (
					-lady.global_basis.z.dot(direction) > 0.97 and gentleman.global_basis.z.dot(direction) > 0.97)
			_expect(lady.global_position.distance_to(gentleman.global_position) >= 1.05, "Pair keeps its distance")
		looking = looking or (lady.state == Citizen.State.LOOK_AROUND and absf(lady.visual.head.rotation.y) > 0.12)
		_expect(sentry.state == Citizen.State.IDLE, "Sentry stays on duty")
	_expect(talking and looking, "Pair faces each other and sometimes looks around")

	await _check_yield()
	await _check_route_variation_and_recovery()
	print("CITIZEN BEHAVIOR: %d failures" % failures)
	quit(int(failures > 0))


func _check_yield() -> void:
	var walker := _actor([Vector3(0, 0, 5), Vector3(0, 0, -12)], "YieldingWalker")
	player.global_position = Vector3(0, 0.08, -1.5)
	var blocked := false
	var retraced := false
	for frame in 60 * 17:
		await physics_frame
		if walker.state == Citizen.State.WAIT and absf(walker.global_position.z - player.global_position.z) < 1.3:
			blocked = true
		if blocked and walker.global_position.z > 4.75:
			retraced = true
			break
		_expect(walker.global_position.z > player.global_position.z + 0.63, "Walker never overlaps the player")
	_expect(blocked and retraced, "Walker yields then returns on foot to the clear checkpoint")
	player.global_position.x = 2.2
	var pedestrian: Citizen = SCENE.instantiate()
	pedestrian.position = Vector3(0, 0.06, -3.5)
	pedestrian.citizen_type = Citizen.CitizenType.SOLDIER
	current_scene.add_child(pedestrian)
	var yielded_to_npc := false
	for frame in 60 * 13:
		await physics_frame
		if walker.state == Citizen.State.WAIT and absf(walker.global_position.z - pedestrian.global_position.z) < 1.3:
			yielded_to_npc = true
			break
	_expect(yielded_to_npc, "Walker also yields to another NPC")
	pedestrian.queue_free()
	walker.queue_free()
	await physics_frame


func _check_route_variation_and_recovery() -> void:
	var walker := _actor([Vector3(0, 0, 24), Vector3(1.5, 0, 26), Vector3(-1.5, 0, 27)], "VariableWalker")
	player.global_position = Vector3(0, 0.04, 11)
	player.camera_yaw = PI
	player._update_camera_pivot()
	var reversed := false
	var waits: Array[float] = []
	var previous_stop := -1
	for frame in 60 * 40:
		await physics_frame
		if walker._last_stop != previous_stop and walker._wait_remaining > 0.0:
			previous_stop = walker._last_stop
			waits.append(walker._wait_remaining)
		reversed = reversed or walker._direction < 0
	waits.sort()
	_expect(reversed, "Resident can reverse the verified route order")
	_expect(waits.size() > 3 and waits[0] >= 2.0 and waits[-1] <= 8.0 and waits[-1] - waits[0] > 0.25,
			"Stop times vary within the requested range")

	walker.global_position.y = -3.0
	for frame in 12:
		await physics_frame
	_expect(walker.global_position.y < -0.6, "No relocation close to the player")
	player.global_position = Vector3(0, 0.05, -22)
	player.camera_yaw = 0.0
	player._update_camera_pivot()
	for frame in 20:
		await physics_frame
	_expect(walker.is_on_floor() and walker.global_position.y > -0.07, "Off-camera recovery finds a clear paved waypoint")


func _actor(points: Array[Vector3], label: String) -> Citizen:
	var path := Path3D.new()
	path.curve = Curve3D.new()
	for point in points:
		path.curve.add_point(point)
	current_scene.add_child(path)
	var npc: Citizen = SCENE.instantiate()
	npc.name = label
	npc.route = path
	npc.activity_radius = 0.0
	npc.wait_time = 0.0
	npc.position = points[0] + Vector3.UP * 0.08
	current_scene.add_child(npc)
	return npc


func _expect(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		failures += 1
