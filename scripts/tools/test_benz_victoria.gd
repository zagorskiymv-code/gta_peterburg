extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_benz_victoria.gd

const Victoria = preload("res://scripts/vehicles/benz_victoria.gd")
const Model = preload("res://scripts/vehicles/victoria_model.gd")
const G = preload("res://scripts/world/district_geometry.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	await _frames(10)
	var parked := current_scene.get_node("VehicleTrial/BenzVictoria") as Victoria
	var player := current_scene.get_node("PlayerSpawn/Player") as CharacterBody3D
	var approach := Transform3D(Basis.IDENTITY, Vector3(0, 0.035, parked.global_position.z))
	var collision := KinematicCollision3D.new()
	_expect(parked.is_on_floor() and player.test_move(approach, Vector3.LEFT * 2.0, collision)
			and collision.get_collider() == parked, "Main district has one grounded car with player collision")
	change_scene_to_file("res://scenes/vehicles/victoria_test_drive.tscn")
	await scene_changed
	var car := current_scene.get_node("PetersburgDistrict/VehicleTrial/BenzVictoria") as Victoria
	var start := car.global_transform
	await _frames(12)
	_expect(car.is_on_floor() and absf(car.global_position.y) < 0.10, "The parked car sits on the road")
	var wheels := car.model.find_children("WheelSpin*", "Node3D", true, false)
	_expect(wheels.size() == 4, "Four independent wheel assemblies")
	var body := car.model.get_node("PaintedBodyTub") as MeshInstance3D
	var mesh := body.mesh
	var paint := body.material_override as StandardMaterial3D
	for index in Model.COLORS.size():
		_key(KEY_1 + index)
		_expect(body.mesh == mesh and body.material_override == paint and paint.albedo_color == Model.COLORS[index],
				"Paint %d changes the shared model material" % index)

	Input.action_press("move_forward")
	await _frames(60)
	_expect(car.drive_speed > 1.1 and car.drive_speed < 1.55, "Progressive acceleration")
	await _frames(286)
	_expect(absf(car.drive_speed * 3.6 - 25.0) < 0.2 and car.is_on_floor(), "Top speed about 25 km/h")
	for wheel in wheels:
		_expect(absf(wheel.rotation.x) > 0.01, "Wheel spins when the car moves")
	var brake_at := car.global_position
	Input.action_press("jump")
	await _frames(155)
	Input.action_release("jump")
	Input.action_release("move_forward")
	var braking_distance := brake_at.distance_to(car.global_position)
	_expect(car.drive_speed < 0.05 and braking_distance > 5.0 and braking_distance < 9.3, "Progressive braking")

	_key(KEY_R)
	await _frames(12)
	Input.action_press("move_forward")
	await _frames(90)
	var heading := car.rotation.y
	var left_at := car.global_position
	Input.action_press("move_left")
	await _frames(56)
	Input.action_release("move_left")
	Input.action_release("move_forward")
	_expect(car.rotation.y > heading + 0.20 and car.global_position.x < left_at.x - 0.20, "Car turns left from input")
	var pivots := car.model.find_children("SteeringPivot*", "Node3D", true, false)
	_expect(pivots.size() == 2 and absf(pivots[0].rotation.y - pivots[1].rotation.y) > 0.025,
			"Front wheels have independent steering angles")

	_key(KEY_R)
	await _frames(12)
	Input.action_press("move_backward")
	await _frames(75)
	Input.action_release("move_backward")
	_expect(car.drive_speed < -1.0 and car.global_position.z > start.origin.z + 0.7, "Reverse control")

	_key(KEY_R)
	await _frames(12)
	var wall := start.origin + Vector3(0, 0.65, -7.0)
	G.collider(current_scene, "TestRoadObstacle", wall, Vector3(3.0, 1.3, 0.50))
	Input.action_press("move_forward")
	await _frames(320)
	Input.action_release("move_forward")
	_expect(car.global_position.z > wall.z + 1.72 and car.global_position.z < wall.z + 2.0
			and car.drive_speed < 0.2 and car.is_on_floor(), "Vehicle stops at the obstacle without penetrating")
	print("BENZ VICTORIA: %d failures" % failures)
	quit(int(failures > 0))


func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		failures += 1
