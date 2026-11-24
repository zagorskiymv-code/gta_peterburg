extends Node3D

enum Pose { IDLE, WALK, RUN, JUMP, FALL, LAND }

const Detail = preload("res://scripts/player/character_detail.gd")

const HIP_HEIGHT := 0.934
const THIGH := 0.425
const SHIN := 0.420
const ANKLE_HEIGHT := 0.108
const TURN_SPEED := 12.0

@onready var body: Node3D = $Body
@onready var head: Node3D = $Body/UpperBody/Head
@onready var arms: Array[Node3D] = [$Body/UpperBody/LeftArmPivot, $Body/UpperBody/RightArmPivot]
@onready var elbows: Array[Node3D] = [$Body/UpperBody/LeftArmPivot/Elbow, $Body/UpperBody/RightArmPivot/Elbow]
@onready var legs: Array[Node3D] = [$Body/LeftLegPivot, $Body/RightLegPivot]
@onready var knees: Array[Node3D] = [$Body/LeftLegPivot/Knee, $Body/RightLegPivot/Knee]
@onready var ankles: Array[Node3D] = [$Body/LeftLegPivot/Knee/Ankle, $Body/RightLegPivot/Knee/Ankle]

@onready var upper_body: Node3D = $Body/UpperBody

@export_range(8.0, 12.0, 0.5) var run_lean_degrees := 10.0
@export_range(0.06, 0.15, 0.005) var run_foot_lift := 0.115

var pose := Pose.IDLE
var phase := 0.0
var breath := 0.0
var movement_blend := 0.0
var run_blend := 0.0
var lean := 0.0
var previous_speed := 0.0
var airborne_blend := 0.0
var falling_blend := 0.0
var landing_time := 0.0
var air_time := 0.0
var feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _idle_time := 0.0
var _blink_time := 0.0
var _blink_period := 3.6
var _portrait: MeshInstance3D
var _blink_frame := 0
var _sleeve_rigs: Array[Skeleton3D] = []


func _ready() -> void:
	Detail.apply(self)
	for arm in arms:
		_sleeve_rigs.append(arm.get_node("SleeveRig"))
	_portrait = head.get_node("PortraitDetails")
	_blink_period = 3.15 + float(abs(hash(str(get_path()))) % 125) * 0.01
	_blink_time = fposmod(float(get_instance_id()) * .113, _blink_period)


func configure_portrait(profile: int, skin: Color, hair: Color) -> void:
	Detail.configure_face(head, profile, skin, hair)
	_blink_frame = 0


func animate(delta: float, displacement: Vector3, direction: Vector3, grounded: bool,
		floor_normal: Vector3, vertical_speed: float, sprinting: bool, stride_scale := 1.0) -> void:
	_advance_blink(delta)
	_idle_time = fposmod(_idle_time + delta, 12.0)
	if not direction.is_zero_approx():
		var target := Vector3(direction.x, 0, direction.z)
		if get_parent() is Node3D:
			target = (get_parent() as Node3D).global_basis.inverse() * target
		rotation.y = rotate_toward(rotation.y, atan2(-target.x, -target.z), TURN_SPEED * delta)

	var distance := Vector2(displacement.x, displacement.z).length()
	var speed := distance / delta
	var blend := 1.0 - exp(-delta * 14.0)
	var active := grounded and speed > 0.12
	var running := active and sprinting and speed > 4.9
	movement_blend = lerpf(movement_blend, clampf(speed / 1.6, 0, 1) if active else 0.0, blend)
	run_blend = lerpf(run_blend, 1.0 if running else 0.0, blend)
	var accelerating := grounded and speed > 0.7 and speed - previous_speed > delta * 7.0
	var desired_lean := maxf(movement_blend * 0.18 + run_blend * 0.82, 0.55 if accelerating else 0.0)
	lean = lerpf(lean, desired_lean if active else 0.0, 1.0 - exp(-delta * (11.0 if active else 16.0)))
	previous_speed = speed
	airborne_blend = lerpf(airborne_blend, 0.0 if grounded else 1.0, blend)
	falling_blend = lerpf(falling_blend, 1.0 if not grounded and vertical_speed < -0.25 else 0.0, blend)
	landing_time = maxf(landing_time - delta, 0)
	if grounded:
		if air_time > 0.12:
			landing_time = 0.19
		air_time = 0.0
	else:
		air_time += delta
		landing_time = 0.0

	if not grounded:
		pose = Pose.FALL if vertical_speed < -0.25 else Pose.JUMP
	elif landing_time > 0.0:
		pose = Pose.LAND
	elif active:
		pose = Pose.RUN if running else Pose.WALK
	else:
		pose = Pose.IDLE

	var stride := lerpf(1.70, 2.48, run_blend) * stride_scale
	if active:
		phase = fposmod(phase + distance / stride, 1.0)
	breath = fposmod(breath + delta * TAU * 0.48, TAU)
	var landing := sin(PI * landing_time / 0.19) * (1.0 - movement_blend * 0.45)
	var local_floor := global_basis.inverse() * floor_normal if grounded else Vector3.UP
	_apply_pose(delta, stride, local_floor, landing, blend, stride_scale)


func _apply_pose(delta: float, stride: float, normal: Vector3, landing: float, blend: float, stride_scale: float) -> void:
	var stance := lerpf(0.50, 0.36, run_blend)
	var idle := (1.0 - movement_blend) * (1.0 - airborne_blend)
	var shift := sin(_idle_time * TAU / 6.0) * idle
	for index in 2:
		var cycle := fposmod(phase + index * 0.5, 1.0)
		var foot := _step(cycle, stance, stride, stride_scale) * movement_blend
		var side := -1.0 if index == 0 else 1.0
		var air_z := lerpf(-0.16 if index == 0 else 0.13, -0.06 if index == 0 else 0.11, falling_blend)
		var air_y := lerpf(0.19 if index == 0 else 0.08, 0.09 if index == 0 else 0.06, falling_blend)
		foot.x += side * .027 * idle
		foot = foot.lerp(Vector2(air_z, air_y), airborne_blend)
		var grade := -(normal.z * foot.x + normal.x * side * 0.108) / maxf(normal.y, 0.55)
		feet[index] = Vector2(foot.x, foot.y + ANKLE_HEIGHT + clampf(grade, -0.23, 0.23))

		var swing := cos(cycle * TAU)
		var arm_angle := -swing * lerpf(0.29, 0.51, run_blend) * movement_blend
		arm_angle = lerpf(arm_angle, lerpf(0.36, 0.65, falling_blend) * (1 if index == 0 else 0.83), airborne_blend)
		arms[index].rotation.x = lerpf(arms[index].rotation.x, arm_angle + landing * 0.20 + side * shift * .028, blend)
		arms[index].rotation.z = side * (0.065 + .017 * idle + airborne_blend * (0.18 + falling_blend * 0.26))
		_bend_elbow(index, lerpf(elbows[index].rotation.x, 0.12 + run_blend * 0.76 + airborne_blend * 0.22, blend))

	var wave := sin(phase * TAU)
	var hip := HIP_HEIGHT + sin(breath) * 0.003 - movement_blend * (0.020 + absf(wave) * 0.012)
	hip += cos(phase * TAU * 2.0) * run_blend * 0.014
	hip -= landing * 0.085 + airborne_blend * 0.065
	var reach := THIGH + SHIN - 0.008
	for foot in feet:
		hip = minf(hip, foot.y + sqrt(maxf(0, reach * reach - foot.x * foot.x)))
	body.position.x = shift * .012
	# Offset the hip pivots so the planted feet stay in place.
	for leg in legs:
		var side := -1.0 if leg == legs[0] else 1.0
		leg.position.x = side * .108 - body.position.x
	body.position.y = minf(lerpf(body.position.y, hip, 1.0 - exp(-delta * 23.0)), hip)
	# Lean the coat and head independently so the hip joints and feet stay level.
	upper_body.rotation.x = -deg_to_rad(run_lean_degrees) * lean + 0.08 * falling_blend - 0.10 * landing
	upper_body.rotation.y = wave * movement_blend * lerpf(0.034, 0.075, run_blend)
	upper_body.rotation.z = wave * movement_blend * 0.027 + sin(breath) * 0.009 - shift * .026
	head.rotation.x = lerpf(head.rotation.x, idle * (sin(_idle_time * .81) * .037 - .012), blend)
	head.rotation.y = (sin(breath) * .016 + sin(_idle_time * .58) * .065) * idle
	var pitch := atan2(normal.z, maxf(normal.y, 0.55))
	for index in 2:
		var cycle := fposmod(phase + index * 0.5, 1.0)
		var swing_progress := clampf((cycle - stance) / (1.0 - stance), 0.0, 1.0)
		var ankle_motion := sin(TAU * swing_progress) * run_blend * 0.23 * (1.0 - airborne_blend)
		_pose_leg(index, feet[index], pitch + ankle_motion)


func _bend_elbow(index: int, angle: float) -> void:
	elbows[index].rotation.x = angle
	_sleeve_rigs[index].set_bone_pose_rotation(1, Quaternion(Vector3.RIGHT, angle))


func _advance_blink(delta: float) -> void:
	_blink_time = fposmod(_blink_time + delta, _blink_period)
	_set_blink(_blink_time)


func _set_blink(time: float) -> void:
	var elapsed := time - (_blink_period - .17)
	var closure := smoothstep(0.0, .065, elapsed) * (1.0 - smoothstep(.075, .17, elapsed))
	var frame := roundi(closure * 4.0)
	if _blink_frame == frame:
		return
	_blink_frame = frame
	var frames: Array = _portrait.get_meta(&"eye_frames")
	_portrait.mesh = frames[frame]


func _step(cycle: float, stance: float, stride: float, stride_scale: float) -> Vector2:
	var travel := stance * stride
	if cycle < stance:
		return Vector2(-travel * 0.5 + cycle * stride, 0.0)
	var swing := (cycle - stance) / (1.0 - stance)
	return Vector2(lerpf(travel * 0.5, -travel * 0.5, smoothstep(0.0, 1.0, swing)),
			sin(PI * pow(swing, lerpf(1.0, 0.68, run_blend))) * lerpf(0.105, run_foot_lift, run_blend) * stride_scale * stride_scale)


func _pose_leg(index: int, foot: Vector2, pitch: float) -> void:
	var vertical := foot.y - body.position.y
	var length := clampf(Vector2(foot.x, vertical).length(), 0.12, THIGH + SHIN - 0.002)
	var hip_angle := acos(clampf((THIGH * THIGH + length * length - SHIN * SHIN) / (2 * THIGH * length), -1, 1))
	var knee_angle := acos(clampf((length * length - THIGH * THIGH - SHIN * SHIN) / (2 * THIGH * SHIN), -1, 1))
	legs[index].rotation.x = atan2(-foot.x, -vertical) + hip_angle
	knees[index].rotation.x = -knee_angle
	ankles[index].rotation.x = pitch - legs[index].rotation.x - knees[index].rotation.x


func _reset_idle_offsets() -> void:
	body.position.x = 0.0
	upper_body.scale = Vector3.ONE
	legs[0].position.x = -.108
	legs[1].position.x = .108
	_set_blink(0.0)


func pose_seated(steering: float = 0.0) -> void:
	_reset_idle_offsets()
	rotation = Vector3.ZERO
	body.position.y = 0.025
	upper_body.rotation = Vector3(0.07, steering * 0.08, 0)
	head.rotation = Vector3.ZERO
	for index in 2:
		legs[index].rotation.x = 1.67
		knees[index].rotation.x = -0.73
		ankles[index].rotation.x = -0.94
		arms[index].rotation.x = 0.91 if index == 0 else 0.66
		arms[index].rotation.z = 0.05 + steering * 0.68 if index == 0 else -0.12
		_bend_elbow(index, 0.53 if index == 0 else 0.70)


func leave_seat() -> void:
	body.position.y = HIP_HEIGHT
	upper_body.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	for index in 2:
		legs[index].position.x = -0.108 if index == 0 else 0.108
		legs[index].rotation = Vector3.ZERO
		knees[index].rotation = Vector3.ZERO
		ankles[index].rotation = Vector3.ZERO
		arms[index].rotation = Vector3.ZERO
		_bend_elbow(index, 0.0)


func pose_mounted() -> void:
	pose_seated()
	for index in 2:
		legs[index].rotation.x = 0.86
		legs[index].position.x = -0.20 if index == 0 else 0.20
		legs[index].rotation.z = -0.52 if index == 0 else 0.52
		knees[index].rotation.x = -1.10
		ankles[index].rotation.x = 0.24
		arms[index].rotation.x = 0.68
		_bend_elbow(index, 0.60)



func pose_cycling(angle: float) -> void:
	pose_seated()
	upper_body.rotation.x = -0.21
	for index in 2:
		var phase_angle := angle + index * PI
		legs[index].rotation.x = 0.66 + cos(phase_angle) * 0.29
		knees[index].rotation.x = -0.58 + sin(phase_angle) * 0.41
		ankles[index].rotation.x = -legs[index].rotation.x - knees[index].rotation.x
		arms[index].rotation.x = 0.72
		_bend_elbow(index, 0.27)


func pose_opening(rise: float, look: float) -> void:
	_reset_idle_offsets()
	body.position.y = lerpf(0.17, HIP_HEIGHT, rise)
	upper_body.rotation = Vector3(lerpf(-0.22, 0.0, rise), look * 0.16, 0.0)
	head.rotation = Vector3(lerpf(0.17, 0.0, rise), look, 0)
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		arms[index].rotation = Vector3(0.64 * (1.0 - rise), 0.0, side * 0.10)
		_bend_elbow(index, 0.63 * (1.0 - rise))
		_pose_leg(index, Vector2((-0.63 + index * 0.13) * (1.0 - rise), ANKLE_HEIGHT), 0.0)


func pose_conversation(time: float, duration: float, speaking: bool) -> void:
	_set_blink(fposmod(time + _blink_time, _blink_period))
	var blend := smoothstep(0.0, 0.36, minf(time, duration - time))
	var gesture := (0.55 + 0.22 * sin(time * 5.0)) * blend if speaking else 0.0
	head.rotation.x = sin(time * (4.2 if speaking else 2.2)) * blend * 0.085
	upper_body.rotation.y = sin(time * 2.7) * gesture * 0.12
	arms[1].rotation.x = -gesture * 0.58
	arms[1].rotation.z = -gesture * 0.31
	_bend_elbow(1, gesture * 0.86)


func pose_inspect(time: float, duration: float) -> void:
	var lean_in := smoothstep(0.0, 0.55, time) * (1.0 - smoothstep(duration - 0.55, duration, time))
	upper_body.rotation.x = -0.19 * lean_in
	head.rotation.x = (0.12 + sin(time * 5.0) * 0.12) * lean_in
	arms[1].rotation.x = -0.56 * lean_in
	_bend_elbow(1, 0.31 * lean_in)
