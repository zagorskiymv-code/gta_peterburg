extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_victoria_city_access.gd

const Victoria = preload("res://scripts/vehicles/benz_victoria.gd")

var car: Victoria
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	car = current_scene.get_node("VehicleTrial/BenzVictoria")

	await _curb(Vector3(0, 0.08, 34), Vector3(5.7, 0, 34))
	_expect(car.global_position.x > 5.45 and car.global_position.y > 0.045, "Drive onto the raised east sidewalk")
	await _curb(Vector3(5.7, 0.13, 34), Vector3(-5.65, 0, 34))
	_expect(car.global_position.x < -5.42 and car.global_position.y > 0.045, "Drive down to the road and up the west curb")
	await _curb(Vector3(0, 0.09, 16), Vector3(5.4, 0, 16))
	_expect(car.global_position.x > 5.15 and car.global_position.y > 0.10, "Traverse the original street's beveled pavement")

	await _curb(Vector3(43, 0.11, -27), Vector3(66, 0, -27))
	_expect(car.global_position.x > 65.7 and car.global_position.y > -0.06, "Cross the existing arched canal bridge")
	await _curb(Vector3(26.5, 0.10, 86), Vector3(26.5, 0, 100))
	_expect(car.global_position.z > 99.75 and car.global_position.y > -0.06, "Use the New Holland bridge and its ground seams")

	await _curb(Vector3(24, 0.08, -203), Vector3(24, 0, -174))
	_expect(car.global_position.z > -174.26 and car.global_position.y > -0.05, "Drive through the General Staff arch")

	var avenue := current_scene.get_node("NevskyProspekt/Avenue") as Node3D
	var bridge := current_scene.get_node("NevskyProspekt/NevaBridge") as Node3D
	var centerline: PackedVector3Array = avenue.get_meta(&"route_points")
	var route := Curve3D.new()
	for index in centerline.size():
		if centerline[index].z > -49.0:
			continue
		var tangent := centerline[mini(index + 1, centerline.size() - 1)] - centerline[maxi(index - 1, 0)]
		var at := centerline[index] - tangent.normalized().cross(Vector3.UP) * 1.15
		route.add_point(avenue.to_global(at))
	for distance in range(2, 45, 2):
		route.add_point(bridge.to_global(Vector3(-1.15, 0, -distance)))

	await _place(route.sample_baked(0.0), route.sample_baked(2.0))
	var arrived := false
	var length := route.get_baked_length()
	for frame in 60 * 87:
		var progress := route.get_closest_offset(car.global_position)
		if progress > length - 0.65:
			arrived = true
			break
		_aim(route.sample_baked(minf(length, progress + 3.0), true), 0.73)
		await physics_frame
		if car.global_position.y < -0.35:
			break
	_expect(arrived and bridge.to_local(car.global_position).z < -42.0,
			"Northbound Nevsky connects to Palace Bridge with traffic active: %s" % car.global_position)

	# The visible raised leaf remains a physical barrier, as it is for the pedestrian.
	var leaf := bridge.to_global(Vector3(-1.15, 0.0, -64.0))
	for frame in 60 * 6:
		_aim(leaf, 0.8)
		await physics_frame
	var local := bridge.to_local(car.global_position)
	_expect(local.z < -46.0 and local.z > -51.5 and car.is_on_floor(),
			"Only the raised deck ends the drive: %s" % local)
	print("VICTORIA CITY ACCESS: %d failures" % failures)
	quit(int(failures > 0))


func _curb(from: Vector3, to: Vector3) -> void:
	await _place(from, to)
	for frame in 60 * 12:
		var remaining := (car.global_position - to).slide(Vector3.UP).length()
		if remaining < 0.18:
			return
		_aim(to, 0.6)
		await physics_frame


func _place(from: Vector3, to: Vector3) -> void:
	var heading := (to - from).slide(Vector3.UP).normalized()
	car.reset_drive(Transform3D(Basis.looking_at(heading), from + Vector3.UP * 0.12))
	for frame in 12:
		await physics_frame


func _aim(target: Vector3, throttle: float) -> void:
	var delta := car.global_position - target
	var error := angle_difference(car.global_rotation.y, atan2(delta.x, delta.z))
	car.set_drive_input(throttle, clampf(error * 2.45, -1.0, 1.0), false)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		failures += 1
