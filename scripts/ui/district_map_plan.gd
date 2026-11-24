extends Node2D

const Period = preload("res://scripts/ui/period_theme.gd")

enum Ink { WATER, LAND, GARDEN, SQUARE, STREET, BUILDING }
const COLORS := Period.MAP_INKS
const SCALE := 1.43
const COBBLE := preload("res://materials/cobblestone.gdshader")
const WATER := preload("res://materials/canal_water.gdshader")
const STRUCTURES := ["Masonry", "Facade", "MarbleBody", "MuseumBody", "BrickHall", "StableFloor", "SingerMasonry", "CurvedWingBay", "StationMasonry"]

var _layers: Array[ArrayMesh] = []
var _sites: Array[Vector2] = []
var _site_names := PackedStringArray(["Исаакий", "Дворцовая пл.", "Конюшня"])
var _font: Font


func build(world: Node3D, font: Font) -> void:
	_font = font
	var layers: Array[PackedVector3Array] = []
	for color in COLORS:
		layers.append(PackedVector3Array())
	for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		var layer := _ink(mesh)
		if layer != -1:
			var footprint: PackedVector2Array = mesh.get_parent().get_meta(&"plan_polygon", PackedVector2Array())
			if layer == Ink.BUILDING and not footprint.is_empty():
				_project_footprint(footprint, mesh.global_transform, layers)
			else:
				_project(mesh.mesh, mesh.global_transform, layers, layer)
	# The rows across the river and just beyond the district use instancing.
	var near := world.get_node_or_null("BackgroundCity/Near")
	if near:
		for row: MultiMeshInstance3D in near.find_children("Stucco*", "MultiMeshInstance3D", true, false):
			if row.multimesh:
				for index in row.multimesh.instance_count:
					_project(row.multimesh.mesh, row.global_transform * row.multimesh.get_instance_transform(index),
							layers, Ink.BUILDING)
	for index in layers.size():
		if layers[index].is_empty():
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_color(COLORS[index])
		for vertex in layers[index]:
			surface.add_vertex(vertex)
		_layers.append(surface.commit())
	for path in ["Landmarks/SaintIsaacsCathedral", "Landmarks/PalaceSquare", "PalaceStables"]:
		var landmark := world.get_node(path) as Node3D
		_sites.append(project(landmark.global_position))
	queue_redraw()


static func project(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z) * SCALE


func _ink(mesh: MeshInstance3D) -> int:
	if not mesh.mesh:
		return -1
	var label := String(mesh.name).rstrip("0123456789")
	var material := mesh.material_override as ShaderMaterial
	if material and material.shader == WATER and mesh.mesh is PlaneMesh:
		return Ink.WATER
	if label in ["Lawn", "PlantingBed", "GravelGarden", "GravelWalk"]:
		return Ink.GARDEN
	if label in ["ParadeGround", "PalaceForecourt", "IsaacStoneParvis", "GardenCourt",
			"WarehouseCourt", "MarketPassage"]:
		return Ink.SQUARE
	if label.ends_with("Ground") or label == "IslandQuay":
		return Ink.LAND
	if (material and material.shader == COBBLE) or label in ["MainSouth", "Sidewalk", "WestSidewalk",
			"EastSidewalk", "NevskySidewalks", "BypassSidewalks", "BridgeFootways", "PalaceApproach",
			"MillionnayaStreet", "WestBlockFootway", "LaneWestFootway", "LinkStreetFootway",
			"LaneEastFootway", "NevskyWestFootway", "SouthBlockFootway", "MerchantFootway", "GardenApproach", "NorthQuay", "SouthQuay", "WestPromenade", "CrossStreetContinuation",
			"NorthernLaneContinuation", "SouthernAxialStreet", "OuterQuayContinuation", "TimberDeck"]:
		return Ink.STREET
	if label in STRUCTURES or label.ends_with("Masonry") or label == "MasonryPier":
		return Ink.BUILDING
	return -1


func _project_footprint(outline: PackedVector2Array, pose: Transform3D,
		layers: Array[PackedVector3Array]) -> void:
	var output := layers[Ink.BUILDING]
	for index in Geometry2D.triangulate_polygon(outline):
		var point := outline[index]
		var flat := project(pose * Vector3(point.x, 0, point.y))
		output.append(Vector3(flat.x, flat.y, 0))
	layers[Ink.BUILDING] = output


func _project(mesh: Mesh, pose: Transform3D, layers: Array[PackedVector3Array], ink: int) -> void:
	var output := layers[ink]
	if mesh is BoxMesh or mesh is PlaneMesh:
		var flat := PackedVector2Array()
		var bounds := mesh.get_aabb()
		for index in 8:
			flat.append(project(pose * bounds.get_endpoint(index)))
		var hull := Geometry2D.convex_hull(flat)
		for i in range(1, hull.size() - 2):
			for point in [hull[0], hull[i], hull[i + 1]]:
				output.append(Vector3(point.x, point.y, 0))
	else:
		var faces := mesh.get_faces()
		for index in range(0, faces.size(), 3):
			var a := project(pose * faces[index])
			var b := project(pose * faces[index + 1])
			var c := project(pose * faces[index + 2])
			if absf((b - a).cross(c - a)) < 0.01:
				continue
			for point in [a, b, c]:
				output.append(Vector3(point.x, point.y, 0))
	layers[ink] = output


func _draw() -> void:
	for layer in _layers:
		draw_mesh(layer, null)
	if not _font:
		return
	for index in _sites.size():
		var at := _sites[index]
		draw_circle(at, 4.5, Period.BURGUNDY, true, -1.0, true)
		draw_circle(at, 2.1, Period.BRASS_LIGHT, true, -1.0, true)
		var origin := at + Vector2(7, 4)
		draw_string_outline(_font, origin, _site_names[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Period.CREAM)
		draw_string(_font, origin, _site_names[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Period.INK)


func copy_geometry_from(source: Node2D, world: Node3D) -> void:
	_layers.assign(source._layers)
	_sites.assign(source._sites)
	_site_names = source._site_names.duplicate()
	_font = source._font
	var extra := {
		"Landmarks/WinterPalace": "Зимний дворец",
		"Landmarks/AlexanderGarden": "Александровский сад",
		"Landmarks/NewHolland": "Новая Голландия",
		"Landmarks/SingerHouse": "Дом Зингера",
	}
	for path in extra:
		var site := world.get_node_or_null(path) as Node3D
		if site:
			_sites.append(project(site.global_position))
			_site_names.append(extra[path])
	queue_redraw()
