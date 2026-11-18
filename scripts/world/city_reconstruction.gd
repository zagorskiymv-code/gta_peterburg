@tool
extends RefCounted

const G = preload("res://scripts/world/district_geometry.gd")
const F = preload("res://scripts/world/district_facades.gd")
const WATER := preload("res://materials/canal_water.gdshader")
const DEATH = preload("res://scripts/world/water_death_zone.gd")
const LAMP := preload("res://scenes/world/props/gas_lamp.tscn")
const BENCH := preload("res://scenes/world/props/wooden_bench.tscn")
var brick := G.solid_material(Color("#98604e"))
var salt_stone := G.solid_material(Color("#b4a69a"))
var wood := G.solid_material(Color("#6b4934"))
var iron := G.solid_material(Color("#3e4841"))
var gold := G.solid_material(Color("#c39b47"))
var lawn := G.solid_material(Color("#657951"))
var sand := G.solid_material(Color("#b3a58a"))
var box := BoxMesh.new()
var salvaged_wood := G.solid_material(Color("#997552"))

func south(root: Node3D, paving: Material) -> void:
	var group := G.group(root, "SouthernPerimeterBlocks")
	var f := F.new()
	for lot in [
		["WestLaneCorner",-38.15,44,90,18,7.7,4,F.Kind.TENEMENT,"#c6b391"],
		["PerimeterLink",-38.15,58.72,180,7.7,11.44,3,F.Kind.MERCHANT,"#cbb49c"],
		["CourtyardBackWing",-24.0,21.65,0,7.8,5.3,3,F.Kind.TENEMENT,"#b7b5a1"],
		["MerchantReturn",14.0,44.0,-90,3.0,11.0,3,F.Kind.MERCHANT,"#baac9d"],
		["SouthTenementReturn",-11.45,57.0,90,14.5,7.9,5,F.Kind.TENEMENT,"#b8b399"],
	]:
		f.add_building(group,lot[0],Vector2(lot[1],lot[2]),lot[3],Vector2(lot[4],lot[5]),lot[6],lot[7],Color(lot[8]))
	_slab(group,"WorkshopCourtyard",Vector2(-39.5,31.4),Vector2(18.1,4.7),paving,0.017)
	_slab(group,"MerchantServiceLane",Vector2(21.25,46.0),Vector2(3.3,40),paving,0.018)
	_slab(group,"CanalLoadingLane",Vector2(40.6,24),Vector2(2.4,55),paving,0.019)
	_prop(group,LAMP,Vector3(-40,0.017,30.4))
	_crates(group,Vector3(39.25,0.02,54.5))
	_billboard(group, Vector3(-10.5, 0.02, -34.9))
	_cart(group, Vector3(-43, 0.018, 32.3))
	_close_residual_lots(group, f, paving)


func _close_residual_lots(root: Node3D, facades: RefCounted, paving: Material) -> void:
	var blocks := G.group(root, "CompletedStreetBlocks")
	# Close the street fronts at existing party walls and leave entrances to the rear courts.
	for lot in [
		["EastLaneTenement", -21.6, -12.5, -90, 15.0, 8.0, 4, F.Kind.TENEMENT, "#c5b497"],
		["EastLaneCorner", -21.6, 1.0, -90, 12.0, 8.0, 3, F.Kind.MERCHANT, "#c3bba2"],
		["LaneRearWing", -38.0, 6.5, 90, 13.0, 9.0, 3, F.Kind.TENEMENT, "#b8b19f"],
		["WorkshopCourtWing", -38.2, 18.8, 0, 8.4, 11.6, 2, F.Kind.WAREHOUSE, "#aa8873"],
		["MainStreetNorthWing", 18.0, -12.5, 90, 9.0, 6.0, 3, F.Kind.TENEMENT, "#beb5a2"],
		["MainStreetSouthWing", 18.0, 3.8, 90, 7.5, 6.0, 2, F.Kind.MERCHANT, "#c9b59f"],
		["WesternCornerBackWing", -73.15, -10.0, -90, 10.0, 8.3, 3, F.Kind.TENEMENT, "#aea99b"],
		["GrocerStoreWing", -72.7, 12.8, -90, 10.4, 7.4, 2, F.Kind.WAREHOUSE, "#ae8a72"],
		["OuterQuayFrontLink", 81.0, 23.75, -90, 5.5, 8.0, 3, F.Kind.TENEMENT, "#c1b19c"],
		["OuterQuayMerchantLink", 80.5, 47.75, -90, 4.5, 8.0, 3, F.Kind.MERCHANT, "#b3b39c"],
	]:
		facades.add_building(blocks, lot[0], Vector2(lot[1], lot[2]), lot[3],
				Vector2(lot[4], lot[5]), lot[6], lot[7], Color(lot[8]))
	_slab(blocks, "WesternPassage", Vector2(-71.3,1.3), Vector2(22.6,3.15), paving, 0.024)
	_slab(blocks, "MainStreetServicingCourt", Vector2(18.5,-4.0), Vector2(8.5,7.5), paving, 0.022)
	_slab(blocks, "LaneServiceCourt", Vector2(-33.1,23.5), Vector2(1.8,3.0), paving, 0.022)


func quays(root: Node3D) -> void:
	var quay := G.group(root, "HistoricalCanalQuays")
	var ashlar: Array[Transform3D] = []
	var bollards: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var x: float = 55.0 + side * 6.97
		for i in 46:
			var z := -89.0 + i * 3.94
			for course in 3:
				ashlar.append(G.box_transform(Vector3(x, -0.47-course*0.80, z+0.35*(course%2)),
						Vector3(0.16,0.773,3.90)))
		for z in [-71.0, -51.0, -7.0, 14.0, 31.0, 47.0, 71.0]:
			var footing := Vector3(x+side*0.38,0.17,z)
			bollards.append(G.box_transform(footing,Vector3(0.39,0.31,0.39)))
			bollards.append(G.box_transform(footing+Vector3.UP*0.20,Vector3(0.23,0.24,0.23)))
	G.batch(quay,"GraniteCourses",box,salt_stone,ashlar)
	G.batch(quay,"MooringPosts",box,iron,bollards)
	for site: Vector2 in [Vector2(48,-62),Vector2(62,36),Vector2(48,65)]:
		var inward := 1.0 if site.x < 55.0 else -1.0
		var platform := G.group(quay,"WaterLanding",Vector3(site.x,-1.6,site.y))
		G.box(platform,"LandingStone",Vector3(inward*0.82,-0.10,0),Vector3(1.8,0.24,4.6),salt_stone,true)
		for i in 6:
			G.box(platform,"QuayStep",Vector3(inward*0.42,i*0.25,-2.3-i*0.36),
					Vector3(1.05,0.24,0.39),salt_stone,true)
		var boat := SphereMesh.new()
		boat.radial_segments = 12
		boat.rings = 6
		G.mesh_part(platform,"MooringDinghy",Vector3(inward*2.7,-0.66,0.35),boat,wood).scale = Vector3(0.75,0.34,3.1)
		for dz in [-0.7,0.62]:
			G.box(platform,"BoatThwart",Vector3(inward*2.7,-0.47,0.35+dz),Vector3(0.55,0.09,0.16),salt_stone)
	_prop(quay,LAMP,Vector3(63.3,0.02,56.5))
	_crates(quay,Vector3(68.1,0.03,-70.0))


func admiralty(root: Node3D, paving: Material) -> void:
	var base := G.group(root, "Admiralty", Vector3(-66.0,0,-253.2))
	var ochre := G.solid_material(Color("#d6bc81"))
	var white := G.solid_material(Color("#e1d5ba"))
	var f := F.new()
	for side in [-1.0,1.0]:
		for bay in 2:
			var x: float = side*(8.75+bay*8.5)
			f.add_building(base,"AdmiraltyWing",Vector2(x,0),0,Vector2(8.5,8),3,F.Kind.TENEMENT,Color("#cfb681"))
		var col := CylinderMesh.new()
		col.height = 6.1
		col.top_radius = 0.15
		col.bottom_radius = 0.20
		col.radial_segments = 10
		for j in 5:
			G.mesh_part(base,"AdmiraltyColonnade",Vector3(side*(16.2+j*0.79),3.29,4.29),col,white)
		G.box(base,"WingPediment",Vector3(side*17.8,6.75,4.19),Vector3(4.9,0.42,0.74),white)
	_gateway(base,"AdmiraltyArch",Vector3.ZERO,3.15,8.0,11.2,ochre,white)
	G.box(base,"CentralAttic",Vector3(0,11.84,0),Vector3(9.1,1.48,8.3),white)
	G.box(base,"TowerBase",Vector3(0,14.08,0),Vector3(7.65,3.9,6.3),ochre,true)
	var tower_col := CylinderMesh.new()
	tower_col.height = 3.1
	tower_col.top_radius = 0.14
	tower_col.bottom_radius = 0.17
	tower_col.radial_segments = 8
	for side in [-1.0,1.0]:
		for i in 5:
			G.mesh_part(base,"TowerColumns",Vector3(-2.85+i*1.42,14.0,side*3.28),tower_col,white)
	G.box(base,"LanternCornice",Vector3(0,16.18,0),Vector3(8.1,0.38,7.1),white)
	_cylinder(base,"GoldenSpire",Vector3(0,23.02,0),13.5,1.15,0.045,gold,8)
	G.box(base,"VaneShipHull",Vector3(0,30.04,0),Vector3(1.65,0.18,0.21),gold)
	for i in 3:
		G.box(base,"VaneShipMast",Vector3(-0.51+i*0.49,30.44,0),Vector3(0.057,0.81,0.06),gold)
		var sail := G.box(base,"VaneSail",Vector3(-0.61+i*0.49,30.53,0),Vector3(0.31,0.35,0.045),gold)
		sail.rotation_degrees.z = -7
	_slab(base,"AdmiraltyAxialWalk",Vector2(0,0),Vector2(5,26),paving,0.025)
	_garden(G.group(root,"AlexanderGarden",Vector3(-66,0,-240.3)))


func _garden(garden: Node3D) -> void:
	_slab(garden,"GravelGarden",Vector2.ZERO,Vector2(32,16.4),sand,0.04)
	for side in [-1.0,1.0]:
		for end in [-1.0,1.0]:
			var bed := Vector2(side*9.8,end*4.31)
			_slab(garden,"Lawn",bed,Vector2(10.5,5.6),lawn,0.076)
			for i in 3:
				_tree(garden,Vector3(bed.x-3.32+i*3.32,0.083,bed.y+sin(i*2.1)),2.65+i*0.48)
			var shrub := SphereMesh.new()
			shrub.radial_segments = 8
			shrub.rings = 4
			for dx in [-4.15,4.15]:
				G.mesh_part(garden,"ClippedShrub",Vector3(bed.x+dx,0.43,bed.y-0.90),shrub,lawn).scale = Vector3(0.72,0.77,0.63)
			_prop(garden,BENCH,Vector3(side*8.4,0.04,end*0.95),0 if end<0 else 180)
			_prop(garden,LAMP,Vector3(side*3.6,0.04,end*5.97))
		_link(garden,"LowIronFence",Vector3(side*15.9,0.39,-7.8),Vector3(side*15.9,0.39,-2.8),0.11,iron)
		_link(garden,"LowIronFence",Vector3(side*15.9,0.39,2.8),Vector3(side*15.9,0.39,7.8),0.11,iron)
	var base := Vector3(0,0.04,0)
	_cylinder(garden,"FountainBasin",base+Vector3.UP*0.28,0.52,2.0,2.12,salt_stone,24)
	_cylinder(garden,"FountainPedestal",base+Vector3.UP*0.81,1.3,0.33,0.20,salt_stone,12)
	_cylinder(garden,"CastBowl",base+Vector3.UP*1.49,0.22,0.36,0.74,iron,16)
	G.collider(garden,"FountainBasin",base+Vector3.UP*0.30,Vector3(3.7,0.56,1.4))
	var cascade := StandardMaterial3D.new()
	cascade.albedo_color = Color("#91b8be")
	cascade.roughness = 0.26
	for i in 8:
		var a := TAU*i/8.0
		var d := Vector3(cos(a),0,sin(a))
		_link(garden,"FountainWaterSpout",Vector3(0,1.46,0)+d*0.54,Vector3(0,0.57,0)+d*1.23,0.034,cascade)


func holland(root: Node3D, paving: Material) -> void:
	var island := G.group(root,"NewHolland")
	var water := ShaderMaterial.new()
	water.shader = WATER
	for feature: Vector4 in [Vector4(26.5,93,43,6), Vector4(9,121,8,50),
			Vector4(55,119.5,14,59), Vector4(30.5,141.5,35,15)]:
		var plane := PlaneMesh.new()
		plane.size = Vector2(feature.z,feature.w)
		var at := Vector3(feature.x,-2.35,feature.y)
		G.mesh_part(island,"IslandWater",at,plane,water).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		DEATH.add_at_surface(island,at,plane.size)
	_slab(island,"IslandQuay",Vector2(30.5,115),Vector2(35,38),salt_stone,0.00,2.9)
	_slab(island,"WarehouseCourt",Vector2(30.5,116),Vector2(23,30),paving,0.025)
	_slab(island,"IslandAccessBridge",Vector2(26.5,93),Vector2(5.4,6.8),paving,0.01,0.46)
	for x in [23.86,29.14]:
		G.box(island,"AccessBridgeCoping",Vector3(x,0.575,93),Vector3(0.22,1.15,6.6),salt_stone,true)
	for x in [13.12,47.88]:
		G.box(island,"IslandQuayWall",Vector3(x,0.58,115),Vector3(0.24,1.16,38),salt_stone,true)
	G.box(island,"SouthQuayWall",Vector3(30.5,0.58,133.88),Vector3(35,1.16,0.24),salt_stone,true)
	for bounds: Vector2 in [Vector2(13,23.86),Vector2(29.14,48)]:
		G.box(island,"NorthQuayWall",Vector3((bounds.x+bounds.y)*0.5,0.58,96.1),
				Vector3(bounds.y-bounds.x,1.16,0.24),salt_stone,true)
	var f := F.new()
	for x in [17.7,43.3]:
		for z in [105.5,123.5]:
			f.add_building(island,"BrickTimberStore",Vector2(x,z),90 if x<30 else -90,Vector2(17.8,7.5),3,
					F.Kind.WAREHOUSE,Color("#975c49"))
	_gateway(island,"HollandArch",Vector3(30.5,0,123.5),4.2,6.4,9.5,brick,salt_stone)
	for x in [25.05,35.95]:
		_cylinder(island,"ArchGraniteColumn",Vector3(x,3.01,120.15),5.95,0.51,0.42,salt_stone,12)
		G.box(island,"ArchSideExtension",Vector3(30.5+signf(x-30.5)*6.65,4.75,123.5),Vector3(2.2,9.5,6.4),brick,true)
	G.box(island,"ArchEntablature",Vector3(30.5,9.16,120.16),Vector3(13.55,0.63,0.64),salt_stone)
	for at: Vector3 in [Vector3(23,0.025,102),Vector3(37.5,0.025,113),Vector3(31,0.025,130)]:
		_prop(island,LAMP,at)
	for at: Vector3 in [Vector3(22.6,0.025,112),Vector3(37.2,0.025,127.0)]:
		_crates(island,at)


func squares(root: Node3D, paving: Material) -> void:
	var square := G.group(root,"SquareDetails")
	var contrast := G.solid_material(Color("#9b9184"))
	_slab(square,"IsaacAxialPaving",Vector2(-49,-108.5),Vector2(9,7.5),paving,0.025)
	for x in [-69.8,-27.6]:
		_slab(square,"IsaacGraniteWalk",Vector2(x,-113.25),Vector2(4.8,3.25),contrast,0.028)
		_prop(square,LAMP,Vector3(x,0.028,-114.1))
	for x in [-31.8,63.7]:
		_slab(square,"PalaceStoneBorder",Vector2(x,-223),Vector2(3.15,55),contrast,0.030)
		for z in [-248.5,-205.4]:
			_prop(square,LAMP,Vector3(x,0.029,z))


func _gateway(parent: Node3D, label: String, pos: Vector3, half_open: float, depth: float,
		height: float, material: Material, trim: Material) -> void:
	var gate := G.group(parent,label,pos)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var x0 := lerpf(-half_open,half_open,i/16.0)
		var x1 := lerpf(-half_open,half_open,(i+1)/16.0)
		var y0 := 3.0+1.65*sqrt(maxf(0.0,1.0-pow(x0/half_open,2)))
		var y1 := 3.0+1.65*sqrt(maxf(0.0,1.0-pow(x1/half_open,2)))
		var a := Vector3(x0,y0,-depth*0.5)
		var b := Vector3(x1,y1,-depth*0.5)
		var c := b+Vector3.BACK*depth
		var d := a+Vector3.BACK*depth
		for v: Vector3 in [a,d,c,a,c,b,a,b,Vector3(x1,height,b.z),a,Vector3(x1,height,b.z),Vector3(x0,height,a.z),
				d,Vector3(x0,height,d.z),Vector3(x1,height,c.z),d,Vector3(x1,height,c.z),c]:
			surface.add_vertex(v)
	surface.generate_normals()
	var mesh := surface.commit()
	G.mesh_part(gate,"ArchVault",Vector3.ZERO,mesh,material)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	gate.add_child(body)
	for side in [-1.0,1.0]:
		G.box(gate,"AdmiraltyGatewayPier" if label=="AdmiraltyArch" else "HollandGatewayPier",
				Vector3(side*(half_open+0.66),height*0.5,0),Vector3(1.29,height,depth),material,true)
	var trim_blocks: Array[Transform3D] = []
	for j in 15:
		var theta := PI*j/14.0
		var basis := Basis(Vector3.BACK,atan2(1.75*cos(theta),-(half_open+0.14)*sin(theta)))
		for side in [-1.0,1.0]:
			trim_blocks.append(Transform3D(basis.scaled_local(Vector3(0.43,0.21,0.19)),
					Vector3((half_open+0.14)*cos(theta),3.0+1.75*sin(theta),side*(depth*0.5+0.07))))
	G.batch(gate,"ShapedStoneVoussoirs",box,trim,trim_blocks)
	G.box(gate,"GatewayCornice",Vector3(0,height-0.23,0),Vector3(half_open*2+2.75,0.35,depth+0.30),trim)


func _tree(root: Node3D, at: Vector3, height: float) -> void:
	_cylinder(root,"LindenTrunk",at+Vector3.UP*height*0.36,height*0.73,0.13,0.21,wood,8)
	G.collider(root,"LindenTrunk",at+Vector3.UP*height*0.36,Vector3(0.32,height*0.72,0.32))
	var crown := SphereMesh.new()
	crown.radial_segments = 9
	crown.rings = 6
	G.mesh_part(root,"VariedLindenCrown",at+Vector3.UP*height*0.92,crown,lawn).scale = Vector3(height*0.57,height*0.68,height*0.55)


func _cart(root: Node3D, at: Vector3) -> void:
	var cart := G.group(root,"ParkedWoodenCart",at)
	G.box(cart,"CartBed",Vector3(0,0.66,0),Vector3(1.17,0.18,1.8),wood,true)
	for i in 5:
		var board := G.box(cart, "SalvagedTimber", Vector3((i % 3 - 1) * 0.24, 0.792 + i / 3 * 0.072, 0.03),
				Vector3(0.20, 0.074, 1.39 - (i % 2) * 0.26), salvaged_wood)
		board.rotation.y = (i - 2) * 0.055
	for x in [-0.66,0.66]:
		var wheel := TorusMesh.new()
		wheel.inner_radius = 0.37
		wheel.outer_radius = 0.48
		wheel.rings = 16
		wheel.ring_segments = 7
		G.mesh_part(cart,"CartWheel",Vector3(x,0.47,0),wheel,iron).rotation_degrees.z = 90
		for angle in [0,60,120]:
			G.box(cart,"CartSpoke",Vector3(x,0.47,0),Vector3(0.041,0.79,0.045),wood).rotation_degrees.x = angle
		G.box(cart,"CartShaft",Vector3(x*0.78,0.48,-1.27),Vector3(0.08,0.08,1.33),wood)


func _crates(root: Node3D, at: Vector3) -> void:
	var cargo := G.group(root,"QuayCargo",at)
	for i in 3:
		G.box(cargo,"SlattedCrate",Vector3((i%2)*0.64,0.27+i/2*0.28,float(i%2)*0.50),
				Vector3(0.53,0.49,0.48),wood,true)
	var barrel := Vector3(-0.50, 0.28, 0.55)
	_cylinder(cargo, "OakBarrelLower", barrel - Vector3.UP * 0.14, 0.28, 0.201, 0.244, wood, 14)
	_cylinder(cargo, "OakBarrelUpper", barrel + Vector3.UP * 0.14, 0.28, 0.244, 0.201, wood, 14)
	for height in [-0.20, 0.0, 0.20]:
		var radius: float = 0.251 - absf(height) * 0.15
		_cylinder(cargo, "BarrelHoop", barrel + Vector3.UP * height, 0.034, radius, radius, iron, 14)
	_cylinder(cargo, "BarrelLid", barrel + Vector3.UP * 0.281, 0.012, 0.185, 0.185, wood, 14)


func _billboard(root: Node3D, at: Vector3) -> void:
	var kiosk := G.group(root,"PosterColumn",at)
	_cylinder(kiosk,"CastIronBase",Vector3.UP*0.22,0.38,0.36,0.42,iron,12)
	_cylinder(kiosk,"Advertisements",Vector3.UP*1.16,1.67,0.32,0.32,sand,14)
	_cylinder(kiosk,"WeatherCap",Vector3.UP*2.08,0.30,0.44,0.06,iron,12)
	G.collider(kiosk,"StreetFurniture",Vector3.UP,Vector3(0.58,2,0.58))
	var label := Label3D.new()
	label.text = "АФИША\nТЕАТРЪ\nВъ 7 часовъ"
	label.position = Vector3(0,1.22,0.327)
	label.font_size = 27
	label.modulate = Color("#4d382a")
	label.pixel_size = 0.005
	label.outline_size = 1
	kiosk.add_child(label)


func _link(root: Node3D, label: String, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var delta := b-a
	var beam := G.box(root,label,(a+b)*0.5,Vector3(width,width,delta.length()),material)
	beam.basis = Basis.looking_at(delta,Vector3.UP)


func _cylinder(root: Node3D, label: String, at: Vector3, height: float, bottom: float,
		top: float, material: Material, sections: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.radial_segments = sections
	G.mesh_part(root,label,at,mesh,material)


func _slab(root: Node3D,label: String,at: Vector2,size: Vector2,material: Material,top: float,depth := 0.18) -> void:
	G.box(root,label,Vector3(at.x,top-depth*0.5,at.y),Vector3(size.x,depth,size.y),material,true)


func _prop(root: Node3D, scene: PackedScene, at: Vector3, yaw := 0.0) -> void:
	var instance: Node3D = scene.instantiate()
	instance.position = at
	instance.rotation_degrees.y = yaw
	root.add_child(instance,true)
