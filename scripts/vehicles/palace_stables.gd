extends Node3D

const G = preload("res://scripts/world/district_geometry.gd")
const Horse = preload("res://scripts/vehicles/horse_visual.gd")

var _oak := G.solid_material(Color("#70513b"))
var _oiled := G.solid_material(Color("#44342a"))
var _brick := G.solid_material(Color("#895e4a"))
var _stone := G.solid_material(Color("#a2957d"))
var _hay := G.solid_material(Color("#b89852"))
var _shadow := G.solid_material(Color("#32332d"))
var _sheet := G.solid_material(Color("#444e48"))
var _horses: Array[Horse] = []
var _walker: AnimatableBody3D
var _seconds := 0.0


func _ready() -> void:
	G.box(self, "StableFloor", Vector3(0, -0.11, 0), Vector3(9.90, 0.24, 9.3), _stone, true)
	var threshold := G.group(self, "StableThreshold", Vector3(0, -0.077, 4.92))
	threshold.rotation.x = 0.10
	G.box(threshold, "StoneThresholdRamp", Vector3.ZERO, Vector3(3.04, 0.10, 0.81), _stone, true)
	G.box(self, "RearBrickWall", Vector3(0, 1.52, -4.5), Vector3(9.90, 3.10, 0.33), _brick, true)
	for side: float in [-1.0, 1.0]:
		G.box(self, "SideWall", Vector3(side * 4.79, 1.52, 0), Vector3(0.32, 3.10, 9.0), _brick, true)
		G.box(self, "FrontWall", Vector3(side * 3.32, 1.52, 4.48), Vector3(3.24, 3.10, 0.28), _brick, true)
		G.box(self, "GateJamb", Vector3(side * 1.70, 1.45, 4.46), Vector3(0.21, 2.85, 0.39), _oiled, true)
		var open_gate := G.group(self, "OpenEntranceGate", Vector3(side * 1.65, 0, 4.49))
		open_gate.rotation.y = side * -1.34
		_fence(open_gate, Vector3(side * 0.68, 0, 0), 1.34, 1.73, false)
		var roof := G.box(self, "RoofSlope", Vector3(side * 2.48, 3.52, -0.02), Vector3(5.17, 0.22, 9.75), _sheet)
		roof.rotation.z = -side * 0.19
	for z in [-3.25, 0.15, 3.40]:
		G.box(self, "TieBeam", Vector3(0, 2.96, z), Vector3(9.62, 0.17, 0.16), _oiled)
	G.box(self, "GateLintel", Vector3(0, 2.85, 4.47), Vector3(3.53, 0.23, 0.43), _oiled)
	var gable := PrismMesh.new()
	gable.size = Vector3(9.75, 0.78, 0.24)
	for z in [-4.52, 4.49]:
		G.mesh_part(self, "TimberGable", Vector3(0, 3.45, z), gable, _oak)
	for x in [-3.30, 3.30]:
		G.box(self, "VentFrame", Vector3(x, 1.94, 4.627), Vector3(1.07, 0.71, 0.11), _oak)
		G.box(self, "VentOpening", Vector3(x, 1.94, 4.694), Vector3(0.89, 0.53, 0.039), _shadow)
		for offset in [-0.29, 0.0, 0.29]:
			G.box(self, "VentGrille", Vector3(x + offset, 1.94, 4.730), Vector3(0.043, 0.54, 0.044), _oiled)
	var label := Label3D.new()
	label.text = "КОНЮШНЯ"
	label.font_size = 42
	label.pixel_size = 0.006
	label.modulate = Color("#e3cba2")
	label.position = Vector3(0, 2.88, 4.70)
	add_child(label)

	for index in 5:
		var x := -4.65 + 1.48 * index
		var partition := G.group(self, "StallPartition", Vector3(x, 0, -2.68))
		partition.rotation.y = PI / 2.0
		_fence(partition, Vector3.ZERO, 3.40, 1.48)
	for index in 4:
		var x := -3.91 + 1.48 * index
		_fence(self, Vector3(x, 0, -0.99), 1.44, 1.21)
		_add_feed(Vector3(x, 0, -4.02))
		_add_horse(index, Vector3(x, 0.015, -2.63), false)
	_fence(self, Vector3(3.10, 0, 2.62), 3.57, 1.35)
	var paddock_side := G.group(self, "PaddockFence", Vector3(1.27, 0, 0.83))
	paddock_side.rotation.y = PI / 2.0
	_fence(paddock_side, Vector3.ZERO, 3.58, 1.36)
	_add_feed(Vector3(4.0, 0, -3.92))
	_add_horse(4, Vector3(3.15, 0.015, 0.72), true)
	for at: Vector3 in [Vector3(-4.15, 0, 2.8), Vector3(-3.53, 0, 3.62), Vector3(4.15, 0, 3.63)]:
		_bale(at)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.42, 0.62)
	light.light_color = Color("#f1c58b")
	light.light_energy = 0.65
	light.omni_range = 8.0
	add_child(light)


func _physics_process(delta: float) -> void:
	_seconds += delta
	var phase := fposmod(_seconds, 16.0)
	var moving := is_instance_valid(_walker) and (phase >= 1.5 and phase < 4.7 or phase >= 9.5 and phase < 12.7)
	var direction := 1.0 if phase < 8.0 else -1.0
	var elapsed := fposmod(phase, 8.0)
	var walk := clampf((elapsed - 1.5) / 3.2, 0.0, 1.0)
	var travel := smoothstep(0.0, 1.0, walk) * 1.42
	var turn := smoothstep(5.7, 8.0, elapsed) * PI
	var position_z := 0.72 - travel if direction > 0.0 else -0.70 + travel
	var distance := 0.0
	if is_instance_valid(_walker):
		distance = absf(position_z - _walker.position.z)
		_walker.position.z = position_z
		_walker.rotation.y = turn if direction > 0.0 else PI + turn
	for index in _horses.size():
		if is_instance_valid(_horses[index]) and _horses[index].get_parent().get_parent() == self:
			_horses[index].animate_gait(delta, distance if index == 4 and moving else 0.0)


func _add_horse(index: int, at: Vector3, moving: bool) -> void:
	var body := AnimatableBody3D.new()
	body.name = "Horse%02d" % (index + 1)
	body.position = at
	body.sync_to_physics = false
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.75, 1.81, 2.37)
	shape.shape = box
	shape.position = Vector3(0, 1.0, -0.14)
	body.add_child(shape)
	var horse := Horse.new()
	horse.name = "HorseVisual"
	horse.coat_index = index
	body.add_child(horse)
	_horses.append(horse)
	if moving:
		_walker = body


func _fence(parent: Node3D, center: Vector3, width: float, height: float, solid := true) -> void:
	for side: float in [-1.0, 1.0]:
		G.box(parent, "FencePost", center + Vector3(side * (width * 0.5 - 0.08), height * 0.5, 0),
				Vector3(0.15, height, 0.15), _oiled)
	for y in [0.35, 0.66, height - 0.19]:
		G.box(parent, "TimberRail", center + Vector3(0, y, 0), Vector3(width, 0.14, 0.10), _oak)
	if solid:
		G.collider(parent, "StallGuard", center + Vector3(0, height * 0.5, 0), Vector3(width, height, 0.12))


func _add_feed(at: Vector3) -> void:
	G.box(self, "TroughBase", at + Vector3.UP * 0.32, Vector3(1.16, 0.32, 0.47), _oak)
	for side: float in [-1.0, 1.0]:
		G.box(self, "TroughEdge", at + Vector3(0, 0.51, side * 0.22), Vector3(1.21, 0.14, 0.085), _oiled)
	G.box(self, "LooseFodder", at + Vector3.UP * 0.49, Vector3(1.02, 0.10, 0.31), _hay)


func _bale(at: Vector3) -> void:
	G.box(self, "HayBale", at + Vector3.UP * 0.27, Vector3(0.86, 0.51, 0.59), _hay, true)
	for x in [-0.25, 0.25]:
		G.box(self, "BaleTwine", at + Vector3(x, 0.47, 0), Vector3(0.030, 0.11, 0.61), _oak)
