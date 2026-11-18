extends Node3D

const G = preload("res://scripts/world/district_geometry.gd")
const Horse = preload("res://scripts/vehicles/horse_visual.gd")
const Visual = preload("res://scripts/player/historical_character_visual.gd")
const Wardrobe = preload("res://scripts/npc/citizen_wardrobe.gd")
const DRIVER := preload("res://scenes/player/historical_character_visual.tscn")

var livery := 0
var _wood := G.solid_material(Color("#644533"))
var _iron := G.solid_material(Color("#2e2f31"))
var _leather := G.solid_material(Color("#482b28"))
var _brass := G.solid_material(Color("#bf975c"))
var _paint: StandardMaterial3D
var _horse: Horse
var _coachman: Visual
var _wheels: Array[Node3D] = []
var _coachman_hands: Array[Node3D] = []
var _wheel_radius: Array[float] = []
var _reins: Array[MeshInstance3D] = []
var _shafts: Array[MeshInstance3D] = []
var _previous := Vector3.ZERO
var _heading := 0.0
var _bend := 0.0


func _ready() -> void:
	var colors := ["#354541", "#694030", "#343f54", "#4b3035"]
	_paint = G.solid_material(Color(colors[livery % colors.size()]))
	var coach := G.group(self, "OpenCoach")
	G.box(coach, "SprungUnderframe", Vector3(0, 0.53, 1.20), Vector3(1.36, 0.15, 2.33), _iron)
	G.box(coach, "PassengerBox", Vector3(0, 0.79, 1.63), Vector3(1.40, 0.43, 1.31), _paint)
	G.box(coach, "PassengerFloor", Vector3(0, 0.75, 0.97), Vector3(1.31, 0.09, 1.24), _wood)
	G.box(coach, "PassengerBench", Vector3(0, 1.03, 1.84), Vector3(1.27, 0.19, 0.61), _leather)
	var back := G.box(coach, "PaddedRearBackrest", Vector3(0, 1.26, 2.10), Vector3(1.36, 0.47, 0.16), _leather)
	back.rotation.x = 0.15
	G.box(coach, "FoldedLeatherHood", Vector3(0, 1.39, 2.20), Vector3(1.37, 0.21, 0.24), _iron)
	for index in 4:
		G.box(coach, "HoodFold", Vector3(0, 1.33 + index * 0.041, 2.32),
				Vector3(1.39 - index * 0.045, 0.018, 0.035), _leather)
	G.box(coach, "CoachmanBox", Vector3(0, 0.93, 0.63), Vector3(1.16, 0.55, 0.50), _paint)
	G.box(coach, "CoachmanCushion", Vector3(0, 1.24, 0.64), Vector3(1.16, 0.15, 0.48), _leather)
	G.box(coach, "CoachmanBack", Vector3(0, 1.38, 0.89), Vector3(1.17, 0.32, 0.09), _paint)
	G.box(coach, "Footboard", Vector3(0, 0.99, 0.03), Vector3(1.20, 0.12, 0.59), _wood)
	G.box(coach, "LeatherDash", Vector3(0, 1.09, -0.21), Vector3(1.25, 0.29, 0.10), _iron)

	for side: float in [-1.0, 1.0]:
		G.box(coach, "Pinstripe", Vector3(side * 0.705, 0.92, 1.64), Vector3(0.019, 0.037, 1.26), _brass)
		G.box(coach, "PassengerStep", Vector3(side * 0.75, 0.49, 1.14), Vector3(0.23, 0.07, 0.43), _iron)
		G.box(coach, "BenchSide", Vector3(side * 0.655, 1.05, 1.76), Vector3(0.10, 0.25, 0.68), _paint)
		G.box(coach, "LampCase", Vector3(side * 0.60, 1.25, -0.12), Vector3(0.16, 0.23, 0.13), _brass)
		G.box(coach, "LampGlass", Vector3(side * 0.60, 1.26, -0.19), Vector3(0.115, 0.15, 0.024),
				G.solid_material(Color("#e2bb77")))
		_wheel(Vector3(side * 0.79, 0.40, 0.47), 0.40)
		_wheel(Vector3(side * 0.79, 0.55, 1.97), 0.55)
		_shafts.append(G.box(self, "WoodenShaft", Vector3.ZERO, Vector3.ONE, _wood))
		_reins.append(G.box(self, "LeatherRein", Vector3.ZERO, Vector3.ONE, _iron))

	_horse = Horse.new()
	_horse.name = "HarnessHorse"
	_horse.coat_index = livery
	_horse.harnessed = true
	_horse.position.z = -1.41
	add_child(_horse)
	_coachman = DRIVER.instantiate()
	_coachman.name = "Coachman"
	add_child(_coachman)
	_coachman.position = Vector3(-0.10, 1.34, 0.66)
	Wardrobe.new().dress(_coachman, Wardrobe.Outfit.WORKER, -1, Color("#4d514b"), Color.TRANSPARENT, Color.TRANSPARENT)
	_coachman.pose_seated()
	for elbow in _coachman.elbows:
		_coachman_hands.append(elbow.get_node("Hand"))
	_previous = global_position
	_heading = global_rotation.y
	_links()


func _physics_process(delta: float) -> void:
	var distance := _previous.distance_to(global_position)
	var yaw := angle_difference(_heading, global_rotation.y)
	var turn := clampf(yaw / maxf(distance, 0.05) * 0.42, -0.14, 0.14)
	_bend = lerpf(_bend, turn, 1.0 - exp(-delta * 6.0))
	_horse.rotation.y = _bend
	_horse.animate_gait(delta, distance)
	_coachman.pose_seated(_bend)
	for index in _wheels.size():
		_wheels[index].rotate_x(-distance / _wheel_radius[index])
	_links()
	_previous = global_position
	_heading = global_rotation.y


func _links() -> void:
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		_beam(_shafts[index], Vector3(side * 0.48, 0.62, 0.33),
				_horse.transform * Vector3(side * 0.34, 1.21, -0.38), 0.057)
		var bit := to_local(_horse.head.to_global(Vector3(side * 0.13, -0.281, -0.335)))
		_beam(_reins[index], to_local(_coachman_hands[index].global_position), bit, 0.013)


func _beam(part: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	part.transform = Transform3D(Basis.looking_at((b - a).normalized()).scaled_local(
			Vector3(width, width, a.distance_to(b))), (a + b) * 0.5)


func _wheel(at: Vector3, radius: float) -> void:
	var pivot := G.group(self, "Wheel", at)
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.069
	ring.outer_radius = radius
	ring.rings = 22
	ring.ring_segments = 5
	G.mesh_part(pivot, "IronTyre", Vector3.ZERO, ring, _iron).rotation.z = PI * 0.5
	var spokes: Array[Transform3D] = []
	var length := radius - 0.084
	for index in 12:
		var turn := Basis(Vector3.RIGHT, TAU * index / 12.0)
		spokes.append(Transform3D(turn.scaled_local(Vector3(0.028, length, 0.028)),
				turn * Vector3(0, length * 0.5 + 0.040, 0)))
	G.batch(pivot, "WoodSpokes", BoxMesh.new(), _wood, spokes)
	var hub := CylinderMesh.new()
	hub.radial_segments = 10
	hub.top_radius = 0.083
	hub.bottom_radius = 0.083
	hub.height = 0.145
	G.mesh_part(pivot, "Hub", Vector3.ZERO, hub, _brass).rotation.z = PI * 0.5
	_wheels.append(pivot)
	_wheel_radius.append(radius)
