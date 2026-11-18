extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_district_traffic.gd

const Traffic = preload("res://scripts/systems/district_traffic.gd")
const Agent = preload("res://scripts/systems/traffic_agent.gd")
const G = preload("res://scripts/world/district_geometry.gd")
const ALLOWED_SURFACES := [&"NevskyRoadCollision", &"BypassRoadCollision"]

var failures := 0
var traffic: Traffic
var bridge: Node3D
var space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	traffic = current_scene.get_node("DistrictTraffic")
	traffic.get_node("TrafficFleet").queue_free()
	traffic.get_node("CarriageFleet").queue_free()
	bridge = current_scene.get_node("NevskyProspekt/NevaBridge")
	await physics_frame
	space = traffic.get_world_3d().direct_space_state
	_expect(traffic.lanes.size() == 4, "Four directed lanes")
	var debug_key := InputEventKey.new()
	debug_key.physical_keycode = KEY_F7
	debug_key.pressed = true
	root.push_input(debug_key)
	_expect(traffic.has_node("TrafficDebug"), "F7 draws the debug lanes")
	root.push_input(debug_key)
	_expect(not traffic.has_node("TrafficDebug"), "F7 removes the debug lanes")
	for key in traffic.lanes:
		_verify_surface(traffic.lanes[key])
	var north := traffic.lanes[&"NevskyToBridge"].curve
	var south := traffic.lanes[&"NevskyToDistrict"].curve
	_expect(north.sample_baked(12.0).x < -1.5 and south.sample_baked(south.get_baked_length() - 12.0).x > 1.5,
			"Traffic uses its left side in both directions")

	await _verify_obstacle()
	await _verify_moving_traffic()
	await _verify_drives()
	print("DISTRICT TRAFFIC: %d failures" % failures)
	quit(int(failures > 0))


func _verify_surface(lane: Path3D) -> void:
	var length := lane.curve.get_baked_length()
	var count := ceili(length / 0.37)
	var former_heading := Vector3.ZERO
	for i in count + 1:
		var distance := length * float(i) / count
		var point := lane.curve.sample_baked(distance, true)
		var ahead := lane.curve.sample_baked(minf(distance + 0.25, length), true)
		var before := lane.curve.sample_baked(maxf(distance - 0.25, 0.0), true)
		var heading := before.direction_to(ahead)
		_expect(former_heading.is_zero_approx() or former_heading.dot(heading) > 0.93, "%s has no sudden heading change at %s" % [lane.name, point])
		former_heading = heading
		var side := heading.cross(Vector3.UP)
		for offset: float in [-0.99, 0.0, 0.99]:
			var site := point + side * offset
			var ray := PhysicsRayQueryParameters3D.create(site + Vector3.UP * 0.72, site - Vector3.UP * 0.12, 1)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.collider.name not in ALLOWED_SURFACES:
				_expect(false, "%s leaves the road at %s (%s)" % [lane.name, site, hit.get("collider")])
				return
			_expect(bridge.to_local(site).z > 4.0, "%s enters the closed approach to the raised bridge" % lane.name)


func _verify_obstacle() -> void:
	var lane := traffic.lanes[&"NevskyToBridge"]
	var cutoff := 23.0
	var on_lane := lane.curve.sample_baked(cutoff, true)
	var agent := traffic.create_agent(&"NevskyToBridge", Agent.Profile.AUTOMOBILE, 3.0)
	G.collider(traffic, "TestRoadBlock", on_lane + Vector3.UP * 0.7, Vector3(2.0, 1.4, 0.6))
	for frame in 60 * 8:
		await physics_frame
	_expect(agent.blocked and agent.speed < 0.08 and agent.progress > cutoff - 4.5 and agent.progress < cutoff - 2.1,
			"Car brakes short of the obstacle (%.2f/%.2f m)" % [agent.progress, cutoff])
	traffic.get_node("TestRoadBlock").queue_free()
	for frame in 60 * 5:
		await physics_frame
	_expect(agent.progress > cutoff + 3.0 and not agent.blocked, "Car resumes when road clears")
	agent.queue_free()
	await physics_frame


func _verify_moving_traffic() -> void:
	var vehicle_at := 27.0
	var leader := traffic.create_agent(&"NevskyToBridge", Agent.Profile.CARRIAGE, vehicle_at)
	leader.set_physics_process(false)
	var follower := traffic.create_agent(&"NevskyToBridge", Agent.Profile.BICYCLE, 11.0)
	for frame in 60 * 8:
		await physics_frame
	_expect(follower.speed < 0.08 and follower.blocked and follower.progress < vehicle_at - 3.45,
			"Bicycle stops behind the carriage")
	leader.queue_free()
	var player := current_scene.get_node("PlayerSpawn/Player") as CharacterBody3D
	var player_at := vehicle_at + 5.0
	player.global_position = follower.lane.curve.sample_baked(player_at, true) + Vector3.UP * 0.04
	for frame in 60 * 7:
		await physics_frame
	_expect(follower.progress > vehicle_at and follower.progress < player_at - 1.40 and follower.speed < 0.08,
			"Bicycle resumes after the carriage and stops for the player")
	player.global_position = Vector3(0, 0.03, 12)
	follower.queue_free()
	await physics_frame


func _verify_drives() -> void:
	# Run independently so junction traffic cannot be mistaken for a static route obstruction.
	var types := [Agent.Profile.AUTOMOBILE, Agent.Profile.BICYCLE, Agent.Profile.CARRIAGE, Agent.Profile.CARRIAGE]
	var index := 0
	for key in traffic.lanes:
		var agent := traffic.create_agent(key, types[index])
		var time_limit := ceili(agent.lane.curve.get_baked_length() * 0.6 + 12.0) * 60
		for frame in time_limit:
			await physics_frame
			if agent.at_terminal:
				break
		_expect(agent.at_terminal and agent.speed == 0.0 and bridge.to_local(agent.global_position).z > 4.0,
				"%s drives to its dry terminal (%.2f/%.2f)" % [key, agent.progress, agent.lane.curve.get_baked_length()])
		agent.queue_free()
		await physics_frame
		index += 1


func _expect(passed: bool, message: String) -> void:
	if not passed:
		printerr(message)
		failures += 1
