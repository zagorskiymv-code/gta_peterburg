extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_palace_population.gd

const Citizen = preload("res://scripts/npc/citizen_npc.gd")
const Visual = preload("res://scripts/player/historical_character_visual.gd")

var failures := 0
var space: PhysicsDirectSpaceState3D
var player: CharacterBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	var population := current_scene.get_node("PalaceSquarePopulation") as Node3D
	var nobles := population.get_node("Nobles").get_children()
	var soldiers := population.get_node("Soldiers").get_children()
	_expect(nobles.size() == 12 and soldiers.size() == 7, "Population count")
	player = current_scene.get_node("PlayerSpawn/Player")
	player.global_position = population.to_global(Vector3(0, 0.08, 13))
	await physics_frame
	space = population.get_world_3d().direct_space_state

	var snapshots := {}
	var visited := {}
	var waited := {}
	var unsafe := {}
	for npc: Citizen in nobles + soldiers:
		snapshots[npc] = Vector3(npc.global_position.x, npc.visual.breath, npc.global_position.z)
		visited[npc] = {}
		_clearance(npc, npc.global_position)
		if not npc.route:
			continue
		for index in npc.route.curve.point_count:
			var start := _waypoint(npc, index)
			var end := _waypoint(npc, (index + 1) % npc.route.curve.point_count)
			var steps := ceili(start.distance_to(end) / 0.30)
			for step in steps + 1:
				_clearance(npc, start.lerp(end, float(step) / steps))

	# Exercise the actual controllers while the plaza is inside the activation radius.
	for frame in 60 * 70:
		await physics_frame
		if frame < 10 or frame % 8 != 0:
			continue
		for npc: Citizen in nobles + soldiers:
			if not npc.is_on_floor() or npc.global_position.y < -0.07 or npc.global_position.y > 0.17:
				unsafe[npc.name] = npc.global_position
			if not npc.route:
				continue
			for index in npc.route.curve.point_count:
				if npc.global_position.distance_to(_waypoint(npc, index)) < 0.25:
					visited[npc][index] = true
			if npc.state in [Citizen.State.WAIT, Citizen.State.LOOK_AROUND, Citizen.State.TALK] and visited[npc].size() >= 2:
				waited[npc] = true

	_expect(unsafe.is_empty(), "NPC stays on paving: %s" % unsafe)
	_expect(waited.size() == 10, "All ten walkers pause during their routes")
	for npc: Citizen in nobles + soldiers:
		if npc.route:
			_expect(visited[npc].size() == npc.route.curve.point_count, "%s reaches every waypoint" % npc.name)
		else:
			var original: Vector3 = snapshots[npc]
			var displacement := Vector2(npc.global_position.x - original.x, npc.global_position.z - original.z)
			_expect(displacement.length() < 0.04 and npc.visual.pose == Visual.Pose.IDLE
					and not is_equal_approx(npc.visual.breath, original.y), "%s stands and breathes" % npc.name)

	var sentry: Citizen = soldiers[0]
	var from := player.global_transform
	from.origin = sentry.global_position + Vector3.BACK * 1.5
	var contact := KinematicCollision3D.new()
	_expect(player.test_move(from, Vector3.FORWARD * 1.3, contact)
			and contact.get_collider() == sentry, "Player capsule hits the sentry")
	var staff := current_scene.get_node("Landmarks/GeneralStaff") as Node3D
	player.global_position = staff.to_global(Vector3(0, 0.08, -8))
	player.camera_yaw = PI
	player._update_camera_pivot()
	await physics_frame
	Input.action_press("move_forward")
	for frame in 355:
		await physics_frame
	Input.action_release("move_forward")
	_expect(staff.to_local(player.global_position).z > 20 and player.is_on_floor(), "Player crosses the Staff arch")
	print("PALACE POPULATION: %d failures" % failures)
	quit(int(failures > 0))


func _waypoint(npc: Citizen, index: int) -> Vector3:
	return npc.route.to_global(npc.route.curve.get_point_position(index))


func _clearance(npc: Citizen, site: Vector3) -> void:
	var column := Vector2(17, -220)
	_expect(Vector2(site.x, site.z).distance_to(column) > 11.0, "Central square stays open")
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			site + Vector3.UP * 0.30, site - Vector3.UP * 0.26, 1))
	if floor_hit.is_empty() or floor_hit.position.y < -0.07 or floor_hit.position.y > 0.08:
		_expect(false, "%s has no level paving at %s" % [npc.name, site])
		return
	var body_shape: CollisionShape3D = npc.get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body_shape.shape
	query.transform.origin = floor_hit.position + Vector3.UP * (body_shape.position.y + 0.03)
	query.collision_mask = 1
	query.margin = 0.02
	_expect(space.intersect_shape(query, 1).is_empty(), "%s route capsule blocked at %s" % [npc.name, site])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		failures += 1
