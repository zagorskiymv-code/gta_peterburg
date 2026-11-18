@tool
extends Node3D

enum Paint { BLACK, BURGUNDY, GREEN, BLUE, CREAM }

const G = preload("res://scripts/world/district_geometry.gd")
const COLORS := [Color("#222328"), Color("#652a36"), Color("#304f42"), Color("#314965"), Color("#d6c49c")]
const DRIVER_SEAT := Vector3(-0.245, 1.245, 0.42)
const TRACK := 0.78
const FRONT_AXLE := -1.04
const REAR_AXLE := 1.02
const FRONT_RADIUS := 0.43
const REAR_RADIUS := 0.56

var _lacquer := G.solid_material(COLORS[Paint.BURGUNDY])
var _trim := G.solid_material(Color("#c29658"))
var _steel := G.solid_material(Color("#3f3633"))
var _guards := G.solid_material(Color("#37302d"))
var _leather := G.solid_material(Color("#351f1c"))
var _piping := G.solid_material(Color("#6a4334"))
var _ash := G.solid_material(Color("#82542f"))
var _rubber := G.solid_material(Color("#232221"))
var _brass := G.solid_material(Color("#b68c4e"))
var _glass := G.solid_material(Color("#eed39a"))
var _front: Array[Node3D] = []
var _axles: Array[Node3D] = []
var _radii: Array[float] = []
var _tiller: Node3D


func _ready() -> void:
	_lacquer.roughness = 0.32
	_brass.metallic = 0.62
	_brass.roughness = 0.33
	_leather.roughness = 0.62
	_guards.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass.emission_enabled = true
	_glass.emission = Color("#a1692a")
	_glass.emission_energy_multiplier = 0.30
	_build_body()
	for front in [true, false]:
		var z := FRONT_AXLE if front else REAR_AXLE
		var radius := FRONT_RADIUS if front else REAR_RADIUS
		_cylinder(self, "Axle", Vector3(0, radius, z), 0.045, 1.56, _steel).rotation.z = PI / 2.0
		for side in [-1.0, 1.0]:
			_wheel(Vector3(side * TRACK, radius, z), radius, front)
			_fender(side, radius, z)


func set_paint(paint: Paint) -> void:
	_lacquer.albedo_color = COLORS[paint]


func animate_running_gear(distance: float, steering: float) -> void:
	for index in _axles.size():
		_axles[index].rotate_x(-distance / _radii[index])
	var curvature := tan(steering) / (REAR_AXLE - FRONT_AXLE)
	for pivot in _front:
		var wheel_angle := atan2(tan(steering), 1.0 + pivot.position.x * curvature)
		pivot.rotation.y = wheel_angle
	_tiller.rotation.y = steering * 0.7


func _build_body() -> void:
	G.box(self, "TimberFrame", Vector3(0, 0.61, 0.01), Vector3(1.34, 0.14, 2.60), _steel)
	_beveled_panel(self, "PaintedBodyTub", Vector3(0, 0.82, 0.20), Vector3(1.30, 0.43, 1.95), 0.065, _lacquer)
	G.box(self, "Footboard", Vector3(0, 0.74, -1.06), Vector3(1.17, 0.13, 0.84), _ash)
	G.box(self, "FrontApron", Vector3(0, 0.87, -1.47), Vector3(1.20, 0.23, 0.085), _lacquer)
	G.box(self, "DashBoard", Vector3(0, 1.025, -0.94), Vector3(1.25, 0.44, 0.078), _lacquer)
	G.box(self, "DashBrassEdge", Vector3(0, 1.249, -0.94), Vector3(1.25, 0.027, 0.087), _trim)
	G.box(self, "RearLocker", Vector3(0, 0.97, 1.11), Vector3(1.18, 0.40, 0.49), _lacquer)
	G.box(self, "LockerLid", Vector3(0, 1.173, 1.11), Vector3(1.21, 0.06, 0.51), _steel)
	_beveled_panel(self, "BenchCushion", Vector3(0, 1.10, 0.35), Vector3(1.22, 0.20, 0.62), 0.045, _leather)
	var seat := G.group(self, "BenchBack", Vector3(0, 1.35, 0.67))
	seat.rotation.x = 0.18
	_beveled_panel(seat, "UpholsteredBack", Vector3.ZERO, Vector3(1.24, 0.47, 0.15), 0.035, _leather)
	G.box(seat, "TopPiping", Vector3(0, 0.234, -0.015), Vector3(1.23, 0.033, 0.13), _piping)
	var buttons: Array[Transform3D] = []
	for index in 7:
		var x := -0.51 + index * 0.17
		G.box(seat, "LeatherPleat", Vector3(x, 0.0, -0.078), Vector3(0.021, 0.40, 0.017), _piping)
		buttons.append(G.box_transform(Vector3(x, 0.067, -0.09), Vector3(0.033, 0.032, 0.017)))
	G.batch(seat, "TuftButtons", BoxMesh.new(), _leather, buttons)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.65
		G.box(self, "SidePanelBead", Vector3(x, 0.95, 0.20), Vector3(0.018, 0.022, 1.75), _trim)
		G.box(self, "LowerWoodMolding", Vector3(x - side * 0.022, 0.68, 0.20), Vector3(0.038, 0.035, 1.76), _steel)
		for axle: float in [FRONT_AXLE, REAR_AXLE]:
			for leaf in 3:
				var spring := G.box(self, "LeafSpring", Vector3(side * 0.51, 0.47 + leaf * 0.027, axle),
						Vector3(0.069, 0.026, 0.57 - leaf * 0.12), _steel)
				spring.rotation.x = (0.15 if leaf == 0 else 0.06) * signf(axle)
		G.box(self, "KickStep", Vector3(side * 0.74, 0.51, -0.30), Vector3(0.27, 0.065, 0.57), _steel)
		G.box(self, "LeatherArmrest", Vector3(side * 0.57, 1.26, 0.43), Vector3(0.11, 0.11, 0.50), _leather)
		for offset in [0.22, 0.63]:
			G.box(self, "SeatIron", Vector3(side * 0.58, 1.16, offset), Vector3(0.047, 0.25, 0.055), _steel)
		_lantern(Vector3(side * 0.63, 1.28, -0.98))
	_cylinder(self, "ExposedRearPowerUnit", Vector3(0.18, 0.57, 0.89), 0.20, 0.60, _steel).rotation.z = PI / 2.0
	_cylinder(self, "Flywheel", Vector3(0.43, 0.55, 0.93), 0.245, 0.085, _ash).rotation.z = PI / 2.0
	_cylinder(self, "BrassTank", Vector3(0.0, 0.85, 1.38), 0.11, 0.76, _brass).rotation.z = PI / 2.0
	_tiller = G.group(self, "SteeringTiller", Vector3(-0.31, 1.11, -0.81))
	_cylinder(_tiller, "TillerPost", Vector3(0, 0.19, 0), 0.024, 0.38, _brass)
	var lever := _cylinder(_tiller, "TillerReach", Vector3(0, 0.35, 0.34), 0.021, 0.71, _steel)
	lever.rotation.x = PI * 0.50
	_cylinder(_tiller, "WoodGrip", Vector3(0, 0.36, 0.69), 0.036, 0.24, _ash).rotation.z = PI / 2.0


func _wheel(at: Vector3, radius: float, front: bool) -> void:
	var pivot := G.group(self, "SteeringPivot" if front else "RearWheel", at)
	var wheel := G.group(pivot, "WheelSpin")
	if front:
		_front.append(pivot)
	_axles.append(wheel)
	_radii.append(radius)
	var tire := TorusMesh.new()
	tire.inner_radius = radius - 0.072
	tire.outer_radius = radius
	tire.rings = 28
	tire.ring_segments = 6
	G.mesh_part(wheel, "SolidRubberTyre", Vector3.ZERO, tire, _rubber).rotation.z = PI / 2.0
	var felloe := TorusMesh.new()
	felloe.inner_radius = radius - 0.102
	felloe.outer_radius = radius - 0.040
	felloe.rings = 28
	felloe.ring_segments = 6
	G.mesh_part(wheel, "PaintedFelloe", Vector3.ZERO, felloe, _lacquer).rotation.z = PI / 2.0
	var spokes: Array[Transform3D] = []
	var length := radius - 0.135
	for index in 12:
		var turn := Basis(Vector3.RIGHT, TAU * float(index) / 12.0)
		spokes.append(Transform3D(turn.scaled_local(Vector3(0.036, length, 0.033)),
				turn * Vector3(0, length * 0.5 + 0.059, 0)))
	G.batch(wheel, "AshSpokes", BoxMesh.new(), _ash, spokes)
	_cylinder(wheel, "IronHub", Vector3.ZERO, 0.087, 0.15, _steel).rotation.z = PI / 2.0
	var outside := signf(at.x)
	_cylinder(wheel, "BrassHubCap", Vector3(outside * 0.084, 0, 0), 0.051, 0.034, _brass).rotation.z = PI / 2.0


func _fender(side: float, wheel_radius: float, z: float) -> void:
	var radius := wheel_radius + 0.075
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var a := lerpf(-1.16, 1.06, i / 12.0)
		var b := lerpf(-1.16, 1.06, (i + 1) / 12.0)
		var start := Vector3(side * TRACK, wheel_radius + radius * cos(a), z + radius * sin(a))
		var finish := Vector3(side * TRACK, wheel_radius + radius * cos(b), z + radius * sin(b))
		var width := Vector3.RIGHT * 0.102
		for vertex in [start - width, finish - width, start + width, start + width, finish - width, finish + width]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	G.mesh_part(self, "SweptMudguard", Vector3.ZERO, surface.commit(), _guards)
	for angle in [-0.93, 0.87]:
		var top := Vector3(side * (TRACK - 0.082), wheel_radius + radius * cos(angle) - 0.014,
				z + radius * sin(angle))
		var anchor := Vector3(side * 0.56, 0.64, top.z)
		var support := _cylinder(self, "MudguardStay", (anchor + top) * 0.5, 0.013, anchor.distance_to(top), _steel)
		support.basis = Basis(Vector3.FORWARD, atan2(top.x - anchor.x, top.y - anchor.y))


func _lantern(at: Vector3) -> void:
	var lamp := G.group(self, "BrassCarriageLantern", at)
	G.box(lamp, "LampBracket", Vector3(0, -0.15, 0.06), Vector3(0.046, 0.19, 0.09), _steel)
	G.box(lamp, "BrassCase", Vector3.ZERO, Vector3(0.161, 0.208, 0.125), _brass)
	G.box(lamp, "AmberLens", Vector3(0, 0.008, -0.066), Vector3(0.122, 0.143, 0.015), _glass)
	G.box(lamp, "LampBrow", Vector3(0, 0.092, -0.015), Vector3(0.18, 0.034, 0.158), _brass)
	_cylinder(lamp, "ChimneyVent", Vector3(0, 0.141, 0), 0.042, 0.080, _brass)
	_cylinder(lamp, "VentCap", Vector3(0, 0.187, 0), 0.058, 0.022, _brass)


func _cylinder(parent: Node3D, title: String, center: Vector3, radius: float, height: float,
		material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return G.mesh_part(parent, title, center, mesh, material)


func _beveled_panel(parent: Node3D, title: String, center: Vector3, size: Vector3,
		bevel: float, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var rings: Array[PackedVector3Array] = []
	for index in 4:
		var edge := index == 0 or index == 3
		var half_x := size.x * 0.5 - (bevel * 0.65 if edge else 0.0)
		var half_z := size.z * 0.5 - (bevel * 0.65 if edge else 0.0)
		var y := [-size.y * 0.5, -size.y * 0.5 + bevel, size.y * 0.5 - bevel, size.y * 0.5][index] as float
		rings.append(PackedVector3Array([
			Vector3(-half_x + bevel, y, -half_z), Vector3(half_x - bevel, y, -half_z),
			Vector3(half_x, y, -half_z + bevel), Vector3(half_x, y, half_z - bevel),
			Vector3(half_x - bevel, y, half_z), Vector3(-half_x + bevel, y, half_z),
			Vector3(-half_x, y, half_z - bevel), Vector3(-half_x, y, -half_z + bevel),
		]))
	for level in 3:
		var lower := rings[level]
		var upper := rings[level + 1]
		for index in 8:
			var next := (index + 1) % 8
			for point in [lower[index], lower[next], upper[next], lower[index], upper[next], upper[index]]:
				surface.add_vertex(point)
	for index in range(1, 7):
		for point in [rings[3][0], rings[3][index], rings[3][index + 1],
				rings[0][0], rings[0][index + 1], rings[0][index]]:
			surface.add_vertex(point)
	surface.generate_normals()
	return G.mesh_part(parent, title, center, surface.commit(), material)
