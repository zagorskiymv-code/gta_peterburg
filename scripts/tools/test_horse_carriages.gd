extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_horse_carriages.gd

const Agent = preload("res://scripts/systems/traffic_agent.gd")
const Horse = preload("res://scripts/vehicles/horse_visual.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	await physics_frame
	var stable := current_scene.get_node("PalaceStables") as Node3D
	var observer := current_scene.get_node("PlayerSpawn/Player") as CharacterBody3D
	var space := observer.get_world_3d().direct_space_state
	var boxes := stable.find_children("Horse*", "AnimatableBody3D", true, false)
	_expect(boxes.size() == 5 and stable.global_position.x < -36.0, "Five horses in the stable outside Palace Square")
	var coat_indices := {}
	for horse in boxes:
		var model := horse.get_node("HorseVisual") as Horse
		coat_indices[model.coat_index] = true
		_expect(model._legs.size() == 4, "Four articulated legs")
	_expect(coat_indices.size() == 5, "Five distinct coats")

	var player_pose := observer.global_transform
	player_pose.origin = stable.to_global(Vector3(0, 0.075, 6.0))
	_expect(not observer.test_move(player_pose, Vector3.FORWARD * 5.75), "The stable entrance and center aisle are clear")

	observer.global_position = player_pose.origin
	for frame in 12:
		await physics_frame
	Input.action_press("move_forward")
	for frame in 60:
		await physics_frame
	Input.action_release("move_forward")
	_expect(stable.to_local(observer.global_position).z < 1.2 and observer.is_on_floor(), "Player walks in over the stable threshold")
	observer.global_position = Vector3(0, 0.06, 12)

	var carriages := current_scene.get_node("DistrictTraffic/CarriageFleet").get_children()
	_expect(carriages.size() == 4, "Four moving carriages")
	var progress := {}
	var distance := {}
	var pose := {}
	var collisions := {}
	var clear_ground := true
	var walker_first: Vector3 = boxes[-1].global_position
	var walked := false
	var bent_leg := false
	var mixed_fleet: Array[Node] = carriages.duplicate()
	mixed_fleet.append_array(current_scene.get_node("DistrictTraffic/TrafficFleet").get_children())
	var excludes: Array[RID] = []
	for agent: Agent in mixed_fleet:
		excludes.append(agent.get_rid())

	for agent: Agent in carriages:
		var carriage := agent.get_node("HorseCarriage")
		_expect(carriage.get_node("Coachman").legs[0].rotation.x > 1.4 and carriage.has_node("OpenCoach/PassengerBench"),
				"Coachman and passenger bench")
		progress[agent] = agent.progress
		distance[agent] = 0.0
		pose[agent] = carriage.get_node("HarnessHorse")._legs[0].rotation.x

	var walker := boxes[-1] as AnimatableBody3D
	for frame in 60 * 200:
		await physics_frame
		if frame % 35 != 0:
			continue
		if frame < 60 * 18:
			walked = walked or walker.global_position.distance_to(walker_first) > 0.9
			for horse: AnimatableBody3D in boxes:
				if not _body_clear(space, horse, horse.get_child(0) as CollisionShape3D):
					collisions[horse.name] = horse.global_position
		for agent: Agent in carriages:
			var step: float = fposmod(agent.progress - float(progress[agent]), agent.lane.curve.get_baked_length())
			distance[agent] += step
			progress[agent] = agent.progress
			bent_leg = bent_leg or absf(agent.get_node("HorseCarriage/HarnessHorse")._legs[0].rotation.x - pose[agent]) > 0.18
			var shape := agent.get_node("VehicleFootprint") as CollisionShape3D
			if not _body_clear(space, agent, shape):
				collisions[agent.name] = agent.global_position
			for axle_z: float in [-1.41, 0.47, 1.97]:
				var base := agent.to_global(Vector3(0, 0, axle_z))
				var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
						base + Vector3.UP * 0.12, base - Vector3.UP * 0.20, 1, excludes))
				clear_ground = clear_ground and not floor_hit.is_empty() and floor_hit.collider.name in [
						&"NevskyRoadCollision", &"BypassRoadCollision"]

	_expect(walked and bent_leg, "Stable horse walks in the pen and traffic horses articulate their gait")
	_expect(collisions.is_empty(), "No overlap with other bodies: %s" % collisions)
	_expect(clear_ground, "Horse and axles remain over the existing roads")
	for agent: Agent in carriages:
		_expect(distance[agent] > agent.lane.curve.get_baked_length(), "%s completed a circuit (%.1f of %.1f m)" % [
				agent.name, distance[agent], agent.lane.curve.get_baked_length()])
	print("HORSE CARRIAGES: %d failures" % failures)
	quit(int(failures > 0))


func _body_clear(space: PhysicsDirectSpaceState3D, body: AnimatableBody3D, collision: CollisionShape3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var slightly_smaller := BoxShape3D.new()
	slightly_smaller.size = collision.shape.size - Vector3(0.04, 0.05, 0.04)
	query.shape = slightly_smaller
	query.transform = collision.global_transform
	query.exclude = [body.get_rid()]
	query.collision_mask = 15
	return space.intersect_shape(query, 1).is_empty()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		failures += 1
