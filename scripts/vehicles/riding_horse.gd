extends CharacterBody3D

signal rider_lost(reason: StringName)

const Citizen = preload("res://scripts/npc/citizen_npc.gd")
const Horse = preload("res://scripts/vehicles/horse_visual.gd")

var horse: Horse
var bicycle := false
var delivery_mount := false
var mount_allowed := true
var held_for_handover := false
var bike_model: Node3D
var _collider: CollisionShape3D
var _step_hit := KinematicCollision3D.new()
const STEP_HEIGHT := 0.34
const HORSE_WALK_SPEED := 4.6
const HORSE_GALLOP_SPEED := 14.8
const HORSE_REVERSE_SPEED := 2.6
const DELIVERY_WALK_SPEED := 3.2
const DELIVERY_TROT_SPEED := 6.2
var ridden := false
var _speed := 0.0
var _delay := 1.4
var _walk_remaining := 2.8
var _turn_remaining := 0.0


func _ready() -> void:
	add_to_group(&"riding_horses")
	collision_layer = 1
	collision_mask = 15
	floor_snap_length = 0.2
	_collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.52, 1.65, 1.88) if bicycle else Vector3(0.78, 1.81, 2.52)
	_collider.shape = shape
	_collider.position = Vector3(0, shape.size.y * 0.5, -0.12)
	add_child(_collider)


func set_ridden(value: bool) -> void:
	ridden = value
	_turn_remaining = 0.0
	collision_layer = 3 if value else 1
	_speed = 0.0
	_delay = 1.4


func die(reason: StringName) -> void:
	if ridden:
		rider_lost.emit(reason)


func _physics_process(delta: float) -> void:
	var start := global_position
	var grounded := is_on_floor()
	var jumping := ridden and not bicycle and grounded and not delivery_mount and Input.is_action_just_pressed(&"jump")
	var target := 0.0
	if ridden and not held_for_handover:
		var throttle := Input.get_axis(&"move_backward", &"move_forward")
		var sprinting := Input.is_action_pressed(&"sprint")
		if bicycle:
			target = maxf(throttle * (8.1 if sprinting else 5.2), -1.7)
		elif delivery_mount:
			var forward_speed := DELIVERY_TROT_SPEED if sprinting else DELIVERY_WALK_SPEED
			target = throttle * (HORSE_REVERSE_SPEED if throttle < 0.0 else forward_speed)
		else:
			var forward_speed := HORSE_GALLOP_SPEED if sprinting else HORSE_WALK_SPEED
			target = throttle * (HORSE_REVERSE_SPEED if throttle < 0.0 else forward_speed)
		if bicycle and Input.is_action_pressed(&"jump"):
			target = 0.0
		_turn(Input.get_axis(&"move_right", &"move_left") * delta * 1.7)
	elif bicycle or delivery_mount:
		pass
	elif _delay > 0.0:
		_delay -= delta
		var step := minf(_turn_remaining, 2.0 * delta)
		if _turn(step):
			_turn_remaining -= step
		if _delay <= 0.0:
			_walk_remaining = 2.8
	else:
		_walk_remaining -= delta
		var motion := -global_basis.z * 0.65
		var ahead := global_position - global_basis.z * 1.62
		var ray := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.23,
				ahead - Vector3.UP * 0.23, 1, [get_rid()])
		var support := get_world_3d().direct_space_state.intersect_ray(ray)
		if _walk_remaining <= 0.0 or support.is_empty() or support.normal.y < 0.76 or test_move(global_transform, motion):
			_delay = 1.5
			_turn_remaining = PI * 0.68
		else:
			target = 1.15
	var acceleration := 3.8
	if ridden and not bicycle:
		acceleration = 9.5 if _speed * target < 0.0 or is_zero_approx(target) else 6.4
	_speed = move_toward(_speed, target, delta * acceleration)
	if delivery_mount and ridden and not is_zero_approx(_speed) and not _delivery_support(_speed * delta):
		_speed = 0.0
	velocity.x = -global_basis.z.x * _speed
	velocity.z = -global_basis.z.z * _speed
	if jumping:
		velocity.y = 5.0
	elif not grounded:
		velocity += get_gravity() * delta
	elif _step_over(velocity.slide(Vector3.UP) * delta):
		velocity = Vector3.DOWN
	var impact_motion := velocity.slide(Vector3.UP)
	move_and_slide()
	if ridden and not bicycle and impact_motion.length_squared() > 0.16:
		var direction := impact_motion.normalized()
		for index in get_slide_collision_count():
			var impact := get_slide_collision(index)
			var pedestrian := impact.get_collider() as Citizen
			if pedestrian and direction.dot(impact.get_normal()) < -0.3:
				pedestrian.launch_from_horse(direction, self)
	var travel := (global_position - start).slide(Vector3.UP).length()
	if is_instance_valid(horse):
		horse.animate_gait(delta, travel * signf(_speed),
				ridden and not delivery_mount and _speed > HORSE_WALK_SPEED + 0.2,
				not is_on_floor(), velocity.y, delivery_mount and ridden and _speed > DELIVERY_WALK_SPEED + 0.2)
	if bicycle:
		bike_model.roll(travel * signf(_speed))


func _delivery_support(travel: float) -> bool:
	var space := get_world_3d().direct_space_state
	# Keep the leading hooves on supported ground, including when backing up.
	var leading := -1.49 if travel > 0.0 else 1.26
	for side in [-0.26, 0.26]:
		var at := to_global(Vector3(side, 0, leading - travel))
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.65, at - Vector3.UP * 0.44,
				1, [get_rid()])
		var ground := space.intersect_ray(query)
		if ground.is_empty() or ground.normal.y < 0.67:
			return false
	return true


func _step_over(motion: Vector3) -> bool:
	if motion.length_squared() < 0.000001 or not test_move(global_transform, motion, _step_hit):
		return false
	if _step_hit.get_normal().y >= cos(floor_max_angle) or not _step_hit.get_collider() is StaticBody3D:
		return false
	var rise := Vector3.UP * (STEP_HEIGHT + 0.008)
	if test_move(global_transform, rise):
		return false
	var raised := global_transform.translated(rise)
	if test_move(raised, motion):
		return false
	var landing := raised.translated(motion)
	if not test_move(landing, -rise, _step_hit) or _step_hit.get_normal().y < cos(floor_max_angle):
		return false
	var lift := rise.y + _step_hit.get_travel().y
	if lift <= 0.002 or lift > STEP_HEIGHT:
		return false
	global_transform = landing.translated(_step_hit.get_travel() + Vector3.UP * 0.008)
	return true


func _turn(angle: float) -> bool:
	if absf(angle) < 0.001:
		return true
	var rotated := Transform3D(Basis(Vector3.UP, rotation.y + angle), global_position)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _collider.shape
	query.transform = (rotated * _collider.transform).translated(Vector3.UP * 0.018)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	if space.intersect_shape(query, 1).is_empty():
		global_transform = rotated
		return true
	if not delivery_mount or not is_on_floor():
		return false
	# A low paving edge may touch the long footprint while turning in place.
	query.transform.origin.y += STEP_HEIGHT
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.motion = Vector3.DOWN * STEP_HEIGHT
	var clear := space.cast_motion(query)[0]
	var lift := STEP_HEIGHT * (1.0 - clear)
	if lift <= 0.002 or lift > STEP_HEIGHT - 0.018:
		return false
	global_transform = rotated.translated(Vector3.UP * lift)
	return true
