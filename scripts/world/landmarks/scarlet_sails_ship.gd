@tool
extends Node3D

const G = preload("res://scripts/world/district_geometry.gd")
const SAIL_SHADER := preload("res://materials/scarlet_sail.gdshader")
var dark_wood := G.solid_material(Color("#583425"))
var teak := G.solid_material(Color("#936144"))
var gold := G.solid_material(Color("#cba35c"))
var rope := G.solid_material(Color("#594636"))
var sailing: Node3D
var glow := StandardMaterial3D.new()
var clock := 0.0

func _ready() -> void:
	sailing = G.group(self, "RockingHull")
	_hull()
	G.box(sailing, "GildedSternGallery", Vector3(0, 2.45, 22.5), Vector3(7, 2.0, 4.0), dark_wood)
	var spars: Array[Transform3D] = []
	var rigging: Array[Transform3D] = []
	var rail: Array[Transform3D] = []
	var sail_material := ShaderMaterial.new()
	sail_material.shader = SAIL_SHADER
	for side in [-1.0, 1.0]:
		for i in 23:
			var z := -21.0 + 1.88 * i
			var x: float = side * _beam_width(z)
			rail.append(G.box_transform(Vector3(x, 2.25, z), Vector3(0.105, 0.77, 0.105)))
			if i < 22:
				_link(rail, Vector3(x, 2.64, z), Vector3(side * _beam_width(z+1.88), 2.64, z+1.88), 0.12)
	for mast in 3:
		var z := -13.5 + mast * 12.6
		var top := 20.2 if mast == 1 else 17.5
		_link(spars, Vector3(0, 0.8, z), Vector3(0, top, z), 0.27)
		for tier in 3:
			var y := 10.0 + tier * 3.55
			if y > top - 0.3:
				continue
			var width := 9.6 - tier * 2.0 + (1.05 if mast == 1 else 0.0)
			_link(spars, Vector3(-width*0.57, y, z), Vector3(width*0.57, y, z), 0.12)
			G.mesh_part(sailing, "BillowingScarletSail", Vector3(0, y, z-0.20),
					_sail(width, 3.0 if tier else 4.2), sail_material)
		for side in [-1.0, 1.0]:
			_link(rigging, Vector3(0, top-0.8, z), Vector3(side*3.8, 2.45, z+3.2), 0.035)
			_link(rigging, Vector3(0, top-1.4, z), Vector3(side*3.8, 2.45, z-2.65), 0.035)
		_link(rigging, Vector3(0, top, z), Vector3(0, 2.5, -25 if mast == 0 else z-14), 0.046)
	_link(spars, Vector3(0, 2.55, -23), Vector3(0, 4.70, -29.5), 0.22)
	var unit := BoxMesh.new()
	G.batch(sailing, "WoodSpars", unit, teak, spars)
	G.batch(sailing, "StandingRigging", unit, rope, rigging)
	G.batch(sailing, "GoldRail", unit, gold, rail)
	_lights()

func _process(delta: float) -> void:
	clock = fposmod(clock + delta, TAU * 20.0)
	sailing.rotation.z = sin(clock * 0.60) * 0.026
	sailing.rotation.x = sin(clock * 0.40) * 0.013
	sailing.position.y = sin(clock * 0.55) * 0.14
	glow.emission_energy_multiplier = 0.84 + 0.13 * sin(clock * 2.4) + 0.09 * sin(clock * 4.3)

func _hull() -> void:
	var hull := _surface()
	var deck := _surface()
	var stripes: Array[Transform3D] = []
	for i in 20:
		var a := -26.0 + i * 2.6
		var b := a + 2.6
		for side in [-1.0, 1.0]:
			var pa := Vector3(side*_beam_width(a), _sheer(a), a)
			var pb := Vector3(side*_beam_width(b), _sheer(b), b)
			var qa := Vector3(pa.x*0.68, -1.38, a)
			var qb := Vector3(pb.x*0.68, -1.38, b)
			if side > 0:
				_quad(hull, pa, qa, qb, pb)
			else:
				_quad(hull, pa, pb, qb, qa)
			_link(stripes, pa - Vector3.UP*0.19, pb - Vector3.UP*0.19, 0.14)
		_quad(deck, Vector3(-_beam_width(a), _sheer(a), a), Vector3(_beam_width(a), _sheer(a), a),
				Vector3(_beam_width(b), _sheer(b), b), Vector3(-_beam_width(b), _sheer(b), b))
	G.mesh_part(sailing, "DarkWoodPlanking", Vector3.ZERO, _finish(hull), dark_wood)
	G.mesh_part(sailing, "TimberDeck", Vector3.ZERO, _finish(deck), teak)
	G.batch(sailing, "GiltSheerStrake", BoxMesh.new(), gold, stripes)

func _beam_width(z: float) -> float:
	return 0.145 + 4.25 * pow(maxf(0.0, 1.0 - pow(absf(z)/26.0, 3.0)), 0.71)

func _sheer(z: float) -> float:
	return 1.72 + pow(absf(z)/26.0, 4.0)*0.95

func _sail(width: float, height: float) -> ArrayMesh:
	var surface := _surface()
	var grid := Vector2i(12, 7)
	for ix in grid.x:
		for iy in grid.y:
			var a := Vector2(float(ix)/grid.x, float(iy)/grid.y)
			var b := Vector2(float(ix+1)/grid.x, float(iy+1)/grid.y)
			for uv: Vector2 in [a, Vector2(b.x,a.y), b, a, b, Vector2(a.x,b.y)]:
				var billow := sin(PI*uv.x)*sin(PI*uv.y*0.90)*1.32
				var folds := 0.115*sin(uv.x*TAU*5.0)*uv.y
				var hem := 0.38*uv.y*pow(absf(uv.x-0.5)*2.0, 2)
				surface.set_uv(uv)
				surface.add_vertex(Vector3((uv.x-0.5)*width*(1.0-uv.y*0.16),
						-uv.y*height+hem, -billow + folds))
	return _finish(surface)

func _lights() -> void:
	glow.albedo_color = Color("#ffd17d")
	glow.emission_enabled = true
	glow.emission = Color("#ff9a36")
	var bulbs: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for i in 14:
			var z := -20.0 + i * 3.03
			bulbs.append(G.box_transform(Vector3(side*_beam_width(z), 2.62, z), Vector3(0.18, 0.25, 0.17)))
	G.batch(sailing, "CelebrationLights", BoxMesh.new(), glow, bulbs)
	for z in [-12.0, 14.0]:
		var lantern := OmniLight3D.new()
		lantern.position = Vector3(0, 4.8, z)
		lantern.light_color = Color("#ffb65e")
		lantern.light_energy = 0.75
		lantern.omni_range = 12
		sailing.add_child(lantern)
	# A handful of warm floating sparks around the aft lantern.
	var sparks := GPUParticles3D.new()
	sparks.position = Vector3(0, 3.3, 13)
	sparks.amount = 10
	sparks.lifetime = 2.8
	var drift := ParticleProcessMaterial.new()
	drift.direction = Vector3.UP
	drift.initial_velocity_min = 0.1
	drift.initial_velocity_max = 0.38
	drift.gravity = Vector3(0, 0.06, 0)
	sparks.process_material = drift
	var spark := SphereMesh.new()
	spark.radius = 0.049
	spark.height = 0.098
	spark.radial_segments = 5
	spark.rings = 3
	spark.material = glow
	sparks.draw_pass_1 = spark
	sailing.add_child(sparks)

func _link(parts: Array[Transform3D], a: Vector3, b: Vector3, thickness: float) -> void:
	var span := b-a
	var aim := Basis.looking_at(span, Vector3.UP if absf(span.normalized().x) > 0.95 else Vector3.RIGHT)
	parts.append(Transform3D(aim.scaled_local(Vector3(thickness, thickness, span.length()+0.025)), (a+b)*0.5))

func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point: Vector3 in [a,b,c,a,c,d]:
		surface.add_vertex(point)

func _finish(surface: SurfaceTool) -> ArrayMesh:
	surface.generate_normals()
	return surface.commit()
