extends Node3D

signal transport_entered(vehicle: Node3D)

const G = preload("res://scripts/world/district_geometry.gd")
const Player = preload("res://scripts/player/player_controller.gd")
const Bike = preload("res://scripts/vehicles/penny_farthing.gd")
const Horse = preload("res://scripts/vehicles/riding_horse.gd")
const Visual = preload("res://scripts/player/historical_character_visual.gd")

var player: Player
var stable: Node3D
var _mounted: Horse
var _arm: SpringArm3D
var _camera: Camera3D
var _visual: Visual
var _visual_pose: Transform3D
var _key := false
var _drowned := false
var _layer: int
var _mask: int
var hud_hint := ""
var _bike_parking: Dictionary[Horse, Transform3D] = {}


func mounted_transport() -> Node3D:
	return _mounted


func configure(actor: Player, yard: Node3D) -> void:
	player = actor
	stable = yard
	_visual = player.character_visual
	player.died.connect(func(_reason: StringName) -> void: _drowned = is_instance_valid(_mounted))
	_spawn_bicycles.call_deferred()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_mounted) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		_arm.rotation.y = wrapf(_arm.rotation.y - event.screen_relative.x * Player.MOUSE_SENSITIVITY, -PI, PI)
		_arm.rotation.x = clampf(_arm.rotation.x - event.screen_relative.y * Player.MOUSE_SENSITIVITY, -1.20, 0.45)
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if not player.is_dead and (is_instance_valid(_mounted) or is_instance_valid(_candidate())):
			_key = true
			get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _drowned:
		_drowned = false
		var horse := _mounted
		_dismount(horse.global_position)
		if horse.bicycle:
			horse.global_transform = _bike_parking[horse]
		else:
			horse.global_position = stable.to_global(Vector3(0, 0.08, 7.2))
		horse.reset_physics_interpolation()
		horse.velocity = Vector3.ZERO
	if is_instance_valid(_mounted):
		player.global_position = _mounted.global_position
		_pose_rider()
		if _key:
			var at := _exit_site()
			if at.is_finite():
				_dismount(at)
	elif _key:
		var nearby := _candidate()
		if nearby:
			_mount(nearby)
	_key = false
	var nearby := _candidate() if not is_instance_valid(_mounted) else null
	if is_instance_valid(_mounted):
		if _mounted.bicycle:
			hud_hint = "E — слезть · Пробел — тормоз"
		elif _mounted.delivery_mount:
			hud_hint = "E — спешиться · Shift — рысь"
		else:
			hud_hint = "E — спешиться · Shift — галоп · Пробел — прыжок"
	else:
		hud_hint = ("E — сесть на велосипед" if nearby is Horse and nearby.bicycle else "E — сесть на лошадь") if nearby else ""


func _pose_rider() -> void:
	if _mounted.bicycle:
		_visual.pose_cycling(_mounted.bike_model.crank_angle())
	else:
		_visual.pose_mounted()


func _spawn_bicycles() -> void:
	await get_tree().physics_frame
	var parking := [
		Vector2(-5.8, 16), Vector2(6.2, -11), Vector2(6.1, 70), Vector2(-5.9, 48),
		Vector2(-9.95, -47), Vector2(10.3, -87), Vector2(9.35, -111), Vector2(-9.8, -139),
		Vector2(-28, -119), Vector2(44, 25), Vector2(66.5, -57), Vector2(64, 47),
		Vector2(28.5, 102), Vector2(34, 113), Vector2(-51.5, -214), Vector2(-59, -267),
		Vector2(-70, -240), Vector2(71.5, 68), Vector2(15.4, -46), Vector2(22, -54),
		Vector2(-33.5, -56), Vector2(32, -143), Vector2(-73.8, -150), Vector2(69, -199),
		Vector2(51.0, -235), Vector2(-18.1, -236), Vector2(28, 79), Vector2(32, 63),
		Vector2(-47, 75), Vector2(-58, 56), Vector2(74, 69), Vector2(67, 17),
	]
	var world := stable.get_world_3d().direct_space_state
	var container := Node3D.new()
	container.name = "ParkedBicycles"
	add_child(container)
	var parking_shape := BoxShape3D.new()
	parking_shape.size = Vector3(0.60, 1.71, 2.06)
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = parking_shape
	fit.collision_mask = 15
	for index in parking.size():
		if _crosses_pedestrian_route(parking[index]):
			continue
		var at := Vector3(parking[index].x, 0, parking[index].y)
		var floor_hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.22,
				at - Vector3.UP * 0.18, 1))
		if floor_hit.is_empty() or floor_hit.normal.y < 0.85:
			continue
		var floor_position: Vector3 = floor_hit.position
		var yaw := PI if index % 2 == 0 else 0.0
		fit.transform = Transform3D(Basis(Vector3.UP, yaw), floor_position + Vector3.UP * 0.94)
		if not world.intersect_shape(fit, 1).is_empty():
			continue
		var ride := Horse.new()
		ride.name = "PennyFarthing%02d" % (index + 1)
		ride.bicycle = true
		ride.position = floor_position + Vector3.UP * 0.025
		ride.rotation.y = yaw
		var model := Bike.new()
		model.variant = index % 6
		ride.bike_model = model
		ride.add_child(model)
		container.add_child(ride)
		_bike_parking[ride] = ride.global_transform
		ride.rider_lost.connect(player.die)


func _crosses_pedestrian_route(site: Vector2) -> bool:
	for citizen in get_tree().get_nodes_in_group(&"street_citizens"):
		if not is_instance_valid(citizen.route):
			continue
		var path: Path3D = citizen.route
		var count := path.curve.point_count
		for index in count:
			var a := path.to_global(path.curve.get_point_position(index))
			var b := path.to_global(path.curve.get_point_position((index + 1) % count))
			var closest := Geometry2D.get_closest_point_to_segment(site, Vector2(a.x, a.z), Vector2(b.x, b.z))
			if closest.distance_squared_to(site) < 1.55 * 1.55:
				return true
	return false


func _candidate() -> Node3D:
	if not player.is_physics_processing() or player.is_dead or not player.is_on_floor():
		return null
	var best: Node3D
	var distance := 2.80 * 2.80
	var nearby := get_tree().get_nodes_in_group(&"riding_horses")
	var inside := stable.to_local(player.global_position)
	if absf(inside.x) < 4.62 and absf(inside.z) < 4.50:
		for stall in stable.get_children():
			if stall is AnimatableBody3D and stall.has_node("HorseVisual"):
				nearby.append(stall)
	for horse: Node3D in nearby:
		var gap := player.global_position.distance_squared_to(horse.global_position)
		if gap < distance and (not horse is Horse or horse.mount_allowed):
			distance = gap
			best = horse
	return best


func _mount(target: Node3D) -> void:
	if target is Horse:
		_mounted = target
	else:
		var entrance := _entrance()
		if not entrance.is_finite():
			return
		_mounted = Horse.new()
		_mounted.position = entrance
		_mounted.rotation.y = PI
		add_child(_mounted)
		_mounted.horse = target.get_node("HorseVisual")
		_mounted.horse.reparent(_mounted, false)
		var saddle := G.solid_material(Color("#4c3426"))
		var blanket := G.solid_material(Color("#69403b"))
		G.box(_mounted.horse, "SaddleBlanket", Vector3(0, 1.60, 0.01), Vector3(0.54, 0.07, 0.51), blanket)
		G.box(_mounted.horse, "Saddle", Vector3(0, 1.665, 0.02), Vector3(0.39, 0.11, 0.40), saddle)
		target.queue_free()
		_mounted.rider_lost.connect(player.die)
	_mounted.set_ridden(true)
	_layer = player.collision_layer
	_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	_visual_pose = _visual.transform
	_visual.reparent(_mounted, false)
	_visual.transform = Transform3D(Basis.IDENTITY, (Vector3(0, 1.49, -0.08) if _mounted.bicycle else Vector3(0, 1.74, -0.08)))
	_pose_rider()
	_arm = SpringArm3D.new()
	_arm.spring_length = 4.9
	_arm.position = Vector3(0, 2.15, 0)
	_arm.rotation.x = -0.30
	_arm.collision_mask = 1
	_arm.add_excluded_object(_mounted.get_rid())
	_mounted.add_child(_arm)
	_camera = Camera3D.new()
	_camera.fov = 63.0
	_arm.add_child(_camera)
	_camera.make_current()
	transport_entered.emit(_mounted)


func _entrance() -> Vector3:
	var world := stable.get_world_3d().direct_space_state
	var gap := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.83, 1.79, 2.58)
	gap.shape = shape
	gap.collision_mask = 15
	gap.exclude = [player.get_rid()]
	for x in [0.0, -1.20, 1.20, -2.45, 2.45]:
		var point := stable.to_global(Vector3(x, 0.06, 6.65))
		var ground := world.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.23,
				point - Vector3.UP * 0.29, 1, [player.get_rid()]))
		if ground.is_empty() or ground.normal.y < 0.85:
			continue
		var at: Vector3 = ground.position + Vector3.UP * 0.055
		gap.transform.origin = at + Vector3.UP
		if world.intersect_shape(gap, 1).is_empty():
			return at
	return Vector3.INF


func _dismount(at: Vector3) -> void:
	_mounted.set_ridden(false)
	_mounted = null
	_arm.queue_free()
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.collision_layer = _layer
	player.collision_mask = _mask
	_visual.reparent(player, false)
	_visual.transform = _visual_pose
	_visual.leave_seat()
	player.reset_physics_interpolation()
	player.set_physics_process(true)
	player.spring_arm.get_node("Camera3D").make_current()


func _exit_site() -> Vector3:
	var space := _mounted.get_world_3d().direct_space_state
	var capsule := player.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	query.collision_mask = _mask | 8
	query.exclude = [player.get_rid()]
	for offset: Vector3 in [Vector3(-1.18, 0, 0), Vector3(1.18, 0, 0), Vector3(0, 0, 1.95)]:
		var point := _mounted.to_global(offset)
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.43,
				point - Vector3.UP * 0.27, 1, [_mounted.get_rid(), player.get_rid()]))
		if floor_hit.is_empty() or floor_hit.normal.y < 0.83:
			continue
		var at: Vector3 = floor_hit.position + Vector3.UP * 0.04
		query.transform.origin = at + capsule.position
		if not space.intersect_shape(query, 1).is_empty():
			continue
		var shoulder := Vector3.UP * 0.9
		var ray := PhysicsRayQueryParameters3D.create(_mounted.global_position + shoulder, at + shoulder, 1 | 4 | 8,
				[_mounted.get_rid(), player.get_rid()])
		if space.intersect_ray(ray).is_empty():
			return at
	return Vector3.INF
