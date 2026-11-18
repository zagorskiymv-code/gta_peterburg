extends Node3D

const Citizen = preload("res://scripts/npc/citizen_npc.gd")
const Outfit = preload("res://scripts/npc/citizen_wardrobe.gd").Outfit
const CITIZEN_SCENE := preload("res://scenes/npc/citizen_npc.tscn")

# X/Z waypoints in district metres. Each circuit serves its own stretch of pavement.
func _ready() -> void:
	var avenue := _zone("Nevsky")
	_place(avenue, "NevskyClerk", Outfit.CLERK, 1.38, 1.5,
			[Vector2(9.1,-56.2), Vector2(8.6,-65), Vector2(10.1,-71)])
	_place(avenue, "NevskyShopper", Outfit.TOWNSWOMAN, 1.11, 2.7,
			[Vector2(-9.3,-57), Vector2(-9.5,-70), Vector2(-10.3,-77)])
	_place(avenue, "NevskyGentleman", Outfit.ELDER, 0.98, 3.3,
			[Vector2(9.4,-131), Vector2(9.5,-141), Vector2(9.3,-149)])

	var singer := _zone("Singer")
	_place(singer, "SingerCustomer", Outfit.MERCHANT, 1.28, 3.7,
			[Vector2(9.6,-78), Vector2(9.65,-85), Vector2(10.2,-90)])
	_place(singer, "SingerClerk", Outfit.CLERK, 1.41, 2.4,
			[Vector2(-9.3,-84), Vector2(-9.3,-92), Vector2(-9.7,-97)])

	var canal := _zone("Canal")
	_place(canal, "InnerQuayWalker", Outfit.TOWNSWOMAN, 1.02, 2.9,
			[Vector2(45.6,18), Vector2(45.7,29), Vector2(45.3,44)])
	_place(canal, "OuterQuayWalker", Outfit.ELDER, 0.94, 3.4,
			[Vector2(65.1,-73), Vector2(65.8,-62), Vector2(65.4,-47)])

	var holland := _zone("NewHolland")
	_place(holland, "WarehouseWorker", Outfit.WORKER, 1.33, 1.6,
			[Vector2(25.2,115), Vector2(24.9,106), Vector2(24.2,104)])
	_place(holland, "WarehouseClerk", Outfit.CLERK, 1.26, 2.2,
			[Vector2(36.4,104), Vector2(36.5,110), Vector2(36.3,116)])

	var market := _zone("Market")
	_place(market, "MarketVendor", Outfit.VENDOR, 0.98, 4.7,
			[Vector2(-43.85,-228), Vector2(-43.85,-224.3), Vector2(-43.85,-220.5)])
	_place(market, "MarketShopper", Outfit.MERCHANT, 1.17, 3.4,
			[Vector2(-54.3,-219.5), Vector2(-45.45,-224.3), Vector2(-54.55,-228.5)])

	for index in 3:
		var vendor: Citizen = CITIZEN_SCENE.instantiate()
		vendor.name = "FairVendor%d" % (index + 1)
		vendor.outfit = Outfit.VENDOR
		vendor.variation_seed = index + 12
		vendor.crowd_lod = true
		vendor.position = Vector3(-41.60 if index == 1 else -56.8, 0.12, -228.72 + index * 2.95)
		vendor.rotation.y = PI * 0.5 if index == 1 else -PI * 0.5
		market.add_child(vendor)

	var south := _zone("SouthernStreets")
	_place(south, "ResidentialWorker", Outfit.WORKER, 1.37, 2.1,
			[Vector2(5.05,30), Vector2(5.02,42), Vector2(5.05,58)])

	var garden := _zone("AlexanderGarden")
	_place(garden, "GardenVisitor", Outfit.ELDER, 0.96, 4.0,
			[Vector2(-79.9,-240.3), Vector2(-75.5,-240.3), Vector2(-71.3,-240.3)])

	# Short lanes leave gaps at shop doors and crossings. No walker changes sides of the avenue.
	_fill_sidewalks(avenue)
	_extra(canal, "QuayClerk", Outfit.CLERK, [Vector2(45.8,-79), Vector2(45.7,-66)])
	_extra(canal, "QuayMerchant", Outfit.MERCHANT, [Vector2(65.2,-16), Vector2(65.3,5)])
	_extra(canal, "QuayWorker", Outfit.WORKER, [Vector2(45.5,69), Vector2(45.5,82)])
	_extra(holland, "WarehousePorter", Outfit.WORKER, [Vector2(28.1,108), Vector2(28.1,116)])
	_extra(holland, "WarehouseBuyer", Outfit.MERCHANT, [Vector2(32.2,103), Vector2(34.4,103), Vector2(33.0,105.4)])
	_extra(market, "WestStallKeeper", Outfit.VENDOR, [Vector2(-54.8,-231.2), Vector2(-52.9,-230.8)])
	_extra(market, "EastStallCustomer", Outfit.TOWNSWOMAN, [Vector2(-46.2,-218.1), Vector2(-46.4,-216.4)])
	_extra(south, "SouthSideClerk", Outfit.CLERK, [Vector2(-5.45,38), Vector2(-5.5,57)])
	_extra(south, "SouthSideElder", Outfit.ELDER, [Vector2(-5.3,66), Vector2(-5.3,73)])
	_extra(south, "SouthSideMerchant", Outfit.MERCHANT, [Vector2(5.75,66), Vector2(5.65,74)])
	_extra(garden, "GardenMerchant", Outfit.MERCHANT, [Vector2(-62.6,-244.4), Vector2(-62.8,-242.4)])
	_extra(garden, "GardenStroller", Outfit.TOWNSWOMAN, [Vector2(-59.5,-240.3), Vector2(-53.5,-240.3)])


func _fill_sidewalks(avenue: Node3D) -> void:
	var lanes: Array[Vector3] = [
		Vector3(8.65,-36,-43), Vector3(9.0,-44.5,-51),
		Vector3(10.25,-57,-68), Vector3(8.6,-72,-77),
		Vector3(8.75,-80,-89), Vector3(8.75,-91.7,-93.15),
		Vector3(9.35,-105,-112), Vector3(9.25,-113.7,-116.65),
		Vector3(9.35,-125.2,-129), Vector3(8.4,-133,-147),
		Vector3(-8.6,-36,-43), Vector3(-9.4,-44.5,-52),
		Vector3(-8.55,-55,-67), Vector3(-8.5,-70,-79),
		Vector3(-10.25,-83,-91.7), Vector3(-9.3,-107,-114),
		Vector3(-8.6,-116,-123), Vector3(-9.3,-125,-131),
		Vector3(-9.3,-133,-139), Vector3(-9.3,-141,-148),
		Vector3(-9.9,-151,-157),
	]
	var outfits := [Outfit.CLERK, Outfit.TOWNSWOMAN, Outfit.MERCHANT, Outfit.WORKER, Outfit.ELDER]
	for index in lanes.size():
		var lane := lanes[index]
		var points: Array[Vector2] = [Vector2(lane.x, lane.y), Vector2(lane.x, lane.z)]
		if index % 2 == 1:
			points.reverse()
		_extra(avenue, "AvenueWalker%02d" % (index + 1), outfits[index % outfits.size()], points)


func _extra(zone: Node3D, label: String, outfit: Outfit, points: Array[Vector2]) -> void:
	var style := absi(hash(label))
	var speed := 0.94 + (style % 41) * 0.01
	if outfit == Outfit.ELDER:
		speed *= 0.88
	_place(zone, label, outfit, speed, 2.0 + (style % 13) * 0.17, points, style)


func _zone(label: String) -> Node3D:
	var zone := Node3D.new()
	zone.name = label
	add_child(zone)
	return zone


func _place(zone: Node3D, label: String, outfit: Outfit, speed: float, dwell: float, points: Array[Vector2], variant := 0) -> void:
	var path := Path3D.new()
	path.name = label + "Walk"
	path.curve = Curve3D.new()
	for point in points:
		path.curve.add_point(Vector3(point.x, 0, point.y))
	zone.add_child(path)

	# Instantiate once at scene load. The activity radius pauses motion without hiding or removing anyone.
	var npc: Citizen = CITIZEN_SCENE.instantiate()
	npc.name = label
	npc.position = path.curve.get_point_position(0) + Vector3.UP * 0.16
	var heading := points[1] - points[0]
	npc.rotation.y = atan2(-heading.x, -heading.y)
	npc.outfit = outfit
	npc.route = path
	npc.walk_speed = speed
	npc.wait_time = dwell
	npc.activity_radius = 100.0
	npc.crowd_lod = true
	npc.variation_seed = variant
	zone.add_child(npc)
