@tool
extends RefCounted

const Geometry = preload("res://scripts/world/district_geometry.gd")
const Facades = preload("res://scripts/world/district_facades.gd")
const BENCH := preload("res://scenes/world/props/wooden_bench.tscn")
const LAMP := preload("res://scenes/world/props/gas_lamp.tscn")

var lawn := Geometry.solid_material(Color("#686f4a"))
var leaves := Geometry.solid_material(Color("#4e6542"))
var bark := Geometry.solid_material(Color("#584637"))


func build(parent: Node3D, paving: Material, stone: Material) -> void:
	var roads := Geometry.group(parent, "SideStreets")
	# Bounds are x minimum, x maximum, z minimum, z maximum.
	var network := {
		"WestStreet": Vector4(-60, -54, -22, 65),
		"WestLaneLink": Vector4(-54, -32, 25, 31),
		"SouthernCrossStreet": Vector4(-60, -4, 65, 71),
		"SouthernCrossStreetEast": Vector4(4, 43, 65, 71),
		"InnerQuayLane": Vector4(23, 29, -22, 65),
		"CanalGardenLane": Vector4(29, 42, 14, 19),
		"OuterBankLane": Vector4(68, 74, 4, 70),
		"OuterBankLink": Vector4(68, 74, 0, 4),
		"WesternCrossStreet": Vector4(-76, -69, -72, -32),
		"NorthernQuayStreet": Vector4(38, 44, -183.25, -94),
		"AdmiraltyCrossStreet": Vector4(4, 38, -124.5, -117.5),
		"WestPalaceLane": Vector4(-63, -8.5, -188.5, -183.5),
		"WestGardenLane": Vector4(-63, -57, -183.5, -165),
	}
	for label in network:
		var b: Vector4 = network[label]
		_surface(roads, label, Vector2((b.x + b.y) * 0.5, (b.z + b.w) * 0.5),
				Vector2(b.y - b.x, b.w - b.z), 0.0, paving)

	_build_houses(Geometry.group(parent, "AdditionalFrontages"))
	var parks := Geometry.group(parent, "NeighbourhoodGardens")
	_garden(parks, Vector2(-72, 45), Vector2(21, 23), stone)
	_garden(parks, Vector2(-44, -59), Vector2(24, 19), stone)
	_garden(parks, Vector2(35, 38), Vector2(11, 23), stone)
	_garden(parks, Vector2(33, -148), Vector2(9, 25), stone)
	_garden(parks, Vector2(-41.8, -245), Vector2(7.8, 20), stone)
	_garden(parks, Vector2(75.5, -211), Vector2(12, 23), stone)


func _build_houses(parent: Node3D) -> void:
	var facade := Facades.new()
	var lots := [
		["WesternCorner", -65, -9, 90, 17, 8, 4, Facades.Kind.TENEMENT, "#b9bbb0"],
		["Grocer", -65, 11, 90, 15, 8, 2, Facades.Kind.SHOP, "#d8b580"],
		["WestRental", -48, 4, -90, 18, 8, 5, Facades.Kind.TENEMENT, "#cbb298"],
		["WestMerchant", -47, 19, -90, 9, 9, 3, Facades.Kind.MERCHANT, "#c1c3a1"],
		["SouthwestCourt", -47, 49, -90, 23, 10, 4, Facades.Kind.TENEMENT, "#c8aa9d"],
		["SouthernRow", -25, 56, 0, 18, 10, 3, Facades.Kind.MERCHANT, "#d3c3a5"],
		["SouthernPrintworks", -41, 79, 180, 24, 10, 3, Facades.Kind.WAREHOUSE, "#a98370"],
		["SouthernTailor", -15, 78, 180, 15, 9, 2, Facades.Kind.SHOP, "#c5b596"],
		["QuayCustoms", 35.5, 5, -90, 14, 9, 3, Facades.Kind.CIVIC, "#d9c3a0"],
		["QuayMerchant", 35.5, 57, -90, 13, 9, 4, Facades.Kind.MERCHANT, "#c5c8ac"],
		["OuterBankRow", 81, 14, -90, 14, 9, 4, Facades.Kind.TENEMENT, "#cbaf9f"],
		["OuterBankWarehouse", 81, 36, -90, 19, 10, 2, Facades.Kind.WAREHOUSE, "#aa8b78"],
		["OuterBankSouthHouse", 80, 58, -90, 16, 8, 3, Facades.Kind.MERCHANT, "#c6c19d"],
		["WesternWorkshop", -65, -52, -90, 17, 6, 2, Facades.Kind.WAREHOUSE, "#b99881"],
		["WesternTenement", -80, -54, 90, 20, 10, 5, Facades.Kind.TENEMENT, "#c8bea8"],
		["WestNorthCorner", -60, -76, -90, 13, 10, 3, Facades.Kind.MERCHANT, "#ccac95"],
		["NorthernMarket", 49, -109, -90, 22, 8, 3, Facades.Kind.SHOP, "#c5b294"],
		["NorthernCornerTenement", 49, -137, -90, 25, 8, 5, Facades.Kind.TENEMENT, "#d6c6a8"],
		["MillionnayaCorner", 50, -171, -90, 21, 9, 4, Facades.Kind.MERCHANT, "#c6b6a4"],
		["AdmiraltyWestRow", -73, -186.8, 90, 10, 10, 3, Facades.Kind.MERCHANT, "#d0bd99"],
		["MuseumLaneHouse", 81, -236, 180, 13, 11, 4, Facades.Kind.MERCHANT, "#d1b6a1"],
	]
	for lot in lots:
		facade.add_building(parent, lot[0], Vector2(lot[1], lot[2]), lot[3],
				Vector2(lot[4], lot[5]), lot[6], lot[7], Color(lot[8]))


func _garden(parent: Node3D, center: Vector2, size: Vector2, stone: Material) -> void:
	var garden := Geometry.group(parent, "Garden", Vector3(center.x, 0, center.y))
	_surface(garden, "GravelCourt", Vector2.ZERO, size, 0.04, stone)
	var bed_size := Vector2(size.x - 2.2, size.y * 0.33)
	for side in [-1, 1]:
		var position := Vector2(0, side * size.y * 0.24)
		_surface(garden, "GrassBed", position, bed_size, 0.105, lawn)
		for x in [-0.28, 0.28]:
			_tree(garden, Vector3(x * bed_size.x, 0.105, position.y))
		_prop(garden, BENCH, Vector3(side * (size.x * 0.5 - 1.25), 0.04, side * 1.25), side * 90.0)
	_prop(garden, LAMP, Vector3(size.x * 0.5 - 0.65, 0.04, size.y * 0.5 - 0.65))


func _surface(parent: Node3D, label: String, center: Vector2, size: Vector2,
		height: float, material: Material) -> void:
	Geometry.box(parent, label, Vector3(center.x, height - 0.09, center.y),
			Vector3(size.x, 0.18, size.y), material, true)


func _prop(parent: Node3D, scene: PackedScene, center: Vector3, yaw := 0.0) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = center
	prop.rotation_degrees.y = yaw
	parent.add_child(prop, true)


func _tree(parent: Node3D, center: Vector3) -> void:
	var trunk := CylinderMesh.new()
	trunk.radial_segments = 7
	trunk.bottom_radius = 0.21
	trunk.top_radius = 0.12
	trunk.height = 2.7
	Geometry.mesh_part(parent, "LindenTrunk", center + Vector3.UP * 1.35, trunk, bark)
	Geometry.collider(parent, "LindenTrunk", center + Vector3.UP * 1.25, Vector3(0.38, 2.5, 0.38))
	var crown := SphereMesh.new()
	crown.radial_segments = 9
	crown.rings = 5
	crown.radius = 1.54
	crown.height = 3.2
	Geometry.mesh_part(parent, "LindenCrown", center + Vector3.UP * 3.25, crown, leaves)
