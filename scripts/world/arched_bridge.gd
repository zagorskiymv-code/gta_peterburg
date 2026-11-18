@tool
extends RefCounted

const Geometry = preload("res://scripts/world/district_geometry.gd")
const SPAN_SEGMENTS := 32
const RISE := 1.55


static func build(parent: Node3D, west: float, east: float, north: float, south: float,
		paving: Material, stone: Material, coping: Material) -> void:
	var bridge := Geometry.group(parent, "StoneBridge")
	var deck := _surface(west, east, north, south, 0.0, 0.0, false, false)
	Geometry.mesh_part(bridge, "ArchedPaving", Vector3.ZERO, deck, paving)
	_collision(bridge, "DeckCollision", deck)
	Geometry.mesh_part(bridge, "GraniteVault", Vector3.ZERO,
			_surface(west, east, north, south, -0.025, 0.0, true, true), stone)
	for z in [north + 0.24, south - 0.24]:
		var guard := _surface(west, east, z - 0.24, z + 0.24, 1.14, 0.0, true, false)
		Geometry.mesh_part(bridge, "CurvedParapet", Vector3.ZERO, guard, stone)
		_collision(bridge, "ParapetCollision", guard)
		var cap := _surface(west, east, z - 0.31, z + 0.31, 1.22, 1.10, true, false)
		Geometry.mesh_part(bridge, "Coping", Vector3.ZERO, cap, coping)


static func _surface(west: float, east: float, north: float, south: float,
		top: float, bottom: float, solid: bool, vault: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for index in SPAN_SEGMENTS:
		var a := float(index) / SPAN_SEGMENTS
		var b := float(index + 1) / SPAN_SEGMENTS
		var xa := lerpf(west, east, a)
		var xb := lerpf(west, east, b)
		var ha := RISE * pow(sin(PI * a), 2.0)
		var hb := RISE * pow(sin(PI * b), 2.0)
		var an := Vector3(xa, ha + top, north)
		var bn := Vector3(xb, hb + top, north)
		var bs := Vector3(xb, hb + top, south)
		var a_south := Vector3(xa, ha + top, south)
		_quad(surface, an, bn, bs, a_south)
		if not solid:
			continue
		var la := ha + bottom
		var lb := hb + bottom
		if vault:
			la = -2.9 + 3.45 * sqrt(maxf(0, 1.0 - pow(2.0 * a - 1.0, 2.0)))
			lb = -2.9 + 3.45 * sqrt(maxf(0, 1.0 - pow(2.0 * b - 1.0, 2.0)))
		var lan := Vector3(xa, la, north)
		var lbn := Vector3(xb, lb, north)
		var lbs := Vector3(xb, lb, south)
		var las := Vector3(xa, la, south)
		_quad(surface, lan, las, lbs, lbn)
		_quad(surface, lan, lbn, bn, an)
		_quad(surface, a_south, bs, lbs, las)
		if index == 0:
			_quad(surface, an, a_south, las, lan)
		if index == SPAN_SEGMENTS - 1:
			_quad(surface, bn, lbn, lbs, bs)
	surface.generate_normals()
	return surface.commit()


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(vertex)


static func _collision(parent: Node3D, label: String, mesh: Mesh) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
