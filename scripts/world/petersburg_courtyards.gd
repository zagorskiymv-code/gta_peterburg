@tool
extends RefCounted

const Geometry = preload("res://scripts/world/district_geometry.gd")
const Facades = preload("res://scripts/world/district_facades.gd")
const WINDOW := preload("res://scenes/world/props/facade_window.tscn")
const LAMP := preload("res://scenes/world/props/gas_lamp.tscn")

const OPENING_HALF_WIDTH := 1.8
const SPRING_HEIGHT := 2.55
const ARCH_RISE := 1.10
const FRONT := 3.25

var plaster := Geometry.solid_material(Color("#b7a38b"))
var trim := Geometry.solid_material(Color("#c8b497"))
var base_stone := Geometry.solid_material(Color("#8c8173"))
var roof := Geometry.solid_material(Color("#575955"))


func build(parent: Node3D, paving: Material) -> void:
	var yards := Geometry.group(parent, "ConnectedWellCourtyards")
	var facades := Facades.new()
	_wing(facades, yards, "SouthWestWing", Vector2(60, -140.5), 90, Vector2(20.6, 6.5), 4, "#bfa58a")
	_wing(facades, yards, "NorthWestWing", Vector2(60, -170), 90, Vector2(25.6, 6.5), 4, "#bba18b")
	_wing(facades, yards, "SouthEastWing", Vector2(84.5, -144.5), -90, Vector2(29, 8), 5, "#bcab92")
	_wing(facades, yards, "NorthEastWing", Vector2(84.5, -174.55), -90, Vector2(31.1, 8), 4, "#c4b394")
	_wing(facades, yards, "SouthEndWing", Vector2(71.85, -132), 180, Vector2(17.2, 7), 4, "#b5b29a")
	_wing(facades, yards, "NorthEndWing", Vector2(71.85, -193), 0, Vector2(17.2, 7), 4, "#c1b397")
	_wing(facades, yards, "CrossWingWest", Vector2(66, -159), 0, Vector2(5.6, 6.5), 3, "#b5a38d")
	_wing(facades, yards, "CrossWingEast", Vector2(77.85, -159), 0, Vector2(5.3, 6.5), 3, "#b5a38d")

	_gate(yards, "StreetArch", Vector3(60, 0.015, -154), 90)
	_gate(yards, "ConnectingArch", Vector3(71.95, 0.015, -159), 0, 8.43)
	_gate(yards, "NorthernExitArch", Vector3(60, 0.015, -186), 90)
	_paving(yards, "CourtPaving", Vector2(72, -160.5), Vector2(20, 55), paving)
	_paving(yards, "StreetEntryLane", Vector2(52.5, -154), Vector2(19, 3.6), paving)
	_paving(yards, "NorthernExitLane", Vector2(52.5, -186), Vector2(19, 3.6), paving)

	for center in [Vector3(78.2, 0.015, -143), Vector3(77.6, 0.015, -178)]:
		var lamp: Node3D = LAMP.instantiate()
		lamp.position = center
		yards.add_child(lamp, true)


func _wing(facades: RefCounted, parent: Node3D, title: String, center: Vector2, yaw: float,
		dimensions: Vector2, floors: int, color: String) -> void:
	facades.add_building(parent, title, center, yaw, dimensions, floors, Facades.Kind.TENEMENT, Color(color))


func _paving(parent: Node3D, title: String, center: Vector2, dimensions: Vector2, material: Material) -> void:
	Geometry.box(parent, title, Vector3(center.x, -0.085, center.y),
			Vector3(dimensions.x, 0.20, dimensions.y), material, true)


func _gate(parent: Node3D, title: String, center: Vector3, yaw: float, height := 11.08) -> void:
	var gate := Geometry.group(parent, title, center)
	gate.rotation_degrees.y = yaw
	for side in [-1, 1]:
		Geometry.box(gate, "MasonryPier", Vector3(side * 2.49, height * 0.5, 0),
				Vector3(1.4, height, FRONT * 2.0), plaster, true)
		Geometry.box(gate, "PierFoot", Vector3(side * 2.52, 0.24, 0),
				Vector3(1.34, 0.48, FRONT * 2.0 + 0.10), base_stone)

	var arch := _arch_mesh(height)
	Geometry.mesh_part(gate, "BrickVault", Vector3.ZERO, arch, plaster)
	var solid := StaticBody3D.new()
	solid.name = "VaultCollision"
	solid.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = arch.create_trimesh_shape()
	solid.add_child(shape)
	gate.add_child(solid)

	Geometry.box(gate, "Cornice", Vector3(0, height - 0.09, 0),
			Vector3(6.6, 0.27, FRONT * 2.0 + 0.25), trim)
	Geometry.box(gate, "RoofCap", Vector3(0, height + 0.04, 0),
			Vector3(6.41, 0.18, FRONT * 2.0 + 0.18), roof)
	var ring_parts: Array[Transform3D] = []
	for facing in [-1, 1]:
		for i in 13:
			var theta := PI * float(i) / 12.0
			var position := Vector3(cos(theta) * 1.96, SPRING_HEIGHT + sin(theta) * 1.22, facing * (FRONT + 0.035))
			var tangent := Vector2(-1.96 * sin(theta), 1.22 * cos(theta)).angle()
			var basis := Basis(Vector3.BACK, tangent).scaled_local(Vector3(0.39, 0.28, 0.16))
			ring_parts.append(Transform3D(basis, position))
		var floors := 2 if height > 10.0 else 1
		for floor_index in floors:
			for x in [-1.1, 1.1]:
				var window: Node3D = WINDOW.instantiate()
				window.position = Vector3(x, 5.25 + floor_index * 2.65, facing * FRONT)
				window.rotation_degrees.y = 0 if facing > 0 else 180
				gate.add_child(window, true)
	Geometry.batch(gate, "StoneVoussoirs", BoxMesh.new(), trim, ring_parts)


func _arch_mesh(height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i in 16:
		var left_x := lerpf(-OPENING_HALF_WIDTH, OPENING_HALF_WIDTH, float(i) / 16.0)
		var right_x := lerpf(-OPENING_HALF_WIDTH, OPENING_HALF_WIDTH, float(i + 1) / 16.0)
		var left_y := _soffit(left_x)
		var right_y := _soffit(right_x)
		var a := Vector3(left_x, left_y, FRONT)
		var b := Vector3(right_x, right_y, FRONT)
		var c := Vector3(right_x, right_y, -FRONT)
		var d := Vector3(left_x, left_y, -FRONT)
		_quad(surface, a, b, c, d)
		_quad(surface, a, a + Vector3.UP * (height - left_y), b + Vector3.UP * (height - right_y), b)
		_quad(surface, d, c, c + Vector3.UP * (height - right_y), d + Vector3.UP * (height - left_y))
	surface.generate_normals()
	return surface.commit()


func _soffit(x: float) -> float:
	return SPRING_HEIGHT + ARCH_RISE * sqrt(maxf(0, 1.0 - pow(x / OPENING_HALF_WIDTH, 2.0)))


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(point)


func build_rental_block(parent: Node3D, label: String, center: Vector2, yaw: float,
		floors: int, paving: Material) -> void:
	# The front arch faces local +Z. The rear arch opens onto a service lane.
	var block := Geometry.group(parent, label, Vector3(center.x, 0, center.y))
	block.rotation_degrees.y = yaw
	var facades := Facades.new()
	var height := 0.48 + floors * 2.65
	for side in [-1, 1]:
		_wing(facades, block, "SideWing", Vector2(side * 11.6, 0), -side * 90,
				Vector2(24, 6.5), floors, "#b7a58d")
		for end in [-1, 1]:
			_wing(facades, block, "StreetFront", Vector2(side * 5.82, end * 12.0), 0 if end > 0 else 180,
					Vector2(5.25, 6.5), floors, "#c1ab91")
	for end in [-1, 1]:
		_gate(block, "Passage", Vector3(0, 0.012, end * 12.0), 0 if end > 0 else 180, height)
	_paving(block, "InteriorCourt", Vector2.ZERO, Vector2(17.0, 31.0), paving)
	var lamp: Node3D = LAMP.instantiate()
	lamp.position = Vector3(5.8, 0.015, 4)
	block.add_child(lamp, true)
