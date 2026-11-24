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
	await _route(Vector3(40.65,0.04,17), [Vector3(40.65,0,25.75)], "Canal and garden access beside new annex")
	await _route(Vector3(-25.75,0.05,73), [Vector3(-25.75,0,84),Vector3(-25.75,0,73)], "Printworks service arch")
	await _route(Vector3(-43,0.05,28), [Vector3(-43,0,11)], "Western perimeter courtyard arch")
	await _route(Vector3(-28,0.05,9.5), [Vector3(-16.2,0,9.5),Vector3(-16.2,0,2)], "Baranov lane arch")
	await _route(Vector3(24,0.05,-199), [Vector3(24,0,-175),Vector3(24,0,-165)], "Staff arch and rear gallery")
	await _route(Vector3(-59,0.05,32.65), [Vector3(-69,0,32.65)], "Merchant corner garden approach")
	_check_polygon_collisions()
	await _check_campaign_contact()
	print("RECONSTRUCTION ROUTES: %d failures" % failures)
	quit(1 if failures else 0)

func _check_polygon_collisions() -> void:
	var space := player.get_world_3d().direct_space_state
	for mesh: MeshInstance3D in current_scene.find_children("PolygonMasonry", "MeshInstance3D", true, false):
		var building := mesh.get_parent() as Node3D
		var outline: PackedVector2Array = building.get_meta(&"plan_polygon")
		var center := Vector2.ZERO
		for point in outline:
			center += point
		center /= outline.size()
		var at := building.to_global(Vector3(center.x, 0, center.y))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 24, at, 1))
		if hit.is_empty() or hit.collider.get_parent() != building:
			push_error("Missing polygon building collision: %s" % building.get_path())
			failures += 1


func _check_campaign_contact() -> void:
	change_scene_to_file("res://scenes/world/new_game.tscn")
	await scene_changed
	await physics_frame
	var contact := current_scene.get_node("StoryContacts/Baranov") as CharacterBody3D
	var mission_player := current_scene.get_node("PlayerSpawn/Player") as CharacterBody3D
	var missions := current_scene.get_node("MissionManager")
	mission_player.global_position = Vector3(-26.9, 0.04, 9.5)
	var capsule := contact.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	query.transform = capsule.global_transform.translated(Vector3.UP * 0.10)
	query.collision_mask = 1
	if not contact.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty() or not missions._clear_interaction(contact):
		push_error("Baranov or the mission interaction ray is obstructed")
		failures += 1


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
