extends Node3D

const G = preload("res://scripts/world/district_geometry.gd")
const RADII := [0.70, 0.27]
var variant := 0
var _wheels: Array[Node3D] = []
var _pedals: Node3D


func _ready() -> void:
	var colors := ["#742f36", "#294d52", "#513b29", "#25272d", "#a0844d", "#3e5c3f"]
	var frame := G.solid_material(Color(colors[variant % colors.size()]))
	var metal := G.solid_material(Color("#938367"))
	var tire := G.solid_material(Color("#252423"))
	var leather := G.solid_material(Color("#533b2c"))
	var front := Vector3(0, RADII[0], -0.40)
	var rear := Vector3(0, RADII[1], 0.78)
	_wheel(front, RADII[0], metal, tire)
	_wheel(rear, RADII[1], metal, tire)
	var stem := Vector3(0, 1.49, -0.34)
	for side in [-0.075, 0.075]:
		_bar("Fork", front + Vector3(side, 0, 0), stem, 0.043, frame)
	_bar("Spine", stem - Vector3.UP * 0.10, Vector3(0, 0.72, 0.55), 0.061, frame)
	_bar("RearStay", Vector3(0, 0.72, 0.55), rear, 0.042, frame)
	_bar("Handlebar", stem + Vector3.LEFT * 0.29, stem + Vector3.RIGHT * 0.29, 0.027, metal)
	for side in [-0.26, 0.26]:
		_bar("HandleGrip", stem + Vector3(side, 0.0, -0.07), stem + Vector3(side, 0.0, 0.08), 0.047, leather)
	G.box(self, "Saddle", Vector3(0, 1.46, -0.08), Vector3(0.27, 0.075, 0.34), leather)
	_bar("SaddleSpring", Vector3(0, 1.40, -0.08), Vector3(0, 1.28, -0.11), 0.056, metal)
	if variant % 3 == 0:
		G.box(self, "BrassHeadlamp", stem + Vector3(0, -0.14, -0.13), Vector3(0.10, 0.13, 0.12), metal)
	_pedals = G.group(self, "Cranks", front)
	for side in [-1.0, 1.0]:
		var arm := Vector3(side * 0.14, side * 0.14, 0)
		_bar_at(_pedals, "Crank", Vector3(side * 0.14, 0, 0), arm, 0.022, metal)
		G.box(_pedals, "Pedal", arm + Vector3(side * 0.045, 0, 0), Vector3(0.12, 0.042, 0.08), leather)


func crank_angle() -> float:
	return _pedals.rotation.x


func roll(distance: float) -> void:
	for i in _wheels.size():
		_wheels[i].rotate_x(-distance / RADII[i])
	_pedals.rotate_x(-distance / RADII[0])


func _wheel(at: Vector3, radius: float, metal: Material, rubber: Material) -> void:
	var wheel := G.group(self, "SpokedWheel", at)
	_wheels.append(wheel)
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.039
	ring.outer_radius = radius
	ring.rings = 22
	ring.ring_segments = 5
	G.mesh_part(wheel, "Tyre", Vector3.ZERO, ring, rubber).rotation.z = PI / 2.0
	var spokes: Array[Transform3D] = []
	for i in 16:
		var b := Basis(Vector3.RIGHT, TAU * float(i) / 16.0)
		spokes.append(Transform3D(b.scaled_local(Vector3(0.012, radius - 0.04, 0.013)),
				b * Vector3(0, radius * 0.5, 0)))
	G.batch(wheel, "SteelSpokes", BoxMesh.new(), metal, spokes)


func _bar(name_: String, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	_bar_at(self, name_, a, b, width, material)


func _bar_at(parent: Node3D, name_: String, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var part := G.box(parent, name_, (a + b) * 0.5, Vector3(width, width, a.distance_to(b)), material)
	part.basis = Basis.looking_at((b - a).normalized(), Vector3.RIGHT if absf((b - a).normalized().y) > 0.96 else Vector3.UP)
