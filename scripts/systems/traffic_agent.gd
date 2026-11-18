extends AnimatableBody3D

enum Profile { AUTOMOBILE, CARRIAGE, BICYCLE }

# Width, overall length, cruising speed, acceleration, comfortable braking.
const PROFILES := {
	Profile.AUTOMOBILE: [1.80, 3.16, 5.3, 1.30, 2.8],
	Profile.CARRIAGE: [1.82, 5.78, 2.60, 0.85, 2.1],
	Profile.BICYCLE: [0.72, 1.80, 5.0, 1.25, 2.9],
}
const SENSOR_HEIGHT := 0.85
const STOP_MARGIN := 0.36

var lane: Path3D
var looping := false
var progress := 0.0
var speed := 0.0
var at_terminal := false
var blocked := false

var _profile: Array
var _height := SENSOR_HEIGHT
var _shape := BoxShape3D.new()
var _sensing := PhysicsShapeQueryParameters3D.new()


func setup(path: Path3D, profile: Profile, offset := 0.0, loop := false) -> void:
	lane = path
	looping = loop
	_profile = PROFILES[profile]
	progress = clampf(offset, 0.0, lane.curve.get_baked_length())
	# The body can be seen by the player and by other traffic sensors.
	collision_layer = 1 | 8
	collision_mask = 0
	sync_to_physics = false
	match profile:
		Profile.AUTOMOBILE:
			_height = 1.50
		Profile.CARRIAGE:
			_height = 2.55
		Profile.BICYCLE:
			_height = SENSOR_HEIGHT
	_shape.size = Vector3(_profile[0], _height, _profile[1])
	var shape := CollisionShape3D.new()
	shape.name = "VehicleFootprint"
	shape.shape = _shape
	shape.position.y = _height * 0.5 + 0.10
	add_child(shape)
	_sensing.shape = _shape
	_sensing.collision_mask = 1 | 2 | 4 | 8
	_sensing.exclude = [get_rid()]
	_sensing.margin = 0.035
	_apply_pose()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(lane) or at_terminal:
		return
	var length := lane.curve.get_baked_length()
	var remaining := length if looping else length - progress
	var braking: float = _profile[4]
	var horizon := minf(remaining, maxf(1.2, speed * speed / (2.0 * braking) + 1.8))
	var available := _clear_distance(horizon)
	blocked = available + 0.01 < horizon
	var clearance := minf(remaining, maxf(0.0, available - STOP_MARGIN)) if blocked else remaining
	var target := minf(_profile[2], sqrt(2.0 * braking * clearance))
	var bend_start := _pose_at(progress).basis.z
	var bend_end := _pose_at(progress + minf(3.0, remaining)).basis.z
	target *= lerpf(0.45, 1.0, clampf(bend_start.dot(bend_end), 0.0, 1.0))
	var rate: float = braking if speed > target else _profile[3]
	speed = move_toward(speed, target, rate * delta)
	var travel := minf(speed * delta, clearance)
	progress += travel
	if looping:
		progress = fposmod(progress, length)
	if travel > 0.0:
		_apply_pose()
	elif blocked:
		speed = 0.0
	if not looping and remaining - travel <= 0.005:
		at_terminal = true
		speed = 0.0


func _clear_distance(horizon: float) -> float:
	var space := get_world_3d().direct_space_state
	var checked := 0.0
	while checked < horizon:
		var next := minf(checked + 0.9, horizon)
		var start := _pose_at(progress + checked)
		var finish := _pose_at(progress + next)
		_sensing.transform = start.translated(Vector3.UP * (_height * 0.5 + 0.10))
		_sensing.motion = Vector3.ZERO
		# cast_motion ignores shapes already intersecting the query.
		if not space.intersect_shape(_sensing, 1).is_empty():
			return checked
		_sensing.motion = finish.origin - start.origin
		var fractions := space.cast_motion(_sensing)
		if fractions[0] < 1.0:
			return lerpf(checked, next, fractions[0])
		checked = next
	return horizon


func _pose_at(distance: float) -> Transform3D:
	var length := lane.curve.get_baked_length()
	var point := _sample(distance, length)
	var before := _sample(distance - 0.35, length)
	var after := _sample(distance + 0.35, length)
	return lane.global_transform * Transform3D(Basis.looking_at((after - before).normalized(), Vector3.UP), point)


func _sample(distance: float, length: float) -> Vector3:
	return lane.curve.sample_baked(fposmod(distance, length) if looping else clampf(distance, 0.0, length), true)


func _apply_pose() -> void:
	var pose := _pose_at(progress)
	# setup is also usable before add_child when the parent is identity.
	if is_inside_tree():
		global_transform = pose
	else:
		transform = pose
