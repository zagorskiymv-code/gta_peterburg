@tool
extends Node3D

const G = preload("res://scripts/world/district_geometry.gd")
var hull := G.solid_material(Color("#343d3d"))
var red := G.solid_material(Color("#753d32"))
var deck := G.solid_material(Color("#89775d"))
var white := G.solid_material(Color("#b6b2a0"))
var bronze := G.solid_material(Color("#a88756"))
var iron := G.solid_material(Color("#44433d"))
var unit := BoxMesh.new()


func _ready() -> void:
	_hull_mesh()
	G.box(self, "Forecastle", Vector3(0, 3.05, -25.0), Vector3(8.2, 1.1, 12.3), hull)
	G.box(self, "BridgeSuperstructure", Vector3(0, 4.15, -16), Vector3(8.3, 2.4, 5.6), white)
	G.box(self, "BridgeRoof", Vector3(0, 5.41, -16), Vector3(8.8, 0.22, 6.1), deck)
	G.box(self, "AfterDeckhouse", Vector3(0, 3.3, 19), Vector3(6.75, 1.6, 9), white)
	G.box(self, "MachineryHousing", Vector3(0, 2.96, 0), Vector3(5.8, 0.95, 24), white)
	for z in [-9.5, 1.0, 11.5]:
		_cylinder("Funnel", Vector3(0, 6.31, z), 1.08, 1.25, 6.05, bronze).rotation_degrees.x = -4
		_cylinder("FunnelCap", Vector3(0, 9.24, z - 0.20), 1.12, 1.12, 0.59, iron).rotation_degrees.x = -4
	for z in [-21.0, 23.0]:
		_cylinder("Mast", Vector3(0, 10.0, z), 0.105, 0.24, 14.4, bronze)
		G.box(self, "Yardarm", Vector3(0, 13.85, z), Vector3(5.9, 0.11, 0.10), iron)
		_cylinder("LookoutPlatform", Vector3(0, 11.2, z), 0.58, 0.72, 0.22, iron)
	var small_boat := SphereMesh.new()
	small_boat.radial_segments = 10
	small_boat.rings = 5
	for side in [-1, 1]:
		for z in [-4.7, 7.0]:
			G.mesh_part(self, "Boat", Vector3(side * 4.08, 3.48, z), small_boat, white).scale = Vector3(1.43, 0.59, 5.35)
	# Decorative deck fittings are fixed meshes.
	for station: Vector3 in [Vector3(0, 3.57, -32), Vector3(0, 2.70, 32),
			Vector3(-4.10, 2.62, -17), Vector3(4.10, 2.62, -17),
			Vector3(-4.10, 2.62, 19), Vector3(4.10, 2.62, 19)]:
		_cylinder("DeckMount", station + Vector3.UP * 0.30, 0.56, 0.70, 0.61, iron)
		G.box(self, "DeckFitting", station + Vector3(0, 0.62, -0.56), Vector3(0.22, 0.23, 1.33), iron)
	_rails()


func _hull_mesh() -> void:
	# Cross sections from the bow to the stern. The dark sheer strake sits above the waterline.
	var sections := [Vector2(-45, 0.04), Vector2(-41, 2.5), Vector2(-34, 4.9), Vector2(-22, 5.95),
		Vector2(5, 6.05), Vector2(29, 5.8), Vector2(39, 4.2), Vector2(44.5, 1.0)]
	var tops := [3.85, 3.05, 2.75, 2.50, 2.40, 2.52, 2.78, 2.70]
	var upper := _surface()
	var lower := _surface()
	var top := _surface()
	for i in sections.size() - 1:
		var a: Vector2 = sections[i]
		var b: Vector2 = sections[i + 1]
		for side in [-1.0, 1.0]:
			var p := Vector3(side * a.y, tops[i], a.x)
			var q := Vector3(side * b.y, tops[i + 1], b.x)
			var r := Vector3(side * b.y * 0.93, -0.03, b.x)
			var t := Vector3(side * a.y * 0.93, -0.03, a.x)
			_quad(upper, p, q, r, t, side > 0)
			_quad(lower, t, r, Vector3(side * b.y * 0.60, -1.56, b.x),
					Vector3(side * a.y * 0.60, -1.56, a.x), side > 0)
		_quad(top, Vector3(-a.y, tops[i], a.x), Vector3(a.y, tops[i], a.x),
				Vector3(b.y, tops[i + 1], b.x), Vector3(-b.y, tops[i + 1], b.x), false)
	# Close the transom.
	var z: float = sections[-1].x
	_quad(upper, Vector3(-1, 2.70, z), Vector3(1, 2.70, z),
			Vector3(0.93, -0.03, z), Vector3(-0.93, -0.03, z), false)
	for item in [[upper, hull, "ArmouredHull"], [lower, red, "LowerHull"], [top, deck, "WeatherDeck"]]:
		item[0].generate_normals()
		G.mesh_part(self, item[2], Vector3.ZERO, item[0].commit(), item[1])


func _rails() -> void:
	var parts: Array[Transform3D] = []
	var holes: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for i in 41:
			var z := -32.0 + i * 1.55
			var width := 5.70 if z > -24.0 else lerpf(4.88, 5.70, (z + 32.0) / 8.0)
			parts.append(G.box_transform(Vector3(side * width, 2.92, z), Vector3(0.055, 0.76, 0.055)))
			if i < 40:
				for y in [2.80, 3.22]:
					parts.append(G.box_transform(Vector3(side * width, y, z + 0.78), Vector3(0.045, 0.045, 1.57)))
			if i > 4 and i < 37:
				holes.append(G.box_transform(Vector3(side * (5.36 if z < -18 or z > 25 else 5.86), 1.59, z), Vector3(0.075, 0.19, 0.23)))
	G.batch(self, "DeckRailings", unit, white, parts)
	G.batch(self, "Portholes", unit, iron, holes)


func _cylinder(label: String, at: Vector3, top: float, bottom: float, height: float,
		material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	return G.mesh_part(self, label, at, mesh, material)


func _surface() -> SurfaceTool:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	return mesh


func _quad(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, reverse: bool) -> void:
	for vertex: Vector3 in ([a, c, b, a, d, c] if reverse else [a, b, c, a, c, d]):
		mesh.add_vertex(vertex)
