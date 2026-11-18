extends CharacterBody3D

const Citizen = preload("res://scripts/npc/citizen_npc.gd")
const Model = preload("res://scripts/vehicles/victoria_model.gd")
const TOP_SPEED := 25.0 / 3.6
const REVERSE_SPEED := 1.8
const MAX_STEERING := 0.53
const MAX_STEP_HEIGHT := 0.34
const STEP_CLEARANCE := 0.008
const WHEELBASE := Model.REAR_AXLE - Model.FRONT_AXLE

signal driver_died(reason: StringName)

@export var display_name := "Benz Victoria"
@export var paint := Model.Paint.BURGUNDY

@onready var model: Model = $Model
@onready var footprint: CollisionShape3D = $CollisionShape3D

var has_driver := false
var drive_speed := 0.0
var road_speed_kmh := 0.0
var steering := 0.0
var _throttle := 0.0
var _turn := 0.0
var _brake := false
var _turn_probe := PhysicsShapeQueryParameters3D.new()
var _step_contact := KinematicCollision3D.new()


func _ready() -> void:
	model.set_paint(paint)
	_turn_probe.shape = footprint.shape
	_turn_probe.collision_mask = collision_mask
	_turn_probe.exclude = [get_rid()]


func set_driver_occupied(occupied: bool) -> void:
	has_driver = occupied
	# The existing water volumes monitor layer 2. Only a player-occupied car reports a death.
	set_deferred("collision_layer", 11 if occupied else 9)


func die(reason: StringName) -> void:
	if has_driver:
		driver_died.emit(reason)


func set_drive_input(throttle: float, turn: float, braking: bool) -> void:
	_throttle = clampf(throttle, -1.0, 1.0)
	_turn = clampf(turn, -1.0, 1.0)
	_brake = braking


func set_paint(choice: Model.Paint) -> void:
	paint = choice
	model.set_paint(paint)


func reset_drive(pose: Transform3D) -> void:
	global_transform = pose
	reset_physics_interpolation()
	road_speed_kmh = 0.0
	drive_speed = 0.0
	steering = 0.0
	velocity = Vector3.ZERO
	set_drive_input(0.0, 0.0, false)
	model.animate_running_gear(0.0, 0.0)


func _physics_process(delta: float) -> void:
	var start := global_position
	var grounded := is_on_floor()
	var old_speed := drive_speed
	var desired_speed := (_throttle * TOP_SPEED if _throttle >= 0.0 else _throttle * REVERSE_SPEED)
	var opposite := desired_speed * drive_speed < 0.0
	var rate := 1.34
	if _brake or opposite:
		desired_speed = 0.0
		rate = 3.1
	elif is_zero_approx(_throttle):
		rate = 0.65
	if grounded:
		drive_speed = move_toward(drive_speed, desired_speed, rate * delta)
	var steering_limit := MAX_STEERING * lerpf(1.0, 0.68, absf(drive_speed) / TOP_SPEED)
	steering = move_toward(steering, _turn * steering_limit, 1.85 * delta)
	var roll_speed := (old_speed + drive_speed) * 0.5
	if grounded and absf(roll_speed) > 0.015:
		_turn_on_road(roll_speed * tan(steering) / WHEELBASE * delta)

	var forward := -global_basis.z.normalized()
	if grounded:
		var horizontal := forward * roll_speed
		if _try_step(horizontal * delta):
			# Refresh floor state without applying horizontal displacement twice.
			velocity = Vector3.DOWN * 1.0
		else:
			velocity = horizontal
	else:
		velocity += get_gravity() * delta
	move_and_slide()
	if has_driver and absf(roll_speed) >= 0.35:
		for index in get_slide_collision_count():
			var impact := get_slide_collision(index)
			var citizen := impact.get_collider() as Citizen
			var direction := forward * signf(roll_speed)
			if citizen and direction.dot(impact.get_normal()) < -0.30:
				citizen.fall_after_vehicle_impact(direction)
	var displacement := global_position - start
	road_speed_kmh = displacement.slide(Vector3.UP).length() * 3.6 / delta
	var distance := displacement.dot(forward)
	if grounded and absf(roll_speed) > 0.1 and absf(distance) < absf(roll_speed) * delta * 0.38:
		drive_speed = 0.0
	model.animate_running_gear(distance, steering)


func _try_step(motion: Vector3) -> bool:
	if motion.length_squared() < 0.000001 or not test_move(global_transform, motion, _step_contact):
		return false
	var floor_limit := cos(floor_max_angle)
	if _step_contact.get_normal().dot(up_direction) >= floor_limit:
		return false
	# Pedestrians and vehicles are yielded to, even if their collider is small.
	if not _step_contact.get_collider() is StaticBody3D:
		return false

	return _step_to(global_transform.translated(motion))


func _step_to(destination: Transform3D) -> bool:
	var floor_limit := cos(floor_max_angle)
	var rise := up_direction * (MAX_STEP_HEIGHT + STEP_CLEARANCE)
	if test_move(global_transform, rise):
		return false
	var raised := global_transform.translated(rise)
	var landing := destination.translated(rise)
	if test_move(raised, landing.origin - raised.origin):
		return false
	# The raised pose must also fit when the front of the car is turning onto the curb.
	_turn_probe.transform = landing * footprint.transform
	if not get_world_3d().direct_space_state.intersect_shape(_turn_probe, 1).is_empty():
		return false
	if not test_move(landing, -rise, _step_contact) or _step_contact.get_normal().dot(up_direction) < floor_limit:
		return false
	var step_up := (rise + _step_contact.get_travel()).dot(up_direction)
	if step_up < 0.002 or step_up > MAX_STEP_HEIGHT:
		return false
	global_transform = landing.translated(_step_contact.get_travel() + up_direction * STEP_CLEARANCE)
	return true


func _turn_on_road(angle: float) -> void:
	var proposed := global_transform
	proposed.basis = Basis(Vector3.UP, angle) * proposed.basis
	# Rotate about the rear axle, where the bicycle approximation has zero lateral slip.
	var rear := Vector3(0, 0, Model.REAR_AXLE)
	proposed.origin += global_basis * rear - proposed.basis * rear
	_turn_probe.transform = proposed * footprint.transform
	_turn_probe.transform.origin += Vector3.UP * 0.018
	var obstacles := get_world_3d().direct_space_state.intersect_shape(_turn_probe, 1)
	if obstacles.is_empty():
		global_transform = proposed
	elif obstacles[0].collider is StaticBody3D:
		_step_to(proposed)
