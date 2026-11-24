@tool
extends RefCounted

const Geometry = preload("res://scripts/world/district_geometry.gd")
const Facades = preload("res://scripts/world/district_facades.gd")
const Courtyards = preload("res://scripts/world/petersburg_courtyards.gd")
const LAMP := preload("res://scenes/world/props/gas_lamp.tscn")
const BENCH := preload("res://scenes/world/props/wooden_bench.tscn")

var brick := Geometry.solid_material(Color("#a56850"))
var produce := [Geometry.solid_material(Color("#a14030")), Geometry.solid_material(Color("#747e42")), Geometry.solid_material(Color("#c29453"))]
var stucco := Geometry.solid_material(Color("#baa48a"))
var stone_trim := Geometry.solid_material(Color("#cdbb9d"))
var wood := Geometry.solid_material(Color("#564434"))
var iron := Geometry.solid_material(Color("#414845"))
var grass := Geometry.solid_material(Color("#6b7450"))
var window := Geometry.solid_material(Color("#444843"))
var box := BoxMesh.new()


func build(parent: Node3D, paving: Material, stone: Material) -> void:
	var blocks := Geometry.group(parent, "UrbanBlocks")
	_streets(Geometry.group(blocks, "NewStreets"), paving, stone)
	var courts := Courtyards.new()
	courts.build_rental_block(blocks, "QuayRentalCourt", Vector2(72, -108.5), 90, 3, paving)
	courts.build_rental_block(blocks, "WorkshopRentalCourt", Vector2(-72, 72), 90, 4, paving)
	_market(Geometry.group(blocks, "StoneMarket", Vector3(-49.25, 0, -224.3)), paving)
	_firehouse(Geometry.group(blocks, "FireWatchHouse", Vector3(36.5, 0, 80)))
	_quay_yard(Geometry.group(blocks, "QuayServiceYard", Vector3(76, 0, -67)), paving, stone)
	_garden(Geometry.group(blocks, "IsaacWestGarden", Vector3(-62, 0, -172.5)), Vector2(9, 16), stone)
	_garden(Geometry.group(blocks, "SouthernGarden", Vector3(16, 0, 79)), Vector2(15, 13), stone)
	_garden(Geometry.group(blocks, "PalaceSidePromenade", Vector3(-49, 0, -272)), Vector2(24, 15), stone)
	_garden(Geometry.group(blocks, "OuterQuayGarden", Vector3(80, 0, 79)), Vector2(15, 14), stone)
	_frontages(blocks)
	_rebuild_west_blocks(blocks, paving, stone)
	_southwest_corner(blocks, stone)


func _rebuild_west_blocks(parent: Node3D, paving: Material, stone: Material) -> void:
	var facades := Facades.new()
	var arches := Courtyards.new()
	var west := Geometry.group(parent, "WesternResidentialBlock")
	# Rectangles use west/north/east/south bounds. Shared edges are party walls.
	_lot(facades, west, "CrossStreetHouse", Vector4(-52.6, -20, -33.4, -12), 180, 4, "#c8b89d")
	_lot(facades, west, "WestStreetTenement", Vector4(-52.6, -12, -45.35, 2), -90, 5, "#bdad98")
	_lot(facades, west, "WestStreetMerchant", Vector4(-52.6, 2, -45.35, 17), -90, 3, "#c9ad91", true)
	_lot(facades, west, "LaneTenement", Vector4(-40.65, -12, -33.4, 5), 90, 4, "#c8aea1")
	_lot(facades, west, "LaneLodgings", Vector4(-40.65, 5, -33.4, 17), 90, 3, "#b3b69e")
	_lot(facades, west, "SouthWestReturn", Vector4(-52.6, 17, -46.19, 24), 0, 4, "#b9b49b")
	_lot(facades, west, "SouthEastReturn", Vector4(-39.81, 17, -33.4, 24), 0, 4, "#c5b29b")
	arches.add_passage(west, "LinkStreetArch", Vector2(-43, 20.5), 0, 4, 7)
	_slab(west, "WestCourt", Vector2(-43, 6.5), Vector2(4.7, 35), 0.024, paving)
	_slab(west, "WestBlockFootway", Vector2(-53.3, 2.5), Vector2(1.4, 45), 0.044, stone)
	_slab(west, "LaneWestFootway", Vector2(-32.7, 2.5), Vector2(1.4, 45), 0.044, stone)
	_slab(west, "LinkStreetFootway", Vector2(-43, 24.5), Vector2(19.2, 1), 0.040, stone)

	var main := Geometry.group(parent, "MainStreetWesternBlock")
	_lot(facades, main, "CrossingCorner", Vector4(-24.9, -20, -7, -12), 180, 4, "#cdbda2", true)
	_lot(facades, main, "NevskyDraper", Vector4(-14, -12, -7, 4), 90, 5, "#bfad9c", true)
	_lot(facades, main, "NevskyHaberdasher", Vector4(-14, 4, -7, 18), 90, 4, "#c7aa99", true)
	_lot(facades, main, "LaneShop", Vector4(-24.9, -12, -18.4, 6.31), -90, 4, "#d0bc9b", true)
	arches.add_passage(main, "BaranovCourtArch", Vector2(-21.65, 9.5), -90, 4, 6.5)
	_lot(facades, main, "LaneReturn", Vector4(-24.9, 12.69, -18.4, 18), -90, 4, "#b5baa5")
	_lot(facades, main, "SouthCourtFront", Vector4(-24.9, 18, -7, 23.5), 0, 4, "#cfb69d")
	_slab(main, "NevskyWellCourt", Vector2(-16.2, 3), Vector2(4.4, 30), 0.024, paving)
	_slab(main, "LaneEastFootway", Vector2(-25.45, 2.5), Vector2(1.1, 45), 0.044, stone)
	_slab(main, "NevskyWestFootway", Vector2(-5.5, 22.5), Vector2(3, 5), 0.065, stone)
	_slab(main, "SouthBlockFootway", Vector2(-15.95, 24.25), Vector2(17.9, 1.5), 0.044, stone)


func _lot(facades: RefCounted, parent: Node3D, title: String, bounds: Vector4,
		yaw: float, floors: int, tint: String, retail := false) -> void:
	var dimensions := Vector2(bounds.z - bounds.x, bounds.w - bounds.y)
	if absf(yaw) == 90.0:
		dimensions = Vector2(dimensions.y, dimensions.x)
	var kind := Facades.Kind.SHOP if retail else Facades.Kind.TENEMENT
	facades.add_building(parent, title, Vector2((bounds.x + bounds.z) / 2, (bounds.y + bounds.w) / 2),
			yaw, dimensions, floors, kind, Color(tint))


func _southwest_corner(parent: Node3D, stone: Material) -> void:
	var corner := Geometry.group(parent, "SouthwesternCornerGap")
	Facades.new().add_polygon_building(corner, "ChamferedMerchantHouse", PackedVector2Array([
		Vector2(-77, 18.5), Vector2(-61.3, 18.5), Vector2(-61.3, 29.1),
		Vector2(-64, 31.8), Vector2(-77, 31.8),
	]), 10.9, 3, Color("#c9ac91"), Color("#555c57"), 2.2, [1, 2, 3])
	_slab(corner, "MerchantFootway", Vector2(-60.65, 24.15), Vector2(1.3, 11.3), 0.045, stone)
	_slab(corner, "GardenApproach", Vector2(-70, 32.65), Vector2(14, 1.7), 0.045, stone)


func _streets(parent: Node3D, paving: Material, stone: Material) -> void:
	# Rectangles reference the existing main, palace, and quay streets.
	var roads := {
		"IsaacGardenLane": Vector4(-86, -76.5, -98.5, -93.5),
		"IsaacGardenCross": Vector4(-76.5, -54, -98.5, -93.5),
		"MarketStreet": Vector4(-58, -53, -202, -188.5),
		"MarketToPalace": Vector4(-53, -36, -202, -197),
		"PalaceWestStreet": Vector4(-40, -36, -265, -202),
		"RentalCourtApproach": Vector4(-69, -63, -232.5, -229),
		"WestPalaceLateral": Vector4(-69, -40, -229, -224),
		"RentalServiceLane": Vector4(-69, -49, -268, -263.5),
		"QuayCourtApproach": Vector4(44, 56.5, -124.2, -120.35),
		"QuayCourtForecourt": Vector4(53.25, 56.5, -120.35, -107),
		"OuterServiceLane": Vector4(87.5, 89.1, -111, -93),
		"SouthwestCourtLink": Vector4(-56.5, -53.5, 71, 74),
		"WorkshopRearLane": Vector4(-89.15, -87.5, 72, 87.2),
		"WorkshopServiceLink": Vector4(-89.15, -56.5, 87.2, 89),
		"OuterQuayGardenAccess": Vector4(68, 74, 70, 78),
	}
	for label in roads:
		var rect: Vector4 = roads[label]
		_slab(parent, label, Vector2((rect.x + rect.y) * 0.5, (rect.z + rect.w) * 0.5),
				Vector2(rect.y - rect.x, rect.w - rect.z), 0.025, paving)
	_slab(parent, "MarketForecourt", Vector2(-47, -234), Vector2(21, 3), 0.035, stone)
	_slab(parent, "WestPalaceFootway", Vector2(-42, -232.5), Vector2(4, 50), 0.05, stone)
	_slab(parent, "StationForecourt", Vector2(35, 73), Vector2(17, 4), 0.04, stone)


func _frontages(parent: Node3D) -> void:
	var facades := Facades.new()
	var lots := [
		["MarketCorner", -73, -71.3, 90, 13, 8, 3, "#c6b695"],
		["GardenFrontage", -85, -239, 90, 13, 6, 4, "#c4ab92"],
		["WestBoundaryFrontage", -81, -272, 90, 18, 9, 5, "#b7ab92"],
		["PalaceServiceHouse", -53, -285, 0, 14, 6, 3, "#bda78c"],
		["GardenGateHouse", -79, -89, 0, 11, 7, 2, "#c6b398"],
		["IsaacWestFrontage", -17, -85, 90, 10, 8, 4, "#bdb196"],
		["AdmiraltyBackLane", -25, -76, 0, 14, 7, 4, "#c5ac95"],
		["QuayLodging", 85, -201, 180, 7, 6, 3, "#beaa94"],
		["QuayEastHouse", 80, -223.8, -90, 7, 11, 4, "#b3b197"],
		["CanalNorthEnd", 32, -92, 180, 10, 5.3, 3, "#baa98b"],
		["WestCrossingFrontage", -82, -34, 0, 12, 7, 3, "#d0b68e"],
		["WestSideWorkshop", -82, -8, 90, 22, 9, 3, "#b99983"],
		["WestSideLodgings", -82, 19, 90, 21, 10, 4, "#c8b494"],
		["SouthWestCorner", -83, 32, 0, 10, 3.5, 3, "#b8a78f"],
		["InnerCanalNorthHouse", 33, -78, 180, 14, 8, 4, "#c0ae94"],
		["InnerCanalCourtyardHouse", 31, -108, 90, 15, 10, 4, "#cbbba3"],
		["WestGardenRow", -43, -72, 180, 19, 8, 4, "#c9ad8d"],
		["WestAdmiraltyWorkshop", -72, -278, 90, 15, 8, 2, "#bca586"],
		["SouthStreetCorner", -27, 36, 180, 13, 8, 4, "#c4b497"],
	]
	for lot in lots:
		var kind := Facades.Kind.TENEMENT if int(lot[6]) >= 4 else Facades.Kind.MERCHANT
		facades.add_building(parent, lot[0], Vector2(lot[1], lot[2]), lot[3], Vector2(lot[4], lot[5]),
				lot[6], kind, Color(lot[7]))


func _market(market: Node3D, paving: Material) -> void:
	_slab(market, "MarketPassage", Vector2(0, 0), Vector2(25, 17), 0.038, paving)
	for side in [-1, 1]:
		var row := Geometry.group(market, "MerchantGallery", Vector3(side * 9.5, 0, 0))
		Geometry.box(row, "BrickHall", Vector3(side * 1.25, 2.0, 0),
				Vector3(4.5, 4.0, 15.9), stucco, true)
		Geometry.box(row, "GalleryRoof", Vector3(0, 4.11, 0),
				Vector3(7.26, 0.33, 17.25), stone_trim)
		var pilasters: Array[Transform3D] = []
		var signboards: Array[Transform3D] = []
		var arches: Array[Transform3D] = []
		for i in 6:
			var z := -7.4 + i * 2.95
			pilasters.append(Geometry.box_transform(Vector3(-side * 3.25, 1.92, z), Vector3(0.5, 3.84, 0.46)))
			Geometry.collider(row, "GalleryPier", Vector3(-side * 3.25, 1.92, z), Vector3(0.5, 3.84, 0.46))
			signboards.append(Geometry.box_transform(Vector3(-side * 1.02, 2.88, z), Vector3(0.14, 0.28, 1.45)))
		for i in 5:
			var center_z := -5.925 + i * 2.95
			for j in 9:
				var angle := PI * j / 8.0
				var center := Vector3(-side * 3.25, 2.84 + sin(angle) * 1.07,
						center_z + cos(angle) * 1.32)
				var tangent := atan2(1.32 * sin(angle), 1.07 * cos(angle))
				var basis := Basis(Vector3.RIGHT, tangent).scaled_local(Vector3(0.48, 0.48, 0.24))
				arches.append(Transform3D(basis, center))
		Geometry.batch(row, "ArcadeVoussoirs", box, stone_trim, arches)
		Geometry.batch(row, "StonePiers", box, stone_trim, pilasters)
		Geometry.batch(row, "ShopfrontHeaders", box, wood, signboards)
		for i in 5:
			var z := -5.9 + i * 2.95
			Geometry.box(row, "Counter", Vector3(-side * 1.86, 0.61, z), Vector3(1.16, 1.22, 1.63), wood, true)
			_stock_counter(row, Vector3(-side * 1.86, 1.22, z), i)
	for side: float in [-1.0, 1.0]:
		Geometry.box(market, "FairSignPost", Vector3(side * 2.14, 1.68, 7.85),
				Vector3(0.14, 3.36, 0.14), wood, true)
	Geometry.box(market, "FairSignBoard", Vector3(0, 3.14, 7.87), Vector3(4.43, 0.46, 0.12), wood)
	var title := Label3D.new()
	title.text = "ЯРМАРКА"
	title.font_size = 44
	title.pixel_size = 0.008
	title.position = Vector3(0, 3.14, 7.95)
	title.modulate = Color("#edca8e")
	market.add_child(title)
	_prop(market, LAMP, Vector3(-3.5, 0.04, 6.1))
	_prop(market, LAMP, Vector3(3.5, 0.04, -6.1))


func _stock_counter(row: Node3D, at: Vector3, index: int) -> void:
	Geometry.box(row, "CounterCloth", at + Vector3.UP * 0.014, Vector3(1.10, 0.028, 1.53), produce[index % 3])
	Geometry.box(row, "ProduceTray", at + Vector3(0, 0.064, -0.26), Vector3(0.79, 0.10, 0.58), wood)
	var fruit := SphereMesh.new()
	fruit.radial_segments = 7
	fruit.rings = 3
	var heap: Array[Transform3D] = []
	for i in 12:
		heap.append(Geometry.box_transform(at + Vector3(-0.27 + (i % 4) * 0.177, 0.16 + (i % 3) * 0.014,
				-0.44 + (i / 4) * 0.15), Vector3(0.14, 0.17, 0.14)))
	Geometry.batch(row, "ApplesOrRoots", fruit, produce[(index + 1) % 3], heap)
	for i in 3:
		Geometry.box(row, "FoldedGoods", at + Vector3(0.02, 0.06 + i * 0.055, 0.43), Vector3(0.62, 0.057, 0.39), produce[(i + index) % 3])


func _firehouse(station: Node3D) -> void:
	Geometry.box(station, "StationMasonry", Vector3(0, 3.27, 0), Vector3(16, 6.55, 9), brick, true)
	Geometry.box(station, "Entablature", Vector3(0, 6.31, 0), Vector3(16.4, 0.49, 9.4), stone_trim)
	var parts: Array[Transform3D] = []
	for x in [-5.0, 0.0, 5.0]:
		Geometry.box(station, "EngineBayDoor", Vector3(x, 1.78, -4.61), Vector3(2.65, 3.57, 0.21), wood)
		Geometry.box(station, "EngineBayLintel", Vector3(x, 3.60, -4.66), Vector3(3.05, 0.35, 0.31), stone_trim)
	var casings: Array[Transform3D] = []
	for yaw in [0, 90, 180, 270]:
		var yaw_basis := Basis(Vector3.UP, deg_to_rad(yaw))
		var face := 4.5 if yaw % 180 == 0 else 8.0
		var offsets := [-5.0, 0.0, 5.0] if yaw % 180 == 0 else [-2.65, 0.0, 2.65]
		for offset: float in offsets:
			for y in ([5.1] if yaw == 180 else [2.31, 5.1]):
				var orientation := Transform3D(yaw_basis, Vector3.ZERO)
				casings.append(orientation * Geometry.box_transform(Vector3(offset, y, face + 0.045), Vector3(1.75, 1.56, 0.11)))
				parts.append(orientation * Geometry.box_transform(Vector3(offset, y, face + 0.14), Vector3(1.46, 1.26, 0.10)))
	Geometry.batch(station, "StoneWindowSurrounds", box, stone_trim, casings)
	Geometry.batch(station, "UpperWindows", box, window, parts)
	Geometry.box(station, "FloorStringcourse", Vector3(0, 4.28, 0), Vector3(16.2, 0.16, 9.19), stone_trim)
	var sign_label := Label3D.new()
	sign_label.name = "PeriodStationSign"
	sign_label.position = Vector3(0, 5.90, -4.61)
	sign_label.rotation_degrees.y = 180
	sign_label.text = "ПОЖАРНАЯ ЧАСТЬ"
	sign_label.font_size = 40
	sign_label.pixel_size = 0.0065
	sign_label.outline_size = 0
	sign_label.modulate = Color("#f1d4a4")
	station.add_child(sign_label)
	Geometry.box(station, "Watchtower", Vector3(0, 10.65, 0.35), Vector3(4.25, 8.4, 4.2), brick)
	Geometry.box(station, "WatchBalcony", Vector3(0, 14.72, 0.35), Vector3(5.15, 0.31, 5.05), stone_trim)
	Geometry.box(station, "LanternStage", Vector3(0, 16.04, 0.35), Vector3(3.21, 2.45, 3.21), stucco)
	for yaw in [0, 90, 180, 270]:
		var side := Geometry.group(station, "LookoutWindow", Vector3(0, 16.06, 0.35))
		side.rotation_degrees.y = yaw
		Geometry.box(side, "DeepWindow", Vector3(0, 0, 1.62), Vector3(1.83, 1.51, 0.13), window)
	var rails: Array[Transform3D] = []
	for side in [-1, 1]:
		rails.append(Geometry.box_transform(Vector3(side * 2.40, 15.46, 0.35), Vector3(0.08, 0.10, 4.84)))
		rails.append(Geometry.box_transform(Vector3(0, 15.46, 0.35 + side * 2.40), Vector3(4.84, 0.10, 0.08)))
		for i in 7:
			var offset := -2.40 + 0.80 * i
			rails.append(Geometry.box_transform(Vector3(side * 2.40, 15.12, 0.35 + offset), Vector3(0.07, 0.68, 0.07)))
			if i > 0 and i < 6:
				rails.append(Geometry.box_transform(Vector3(offset, 15.12, 0.35 + side * 2.40), Vector3(0.07, 0.68, 0.07)))
	Geometry.batch(station, "IronBalconyRail", box, iron, rails)
	var cap := CylinderMesh.new()
	cap.radial_segments = 4
	cap.bottom_radius = 2.78
	cap.top_radius = 0.13
	cap.height = 2.05
	Geometry.mesh_part(station, "WatchtowerRoof", Vector3(0, 18.27, 0.35), cap, iron).rotation_degrees.y = 45


func _quay_yard(yard: Node3D, paving: Material, stone: Material) -> void:
	_slab(yard, "ServiceCourt", Vector2(0, 0), Vector2(24, 28), 0.035, paving)
	_slab(yard, "QuayAccess", Vector2(-9, 0), Vector2(7, 30), 0.047, stone)
	var facade := Facades.new()
	facade.add_building(yard, "WarehouseNorth", Vector2(3.5, -10), -90, Vector2(9, 12), 2,
			Facades.Kind.WAREHOUSE, Color("#a27a67"))
	facade.add_building(yard, "WarehouseSouth", Vector2(3.5, 9), -90, Vector2(10, 12), 3,
			Facades.Kind.WAREHOUSE, Color("#aa846d"))
	for z in [-5.5, 4.5]:
		Geometry.box(yard, "ShippingCrate", Vector3(3.5, 0.40, z), Vector3(0.96, 0.8, 0.92), wood, true)
	_prop(yard, LAMP, Vector3(-4, 0.04, -12))


func _garden(garden: Node3D, size: Vector2, stone: Material) -> void:
	_slab(garden, "GravelWalk", Vector2.ZERO, size, 0.018, stone)
	for side in [-1, 1]:
		var bed := Vector2(side * size.x * 0.31, 0)
		_slab(garden, "PlantingBed", bed, Vector2(size.x * 0.31, size.y - 2.2), 0.08, grass)
		for fraction in [-0.29, 0.0, 0.29]:
			var position := Vector3(bed.x, 0.08, fraction * size.y)
			var trunk := CylinderMesh.new()
			trunk.height = 2.2
			trunk.top_radius = 0.10
			trunk.bottom_radius = 0.19
			trunk.radial_segments = 7
			Geometry.mesh_part(garden, "Trunk", position + Vector3.UP * 1.1, trunk, wood)
			Geometry.collider(garden, "Trunk", position + Vector3.UP, Vector3(0.36, 2, 0.36))
			var crown := SphereMesh.new()
			crown.radius = 1.35
			crown.height = 3.3
			crown.radial_segments = 9
			crown.rings = 5
			Geometry.mesh_part(garden, "Crown", position + Vector3.UP * 3.1, crown, grass)
	_prop(garden, BENCH, Vector3(0, 0.018, size.y * 0.30))
	_prop(garden, LAMP, Vector3(size.x * 0.15, 0.018, -size.y * 0.39))


func _slab(parent: Node3D, label: String, center: Vector2, dimensions: Vector2,
		height: float, material: Material) -> void:
	Geometry.box(parent, label, Vector3(center.x, height - 0.12, center.y),
			Vector3(dimensions.x, 0.24, dimensions.y), material, true)


func _prop(parent: Node3D, scene: PackedScene, center: Vector3) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = center
	parent.add_child(prop, true)
