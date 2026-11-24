@tool
extends RefCounted

const G = preload("res://scripts/world/district_geometry.gd")
const Period = preload("res://scripts/ui/period_theme.gd")

var iron := G.solid_material(Color("#343a35"))
var enamel := G.solid_material(Color("#263e43"))
var brass := G.solid_material(Color("#a38856"))
var oak := G.solid_material(Color("#634633"))
var pine := G.solid_material(Color("#997454"))
var stone := G.solid_material(Color("#a99c89"))
var dark := G.solid_material(Color("#292823"))
var paper := G.solid_material(Color("#c6ae83"))
var linen := G.solid_material(Color("#baad92"))
var red := G.solid_material(Color("#79514a"))
var box := BoxMesh.new()


func build(world: Node3D) -> void:
	var street := G.group(world, "StreetDetails")
	var buildings: Node3D = world.get_node("Buildings")
	var shop := G.group(world.get_node("Infill/UrbanBlocks/MainStreetWesternBlock/LaneShop"),
			"ShopDetails", Vector3(0, 0, 3.25))
	_shop(shop)
	var house := G.group(buildings.get_node("SouthMerchantHouse"), "DoorDetails", Vector3(0, 0, 5.5))
	_entrance(house)
	var books := G.group(world.get_node("Landmarks/ConnectingFrontages/Bookseller"),
			"BooksellerDetails", Vector3(0, 0, 4.5))
	_plate(books, Vector3(-5.8, 2.91, 0.18), "НЕВСКІЙ ПРОСПЕКТЪ", 2.1, enamel)
	_clock(books, Vector3(0, 4.2, 0.17))
	_news_board(books, Vector3(5.9, 1.50, 0.17))
	var north := G.group(buildings.get_node("NorthernTenement"), "BasementDetails", Vector3(0, 0, 4.75))
	for x in [-3.4, 3.4]:
		_cellar_window(north, Vector3(x, 0.37, 0.12))
	_plate(north, Vector3(1.14, 1.92, 0.16), "№ 18", 0.55, enamel)
	_cellar_door(north, Vector3(5.83, 0.46, 0.13))

	var court := G.group(world.get_node("Infill/ConnectedWellCourtyards/NorthEndWing"),
			"Household", Vector3(5.7, 0.066, 3.65))
	_pump(court)
	_bucket(court, Vector3(0.34, 0, 0.13))
	_firewood(court, Vector3(-2.05, 0, 0.02))
	for side in [-1.0, 1.0]:
		var shutter := G.group(court, "WoodenShutter", Vector3(0.02 + side * 0.64, 4.32, -0.13))
		shutter.rotation.y = side * 0.18
		for slat in 4:
			G.box(shutter, "Board", Vector3((slat - 1.5) * 0.081, 0, 0),
					Vector3(0.077, 1.21, 0.06), enamel)
		for y in [-0.39, 0.39]:
			G.box(shutter, "Hinge", Vector3(0, y, 0.045), Vector3(0.31, 0.045, 0.035), iron)
	_laundry(court)
	var stable := G.group(world.get_node("PalaceStables"), "StableWallDetails")
	_hitch(stable)
	_stable_tools(stable)
	_trough(stable)
	var cargo := G.group(world.get_node("Landmarks/NewHolland"), "WarehouseSacks",
			Vector3(39.1, 0.025, 105.3))
	_sacks(cargo)
	for z in [42.75, 59.2, 72.6]:
		_grate(street, Vector3(3.74, 0.009, z))
	for p: Vector3 in [Vector3(-1.35, 0.009, 37.1), Vector3(0.84, 0.009, 63.6)]:
		_manhole(street, p)
	_puddle(street, Vector3(2.9, 0.012, 56.5))
	_litter(street, Vector3(6.14, 0.073, 59.3))
	var quay := G.group(street, "CornerPosts", Vector3(6.45, 0.065, 74.5))
	for z in [-0.85, 0.92]:
		_post(quay, Vector3(0, 0, z), 0.47)
	var guide := G.group(buildings.get_node("SouthTenement"), "Directions", Vector3(5.8, 2.12, 5.18))
	_plate(guide, Vector3.ZERO, "КЪ НЕВСКОМУ →", 1.45, enamel)


func _shop(root: Node3D) -> void:
	var sign := G.group(root, "HangingSign", Vector3(-1.42, 2.88, 0.58))
	sign.rotation.y = PI * 0.5
	_plate(sign, Vector3.ZERO, "БАКАЛЕЯ", 0.88, oak)
	_plate(sign, Vector3(0, 0, -0.049), "БАКАЛЕЯ", 0.88, oak, PI)
	_beam(root, "SignBracket", Vector3(-1.42, 3.28, 0.13), Vector3(-1.42, 3.28, 1.02), 0.038, iron)
	for z in [0.26, 0.89]:
		_beam(root, "SignChain", Vector3(-1.42, 3.28, z), Vector3(-1.42, 3.04, z), 0.016, iron)
	_plate(root, Vector3(1.06, 2.20, 0.17), "№ 7", 0.39, enamel)
	var display := G.group(root, "ShopWindowDisplay", Vector3(3.95, 1.10, 0.15))
	# The existing window sits against solid masonry, so build a shallow glazed display in its frame.
	G.box(display, "ShadowBox", Vector3(0, 0.53, 0.11), Vector3(0.88, 1.02, 0.21), dark)
	for y in [0.10, 0.50, 1.02]:
		G.box(display, "WindowShelf", Vector3(0, y, 0.23), Vector3(0.91, 0.04, 0.23), oak)
	_bread_basket(display, Vector3(-0.19, 0.12, 0.24))
	for i in 3:
		_round(display, "PreserveJar", Vector3(-0.25 + 0.25 * i, 0.64, 0.26), 0.095, 0.066, 0.26, paper if i == 1 else red)
		_round(display, "JarLid", Vector3(-0.25 + 0.25 * i, 0.77, 0.26), 0.071, 0.071, 0.035, brass)
	for x in [-0.44, 0, 0.44]:
		G.box(display, "GlazingBar", Vector3(x, 0.56, 0.35), Vector3(0.034, 0.99, 0.035), oak)
	var glass := G.solid_material(Color(0.63, 0.74, 0.71, 0.17))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.28
	G.box(display, "Glass", Vector3(0, 0.56, 0.337), Vector3(0.86, 0.96, 0.013), glass).cast_shadow = 0


func _entrance(root: Node3D) -> void:
	_plate(root, Vector3(1.02, 1.92, 0.16), "№ 24", 0.48, enamel)
	for i in 3:
		G.box(root, "Threshold", Vector3(0, 0.102 + i * 0.043, 0.42 - i * 0.085),
				Vector3(1.64 - i * 0.09, 0.095, 0.40), stone)
	var roof := G.box(root, "DoorCanopy", Vector3(0, 2.79, 0.49), Vector3(1.88, 0.069, 0.84), enamel)
	roof.rotation.x = 0.09
	for x in [-0.78, 0.78]:
		_beam(root, "ForgedBrace", Vector3(x, 2.43, 0.15), Vector3(x, 2.73, 0.77), 0.023, iron)
	_beam(root, "Handrail", Vector3(-0.86, 0.91, 0.74), Vector3(-0.86, 1.0, 0.20), 0.032, iron)
	_beam(root, "RailUpright", Vector3(-0.86, 0.10, 0.72), Vector3(-0.86, 0.91, 0.72), 0.028, iron)
	_wall_lamp(root, Vector3(1.27, 2.54, 0.24))
	for x in [-2.48, 2.48]:
		var sill := Vector3(x, 3.705, 0.19)
		_round(root, "FlowerPot", sill + Vector3.UP * 0.12, 0.10, 0.14, 0.24, red)
		_blob(root, "Foliage", sill + Vector3.UP * 0.30, Vector3(0.32, 0.26, 0.29), enamel)


func _wall_lamp(root: Node3D, at: Vector3) -> void:
	_beam(root, "LampArm", at + Vector3(0, -0.18, -0.14), at + Vector3(0, -0.18, 0.22), 0.038, iron)
	var amber := G.solid_material(Color("#dbc18b"))
	amber.emission_enabled = true
	amber.emission = Color("#d1a259")
	amber.emission_energy_multiplier = 0.32
	var center := at + Vector3(0, 0, 0.20)
	G.box(root, "LampGlass", center, Vector3(0.20, 0.28, 0.20), amber)
	for x in [-0.10, 0.10]:
		for z in [-0.10, 0.10]:
			G.box(root, "LampFrame", center + Vector3(x, 0, z), Vector3(0.021, 0.30, 0.021), iron)
	_round(root, "LampHood", center + Vector3.UP * 0.19, 0.18, 0.028, 0.13, iron, 4)


func _plate(root: Node3D, at: Vector3, caption: String, width: float, material: Material, yaw := 0.0) -> void:
	var plate := G.group(root, "PaintedPlate", at)
	plate.rotation.y = yaw
	G.box(plate, "Rim", Vector3.ZERO, Vector3(width, 0.30, 0.045), brass)
	G.box(plate, "Face", Vector3(0, 0, 0.024), Vector3(width - 0.055, 0.252, 0.024), material)
	_label(plate, caption, Vector3(0, 0, 0.04), 0.0035)


func _label(root: Node3D, caption: String, at: Vector3, pixels: float, tint := Color("#e7d6a9")) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position = at
	label.font = Period.typeface()
	label.font_size = 32
	label.pixel_size = pixels
	label.modulate = tint
	label.outline_size = 0
	root.add_child(label, true)


func _news_board(root: Node3D, at: Vector3) -> void:
	var board := G.group(root, "NewspaperBoard", at)
	G.box(board, "WoodenFrame", Vector3.ZERO, Vector3(0.95, 1.02, 0.11), oak)
	G.box(board, "Posting", Vector3(0, 0.01, 0.063), Vector3(0.76, 0.82, 0.012), paper)
	_label(board, "ВѢСТИ", Vector3(0, 0.26, 0.075), 0.0048, Color("#483930"))
	var lines: Array[Transform3D] = []
	for column in [-1, 1]:
		for i in 12:
			lines.append(G.box_transform(Vector3(column * 0.17, 0.13 - i * 0.042, 0.071),
					Vector3(0.26 - (i % 3) * 0.04, 0.009, 0.008)))
	G.batch(board, "PrintColumns", box, oak, lines)
	G.box(board, "NewspaperPocket", Vector3(0, -0.47, 0.14), Vector3(0.85, 0.13, 0.15), oak)
	for i in 3:
		var fold := G.box(board, "FoldedNewspaper", Vector3((i - 1) * 0.24, -0.34, 0.14),
				Vector3(0.21, 0.20, 0.026), paper)
		fold.rotation.x = 0.18


func _clock(root: Node3D, at: Vector3) -> void:
	var clock := G.group(root, "StreetClock", at)
	clock.rotation.x = PI * 0.5
	_round(clock, "ClockCase", Vector3.ZERO, 0.56, 0.56, 0.18, iron, 24)
	_round(clock, "Bezel", Vector3(0, 0.105, 0), 0.51, 0.51, 0.045, brass, 24)
	_round(clock, "Dial", Vector3(0, 0.134, 0), 0.47, 0.47, 0.017, paper, 24)
	var marks: Array[Transform3D] = []
	for i in 12:
		var angle := i * TAU / 12.0
		marks.append(Transform3D(Basis(Vector3.UP, angle).scaled_local(Vector3(0.022, 0.012, 0.064)),
				Vector3(sin(angle) * 0.38, 0.148, cos(angle) * 0.38)))
	G.batch(clock, "HourMarks", box, dark, marks)
	for tip: Vector3 in [Vector3(-0.17, 0.16, 0.15), Vector3(0.23, 0.16, 0.19)]:
		_beam(clock, "ClockHand", Vector3(0, 0.16, 0), tip, 0.024, dark)


func _cellar_window(root: Node3D, at: Vector3) -> void:
	G.box(root, "CellarStone", at, Vector3(0.77, 0.47, 0.16), stone)
	G.box(root, "CellarRecess", at + Vector3.FORWARD * -0.095, Vector3(0.62, 0.30, 0.035), dark)
	var bars: Array[Transform3D] = []
	for i in 6:
		bars.append(G.box_transform(at + Vector3(-0.25 + i * 0.10, 0, 0.12), Vector3(0.021, 0.31, 0.033)))
	G.batch(root, "CellarIronBars", box, iron, bars)


func _cellar_door(root: Node3D, at: Vector3) -> void:
	G.box(root, "CellarDoorLintel", at + Vector3.UP * 0.42, Vector3(0.75, 0.09, 0.20), stone)
	for i in 6:
		G.box(root, "CellarDoorPlank", at + Vector3((i - 2.5) * 0.102, 0, 0.027),
				Vector3(0.099, 0.82, 0.08), oak if i % 2 == 0 else pine)
	for y in [-0.23, 0.23]:
		G.box(root, "StrapHinge", at + Vector3(0, y, 0.078), Vector3(0.61, 0.035, 0.018), iron)
	_ring(root, "CellarDoorPull", at + Vector3(0.18, 0.05, 0.095), 0.045, 0.008, iron, Vector3(PI * 0.5, 0, 0))


func _pump(root: Node3D) -> void:
	_post(root, Vector3.ZERO, 1.02)
	_round(root, "PumpBonnet", Vector3(0, 1.08, 0), 0.11, 0.072, 0.15, enamel)
	_beam(root, "Spout", Vector3(0, 0.70, 0.04), Vector3(0, 0.66, 0.29), 0.065, iron)
	_beam(root, "Lever", Vector3(-0.04, 1.07, 0), Vector3(-0.39, 0.84, 0), 0.038, iron)
	_round(root, "SplashStone", Vector3(0, 0.022, 0.19), 0.23, 0.23, 0.045, stone, 10)


func _bucket(root: Node3D, at: Vector3) -> void:
	_round(root, "Bucket", at + Vector3.UP * 0.12, 0.12, 0.16, 0.24, iron)
	_round(root, "BucketOpening", at + Vector3.UP * 0.242, 0.14, 0.14, 0.008, dark)
	_ring(root, "BucketHandle", at + Vector3.UP * 0.22, 0.135, 0.009, iron, Vector3(PI * 0.5, 0, 0))


func _firewood(root: Node3D, at: Vector3) -> void:
	var rounds: Array[Transform3D] = []
	var faces: Array[Transform3D] = []
	var timber := CylinderMesh.new()
	timber.radial_segments = 6
	for row in 3:
		for i in 6 - row:
			var center := at + Vector3((i + row * 0.5) * 0.147, 0.08 + row * 0.13, 0)
			var turned := Basis(Vector3.RIGHT, PI * 0.5)
			rounds.append(Transform3D(turned.scaled_local(Vector3(0.14, 0.54, 0.14)), center))
			faces.append(Transform3D(turned.scaled_local(Vector3(0.104, 0.012, 0.104)), center + Vector3(0, 0, 0.272)))
	G.batch(root, "FirewoodBark", timber, oak, rounds)
	G.batch(root, "SplitWoodEnds", timber, pine, faces)


func _laundry(root: Node3D) -> void:
	var a := Vector3(-6.8, 3.16, 0.47)
	var b := Vector3(2.65, 3.12, 0.62)
	for hook in [a, b]:
		_beam(root, "ClotheslineHook", Vector3(hook.x, hook.y, -0.13), hook, 0.027, iron)
	var prior := a
	for i in range(1, 9):
		var fraction := i / 8.0
		var p := a.lerp(b, fraction) - Vector3.UP * sin(PI * fraction) * 0.28
		_beam(root, "Clothesline", prior, p, 0.011, oak)
		prior = p
	for i in 5:
		var fraction := 0.25 + i * 0.125
		var p := a.lerp(b, fraction) - Vector3.UP * sin(PI * fraction) * 0.28
		var width := 0.48 + (i % 3) * 0.16
		for pleat in 4:
			var cloth := G.box(root, "LinenPleat", p + Vector3((pleat - 1.5) * width / 4, -0.35, 0),
					Vector3(width / 4 + 0.012, 0.68 - (i % 2) * 0.15, 0.017), linen if i != 2 else red)
			cloth.rotation.y = 0.19 if pleat % 2 == 0 else -0.19


func _hitch(root: Node3D) -> void:
	for x in [-3.65, 3.65]:
		_ring(root, "HitchingRing", Vector3(x, 1.03, 4.67), 0.115, 0.022, iron, Vector3(PI * 0.5, 0, 0))
		G.box(root, "RingAnchor", Vector3(x, 1.14, 4.645), Vector3(0.09, 0.11, 0.055), iron)


func _trough(root: Node3D) -> void:
	var trough := G.group(root, "WateringTrough", Vector3(-3.57, -0.012, 4.90))
	G.box(trough, "GraniteBase", Vector3(0, 0.15, 0), Vector3(1.48, 0.30, 0.49), stone)
	for side in [-1.0, 1.0]:
		G.box(trough, "StoneRim", Vector3(0, 0.34, side * 0.218), Vector3(1.52, 0.16, 0.094), stone)
		G.box(trough, "StoneEnd", Vector3(side * 0.708, 0.34, 0), Vector3(0.105, 0.16, 0.45), stone)
	var water := G.solid_material(Color("#4e5a53"))
	water.roughness = 0.23
	G.box(trough, "StillWater", Vector3(0, 0.345, 0), Vector3(1.31, 0.01, 0.34), water).cast_shadow = 0


func _stable_tools(root: Node3D) -> void:
	var tools := G.group(root, "FarrierTools", Vector3(-2.53, 1.54, 4.65))
	G.box(tools, "ToolRack", Vector3.ZERO, Vector3(0.75, 0.16, 0.07), oak)
	for x in [-0.23, 0.03]:
		for i in 10:
			var a := -0.29 + i * PI * 1.55 / 10
			var b := -0.29 + (i + 1) * PI * 1.55 / 10
			_beam(tools, "Horseshoe", Vector3(x + cos(a) * 0.076, -0.12 - sin(a) * 0.083, 0.06),
					Vector3(x + cos(b) * 0.076, -0.12 - sin(b) * 0.083, 0.06), 0.020, iron)
	_beam(tools, "HammerHandle", Vector3(0.25, -0.24, 0.075), Vector3(0.23, 0.01, 0.075), 0.028, pine)
	G.box(tools, "HammerHead", Vector3(0.23, 0.02, 0.08), Vector3(0.14, 0.039, 0.046), iron)


func _sacks(root: Node3D) -> void:
	for i in 3:
		var at := Vector3(0, 0.25, i * 0.42)
		var sack := _blob(root, "BurlapSack", at, Vector3(0.43, 0.54, 0.38), linen if i != 1 else paper)
		sack.rotation.z = -0.15
		_round(root, "SackTie", at + Vector3(-0.05, 0.23, 0), 0.067, 0.045, 0.065, oak)


func _bread_basket(root: Node3D, at: Vector3) -> void:
	_round(root, "WickerBasket", at + Vector3.UP * 0.055, 0.102, 0.15, 0.11, pine, 12)
	for i in 3:
		var loaf := _blob(root, "BreadLoaf", at + Vector3(-0.07 + i * 0.068, 0.14, 0), Vector3(0.082, 0.12, 0.18), paper)
		loaf.rotation.x = 0.25


func _post(root: Node3D, at: Vector3, height: float) -> void:
	_round(root, "CastIronFoot", at + Vector3.UP * 0.07, 0.145, 0.095, 0.14, iron)
	_round(root, "CastIronStem", at + Vector3.UP * height * 0.53, 0.075, 0.06, height * 0.83, iron)
	_blob(root, "PostFinial", at + Vector3.UP * height, Vector3(0.16, 0.14, 0.16), iron)


func _grate(root: Node3D, at: Vector3) -> void:
	G.box(root, "GrateRim", at, Vector3(0.35, 0.013, 0.53), iron)
	var slots: Array[Transform3D] = []
	for i in 7:
		slots.append(G.box_transform(at + Vector3(0, 0.008, -0.19 + i * 0.063),
				Vector3(0.255, 0.003, 0.033)))
	G.batch(root, "DrainSlots", box, dark, slots)


func _manhole(root: Node3D, at: Vector3) -> void:
	_round(root, "CastIronAccessCover", at, 0.32, 0.32, 0.012, iron, 20)
	_ring(root, "CoverRaisedRing", at + Vector3.UP * 0.009, 0.25, 0.011, dark)
	var raised: Array[Transform3D] = []
	for x in range(-2, 3):
		for z in range(-2, 3):
			raised.append(G.box_transform(at + Vector3(x * 0.067, 0.008, z * 0.067), Vector3(0.034, 0.006, 0.034)))
	G.batch(root, "CoverTread", box, dark, raised)


func _puddle(root: Node3D, at: Vector3) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 18:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3.ZERO)
		for j in [i + 1, i]:
			var angle := float(j) * TAU / 18.0
			var edge := 0.84 + sin(angle * 5.0) * 0.12 + cos(angle * 3.0) * 0.10
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(cos(angle) * 0.49 * edge, 0, sin(angle) * 1.12 * edge))
	var wet := G.solid_material(Color(0.22, 0.26, 0.27, 0.36))
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.cull_mode = BaseMaterial3D.CULL_DISABLED
	wet.roughness = 0.18
	G.mesh_part(root, "RainPuddle", at, surface.commit(), wet).cast_shadow = 0


func _litter(root: Node3D, at: Vector3) -> void:
	for i in 4:
		var scrap := G.box(root, "PaperScrap", at + Vector3(i * 0.14, 0.008, sin(i * 2.7) * 0.31),
				Vector3(0.13, 0.009, 0.09 + (i % 3) * 0.04), paper if i % 2 else linen)
		scrap.rotation.y = i * 1.4


func _round(root: Node3D, title: String, at: Vector3, bottom: float, top: float, height: float,
		mat: Material, segments := 10) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	G.mesh_part(root, title, at, mesh, mat)


func _blob(root: Node3D, title: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 9
	mesh.rings = 4
	var part := G.mesh_part(root, title, at, mesh, mat)
	part.scale = size
	return part


func _ring(root: Node3D, title: String, at: Vector3, radius: float, thickness: float,
		mat: Material, rotation := Vector3.ZERO) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 14
	mesh.ring_segments = 5
	G.mesh_part(root, title, at, mesh, mat).rotation = rotation


func _beam(root: Node3D, title: String, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var part := G.box(root, title, (a + b) * 0.5, Vector3(width, width, a.distance_to(b)), mat)
	var direction := (b - a).normalized()
	part.basis = Basis.looking_at(direction, Vector3.RIGHT if absf(direction.y) > 0.98 else Vector3.UP)
