extends Node3D

const Manager = preload("res://scripts/systems/mission_manager.gd")
const Step = preload("res://scripts/systems/mission_step.gd")
const Wardrobe = preload("res://scripts/npc/citizen_wardrobe.gd")
const Character := preload("res://scenes/player/historical_character_visual.tscn")

const MISSION := "the_constable_never_sleeps"
const POST := Vector3(-29.4, 0.002, 11.5)
const RETRY := Vector3(-27.3, 0.055, 9.5)
const HIDE_TIME := 10.0
const CELL := 1.25
const SIGHT_RANGE := 36.0
const EYE := Vector3(0, 1.59, 0)

var _mission: Manager
var _player: CharacterBody3D
var _officer: CharacterBody3D
var _court: Marker3D
var _goal: Step
var _grid := AStarGrid2D.new()
var _grid_ready := false
var _route := PackedVector2Array()
var _route_index := 0
var _facing := Vector3.FORWARD
var _last_seen := Vector3.ZERO
var _replan := 0.0
var _grace := 0.0
var _capture := 0.0
var _hidden := 0.0
var _displayed := ""
var _started := false


func configure(mission: Manager, player: CharacterBody3D) -> void:
	_mission = mission
	_player = player
	_officer = CharacterBody3D.new()
	_officer.name = "Constable"
	_officer.collision_layer = 4
	_officer.collision_mask = 1 | 4 | 8
	_officer.floor_snap_length = 0.3
	_officer.add_to_group(&"story_contacts")
	var shape := CapsuleShape3D.new()
	shape.radius = 0.29
	shape.height = 1.76
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.88
	_officer.add_child(collider)
	var visual := Character.instantiate()
	_officer.add_child(visual)
	add_child(_officer)
	Wardrobe.new().dress(visual, Wardrobe.Outfit.PATROLMAN, Wardrobe.Hat.FORAGE_CAP,
			Color("#242d38"), Color("#63363a"), Color("#30323b"))
	_court = Marker3D.new()
	_court.name = "HidingCourt"
	_court.position = Vector3(24.6, 0.025, 113.8)
	add_child(_court)
	_park_officer()
	mission.objective_changed.connect(_objective_changed)


func _park_officer() -> void:
	_officer.hide()
	_officer.process_mode = Node.PROCESS_MODE_DISABLED


func _objective_changed(id: String, step: Step) -> void:
	if id != MISSION:
		return
	if not step:
		_goal = null
		_park_officer()
		return
	if step.kind == Step.Kind.INTERACT_NPC:
		var needs_checkpoint := _started or _player.global_position.distance_to(POST) > step.radius
		_goal = null
		_officer.global_position = POST
		_officer.velocity = Vector3.ZERO
		_officer.reset_physics_interpolation()
		_officer.process_mode = Node.PROCESS_MODE_INHERIT
		_officer.show()
		if needs_checkpoint:
			_player.respawn_at(RETRY)
		_facing = (_player.global_position - POST).slide(Vector3.UP).normalized()
		_officer.rotation.y = atan2(-_facing.x, -_facing.z)
		return
	_goal = step
	_started = true
	_last_seen = _player.global_position
	_route.clear()
	_route_index = 0
	_replan = 0.0
	_grace = 1.8
	_capture = 0.0
	_hidden = 0.0
	_displayed = ""


func _physics_process(delta: float) -> void:
	if not _goal or _player.is_dead:
		return
	var in_view := _can_see_player()
	var gap := _officer.global_position.distance_to(_player.global_position)
	if in_view:
		_last_seen = _player.global_position
	_grace = maxf(0.0, _grace - delta)
	if _grace <= 0.0 and in_view and gap < 1.28 and _player.is_physics_processing():
		_capture += delta
		if _capture >= 0.4:
			_mission.resolve_chase(_court, false)
			return
	else:
		_capture = 0.0
	var in_court := _player.global_position.distance_to(_court.global_position) <= _goal.radius
	_hidden = minf(HIDE_TIME, _hidden + delta) if in_court and not in_view else 0.0
	if _hidden >= HIDE_TIME:
		_mission.resolve_chase(_court, true)
		return
	var caption := _goal.objective
	if in_court:
		caption = ("Скройтесь из поля зрения городового" if in_view else
				"Оставайтесь незамеченным — %d с" % ceili(HIDE_TIME - _hidden))
	if caption != _displayed:
		_displayed = caption
		_mission.set_chase_prompt(_court, caption)
	_follow(delta, in_view)


func _can_see_player() -> bool:
	var eye := _officer.global_position + EYE
	var chest := _player.global_position + Vector3.UP * 1.25
	var offset := chest - eye
	var distance := offset.length()
	if distance > SIGHT_RANGE:
		return false
	var horizontal := offset.slide(Vector3.UP)
	if distance > 3.0 and _facing.dot(horizontal.normalized()) < 0.13:
		return false
	var space := get_world_3d().direct_space_state
	for height in [1.18, 1.58]:
		var ray := PhysicsRayQueryParameters3D.create(eye, _player.global_position + Vector3.UP * height, 1,
				[_player.get_rid(), _officer.get_rid()])
		if space.intersect_ray(ray).is_empty():
			return true
	return false


func _follow(delta: float, in_view: bool) -> void:
	var direction := Vector3.ZERO
	if in_view and _clear_walk_to(_last_seen):
		direction = (_last_seen - _officer.global_position).slide(Vector3.UP)
		_replan = 0.0
	else:
		_replan -= delta
		if _replan <= 0.0:
			_replan = 0.42
			_rebuild_route()
		while _route_index < _route.size():
			var next := _route[_route_index]
			direction = Vector3(next.x - _officer.global_position.x, 0, next.y - _officer.global_position.z)
			if direction.length() > 0.37:
				break
			_route_index += 1
	if direction.length() > 0.32:
		_facing = direction.normalized()
		_officer.rotation.y = lerp_angle(_officer.rotation.y, atan2(-_facing.x, -_facing.z), minf(1.0, delta * 12.0))
	else:
		direction = Vector3.ZERO
	var speed := 6.4 if in_view else 4.4
	var motion := direction.normalized() * speed
	_officer.velocity.x = motion.x
	_officer.velocity.z = motion.z
	_officer.velocity.y = 0.0 if _officer.is_on_floor() else _officer.velocity.y - 9.8 * delta
	_officer.move_and_slide()
	_officer.get_node("CharacterVisual").animate(delta, _officer.get_position_delta(), direction.normalized(),
			_officer.is_on_floor(), Vector3.UP, _officer.velocity.y, in_view)


func _clear_walk_to(at: Vector3) -> bool:
	var motion := (at - _officer.global_position).slide(Vector3.UP)
	if motion.length_squared() > 24.0 * 24.0:
		return false
	# A raised probe ignores paving seams. The moving body still resolves walls and traffic.
	if _officer.test_move(_officer.global_transform.translated(Vector3.UP * 0.16), motion, null, 0.025):
		return false
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	var samples := maxi(1, ceili(motion.length() / CELL))
	for index in range(1, samples + 1):
		var point := _officer.global_position + motion * (float(index) / samples)
		ray.from = point + Vector3.UP * 0.55
		ray.to = point - Vector3.UP * 0.45
		var ground := space.intersect_ray(ray)
		if ground.is_empty() or ground.get("normal", Vector3.ZERO).y < 0.64:
			return false
	return true


func _rebuild_route() -> void:
	if not _grid_ready:
		_build_grid()
	var from := _near_cell(_officer.global_position, true)
	var to := _near_cell(_last_seen, false)
	_route.clear()
	_route_index = 0
	if not _grid.region.has_point(from) or not _grid.region.has_point(to):
		return
	for id in _grid.get_id_path(from, to):
		_route.append(Vector2(id) * CELL)


func _near_cell(at: Vector3, require_clear_path: bool) -> Vector2i:
	var nearest := Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))
	var best := _grid.region.end
	var best_gap := INF
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var id := nearest + Vector2i(dx, dz)
			if not _grid.region.has_point(id) or _grid.is_point_solid(id):
				continue
			var point := Vector3(id.x * CELL, at.y, id.y * CELL)
			var gap := at.distance_squared_to(point)
			if gap < best_gap and (not require_clear_path or _clear_walk_to(point)):
				best = id
				best_gap = gap
	return best


func _build_grid() -> void:
	_grid.region = Rect2i(-58, -34, 99, 141)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.38
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = sphere
	fit.collision_mask = 1
	var floor_ray := PhysicsRayQueryParameters3D.new()
	floor_ray.collision_mask = 1
	for z in range(_grid.region.position.y, _grid.region.end.y):
		for x in range(_grid.region.position.x, _grid.region.end.x):
			var at := Vector3(x * CELL, 0, z * CELL)
			floor_ray.from = at + Vector3.UP * 0.54
			floor_ray.to = at - Vector3.UP * 0.44
			var floor_hit := space.intersect_ray(floor_ray)
			var blocked: bool = floor_hit.is_empty() or floor_hit.get("normal", Vector3.ZERO).y < 0.64
			if not blocked:
				fit.transform.origin = floor_hit.position + Vector3.UP * 0.81
				blocked = not space.intersect_shape(fit, 1).is_empty()
			_grid.set_point_solid(Vector2i(x, z), blocked)
	_grid_ready = true
