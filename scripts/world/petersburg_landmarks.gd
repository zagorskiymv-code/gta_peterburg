@tool
extends RefCounted

const Geometry = preload("res://scripts/world/district_geometry.gd")
const Headquarters = preload("res://scripts/world/landmarks/general_staff.gd")
const CATHEDRAL := preload("res://scenes/world/landmarks/isaac/cathedral.tscn")
const Sculpture = preload("res://scripts/world/landmark_sculpture.gd")
const Facades = preload("res://scripts/world/district_facades.gd")
const LAMP := preload("res://scenes/world/props/gas_lamp.tscn")
const BENCH := preload("res://scenes/world/props/wooden_bench.tscn")

var marble := Geometry.solid_material(Color("#a4a197"))
var carved_stone := Geometry.solid_material(Color("#bdb6a4"))
var granite := Geometry.solid_material(Color("#68423c"))
var bronze := Geometry.solid_material(Color("#4b5946"))
var shadow := Geometry.solid_material(Color("#302924"))
var grass := Geometry.solid_material(Color("#686f48"))
var box := BoxMesh.new()
var sculpture := Sculpture.new()


func build(parent: Node3D, paving: Material, flagstone: Material, ground: Material) -> void:
	Geometry.box(parent, "NorthernGround", Vector3(0, -0.45, -190), Vector3(180, 0.8, 200), ground, true)
	_tile(parent, "IsaacCrossStreet", Vector2(-29, -96), Vector2(50, 7), paving, 0.01)
	_tile(parent, "PalaceApproach", Vector2(19, -186), Vector2(55, 5.5), paving, 0.01)

	_isaac_garden(Geometry.group(parent, "SaintIsaacGarden", Vector3(-49, 0, -93)), flagstone)
	var cathedral := CATHEDRAL.instantiate() as Node3D
	cathedral.position = Vector3(-49, 0, -136)
	parent.add_child(cathedral)
	_tile(parent, "IsaacStoneParvis", Vector2(-49.5, -136), Vector2(79, 71), flagstone, 0.018)
	_tile(parent, "IsaacNorthWalk", Vector2(-49, -174.5), Vector2(15, 7), flagstone, 0.017)
	_tile(parent, "AdmiraltyForecourt", Vector2(-49, -184.5), Vector2(25, 13), flagstone, 0.017)
	for x in [-59.0, -39.0]:
		_tile(parent, "ForecourtPlanting", Vector2(x, -181), Vector2(3.4, 5.5), grass, 0.065)
		_prop(parent, BENCH, Vector3(x, 0.017, -184.5), 180)
	_tile(parent, "IsaacEastWalk", Vector2(-14.5, -117), Vector2(7, 7), flagstone, 0.017)
	Headquarters.new().build(parent, paving)
	_palace_square(Geometry.group(parent, "PalaceSquare", Vector3(17, 0, -222)), paving, flagstone)
	_palace(Geometry.group(parent, "WinterPalace", Vector3(17, 0, -271)))
	_new_hermitage(Geometry.group(parent, "NewHermitage", Vector3(78, 0, -278)))
	_tile(parent, "MillionnayaStreet", Vector2(61, -251.4), Vector2(56, 8), paving, 0.036)

	var facades := Facades.new()
	var blocks := Geometry.group(parent, "ConnectingFrontages")
	facades.add_building(blocks, "VoznesenskyHouse", Vector2(17, -110), -90, Vector2(13, 10), 3, Facades.Kind.MERCHANT, Color("#c8b895"))
	facades.add_building(blocks, "AdmiraltyTenement", Vector2(17, -137), -90, Vector2(24, 11), 4, Facades.Kind.TENEMENT, Color("#aebb9f"))
	facades.add_building(blocks, "Bookseller", Vector2(16, -160), -90, Vector2(15, 9), 2, Facades.Kind.SHOP, Color("#d2b19a"))
	facades.add_building(blocks, "WestAdmiraltyHouse", Vector2(31, -130), -90, Vector2(10, 7), 3, Facades.Kind.TENEMENT, Color("#d4b88d"))
	facades.add_building(blocks, "MorskayaHouse", Vector2(20, -78), -90, Vector2(10, 8), 4, Facades.Kind.MERCHANT, Color("#b7bda5"))


func _isaac_garden(garden: Node3D, stone: Material) -> void:
	_tile(garden, "GardenCourt", Vector2(0, 2), Vector2(55, 22), stone, 0.028)
	for x in [-16.0, 16.0]:
		for z in [-2.9, 8.5]:
			_tile(garden, "Lawn", Vector2(x, z), Vector2(18.5, 6), grass, 0.067)
			_tree(garden, Vector3(x - 4.5, 0.067, z))
			_tree(garden, Vector3(x + 4.5, 0.067, z))
		_prop(garden, BENCH, Vector3(x - 2, 0.028, 1.55))
		_prop(garden, BENCH, Vector3(x + 2, 0.028, 4.4), 180)
		_prop(garden, LAMP, Vector3(x * 0.42, 0.028, -4))
		_prop(garden, LAMP, Vector3(x * 0.42, 0.028, 5))
	var monument := Geometry.group(garden, "NicholasIMonument", Vector3(0, 0, 8.5))
	Geometry.box(monument, "PedestalStep", Vector3(0, 0.15, 0), Vector3(3.3, 0.24, 2.5), marble, true)
	_cylinder(monument, "RedGranitePedestal", Vector3(0, 1.36, 0), 1.09, 1.29, 2.34, granite, 12)
	Geometry.collider(monument, "PedestalCollision", Vector3(0, 1.28, 0), Vector3(1.98, 2.55, 1.98))
	_cylinder(monument, "PedestalCap", Vector3(0, 2.56, 0), 1.23, 1.17, 0.22, marble, 12)
	var statue := Geometry.mesh_part(monument, "BronzeHorseAndRider", Vector3(0, 2.66, 0),
			sculpture.horse_and_rider(), bronze)
	statue.rotation_degrees.y = 90
	for side in [-1, 1]:
		Geometry.box(monument, "BronzeRelief", Vector3(side * 1.14, 1.26, 0),
				Vector3(0.13, 0.65, 0.96), bronze)


func _palace_square(square: Node3D, paving: Material, stone: Material) -> void:
	_tile(square, "ParadeGround", Vector2(0, 0), Vector2(106, 73), paving, 0.015)
	_tile(square, "PalaceForecourt", Vector2(0, -40), Vector2(106, 7), stone, 0.045)
	var monument := Geometry.group(square, "AlexanderColumn", Vector3(0, 0, 2))
	Geometry.box(monument, "GreyGraniteSteps", Vector3(0, 0.42, 0), Vector3(6.1, 0.83, 6.1), marble, true)
	Geometry.box(monument, "Pedestal", Vector3(0, 1.98, 0), Vector3(3.55, 2.64, 3.55), granite, true)
	var reliefs: Array[Transform3D] = []
	for yaw in [0, 90, 180, 270]:
		var basis := Basis(Vector3.UP, deg_to_rad(yaw))
		reliefs.append(Transform3D(basis.scaled_local(Vector3(2.42, 1.32, 0.12)),
				basis * Vector3(0, 1.91, 1.79)))
	Geometry.batch(monument, "BronzeBasReliefs", box, bronze, reliefs)
	_cylinder(monument, "ShaftFoot", Vector3(0, 3.37, 0), 1.38, 1.49, 0.63, bronze, 24)
	_cylinder(monument, "RedGraniteMonolith", Vector3(0, 11.64, 0), 0.95, 1.19, 16.1, granite, 32)
	_cylinder(monument, "BronzeCapital", Vector3(0, 19.98, 0), 1.38, 1.07, 0.65, bronze, 24)
	_cylinder(monument, "FigurePlinth", Vector3(0, 20.49, 0), 0.83, 1.30, 0.39, bronze, 24)
	Geometry.mesh_part(monument, "WingedAngelAndSerpent", Vector3(0, 20.68, 0), sculpture.angel(), bronze)
	_cross(monument, Vector3(0.61, 22.04, 0.10), 2.69, bronze)
	for x in [-4.42, 4.42]:
		for z in [-4.42, 4.42]:
			_prop(monument, LAMP, Vector3(42.0 if x > 0 and z > 0 else x, 0.015, z))
	for x in [-48.0, 48.0]:
		for z in [-29.0, 29.0]:
			_prop(square, LAMP, Vector3(42.0 if x > 0 and z > 0 else x, 0.015, z))


func _palace(palace: Node3D) -> void:
	var brick := Geometry.solid_material(Color("#a76350"))
	var trim := Geometry.solid_material(Color("#b2745f"))
	var roof := Geometry.solid_material(Color("#524640"))
	Geometry.box(palace, "WinterPalaceMasonry", Vector3(0, 6.3, 0), Vector3(102, 12.6, 25), brick, true)
	Geometry.box(palace, "RusticatedGroundFloor", Vector3(0, 1.94, 0), Vector3(102.35, 3.88, 25.35), trim)
	for y in [3.95, 11.82, 12.42]:
		Geometry.box(palace, "ContinuousCornice", Vector3(0, y, 0), Vector3(102.7, 0.29, 25.7), trim)
	Geometry.box(palace, "Roof", Vector3(0, 12.54, 0), Vector3(101.8, 0.25, 24.8), roof)
	var windows: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	var ornaments: Array[Transform3D] = []
	var columns: Array[Transform3D] = []
	for i in 35:
		var x := (i - 17) * 2.86
		for y in [2.16, 6.54, 9.64]:
			if y < 3 and absi(i - 17) <= 1:
				continue
			frames.append(Geometry.box_transform(Vector3(x, y, 12.59), Vector3(1.37, 2.28, 0.23)))
			windows.append(Geometry.box_transform(Vector3(x, y, 12.735), Vector3(0.98, 1.83, 0.09)))
			ornaments.append(Geometry.box_transform(Vector3(x, y + 1.19, 12.72), Vector3(1.52, 0.18, 0.31)))
		if i % 2 == 0 or absi(i - 17) <= 3:
			columns.append(Transform3D(Basis.IDENTITY, Vector3(x - 1.43, 7.97, 12.81)))
		if i % 2 == 0:
			ornaments.append(Geometry.box_transform(Vector3(x, 13.05, 12.43), Vector3(0.32, 1.02, 0.35)))
	for side in [-1, 1]:
		for z in [-8.0, -4.0, 0.0, 4.0, 8.0]:
			for y in [2.16, 6.54, 9.64]:
				frames.append(Geometry.box_transform(Vector3(side * 51.10, y, z), Vector3(0.23, 2.28, 1.37)))
				windows.append(Geometry.box_transform(Vector3(side * 51.245, y, z), Vector3(0.09, 1.83, 0.98)))
	var rear_yaw := Basis(Vector3.UP, PI)
	for i in 25:
		for y in [2.16, 6.54, 9.64]:
			var x := (i - 12) * 3.95
			frames.append(Transform3D(rear_yaw, Vector3(x, y, -12.60)) *
					Geometry.box_transform(Vector3.ZERO, Vector3(1.37, 2.28, 0.24)))
			windows.append(Geometry.box_transform(Vector3(x, y, -12.76), Vector3(0.98, 1.83, 0.10)))
	Geometry.batch(palace, "BaroqueWindowFrames", box, trim, frames)
	Geometry.batch(palace, "Windows", box, shadow, windows)
	Geometry.batch(palace, "SillsAndRoofOrnaments", box, trim, ornaments)
	_batch_columns(palace, columns, 7.25, 0.26, trim)
	Geometry.box(palace, "RoofBalustrade", Vector3(0, 12.96, 12.39), Vector3(102.1, 0.45, 0.26), trim)
	for x in [-2.86, 0.0, 2.86]:
		Geometry.box(palace, "MainGate", Vector3(x, 1.52, 12.73), Vector3(2.13, 3.0, 0.14), shadow)
		var arch := CylinderMesh.new()
		arch.top_radius = 1.065
		arch.bottom_radius = 1.065
		arch.height = 0.14
		arch.radial_segments = 18
		Geometry.mesh_part(palace, "GateArch", Vector3(x, 3.0, 12.73), arch, shadow).rotation_degrees.x = 90


func _tile(parent: Node3D, title: String, center: Vector2, size: Vector2, material: Material, top: float) -> void:
	Geometry.box(parent, title, Vector3(center.x, top - 0.48, center.y),
			Vector3(size.x, 0.96, size.y), material, true)


func _prop(parent: Node3D, scene: PackedScene, center: Vector3, yaw := 0.0) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = center
	prop.rotation_degrees.y = yaw
	parent.add_child(prop, true)


func _tree(parent: Node3D, center: Vector3) -> void:
	var tree := Geometry.group(parent, "Linden", center)
	_cylinder(tree, "Trunk", Vector3.UP * 1.42, 0.12, 0.24, 2.84, granite, 7)
	Geometry.collider(tree, "TrunkCollision", Vector3.UP * 1.2, Vector3(0.42, 2.4, 0.42))
	var crown := SphereMesh.new()
	crown.radius = 1.6
	crown.height = 3.6
	crown.radial_segments = 9
	crown.rings = 5
	Geometry.mesh_part(tree, "Crown", Vector3.UP * 3.45, crown, grass)


func _cross(parent: Node3D, center: Vector3, height: float, material: Material) -> void:
	Geometry.box(parent, "CrossUpright", center, Vector3(height * 0.105, height, height * 0.10), material)
	Geometry.box(parent, "CrossBeam", center + Vector3.UP * height * 0.15,
			Vector3(height * 0.68, height * 0.105, height * 0.10), material)


func _batch_columns(parent: Node3D, transforms: Array[Transform3D], height: float, radius: float,
		material: Material) -> void:
	var column := CylinderMesh.new()
	column.top_radius = radius * 0.84
	column.bottom_radius = radius
	column.height = height
	column.radial_segments = 10
	Geometry.batch(parent, "Columns", column, material, transforms)
	var ends: Array[Transform3D] = []
	for transform in transforms:
		for side in [-1, 1]:
			ends.append(Geometry.box_transform(transform.origin + Vector3.UP * side * height * 0.5,
					Vector3(radius * 2.65, radius * 0.63, radius * 2.65)))
	Geometry.batch(parent, "ColumnCapsAndPlinths", box, marble if material == granite else material, ends)


func _cylinder(parent: Node3D, title: String, center: Vector3, top: float, bottom: float,
		height: float, material: Material, segments: int) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = segments
	Geometry.mesh_part(parent, title, center, cylinder, material)


func _new_hermitage(museum: Node3D) -> void:
	var facade := Geometry.solid_material(Color("#b4a183"))
	var atlas_stone := Geometry.solid_material(Color("#4c5150"))
	Geometry.box(museum, "MuseumBody", Vector3(0, 6.5, 0), Vector3(20, 13, 19), facade, true)
	Geometry.box(museum, "UpperCornice", Vector3(0, 12.83, 0), Vector3(20.45, 0.43, 19.45), carved_stone)
	Geometry.box(museum, "Frieze", Vector3(0, 11.85, 9.62), Vector3(20.16, 0.66, 0.29), carved_stone)
	var windows: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	for x in [-8.3, -6.1, -3.6, 0.0, 3.6, 6.1, 8.3]:
		for y in [2.52, 8.62]:
			if y < 3.0 and absf(x) < 4.0:
				continue
			frames.append(Geometry.box_transform(Vector3(x, y, 9.58), Vector3(1.45, 2.38, 0.23)))
			windows.append(Geometry.box_transform(Vector3(x, y, 9.735), Vector3(1.05, 1.94, 0.14)))
	for yaw in [90, 180, 270]:
		var orientation := Basis(Vector3.UP, deg_to_rad(yaw))
		var face := 9.5 if yaw == 180 else 10.0
		for x in [-6.5, -3.25, 0.0, 3.25, 6.5]:
			for y in [2.52, 8.62]:
				var placement := Transform3D(orientation, Vector3.ZERO)
				frames.append(placement * Geometry.box_transform(Vector3(x, y, face + 0.07), Vector3(1.45, 2.38, 0.23)))
				windows.append(placement * Geometry.box_transform(Vector3(x, y, face + 0.23), Vector3(1.05, 1.94, 0.14)))
	Geometry.batch(museum, "WindowSurrounds", box, carved_stone, frames)
	Geometry.batch(museum, "MuseumWindows", box, shadow, windows)
	Geometry.box(museum, "Portal", Vector3(0, 2.31, 9.64), Vector3(3.7, 4.61, 0.24), carved_stone)
	Geometry.box(museum, "DoubleDoor", Vector3(0, 2.09, 9.79), Vector3(2.80, 4.13, 0.16), shadow)
	_tile(museum, "PorticoPlatform", Vector2(0, 11.52), Vector2(12.2, 5.25), carved_stone, 0.21)
	Geometry.box(museum, "PorticoEntablature", Vector3(0, 4.66, 11.52),
			Vector3(12.36, 0.54, 4.65), carved_stone)
	Geometry.box(museum, "PorticoCornice", Vector3(0, 4.99, 11.52),
			Vector3(12.66, 0.21, 4.91), marble)
	var figures: Array[Transform3D] = []
	var plinths: Array[Transform3D] = []
	for side in [-1, 1]:
		for i in 4:
			var x: float = side * (0.95 + i * 1.39)
			figures.append(Transform3D(Basis.IDENTITY, Vector3(x, 1.07, 13.20)))
		figures.append(Transform3D(Basis(Vector3.UP, side * PI / 2.0), Vector3(side * 5.37, 1.07, 11.10)))
	for placement in figures:
		plinths.append(Geometry.box_transform(placement.origin - Vector3.UP * 0.43, Vector3(0.98, 0.86, 0.91)))
		Geometry.collider(museum, "AtlasPedestal", placement.origin + Vector3.UP * 0.33, Vector3(0.88, 2.14, 0.78))
	Geometry.batch(museum, "GranitePedestals", box, atlas_stone, plinths)
	Geometry.batch(museum, "TenGraniteAtlantes", sculpture.atlas(), atlas_stone, figures)
	_prop(museum, LAMP, Vector3(7.25, -0.05, 15.15))
