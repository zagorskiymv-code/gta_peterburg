extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_city_driving.gd

const Player = preload("res://scripts/player/player_controller.gd")
const Victoria = preload("res://scripts/vehicles/benz_victoria.gd")
const Traffic = preload("res://scripts/systems/district_traffic.gd")
const Agent = preload("res://scripts/systems/traffic_agent.gd")
const G = preload("res://scripts/world/district_geometry.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	var player := current_scene.get_node("PlayerSpawn/Player") as Player
	var car := current_scene.get_node("VehicleTrial/BenzVictoria") as Victoria
	var traffic := current_scene.get_node("DistrictTraffic") as Traffic
	var fleet := traffic.get_node("TrafficFleet")
	var cars := fleet.get_children()
	var visual: Node3D = player.get_node("CharacterVisual")
	var foot_camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	await _frames(15)
	_expect(cars.size() == 6, "Six NPC cars and one free car")
	player.global_position = car.global_position + Vector3.RIGHT * 1.72
	await _frames(10)
	_e()
	await _frames(8)
	_expect(car.has_driver and visual.get_parent() == car and root.get_camera_3d() != foot_camera,
			"E mounts and switches to the vehicle camera")
	_expect(visual.visible and visual.legs[0].rotation.x > 1.4 and player.collision_layer == 0,
			"Actual player character sits behind the tiller")
	var foot_yaw := player.camera_yaw
	if DisplayServer.get_name() != "headless":
		_check_mouse_orbit(car, player)
	Input.action_press("move_forward")
	await _frames(100)
	_expect(car.drive_speed > 1.8 and car.is_on_floor(), "Player drives on the road")
	Input.action_press("jump")
	await _frames(70)
	_expect(car.drive_speed < 0.08 and absf(player.global_position.z - car.global_position.z) < 0.1,
			"Space holds the vehicle")
	Input.action_release("jump")
	Input.action_release("move_forward")

	# Block the primary exit and force the controller to select the opposite side.
	var block_at := car.to_global(Vector3(-1.55, 0.65, 0.22))
	G.collider(car.get_parent(), "TestExitBlock", block_at, Vector3(0.75, 1.3, 2.2))
	_e()
	await _frames(12)
	_expect(not car.has_driver and visual.get_parent() == player and root.get_camera_3d() == foot_camera
			and car.to_local(player.global_position).x > 1.0 and player.is_on_floor(), "E uses the unblocked exit and restores camera")
	_expect(player.is_physics_processing() and player.collision_layer == 2 and player.collision_mask == 5,
			"Walking and original collision layers are restored")
	if DisplayServer.get_name() != "headless":
		_mouse_motion(Vector2(100, 0))
		_expect(not is_equal_approx(player.camera_yaw, foot_yaw), "Mouse returns to the walking camera after exiting")
	car.get_parent().get_node("TestExitBlock").queue_free()
	await _frames(2)
	_e()
	await _frames(8)
	Input.action_press("move_forward")
	await _frames(92)
	_e()
	await _frames(100)
	Input.action_release("move_forward")
	_expect(not car.has_driver and car.drive_speed < 0.15 and root.get_camera_3d() == foot_camera,
			"E while moving brakes and exits only after stopping")
	player.global_position = Vector3(0, 0.065, 12)
	await _frames(5)

	await _check_occupied_car(cars[0], player, car)
	var bridge := current_scene.get_node("NevskyProspekt/NevaBridge") as Node3D
	var traveled := {}
	var wrapped := {}
	var progress := {}
	var exclusions: Array[RID] = []
	for agent: Agent in cars:
		exclusions.append(agent.get_rid())
		var driver: Node3D = agent.get_node("TrafficVictoria/NPCDriver")
		_expect(driver.is_visible_in_tree() and driver.legs[0].rotation.x > 1.4, "NPC driver is visible and seated")
		traveled[agent] = 0.0
		wrapped[agent] = false
		progress[agent] = agent.progress
	await _frames(1)

	var space := traffic.get_world_3d().direct_space_state
	for path in traffic.fleet_lanes:
		var length := path.curve.get_baked_length()
		var count := ceili(length / 0.42)
		for i in count:
			var distance := length * float(i) / count
			var at := path.curve.sample_baked(distance, true)
			var side := at.direction_to(path.curve.sample_baked(minf(distance + 0.28, length), true)).cross(Vector3.UP)
			for offset: float in [-0.90, 0.0, 0.90]:
				var site := at + side * offset
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
						site + Vector3.UP * 0.51, site - Vector3.UP * 0.12, 1, exclusions))
				if hit.is_empty() or hit.collider.name not in [&"NevskyRoadCollision", &"BypassRoadCollision"]:
					_expect(false, "%s crosses off road at %s (%s)" % [path.name, site, hit.get("collider")])
					break

	for frame in 60 * 200:
		await physics_frame
		if frame % 12 != 0:
			continue
		for agent: Agent in cars:
			var step: float = agent.progress - progress[agent]
			if step < -0.01:
				wrapped[agent] = true
				step += agent.lane.curve.get_baked_length()
			traveled[agent] += step
			progress[agent] = agent.progress
			_expect(agent.global_position.y > 0.0 and bridge.to_local(agent.global_position).z > 4.0,
					"Fleet stays on dry roads away from the bridge")
	for agent: Agent in cars:
		_expect(traveled[agent] > agent.lane.curve.get_baked_length() and wrapped[agent],
				"%s completed the circuit (%.1f m of %.1f m)" % [agent.name, traveled[agent], agent.lane.curve.get_baked_length()])
	print("CITY DRIVING: %d failures" % failures)
	quit(int(failures > 0))


func _check_occupied_car(agent: Agent, player: CharacterBody3D, free_car: Victoria) -> void:
	var length := agent.lane.curve.get_baked_length()
	var target := fposmod(agent.progress + 12.0, length)
	var stopping_spot := agent.lane.curve.sample_baked(target, true)
	player.global_position = stopping_spot + Vector3.UP * 0.045
	await _frames(60 * 6)
	_expect(agent.blocked and agent.speed < 0.08 and agent.global_position.distance_to(stopping_spot) > 1.90,
			"A live fleet vehicle yields to a pedestrian")
	player.global_position = agent.to_global(Vector3(1.57, 0.035, 0.0))
	await _frames(7)
	_e()
	await _frames(5)
	_expect(not free_car.has_driver and player.is_physics_processing(), "E cannot take an occupied NPC car")
	player.global_position = Vector3(0, 0.065, 12)


func _check_mouse_orbit(car: Victoria, player: Player) -> void:
	var arm := car.get_node("DrivingCameraArm") as SpringArm3D
	var foot_yaw := player.camera_yaw
	var foot_pitch := player.camera_pitch
	var initial_orbit := arm.rotation
	_mouse_motion(Vector2(140, 95))
	_expect(arm.rotation.y < initial_orbit.y - 0.20 and arm.rotation.x < initial_orbit.x - 0.15,
			"Mouse orbits the driving camera horizontally and vertically")
	_expect(is_equal_approx(player.camera_yaw, foot_yaw) and is_equal_approx(player.camera_pitch, foot_pitch),
			"Driving does not rotate the walking camera")
	_mouse_motion(Vector2(0, 2000))
	_expect(is_equal_approx(arm.rotation.x, deg_to_rad(Player.MIN_CAMERA_PITCH)), "Driving camera pitch is limited")


func _mouse_motion(offset: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.screen_relative = offset
	root.push_input(event)


func _e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	root.push_input(event)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		failures += 1
