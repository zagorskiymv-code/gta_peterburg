extends SceneTree

## godot --headless --path . --fixed-fps 60 --script res://scripts/tools/test_fair_and_riding.gd

const Citizen = preload("res://scenes/npc/citizen_npc.tscn")
var errors := 0
func _initialize(): call_deferred("_run")
func _run():
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	var district = current_scene
	var player = district.get_node("PlayerSpawn/Player")
	var stable = district.get_node("PalaceStables")
	var riding = district.get_node("DistrictRiding")
	var car = district.get_node("VehicleTrial/BenzVictoria")
	await frames(12)
	var fair := district.get_node("Infill/UrbanBlocks/StoneMarket") as Node3D
	check(fair.find_children("CounterCloth*", "MeshInstance3D", true, false).size() == 10, "Ten stocked counters")
	var vendors := district.get_node("DistrictCitizenPopulation/Market")
	check(vendors.find_children("FairVendor*", "CharacterBody3D", false, false).size() == 3, "Three new vendors")
	# Each horse can be selected from the inside aisle and started outside the entrance.
	for i in 5:
		var stall = stable.get_node("Horse%02d" % (i+1))
		var local: Vector3 = stall.position
		var site := Vector3(local.x, 0.075, -0.41) if i < 4 else Vector3(0.86, 0.075, 0.07)
		player.global_position = stable.to_global(site)
		await frames(12)
		key()
		await frames(8)
		var horse = riding._mounted
		check(horse != null and horse.horse.coat_index == i, "Mount horse %s" % i)
		if not horse:
			continue
		check(stable.to_local(horse.global_position).z > 5.8, "Mount outside the stable")
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await frames(65)
		Input.action_release("sprint")
		Input.action_release("move_forward")
		key()
		await frames(14)
		check(riding._mounted == null and player.is_physics_processing(), "Dismount safely")
		if riding._mounted:
			break
		if i == 0:
			var before: Vector3 = horse.global_position
			await frames(155)
			check(horse.global_position.distance_to(before) > 0.45, "Released horse walks")
			player.global_position = horse.to_global(Vector3(1.22, 0.06, 0))
			await frames(10)
			key()
			await frames(8)
			check(riding._mounted == horse, "Same horse can be mounted again")
			key()
			await frames(10)
		horse.queue_free()
		await frames(3)

	player.global_position = car.global_position + Vector3.RIGHT * 1.72
	await frames(12)
	key()
	await frames(12)
	check(car.has_driver, "Player enters car")
	var pedestrian = Citizen.instantiate()
	pedestrian.position = car.global_position + Vector3.FORWARD * 5.3 + Vector3.UP * 0.07
	district.add_child(pedestrian)
	Input.action_press("move_forward")
	await frames(175)
	Input.action_release("move_forward")
	check(is_instance_valid(pedestrian) and pedestrian.struck_down and not pedestrian.is_physics_processing(), "Vehicle impact stops and lays NPC down")
	await frames(460)
	check(not is_instance_valid(pedestrian), "Fallen NPC is removed after delay")
	print("NEW GAMEPLAY: %d failures" % errors)
	quit(int(errors > 0))
func frames(n):
	for i in n: await physics_frame
func key():
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	root.push_input(event)
func check(result, msg):
	if not result:
		printerr(msg)
		errors += 1
