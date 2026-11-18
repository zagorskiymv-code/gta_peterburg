extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_district_edges.gd

var failures := 0
var space: PhysicsDirectSpaceState3D
var player: CharacterBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	await physics_frame
	var district := current_scene as Node3D
	space = district.get_world_3d().direct_space_state
	player = district.get_node("PlayerSpawn/Player")
	var edges := district.get_node("DistrictEdges")
	_sweep(edges.get_node("East"), -289.8, 89.8, 1.0, 2.0)
	_sweep(edges.get_node("North"), -89.8, 89.8, 1.0, 2.0)
	_sweep(edges.get_node("South"), -89.8, 23.80, -1.0, 1.0)
	_sweep(edges.get_node("South"), 29.2, 47.9, -1.0, 1.0)
	_sweep(edges.get_node("South"), 62.1, 89.8, -1.0, 2.0)
	_sweep(edges.get_node("WestQuay"), -89.8, 93.8, -1.0, 1.0)
	_sweep(edges.get_node("WestQuay"), 226.85, 289.8, -1.0, 1.0)

	# Sample the full usable width of the island bridge at both approaches.
	for x in [24.25, 25.5, 26.5, 28.75]:
		var previous := 0.0
		for i in 40:
			var at := Vector3(x, 0, 86.8 + i * 0.30)
			var hit := _floor_at(at)
			_expect(not hit.is_empty(), "New Holland deck gap at %s" % at)
			if not hit.is_empty():
				_expect(absf(hit.position.y - previous) <= 0.12, "New Holland deck step at %s" % at)
				previous = hit.position.y
	# Every dry road approach has a floor up to its visible gate or quay.
	for from: Vector3 in [Vector3(82,0,-27), Vector3(84,0,-251.4), Vector3(0,0,75.5),
			Vector3(71,0,84), Vector3(-77,0,-27), Vector3(-52.5,0,85), Vector3(-39,0,-285)]:
		var outward := Vector3.RIGHT if from.x > 80 else Vector3.BACK
		if from.x < -70:
			outward = Vector3.LEFT
		elif from.z < -280:
			outward = Vector3.FORWARD
		_approach(from, outward)

	await _walk(Vector3(0,0.12,79), Vector3.BACK, 89.26, true)
	await _walk(Vector3(82,0.12,-27), Vector3.RIGHT, 89.26, true)
	await _walk(Vector3(26.5,0.12,86), Vector3.BACK, 98.0, false)
	print("DISTRICT EDGES: %d failures" % failures)
	quit(int(failures > 0))


func _sweep(edge: Node3D, start: float, end: float, inside: float, height: float) -> void:
	var samples := ceili((end - start) / 0.25)
	for index in samples + 1:
		var x := lerpf(start, end, float(index) / samples)
		var inner := edge.to_global(Vector3(x, height, inside * 0.56))
		var outer := edge.to_global(Vector3(x, height, -inside * 0.50))
		_expect(not _ray(inner, outer).is_empty(), "%s: barrier gap at %.2f" % [edge.name, x])
		_expect(not _floor_at(edge.to_global(Vector3(x, 0, inside * 0.42))).is_empty(),
				"%s: ground gap at %.2f" % [edge.name, x])


func _approach(from: Vector3, outward: Vector3) -> void:
	for i in 70:
		var at := from + outward * (i * 0.25)
		var next := at + outward * 0.26
		if not _ray(at + Vector3.UP * 0.6, next + Vector3.UP * 0.6).is_empty():
			return
		_expect(not _floor_at(at).is_empty(), "Unsupported street at %s" % at)
	_expect(false, "Road has no visible stopping point from %s" % from)


func _floor_at(at: Vector3) -> Dictionary:
	return _ray(at + Vector3.UP * 0.22, at - Vector3.UP * 0.22)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()]))


func _walk(from: Vector3, direction: Vector3, limit: float, closed: bool) -> void:
	player.global_position = from
	player.velocity = Vector3.ZERO
	player.camera_yaw = atan2(-direction.x, -direction.z)
	player._update_camera_pivot()
	for i in 8:
		await physics_frame
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in (115 if closed else 104):
		if closed and i == 15:
			Input.action_press("jump")
		elif closed and i == 28:
			Input.action_release("jump")
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var progress := player.global_position.dot(direction)
	_expect(player.is_on_floor() and not player.is_dead, "Player stays grounded from %s" % from)
	_expect(progress <= limit and progress > limit - 0.8 if closed else progress > limit,
			"Player at %s from %s" % [player.global_position, from])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		failures += 1
