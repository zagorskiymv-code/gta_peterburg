extends SceneTree
## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_reconstructed_routes.gd

var player: CharacterBody3D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/world/petersburg_district.tscn")
	await scene_changed
	player = current_scene.get_node("PlayerSpawn/Player")
	await _route(Vector3(26.50,0.08,86.5), [Vector3(26.50,0,100),Vector3(30.5,0,105),
		Vector3(30.5,0,130),Vector3(30.5,0,108),Vector3(26.5,0,100),Vector3(26.5,0,86.5)], "New Holland round trip")
	await _route(Vector3(-63,0.09,-236), [Vector3(-63,0,-245),Vector3(-66,0,-247.4),
		Vector3(-66,0,-259.5),Vector3(-66,0,-246.0),Vector3(-71,0,-241)], "Garden entries and Admiralty arch")
	await _route(Vector3(-29,0.04,-21), [Vector3(-29,0,22), Vector3(-36,0,28)], "Western lane beside infill")
	await _route(Vector3(-57,0.04,1.3), [Vector3(-66,0,1.3),Vector3(-77,0,1.3)], "Western service passage")
	await _route(Vector3(22.4,0.06,-4), [Vector3(17,0,-4),Vector3(22.4,0,-4)], "Main Street service court")
	await _route(Vector3(41,0.05,-154), [Vector3(72,0,-154),Vector3(72,0,-173),
		Vector3(72,0,-186),Vector3(42,0,-186)], "Existing three well-courtyard arches")
	print("RECONSTRUCTION ROUTES: %d failures" % failures)
	quit(1 if failures else 0)

func _route(start: Vector3, points: Array, label: String) -> void:
	player.global_position = start
	player.velocity = Vector3.ZERO
	for i in 7:
		await physics_frame
	Input.action_press(&"move_forward")
	for target: Vector3 in points:
		var reached := false
		for i in 900:
			var direction := target-player.global_position
			direction.y = 0
			if direction.length() < 0.18:
				reached = true
				break
			player.camera_yaw = atan2(-direction.x,-direction.z)
			player._update_camera_pivot()
			await physics_frame
			if player.is_dead or player.global_position.y < -0.25:
				break
		if not reached:
			push_error("%s blocked at %s, player at %s" % [label,target,player.global_position])
			failures += 1
			break
	Input.action_release(&"move_forward")
