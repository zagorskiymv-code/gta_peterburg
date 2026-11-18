extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_district_citizens.gd

const Citizen = preload("res://scripts/npc/citizen_npc.gd")
const SIMULATION_SECONDS := 180

var failures := 0
var space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	var population := current_scene.get_node("DistrictCitizenPopulation") as Node3D
	_expect(population.get_child_count() == 7, "Population covers seven areas")
	var citizens: Array[Citizen] = []
	for zone in population.get_children():
		for actor in zone.get_children():
			if actor is Citizen:
				citizens.append(actor)
	_expect(citizens.size() == 49, "Forty-nine citizens including fair vendors")
	_expect(population.get_node("Nevsky").find_children("*", "CharacterBody3D", false, false).size()
			+ population.get_node("Singer").find_children("*", "CharacterBody3D", false, false).size() == 26,
			"Twenty-six pedestrians on Nevsky including Singer frontage")
	_expect(get_nodes_in_group(&"street_citizens").size() == 71, "City has seventy-one NPC instances")
	space = population.get_world_3d().direct_space_state
	await physics_frame

	var passes := {}
	var last_point := {}
	var airborne := {}
	var unsafe := {}
	var waited := {}
	var vendor: Citizen = population.get_node("Market/MarketVendor")
	var buyer: Citizen = population.get_node("Market/MarketShopper")
	var market_conversation := false
	for npc in citizens:
		# Activate all districts simultaneously for a stricter check than ordinary local play.
		npc.activity_radius = 0.0
		passes[npc] = {}
		last_point[npc] = -1
		airborne[npc] = 0
		if npc.route:
			_check_route(npc)

	for frame in Engine.physics_ticks_per_second * SIMULATION_SECONDS:
		await physics_frame
		if vendor.state == Citizen.State.TALK and buyer.state == Citizen.State.TALK:
			market_conversation = true
		if frame < 12:
			continue
		for npc in citizens:
			airborne[npc] = 0 if npc.is_on_floor() else airborne[npc] + 1
			if npc.global_position.y < -0.22 or airborne[npc] > 18:
				unsafe[npc.name] = npc.global_position
			if frame % 5 != 0 or not npc.route:
				continue
			for index in npc.route.curve.point_count:
				var delta := npc.global_position - _point(npc, index)
				if Vector2(delta.x, delta.z).length_squared() >= 0.22 * 0.22:
					continue
				if last_point[npc] != index:
					last_point[npc] = index
					passes[npc][index] = passes[npc].get(index, 0) + 1
				if npc.state in [Citizen.State.WAIT, Citizen.State.LOOK_AROUND, Citizen.State.TALK] and npc.velocity.length_squared() < 0.01:
					waited[npc] = true

	_expect(market_conversation, "The market buyer and vendor sometimes meet at neighboring stops")
	_expect(unsafe.is_empty(), "Nobody falls from the pavement: %s" % unsafe)
	_expect(waited.size() == citizens.size() - 3, "Everyone pauses at a stop")
	for npc in citizens:
		if not npc.route:
			continue
		for index in npc.route.curve.point_count:
			_expect(passes[npc].get(index, 0) >= 2, "%s repeats stop %d: %s" % [npc.name, index, passes[npc]])
	_expect(population.find_children("*", "CharacterBody3D", true, false).size() == citizens.size(),
			"The same population remains in the scene")
	await _check_distance_tiers(population)
	print("DISTRICT CITIZENS (%d seconds): %d failures" % [SIMULATION_SECONDS, failures])
	quit(int(failures > 0))


func _check_distance_tiers(population: Node3D) -> void:
	var player := current_scene.get_node("PlayerSpawn/Player") as CharacterBody3D
	var walker := population.get_node("Nevsky/NevskyClerk") as Citizen
	walker.activity_radius = 100.0
	player.global_position = Vector3(0, 0.02, 40)
	for frame in 25:
		await physics_frame
	var resting := walker.global_position
	for frame in 60:
		await physics_frame
	_expect(walker._lod_sleeping and walker.visual.is_visible_in_tree()
			and walker.global_position.distance_to(resting) < 0.005, "Distant geometry stays visible without walking")
	player.global_position = Vector3(0, 0.05, -65)
	for frame in 3:
		await physics_frame
	_expect(not walker._lod_sleeping and walker.visual.is_visible_in_tree()
			and walker.global_position.distance_to(resting) < 0.15, "Walkers resume without being replaced or repositioned")


func _check_route(npc: Citizen) -> void:
	var shape: CollisionShape3D = npc.get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.collision_mask = 1
	query.margin = 0.02
	for index in npc.route.curve.point_count:
		var start := _point(npc, index)
		var finish := _point(npc, (index + 1) % npc.route.curve.point_count)
		var steps := ceili(start.distance_to(finish) / 0.28)
		for step in steps + 1:
			var site := start.lerp(finish, float(step) / steps)
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					site + Vector3.UP * 0.19, site - Vector3.UP * 0.16, 1))
			if ground.is_empty():
				_expect(false, "%s unsupported at %s" % [npc.name, site])
				break
			query.transform.origin = ground.position + Vector3.UP * (shape.position.y + 0.03)
			var hit := space.intersect_shape(query, 1)
			if not hit.is_empty():
				_expect(false, "%s blocked at %s by %s" % [npc.name, site, hit[0].collider.get_path()])
				break


func _point(npc: Citizen, index: int) -> Vector3:
	return npc.route.to_global(npc.route.curve.get_point_position(index))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		printerr(message)
		failures += 1
