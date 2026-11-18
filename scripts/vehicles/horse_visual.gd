extends Node3D

const G = preload("res://scripts/world/district_geometry.gd")
const COATS := ["#774832", "#a1502b", "#2e2826", "#b4b4aa", "#c39453"]
const MANES := ["#33241f", "#6a3325", "#21201e", "#726c64", "#e0c494"]
const UPPER := 0.655
const LOWER := 0.665
const STRIDE := 1.62

var coat_index := 0
var harnessed := false
var head: Node3D
var _tail: Node3D
var _trunk: Node3D
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _hooves: Array[Node3D] = []
var _phase := 0.0
var _idle := 0.0
var _gait := 0.0
var _canter := 0.0
var _trot := 0.0
var _coat: StandardMaterial3D
var _mane: StandardMaterial3D
var _dark := G.solid_material(Color("#302821"))
var _mark := G.solid_material(Color("#ded1bc"))
var _brass := G.solid_material(Color("#b48855"))
var _oval := SphereMesh.new()
var _link := CylinderMesh.new()


func _ready() -> void:
	_coat = G.solid_material(Color(COATS[coat_index % COATS.size()]))
	_mane = G.solid_material(Color(MANES[coat_index % MANES.size()]))
	_oval.radius = 0.5
	_oval.height = 1.0
	_oval.radial_segments = 10
	_oval.rings = 4
	_link.top_radius = 0.39
	_link.bottom_radius = 0.5
	_link.radial_segments = 7
	_link.height = 1.0
	_trunk = G.group(self, "Trunk")
	_ellipsoid(_trunk, "Barrel", Vector3(0, 1.28, 0.05), Vector3(0.68, 0.71, 1.73), _coat)
	_ellipsoid(_trunk, "Shoulders", Vector3(0, 1.34, -0.57), Vector3(0.61, 0.75, 0.72), _coat)
	_ellipsoid(_trunk, "Croup", Vector3(0, 1.38, 0.66), Vector3(0.67, 0.72, 0.67), _coat)
	_ellipsoid(_trunk, "Neck", Vector3(0, 1.62, -0.72), Vector3(0.40, 0.89, 0.49), _coat).rotation.x = 0.45
	# Small locks follow the crest and hang down the side of the neck.
	for index in 7:
		var t := float(index) / 6.0
		var lock := _ellipsoid(_trunk, "ManeLock", Vector3(0.12 + sin(t * PI) * 0.055,
				lerpf(1.51, 1.99, t), lerpf(-0.26, -0.83, t)),
				Vector3(0.09, 0.20 + sin(t * PI) * 0.08, 0.17), _mane)
		lock.rotation.x = 0.38
		lock.rotation.z = -0.22
	_ellipsoid(_trunk, "PollAndThroat", Vector3(0, 1.88, -0.91), Vector3(0.29, 0.43, 0.49), _coat).rotation.x = 0.38
	head = G.group(_trunk, "Head", Vector3(0, 1.96, -0.92))
	_ellipsoid(head, "HeadBase", Vector3(0, -0.055, -0.060), Vector3(0.30, 0.34, 0.34), _coat)
	_ellipsoid(head, "Face", Vector3(0, -0.085, -0.19), Vector3(0.31, 0.49, 0.37), _coat).rotation.x = 0.57
	_ellipsoid(head, "Jaw", Vector3(0, -0.22, -0.24), Vector3(0.27, 0.29, 0.32), _coat)
	_ellipsoid(head, "Muzzle", Vector3(0, -0.315, -0.35), Vector3(0.28, 0.18, 0.24), _mane)
	if coat_index in [1, 3]:
		_ellipsoid(head, "Blaze", Vector3(0, -0.11, -0.353), Vector3(0.074, 0.252, 0.036), _mark).rotation.x = 0.48
	for side in [-1.0, 1.0]:
		var ear := _ellipsoid(head, "Ear", Vector3(side * 0.095, 0.13, -0.025), Vector3(0.091, 0.215, 0.075), _coat)
		ear.rotation.z = -side * 0.17
		_ellipsoid(head, "Eye", Vector3(side * 0.143, 0.002, -0.19), Vector3(0.031, 0.038, 0.053), _dark)
		_ellipsoid(head, "Nostril", Vector3(side * 0.105, -0.296, -0.426), Vector3(0.043, 0.033, 0.025), _dark)
	_tail = G.group(_trunk, "TailBase", Vector3(0, 1.52, 0.91))
	_ellipsoid(_tail, "Tail", Vector3(0, -0.40, 0.21), Vector3(0.13, 0.90, 0.22), _mane).rotation.x = -0.36
	for fore in [true, false]:
		for side in [-1.0, 1.0]:
			_leg(Vector3(side * 0.222, 1.27, -0.57 if fore else 0.60), fore)
	if harnessed:
		G.box(_trunk, "Backstrap", Vector3(0, 1.643, -0.23), Vector3(0.71, 0.045, 0.15), _dark)
		for side in [-1.0, 1.0]:
			G.box(_trunk, "Girth", Vector3(side * 0.333, 1.28, -0.23), Vector3(0.050, 0.65, 0.13), _dark)
			G.box(head, "Cheekpiece", Vector3(side * 0.151, -0.148, -0.237), Vector3(0.035, 0.35, 0.043), _dark).rotation.x = 0.50
			_ellipsoid(head, "BitRing", Vector3(side * 0.133, -0.281, -0.335), Vector3(0.045, 0.073, 0.073), _brass)
		G.box(head, "Noseband", Vector3(0, -0.268, -0.398), Vector3(0.277, 0.057, 0.041), _dark)
	animate_gait(0.016, 0.0)


func animate_gait(delta: float, distance: float, fast := false, airborne := false, vertical_speed := 0.0, trotting := false) -> void:
	_idle += delta
	_canter = move_toward(_canter, 1.0 if fast else 0.0, delta * 2.8)
	_trot = move_toward(_trot, 1.0 if trotting else 0.0, delta * 3.4)
	_phase = fposmod(_phase + distance / lerpf(lerpf(STRIDE, 2.45, _trot), 4.55, _canter), 1.0)
	_gait = move_toward(_gait, 1.0 if absf(distance) > 0.003 else 0.0, delta * 3.5)
	_trunk.position.y = sin(_idle * 2.3) * 0.009 + cos(_phase * TAU * 2.0) * lerpf(lerpf(0.022, 0.041, _trot), 0.059, _canter) * _gait
	head.rotation.x = sin(_idle * 1.4) * 0.05 + sin(_phase * TAU) * 0.062 * _gait
	head.rotation.y = sin(_idle * 0.7) * 0.075 * (1.0 - _gait)
	_tail.rotation.y = sin(_idle * 2.4) * 0.18
	_trunk.rotation.x = clampf(vertical_speed * 0.055, -0.29, 0.30) if airborne else sin(_phase * TAU) * _canter * 0.10
	for i in _legs.size():
		_legs[i].position.y = lerpf(1.39, 1.25, _gait)
		if airborne:
			var reaching := smoothstep(-2.2, 2.2, -vertical_speed)
			_pose_leg(i, lerpf(0.28, -0.42, reaching) if i < 2 else -0.30, 0.54 if i < 2 else 0.37)
			continue
		# Hind contacts lead, followed by the front pair and a shared airborne phase.
		# At a trot, diagonal pairs land together.
		var walk_offset := lerpf([0.25, 0.75, 0.0, 0.5][i], [0.0, 0.5, 0.5, 0.0][i], _trot)
		var offset := lerpf(walk_offset, -[0.43, 0.55, 0.0, 0.13][i], _canter)
		var t := fposmod(_phase + offset, 1.0)
		var duty := lerpf(lerpf(0.62, 0.44, _trot), 0.28, _canter)
		var planted := t < duty
		var swing := clampf((t - duty) / (1.0 - duty), 0.0, 1.0)
		var reach := lerpf(0.43, 0.60, _canter)
		var z := lerpf(-reach, reach, t / duty) if planted else lerpf(reach, -reach, smoothstep(0.0, 1.0, swing))
		var lift := 0.0 if planted else sin(PI * swing) * lerpf(0.24, 0.50, _canter)
		_pose_leg(i, z * _gait, 0.088 + lift * _gait)


func _leg(hip: Vector3, fore: bool) -> void:
	var upper := G.group(self, "ForeLeg" if fore else "HindLeg", hip)
	var knee := G.group(upper, "Knee", Vector3.DOWN * UPPER)
	var hoof := G.group(knee, "HoofJoint", Vector3.DOWN * LOWER)
	_ellipsoid(upper, "Muscle", Vector3(0, -0.14, 0), Vector3(0.24 if fore else 0.32, 0.46, 0.27), _coat)
	G.mesh_part(upper, "UpperLeg", Vector3(0, -UPPER * 0.50, 0), _link, _coat).scale = Vector3(0.14, UPPER, 0.16)
	G.mesh_part(knee, "Cannon", Vector3(0, -LOWER * 0.49, 0), _link, _mane).scale = Vector3(0.098, LOWER, 0.108)
	G.box(hoof, "Hoof", Vector3(0, -0.044, -0.02), Vector3(0.127, 0.088, 0.165), _dark)
	_legs.append(upper)
	_knees.append(knee)
	_hooves.append(hoof)


func _pose_leg(index: int, foot_z: float, foot_y: float) -> void:
	var vertical := _legs[index].position.y - foot_y
	var reach := clampf(Vector2(vertical, foot_z).length(), 0.24, UPPER + LOWER - 0.008)
	var a := acos(clampf((UPPER * UPPER + reach * reach - LOWER * LOWER) / (2.0 * UPPER * reach), -1.0, 1.0))
	var bend := acos(clampf((reach * reach - UPPER * UPPER - LOWER * LOWER) / (2.0 * UPPER * LOWER), -1.0, 1.0))
	var sign_bend := 1.0 if index < 2 else -1.0
	_legs[index].rotation.x = atan2(-foot_z, vertical) + sign_bend * a
	_knees[index].rotation.x = -sign_bend * bend
	_hooves[index].rotation.x = -_legs[index].rotation.x - _knees[index].rotation.x


func _ellipsoid(parent: Node3D, title: String, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var part := G.mesh_part(parent, title, center, _oval, material)
	part.scale = size
	return part
