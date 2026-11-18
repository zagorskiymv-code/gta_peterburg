@tool
extends RefCounted

const Geometry = preload("res://scripts/world/district_geometry.gd")
const LAMP := preload("res://scenes/world/props/gas_lamp.tscn")
const WATER := preload("res://materials/canal_water.gdshader")
const BYPASS_ROAD_MOUTH := Vector2(-107.55, -99.0)
const BRIDGE_LENGTH := 132.0
const BRIDGE_HALF_WIDTH := 11.0
const WaterDeath = preload("res://scripts/world/water_death_zone.gd")
const WING_ANGLE := 70.0
const PIERS := [23.0, 50.0, 82.0, 109.0]

var stone := Geometry.solid_material(Color("#8c8275"))
var iron := Geometry.solid_material(Color("#414744"))
var gutter_stone := Geometry.solid_material(Color("#9d9381"))
var leaf_deck := Geometry.solid_material(Color("#554c43"))
var board_seam := Geometry.solid_material(Color("#453e35"))
var leaf_walk := Geometry.solid_material(Color("#817b6a"))
var box := BoxMesh.new()


func build(parent: Node3D, paving: Material, flagstone: Material) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.6
	curve.add_point(Vector3(0, 0, -22))
	curve.add_point(Vector3(0, 0, -148), Vector3.ZERO, Vector3(0, 0, -30))
	curve.add_point(Vector3(-90, 0, -215), Vector3(33, 0, 12), Vector3.ZERO)
	var points := curve.get_baked_points()
	var centerline := Geometry.group(parent, "Avenue")
	var widths := PackedFloat32Array()
	var crossings := _with_crossings(points)
	for point in crossings:
		widths.append(lerpf(4.0, 7.0, smoothstep(22.0, 48.0, -point.z) if point.z > -48.0 else 1.0))
	_build_avenue(centerline, crossings, widths, paving, flagstone)
	_build_bypass(parent, points, paving, flagstone)

	var bridge := Geometry.group(parent, "NevaBridge", points[-1])
	var direction := Vector3(-33, 0, -12).normalized()
	bridge.rotation.y = atan2(-direction.x, -direction.z)
	_build_bridge(bridge, paving, flagstone)
	_build_landing(bridge)
	var water := PlaneMesh.new()
	water.size = Vector2(172, 300)
	var water_material := ShaderMaterial.new()
	water_material.shader = WATER
	var show_ship := parent.get_node_or_null("../Landmarks/ScarletSailsShip") as Node3D
	if show_ship:
		water_material.set_shader_parameter(&"festival_glimmer", Vector3(show_ship.global_position.x + 7,
				show_ship.global_position.z, 1.0))
	Geometry.mesh_part(parent, "WideWater", Vector3(-176, -2.65, -210), water, water_material).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WaterDeath.add_at_surface(parent, Vector3(-176, -2.65, -210), water.size)
	# The long bank faces reach the waterline, including the widened western footway.
	Geometry.box(parent, "GraniteQuayFacing", Vector3(-91.93, -1.56, -147.65),
			Vector3(0.29, 3.0, 111.3), stone)
	Geometry.box(bridge, "FarAbutment", Vector3(0, -1.45, -137), Vector3(28, 2.9, 15), stone)


func _with_crossings(points: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		result.append(a)
		for z in [-24.0, -29.0, -33.0, -94.0, BYPASS_ROAD_MOUTH.y, BYPASS_ROAD_MOUTH.x, -117.5, -124.5]:
			if a.z > z and b.z < z:
				result.append(a.lerp(b, inverse_lerp(a.z, b.z, z)))
	result.append(points[-1])
	return result


func _build_avenue(parent: Node3D, points: PackedVector3Array, widths: PackedFloat32Array,
		paving: Material, flagstone: Material) -> void:
	var road := _mesh_begin()
	var walks := _mesh_begin()
	var curbs := _mesh_begin()
	var gutters := _mesh_begin()
	var last_lamp := -100.0
	var traveled := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var right_a := _right(points, i)
		var right_b := _right(points, i + 1)
		var middle := (a.z + b.z) * 0.5
		var crossing := middle > -33.0 or (middle < -94 and middle > -99) or (middle < -117.5 and middle > -124.5)
		_strip(road, a, b, right_a, right_b, -widths[i], widths[i], -widths[i + 1], widths[i + 1], 0.045)
		for side in [-1.0, 1.0]:
			# The Isaac bypass is a road junction on the west side of Nevsky.
			if side < 0.0 and middle < BYPASS_ROAD_MOUTH.y and middle > BYPASS_ROAD_MOUTH.x:
				continue
			var width_a := widths[i]
			var width_b := widths[i + 1]
			var walk_y := 0.046 if crossing else 0.087
			_side_strip(walks, a, b, right_a, right_b, width_a, width_a + 4, width_b, width_b + 4, side, walk_y)
			if not crossing:
				_side_strip(gutters, a, b, right_a, right_b,
						width_a - 0.42, width_a, width_b - 0.42, width_b, side, 0.047)
				_side_strip(curbs, a, b, right_a, right_b, width_a, width_a + 0.19, width_b, width_b + 0.19, side, 0.102)
		traveled += a.distance_to(b)
		# Keep light posts clear of side street mouths.
		var lamp_spacing := 12.0 if middle < -143.0 and middle > -202.0 else 17.0
		if traveled - last_lamp > lamp_spacing and not crossing and i > 1 and i < points.size() - 6:
			for side in [-1.0, 1.0]:
				_lamp(parent, a + right_a * side * (widths[i] + 0.77) + Vector3.UP * 0.087)
			last_lamp = traveled
	_add_surface(parent, "NevskyRoad", road, paving)
	_add_surface(parent, "NevskySidewalks", walks, flagstone)
	_add_surface(parent, "StoneCurbs", curbs, stone, false)
	_add_surface(parent, "GraniteGutters", gutters, gutter_stone, false)
	parent.set_meta(&"route_points", points)
	parent.set_meta(&"route_half_widths", widths)
	parent.set_meta(&"bypass_road_mouth", BYPASS_ROAD_MOUTH)


func _build_bridge(bridge: Node3D, paving: Material, flagstone: Material) -> void:
	var road := _mesh_begin()
	var walks := _mesh_begin()
	var shell := _mesh_begin()
	var rail_posts: Array[Transform3D] = []
	var fascia: Array[Transform3D] = []
	for i in 66:
		var from := 2.0 * i
		var to := from + 2.0
		if from >= 50.0 and to <= 82.0:
			continue
		var a := Vector3(0, _deck_height(from), -from)
		var b := Vector3(0, _deck_height(to), -to)
		_strip(road, a, b, Vector3.RIGHT, Vector3.RIGHT, -7, 7, -7, 7, 0)
		for side in [-1.0, 1.0]:
			_side_strip(walks, a, b, Vector3.RIGHT, Vector3.RIGHT, 7, 11, 7, 11, side, 0.041)
			var left := a + Vector3(side * 10.96, 0.041, 0)
			var right := b + Vector3(side * 10.96, 0.041, 0)
			var rise := Vector3.UP * 1.24
			_quad(shell, left, right, right + rise, left + rise)
			for y in [0.22, 0.65, 1.18]:
				var origin: Vector3 = (left + right) * 0.5 + Vector3.UP * y
				var frame := Basis(Vector3.RIGHT, atan2(right.y - left.y, 2.0))
				rail_posts.append(Transform3D(frame.scaled_local(Vector3(0.1, 0.09, left.distance_to(right) + 0.03)), origin))
			rail_posts.append(Geometry.box_transform(left + Vector3.UP * 0.62, Vector3(0.12, 1.24, 0.12)))
		_bridge_fascia(fascia, a, b)
	_add_surface(bridge, "BridgeRoad", road, paving)
	_add_surface(bridge, "BridgeFootways", walks, flagstone)
	_add_surface(bridge, "RailCollision", shell, null, true, false)
	Geometry.batch(bridge, "IronRailings", box, iron, rail_posts)
	Geometry.batch(bridge, "IronSpanEdges", box, iron, fascia)
	for distance in PIERS:
		var pier_height := _deck_height(distance) + 2.93
		Geometry.box(bridge, "GranitePier", Vector3(0, pier_height * 0.5 - 3.55, -distance),
				Vector3(19.7, pier_height, 3.6), stone)
		for side in [-1, 1]:
			_lamp(bridge, Vector3(side * 9.85, _deck_height(distance) + 0.041, -distance))
	_palace_trusses(bridge)
	_build_leaf(bridge, "NearLeaf", 50.0, false)
	_build_leaf(bridge, "FarLeaf", 82.0, true)


func _build_landing(bridge: Node3D) -> void:
	# A full-depth granite landing overlaps both ground meshes under the angled seam.
	Geometry.box(bridge, "ShoreLanding", Vector3(0, -1.508, 2.85),
			Vector3(22.0, 3.02, 6.10), stone, true)
	for side in [-1.0, 1.0]:
		var river_edge := bridge.to_global(Vector3(side * 10.96, 0.085, 0))
		var shore_z := -226.72 if side > 0.0 else -203.24
		var shore := Vector3(-89.63, 0.085, shore_z)
		var delta := shore - river_edge
		var length := delta.length()
		var wall := Geometry.group(bridge, "LandingParapet", bridge.to_local((river_edge + shore) * 0.5))
		wall.rotation.y = atan2(-delta.x, -delta.z) - bridge.rotation.y
		Geometry.box(wall, "GraniteReturn", Vector3.UP * 0.60,
				Vector3(0.47, 1.20, length + 0.65), stone, true)


func _palace_trusses(bridge: Node3D) -> void:
	var spans := [0.0, 23.0, 50.0, 82.0, 109.0, 132.0]
	var chords: Array[Transform3D] = []
	var bracing: Array[Transform3D] = []
	for span in [0, 1, 3, 4]:
		var start: float = spans[span]
		var end: float = spans[span + 1]
		var sections := 6
		for side in [-1.0, 1.0]:
			for offset in [0.0, 2.65]:
				var x: float = side * (10.4 - offset)
				for i in sections:
					var a := float(i) / sections
					var b := float(i + 1) / sections
					var d1 := lerpf(start, end, a)
					var d2 := lerpf(start, end, b)
					var top1 := Vector3(x, _deck_height(d1) - 0.26, -d1)
					var top2 := Vector3(x, _deck_height(d2) - 0.26, -d2)
					var depth1 := 0.36 + (1.30 + cos(a * TAU) * 0.79)
					var depth2 := 0.36 + (1.30 + cos(b * TAU) * 0.79)
					var low1 := top1 - Vector3.UP * depth1
					var low2 := top2 - Vector3.UP * depth2
					_beam(chords, top1, top2, 0.23)
					_beam(chords, low1, low2, 0.27)
					_beam(bracing, low1, top2, 0.14)
					_beam(bracing, top1, low1, 0.16)
	Geometry.batch(bridge, "RivetedTrussChords", box, iron, chords)
	Geometry.batch(bridge, "TrussBracing", box, iron, bracing)


func _beam(parts: Array[Transform3D], a: Vector3, b: Vector3, thickness: float) -> void:
	var span := b - a
	var direction := span.normalized()
	var frame := Basis.looking_at(direction, Vector3.UP if absf(direction.x) > 0.95 else Vector3.RIGHT)
	parts.append(Transform3D(frame.scaled_local(Vector3(thickness, thickness, span.length() + 0.025)), (a + b) * 0.5))


func _build_bypass(parent: Node3D, avenue: PackedVector3Array, paving: Material, flagstone: Material) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.6
	var merge := avenue[-1]
	for point in avenue:
		if point.x < -83:
			merge = point
			break
	curve.add_point(Vector3(0, 0, -103), Vector3.ZERO, Vector3(-13, 0, 0))
	curve.add_point(Vector3(-68, 0, -103), Vector3(17, 0, 0), Vector3(-11, 0, 0))
	curve.add_point(Vector3(-84.6, 0, -120), Vector3(0, 0, 9), Vector3(0, 0, -18))
	curve.add_point(Vector3(-84.6, 0, -192), Vector3(0, 0, 15), Vector3(0, 0, -10))
	curve.add_point(merge, Vector3(1.5, 0, 6), Vector3.ZERO)
	var points := curve.get_baked_points()
	var bypass := Geometry.group(parent, "IsaacBypass")
	bypass.set_meta(&"route_points", points)
	var road := _mesh_begin()
	var walks := _mesh_begin()
	var curbs := _mesh_begin()
	var light_distance := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var ra := _right(points, i)
		var rb := _right(points, i + 1)
		var junction := a.x > -12 and a.z > -110 or a.z < -201
		var road_y := 0.043 if junction else 0.037
		_strip(road, a, b, ra, rb, -4.55, 4.55, -4.55, 4.55, road_y)
		for side in [-1.0, 1.0]:
			var height := 0.044 if junction else 0.078
			_side_strip(walks, a, b, ra, rb, 4.55, 6.35, 4.55, 6.35, side, height)
			if not junction:
				_side_strip(curbs, a, b, ra, rb, 4.55, 4.7, 4.55, 4.7, side, 0.092)
		light_distance += a.distance_to(b)
		if light_distance > 23 and not junction:
			_lamp(bypass, a - ra * 5.95 + Vector3.UP * 0.078)
			light_distance = 0.0
	_add_surface(bypass, "BypassRoad", road, paving)
	_add_surface(bypass, "BypassSidewalks", walks, flagstone)
	_add_surface(bypass, "BypassCurbs", curbs, stone, false)


func _bridge_fascia(parts: Array[Transform3D], a: Vector3, b: Vector3) -> void:
	var d := -a.z
	var depth := 0.62 + 1.0 * pow(cos(PI * (d + 1.0) / 22.0), 2.0)
	var middle := (a + b) * 0.5
	var slope := Basis(Vector3.RIGHT, atan2(b.y - a.y, 2.0))
	var dimensions := Vector3(0.24, depth, a.distance_to(b) + 0.02)
	for side in [-1, 1]:
		parts.append(Transform3D(slope.scaled_local(dimensions),
				middle + Vector3(side * 10.91, -depth * 0.5, 0)))


func _build_leaf(bridge: Node3D, label: String, distance: float, opposite: bool) -> void:
	var hinge := Geometry.group(bridge, label, Vector3(0, _deck_height(distance), -distance))
	hinge.rotation.y = PI if opposite else 0.0
	var leaf := Geometry.group(hinge, "RaisedDeck")
	leaf.rotation_degrees.x = WING_ANGLE
	Geometry.box(leaf, "TimberDeck", Vector3(0, -0.24, -8), Vector3(22, 0.48, 16), leaf_deck, true)
	var beams: Array[Transform3D] = []
	var seams: Array[Transform3D] = []
	for i in 16:
		var d := -i - 0.5
		seams.append(Geometry.box_transform(Vector3(0, 0.004, d), Vector3(14, 0.008, 0.034)))
		_beam(beams, Vector3(-10.85, -0.61, d), Vector3(10.85, -0.61, d), 0.24)
	for x in [-8.9, 8.9]:
		Geometry.box(leaf, "WalkwayFacing", Vector3(x, 0.006, -8), Vector3(3.8, 0.012, 16), leaf_walk)
	Geometry.batch(leaf, "TimberBoardJoints", box, board_seam, seams)
	var rails: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var x: float = side * 10.85
		for i in 8:
			var a := Vector3(x, -0.42, -i * 2.0)
			var b := a + Vector3.FORWARD * 2
			var c := a - Vector3.UP * (1.65 - i * 0.13)
			_beam(beams, a, b, 0.22)
			_beam(beams, c, b, 0.20)
			_beam(beams, c, c + Vector3(0, 0.13, -2), 0.26)
			rails.append(Geometry.box_transform(Vector3(x, 0.60, a.z), Vector3(0.11, 1.2, 0.11)))
		for y in [0.4, 1.19]:
			Geometry.box(leaf, "IronGuard", Vector3(x, y, -8), Vector3(0.13, 0.13, 16), iron, true)
	Geometry.batch(leaf, "LeafTrusses", box, iron, beams)
	var truss_body := StaticBody3D.new()
	truss_body.name = "LeafTrussCollision"
	truss_body.collision_mask = 0
	for member in beams:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = member.basis.get_scale().abs()
		collision.shape = shape
		collision.transform = Transform3D(member.basis.orthonormalized(), member.origin)
		truss_body.add_child(collision)
	leaf.add_child(truss_body)
	Geometry.batch(leaf, "LeafRailUprights", box, iron, rails)


func _deck_height(distance: float) -> float:
	return 0.045 + 1.65 * sin(PI * distance / BRIDGE_LENGTH)


func _right(points: PackedVector3Array, i: int) -> Vector3:
	var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
	return tangent.cross(Vector3.UP).normalized()


func _side_strip(mesh: SurfaceTool, a: Vector3, b: Vector3, ra: Vector3, rb: Vector3,
		near_a: float, far_a: float, near_b: float, far_b: float, side: float, y: float) -> void:
	var a1 := near_a * side
	var a2 := far_a * side
	var b1 := near_b * side
	var b2 := far_b * side
	_strip(mesh, a, b, ra, rb, minf(a1, a2), maxf(a1, a2), minf(b1, b2), maxf(b1, b2), y)


func _strip(mesh: SurfaceTool, a: Vector3, b: Vector3, ra: Vector3, rb: Vector3,
		a_left: float, a_right: float, b_left: float, b_right: float, y: float) -> void:
	var up := Vector3.UP * y
	_quad(mesh, a + ra * a_left + up, b + rb * b_left + up, b + rb * b_right + up, a + ra * a_right + up)


func _mesh_begin() -> SurfaceTool:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	return mesh


func _quad(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex: Vector3 in [a, b, c, a, c, d]:
		mesh.add_vertex(vertex)


func _add_surface(parent: Node3D, label: String, surface: SurfaceTool, material: Material,
		solid := true, visible := true) -> void:
	surface.generate_normals()
	var mesh := surface.commit()
	if visible:
		Geometry.mesh_part(parent, label, Vector3.ZERO, mesh, material)
	if solid:
		var body := StaticBody3D.new()
		body.name = label + "Collision"
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = not visible
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)


func _lamp(parent: Node3D, at: Vector3) -> void:
	var lamp: Node3D = LAMP.instantiate()
	lamp.position = at
	parent.add_child(lamp, true)
