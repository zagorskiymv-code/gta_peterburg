@tool
extends Node3D

const MissionManager = preload("res://scripts/systems/mission_manager.gd")
const WALK_TEST := preload("res://resources/missions/walk_test.tres")
const OPENING_MISSION := preload("res://resources/missions/again_twenty_five.tres")
const CAR_MISSION := preload("res://resources/missions/wonder_on_wheels.tres")
const BARANOV_MISSION := preload("res://resources/missions/the_right_man.tres")
const HORSE_MISSION := preload("res://resources/missions/a_horse_not_a_bicycle.tres")
const DEAL_MISSION := preload("res://resources/missions/a_profitable_deal.tres")
const CHASE_MISSION := preload("res://resources/missions/the_constable_never_sleeps.tres")
const ConstableChase = preload("res://scripts/world/constable_chase.gd")
const HorseDelivery = preload("res://scripts/world/horse_delivery.gd")
const BARANOV := preload("res://scenes/npc/baranov.tscn")
const PAUSE_MENU := preload("res://scenes/ui/pause_menu.tscn")
const HUD := preload("res://scenes/ui/district_hud.tscn")
const Opening = preload("res://scripts/world/new_holland_opening.gd")
@export var play_opening := false
@export var resume_campaign := false

const Geometry = preload("res://scripts/world/district_geometry.gd")
const Infill = preload("res://scripts/world/petersburg_infill.gd")
const Courtyards = preload("res://scripts/world/petersburg_courtyards.gd")
const UrbanBlocks = preload("res://scripts/world/petersburg_urban_blocks.gd")
const Bridge = preload("res://scripts/world/arched_bridge.gd")
const WaterDeath = preload("res://scripts/world/water_death_zone.gd")
const Riding = preload("res://scripts/vehicles/district_riding.gd")
const Driving = preload("res://scripts/vehicles/district_driving.gd")
const Traffic = preload("res://scripts/systems/district_traffic.gd")
const Edges = preload("res://scripts/world/district_edges.gd")
const BackgroundCity = preload("res://scripts/world/background_city.gd")
const Reconstruction = preload("res://scripts/world/city_reconstruction.gd")
const Nevsky = preload("res://scripts/world/nevsky_avenue.gd")
const Landmarks = preload("res://scripts/world/petersburg_landmarks.gd")
const StreetDetails = preload("res://scripts/world/street_details.gd")
const Facades = preload("res://scripts/world/district_facades.gd")
const COBBLE := preload("res://materials/cobblestone.gdshader")
const WATER := preload("res://materials/canal_water.gdshader")
const LAMP := preload("res://scenes/world/props/gas_lamp.tscn")
const BENCH := preload("res://scenes/world/props/wooden_bench.tscn")

const LAND_EDGE := 90.0
const WEST_BANK := 48.0
const EAST_BANK := 62.0
const CROSS_STREET := -27.0
const BRIDGE_HALF_WIDTH := 5.0

var paving := ShaderMaterial.new()
var turf := Geometry.solid_material(Color("#747b59"))
var ground := Geometry.solid_material(Color("#8b867b"))
var flagstone := Geometry.solid_material(Color("#ada394"))
var masonry := Geometry.solid_material(Color("#8b857a"))
var coping := Geometry.solid_material(Color("#b5a899"))
var iron := Geometry.solid_material(Color("#333c38"))
var wood := Geometry.solid_material(Color("#584333"))
var unit_box := BoxMesh.new()


func _ready() -> void:
	paving.shader = COBBLE
	var reconstruction := Reconstruction.new()
	_build_streets()
	_build_frontages()
	if play_opening:
		_place_workshop_signs()
	Landmarks.new().build($Landmarks, paving, flagstone, ground)
	Nevsky.new().build($NevskyProspekt, paving, flagstone)
	Infill.new().build($Infill, paving, flagstone)
	Courtyards.new().build($Infill, paving)
	UrbanBlocks.new().build($Infill, paving, flagstone)
	_build_square()
	_build_canal()
	_place_district_props()
	reconstruction.south($Infill,paving)
	reconstruction.quays($Canal)
	reconstruction.admiralty($Landmarks,paving)
	reconstruction.holland($Landmarks,paving)
	reconstruction.squares($Landmarks,paving)
	BackgroundCity.new().build(self)
	Edges.new().build(self, paving, flagstone)
	StreetDetails.new().build(self)
	if not Engine.is_editor_hint():
		var traffic := Traffic.new()
		traffic.name = "DistrictTraffic"
		add_child(traffic)
		traffic.configure($NevskyProspekt/Avenue, $NevskyProspekt/IsaacBypass)
		traffic.start_fleet()
		traffic.start_carriages()
		var driving := Driving.new()
		driving.name = "DistrictDriving"
		add_child(driving)
		driving.configure($PlayerSpawn/Player, $VehicleTrial/BenzVictoria)
		var riding := Riding.new()
		riding.name = "DistrictRiding"
		add_child(riding)
		riding.configure($PlayerSpawn/Player, $PalaceStables)
		var hud := HUD.instantiate()
		add_child(hud)
		hud.configure($PlayerSpawn/Player, driving, riding)
		var pause_menu := PAUSE_MENU.instantiate()
		add_child(pause_menu)
		pause_menu.configure(self, $PlayerSpawn/Player, hud.get_node("Layout/Minimap")._plan)
		var missions := MissionManager.new()
		missions.name = "MissionManager"
		add_child(missions)
		missions.configure(self, $PlayerSpawn/Player, hud, OPENING_MISSION if play_opening else WALK_TEST,
				func() -> Node3D:
					var car := driving.current_vehicle()
					return car if car else riding.mounted_transport(),
				play_opening)
		driving.transport_entered.connect(missions.transport_entered)
		driving.transport_exited.connect(missions.transport_exited)
		riding.transport_entered.connect(missions.transport_entered)
		if play_opening:
			missions.configure_story([CAR_MISSION, BARANOV_MISSION, HORSE_MISSION, DEAL_MISSION, CHASE_MISSION], pause_menu)
			var delivery := HorseDelivery.new()
			delivery.name = "HorseDelivery"
			add_child(delivery)
			delivery.build($PalaceStables)
			missions.objective_changed.connect(delivery.objective_changed)
			var contacts := Geometry.group(self, "StoryContacts")
			var baranov := BARANOV.instantiate() as CharacterBody3D
			baranov.position = Vector3(-25.34, -0.049, 9.5)
			baranov.rotation_degrees.y = 90.0
			contacts.add_child(baranov)
			var chase := ConstableChase.new()
			chase.name = "ConstableChase"
			add_child(chase)
			chase.configure(missions, $PlayerSpawn/Player)
			if resume_campaign:
				if missions.resume_story() == DEAL_MISSION.id:
					$PlayerSpawn.global_position = Vector3(26.4, 0.065, 108.1)
					$PlayerSpawn/Player.respawn_at($PlayerSpawn.global_position)
			else:
				var opening := Opening.new()
				opening.name = "NewHollandOpening"
				add_child(opening)
				opening.finished.connect(missions.start)
				opening.start(self, $PlayerSpawn, $PlayerSpawn/Player, hud, pause_menu)
		$Diagnostics/Fps.hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		$Diagnostics/Fps.visible = not $Diagnostics/Fps.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and $Diagnostics/Fps.visible:
		$Diagnostics/Fps.text = "FPS  %d" % Engine.get_frames_per_second()


func _slab(parent: Node3D, label: String, x1: float, x2: float, z1: float, z2: float,
		top: float, depth: float, material: Material, solid := true) -> void:
	var center := Vector3((x1 + x2) * 0.5, top - depth * 0.5, (z1 + z2) * 0.5)
	Geometry.box(parent, label, center, Vector3(x2 - x1, depth, z2 - z1), material, solid)


func _build_streets() -> void:
	var streets: Node3D = $Streets
	# Reserve the original block and the entire canal in the ground plan.
	_slab(streets, "WestGround", -90, -20, -90, 90, -0.05, 0.8, ground)
	_slab(streets, "NorthGround", -20, 20, -90, -20, -0.05, 0.8, ground)
	_slab(streets, "SouthGround", -20, 20, 20, 90, -0.05, 0.8, ground)
	_slab(streets, "InnerBankGround", 20, WEST_BANK, -90, 90, -0.05, 0.8, ground)
	_slab(streets, "OuterBankGround", EAST_BANK, 90, -90, 90, -0.05, 0.8, ground)
	_slab(streets, "MainSouth", -4, 4, 20, 76, 0, 0.09, paving)
	_slab(streets, "MainToCrossing", -4, 4, -22, -20, 0, 0.09, paving)
	_slab(streets, "CrossStreet", -77, WEST_BANK, -32, -22, 0, 0.09, paving)
	_slab(streets, "OuterBankStreet", EAST_BANK, 85, -32, -22, 0, 0.09, paving)
	_slab(streets, "Lane", -32, -26, -22, 25, 0, 0.09, paving)
	_slab(streets, "LaneToMain", -32, -4, 25, 31, 0, 0.09, paving)
	_slab(streets, "SouthWalkWest", -7, -4, 31, 76, 0.065, 0.16, flagstone)
	_slab(streets, "SouthWalkEast", 4, 7, 20, 76, 0.065, 0.16, flagstone)
	_slab(streets, "SquareApproach", 7, 39, -33, -32, 0.02, 0.10, flagstone)

	# Leave open junction mouths for the main axis, the western alley and the bridge.
	for walk: Vector4 in [
		Vector4(-76, -9, -34, -32), Vector4(-76, -60, -22, -20),
		Vector4(-54, -32, -22, -20), Vector4(-26, -7, -22, -20),
		Vector4(7, 40, -22, -20), Vector4(69, 86, -34, -32),
	]:
		_slab(streets, "CrossStreetFlagstones", walk.x, walk.y, walk.z, walk.w, 0.052, 0.14, flagstone)

	var boundary := Geometry.group(streets, "MasonryBoundary")
	Geometry.box(boundary, "BypassQuayWall", Vector3(-91.75, 0.62, -147.65), Vector3(0.52, 1.34, 111.3), masonry, true)
	Geometry.box(boundary, "QuayReturnNorth", Vector3(-90.65, 0.62, -203.26), Vector3(2.7, 1.34, 0.55), masonry, true)
	Geometry.box(boundary, "QuayReturnSouth", Vector3(-90.65, 0.62, -93.8), Vector3(2.7, 1.34, 0.55), masonry, true)
	_slab(streets, "BypassQuayGround", -92.0, -89.98, -203.53, -93.6, -0.05, 1.2, masonry)


func _build_frontages() -> void:
	var buildings: Node3D = $Buildings
	var facades := Facades.new()
	facades.add_building(buildings, "MainStreetSixthHouse", Vector2(11.5, 14), -90, Vector2(10, 8), 3, Facades.Kind.MERCHANT, Color("#e0c3a5"))
	facades.add_building(buildings, "NorthernTenement", Vector2(-17, -44), 90, Vector2(15, 9.5), 4, Facades.Kind.TENEMENT, Color("#c2cdb0"))
	facades.add_building(buildings, "NorthernMerchantHouse", Vector2(-17, -63), 90, Vector2(15, 10), 3, Facades.Kind.MERCHANT, Color("#dfb5a7"))
	facades.add_building(buildings, "SquareCivicHall", Vector2(23.5, -63.5), 0, Vector2(23, 13), 3, Facades.Kind.CIVIC, Color("#d9caa6"))
	facades.add_building(buildings, "WestCrossStreetShops", Vector2(-30.8, -38.5), 0, Vector2(17, 9), 2, Facades.Kind.SHOP, Color("#e3c790"))
	facades.add_building(buildings, "WestCrossStreetTenement", Vector2(-52, -38.5), 0, Vector2(20, 10), 4, Facades.Kind.TENEMENT, Color("#c7cbb8"))
	facades.add_building(buildings, "LaneHouse", Vector2(-38, -8), 90, Vector2(16, 9), 3, Facades.Kind.TENEMENT, Color("#d0b2ac"))
	facades.add_building(buildings, "LaneShop", Vector2(-21.5, 13), -90, Vector2(10, 6), 2, Facades.Kind.SHOP, Color("#d7c9a4"))
	facades.add_building(buildings, "SouthMerchantHouse", Vector2(14, 34), -90, Vector2(17, 11), 3, Facades.Kind.MERCHANT, Color("#c1cbbb"))
	facades.add_building(buildings, "SouthTenement", Vector2(-13, 41), 90, Vector2(17, 10), 4, Facades.Kind.TENEMENT, Color("#dbc098"))
	facades.add_building(buildings, "SouthCornerHouse", Vector2(14, 54), -90, Vector2(16, 11), 4, Facades.Kind.TENEMENT, Color("#d5b4a7"))
	facades.add_building(buildings, "InnerQuayWarehouse", Vector2(35, -12), 90, Vector2(14, 10), 2, Facades.Kind.WAREHOUSE, Color("#aa8976"))
	facades.add_building(buildings, "OuterQuayWarehouse", Vector2(75.5, -11), -90, Vector2(18, 11), 2, Facades.Kind.WAREHOUSE, Color("#b39a7f"))
	facades.add_building(buildings, "OuterBankCustodian", Vector2(77.5, -40.5), 0, Vector2(13, 10), 3, Facades.Kind.MERCHANT, Color("#d9c6a3"))


func _place_workshop_signs() -> void:
	var frontage: Label3D = $Buildings/WestCrossStreetShops/HandPaintedSign
	frontage.text = "МЕХАНИЧЕСКАЯ  МАСТЕРСКАЯ"
	var signboard := Geometry.group($Buildings, "SouthWorkshopSign", Vector3(-7.79, 2.6, 47.1))
	signboard.rotation_degrees.y = 90.0
	Geometry.box(signboard, "Board", Vector3.ZERO, Vector3(2.8, 0.4, 0.1), wood)
	var lettering := Label3D.new()
	lettering.text = "РЕМОНТЪ ЭКИПАЖЕЙ"
	lettering.position.z = 0.06
	lettering.font_size = 35
	lettering.pixel_size = 0.004
	lettering.outline_size = 0
	lettering.modulate = Color("#eed7a0")
	signboard.add_child(lettering)


func _build_square() -> void:
	var square: Node3D = $Square
	_slab(square, "PavedSquare", 7, 39, -56, -33, 0.02, 0.12, paving)
	for center: Vector3 in [Vector3(12, 0, -51), Vector3(34, 0, -51), Vector3(12, 0, -38), Vector3(34, 0, -38)]:
		Geometry.box(square, "TreeBed", center + Vector3.UP * 0.11, Vector3(4, 0.18, 3.5), coping)
		Geometry.box(square, "Planting", center + Vector3.UP * 0.19, Vector3(3.75, 0.10, 3.25), turf)
		_add_tree(square, center)
	Geometry.box(square, "MonumentBase", Vector3(23, 0.19, -44.5), Vector3(3.3, 0.36, 3.3), coping, true)
	Geometry.box(square, "MonumentPlinth", Vector3(23, 0.96, -44.5), Vector3(1.84, 1.32, 1.84), masonry, true)
	Geometry.box(square, "MonumentCrown", Vector3(23, 1.68, -44.5), Vector3(2.02, 0.21, 2.02), coping)
	var obelisk := CylinderMesh.new()
	obelisk.top_radius = 0.13
	obelisk.bottom_radius = 0.63
	obelisk.height = 2.25
	obelisk.radial_segments = 4
	Geometry.mesh_part(square, "StoneObelisk", Vector3(23, 2.9, -44.5), obelisk, masonry).rotation_degrees.y = 45


func _add_tree(parent: Node3D, center: Vector3) -> void:
	var tree := Geometry.group(parent, "Linden", center)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.24
	trunk.height = 3.3
	trunk.radial_segments = 7
	Geometry.mesh_part(tree, "Trunk", Vector3.UP * 1.65, trunk, wood)
	Geometry.collider(tree, "TrunkCollision", Vector3.UP * 1.45, Vector3(0.43, 2.9, 0.43))
	var leaves := Geometry.solid_material(Color("#586d43"))
	var crown := SphereMesh.new()
	crown.radius = 1.8
	crown.height = 3.1
	crown.radial_segments = 9
	crown.rings = 5
	Geometry.mesh_part(tree, "MainCrown", Vector3(0, 3.95, 0), crown, leaves)
	Geometry.mesh_part(tree, "UpperCrown", Vector3(0.65, 4.62, 0.3), crown, leaves).scale = Vector3.ONE * 0.72


func _build_canal() -> void:
	var canal: Node3D = $Canal
	var water_material := ShaderMaterial.new()
	water_material.shader = WATER
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(EAST_BANK - WEST_BANK, LAND_EDGE * 2)
	Geometry.mesh_part(canal, "Water", Vector3((WEST_BANK + EAST_BANK) * 0.5, -2.35, 0), water_plane, water_material).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WaterDeath.add_at_surface(canal, Vector3((WEST_BANK + EAST_BANK) * 0.5, -2.35, 0), water_plane.size)

	var north := CROSS_STREET - BRIDGE_HALF_WIDTH
	var south := CROSS_STREET + BRIDGE_HALF_WIDTH
	for bank_position: Vector2 in [Vector2(42, WEST_BANK), Vector2(EAST_BANK, 69)]:
		_slab(canal, "NorthQuay", bank_position.x, bank_position.y, -90, north, 0.02, 0.18, flagstone)
		_slab(canal, "SouthQuay", bank_position.x, bank_position.y, south, 90, 0.02, 0.18, flagstone)
	for x in [WEST_BANK, EAST_BANK]:
		var wall_x: float = x - 0.26 if x == WEST_BANK else x + 0.26
		Geometry.box(canal, "GraniteEmbankment", Vector3(wall_x, -1.48, 0), Vector3(0.52, 3.0, 180), masonry)
		_quay_railing(canal, x, -90, north)
		if x == WEST_BANK:
			_quay_railing(canal, x, south, 61.0)
			_quay_railing(canal, x, 62.2, 90)
		else:
			_quay_railing(canal, x, south, 32.0)
			_quay_railing(canal, x, 33.2, 90)

	Bridge.build(canal, WEST_BANK, EAST_BANK, north, south, paving, masonry, coping)
	Geometry.box(canal, "CanalEndWall", Vector3(55, -0.68, -90.1), Vector3(14, 3.5, 0.48), masonry, true)
	# The canal terminates where the northern extension begins.
	Geometry.box(canal, "CanalEndCoping", Vector3(55, 1.085, -90.1), Vector3(14.05, 0.18, 0.57), coping)


func _quay_railing(parent: Node3D, x: float, start: float, end: float) -> void:
	var rail := Geometry.group(parent, "QuayGuard")
	var center := (start + end) * 0.5
	var span := end - start
	Geometry.box(rail, "GraniteCurb", Vector3(x, 0.12, center), Vector3(0.38, 0.24, span), coping)
	for y: float in [0.54, 1.09]:
		Geometry.box(rail, "IronRail", Vector3(x, y, center), Vector3(0.08, 0.09, span), iron)
	var posts: Array[Transform3D] = []
	var count := ceili(span / 2.2)
	for index in count + 1:
		var z := lerpf(start + 0.09, end - 0.09, float(index) / count)
		posts.append(Geometry.box_transform(Vector3(x, 0.65, z), Vector3(0.14, 0.93, 0.14)))
	Geometry.batch(rail, "IronPosts", unit_box, iron, posts)
	Geometry.collider(rail, "ContinuousGuard", Vector3(x, 0.57, center), Vector3(0.32, 1.14, span))


func _place_district_props() -> void:
	var props: Node3D = $Props
	for point: Vector3 in [
		Vector3(9, 0.02, -54), Vector3(37, 0.02, -54), Vector3(9, 0.02, -35), Vector3(37, 0.02, -35),
		Vector3(46, 0.02, -34), Vector3(46, 0.02, -20), Vector3(64, 0.02, -34), Vector3(64, 0.02, -20),
		Vector3(6, 0.065, 38), Vector3(-6, 0.065, 62),
		Vector3(-34, 0, -20), Vector3(-33, 0, 15)
	]:
		_place_prop(props, LAMP, point, 0)
	for point: Vector3 in [
		Vector3(16, 0.02, -53), Vector3(30, 0.02, -53), Vector3(17, 0.02, -36), Vector3(29, 0.02, -36)
	]:
		_place_prop(props, BENCH, point, 0 if point.z < -45 else 180)


func _place_prop(parent: Node3D, scene: PackedScene, center: Vector3, yaw: float) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = center
	prop.rotation_degrees.y = yaw
	parent.add_child(prop, true)
