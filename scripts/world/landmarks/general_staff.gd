@tool
extends RefCounted

const G = preload("res://scripts/world/district_geometry.gd")
const LAMP := preload("res://scenes/world/props/gas_lamp.tscn")
const HALF_ARCH := 4.25
const HEIGHT := 11.6
const DEPTH := 6.6
var ochre := G.solid_material(Color("#cdb27d"))
var stone := G.solid_material(Color("#e0cfac"))
var bronze := G.solid_material(Color("#4f5d50"))
var glass := G.solid_material(Color("#505455"))
var roof := G.solid_material(Color("#6d6a5c"))
var box := BoxMesh.new()

func build(parent: Node3D, paving: Material) -> void:
	var staff := G.group(parent, "GeneralStaff", Vector3(24, 0, -190))
	var frames: Array[Transform3D] = []
	var panes: Array[Transform3D] = []
	var courses: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for i in 7:
			var a: float = side * lerpf(HALF_ARCH + 0.95, 34.0, i / 7.0)
			var b: float = side * lerpf(HALF_ARCH + 0.95, 34.0, (i + 1) / 7.0)
			var x0 := minf(a, b)
			var x1 := maxf(a, b)
			var z0 := _curve(x0)
			var z1 := _curve(x1)
			var outline: Array[Vector3] = [Vector3(x0, 0, z0), Vector3(x1, 0, z1),
				Vector3(x1, 0, z1 + DEPTH), Vector3(x0, 0, z0 + DEPTH)]
			_section(staff, outline)
			var basis := Basis(Vector3.UP, atan2(z0 - z1, x1 - x0))
			var span := Vector2(x1 - x0, z1 - z0).length()
			for y in [0.31, 3.63, 7.27, 11.40]:
				courses.append(Transform3D(basis.scaled_local(Vector3(span + 0.05, 0.19, 0.34)), Vector3((x0+x1)/2, y, (z0+z1)/2 - 0.10)))
			for x in [lerpf(x0, x1, 0.29), lerpf(x0, x1, 0.71)]:
				var z := lerpf(z0, z1, inverse_lerp(x0, x1, x))
				for y in [1.98, 5.26, 8.92]:
					frames.append(Transform3D(basis.scaled_local(Vector3(1.17, 1.98, 0.14)), Vector3(x, y, z - 0.07)))
					panes.append(Transform3D(basis.scaled_local(Vector3(0.89, 1.73, 0.13)), Vector3(x, y, z - 0.16)))
					frames.append(Transform3D(basis.scaled_local(Vector3(0.98, 0.054, 0.09)), Vector3(x, y+0.17, z - 0.24)))
			courses.append(Transform3D(basis.scaled_local(Vector3(0.22, 10.40, 0.23)),
					Vector3(x0 + 0.09, 5.7, z0 - 0.07)))
	G.batch(staff, "WindowFrames", box, stone, frames)
	G.batch(staff, "RecessedGlass", box, glass, panes)
	G.batch(staff, "Entablatures", box, stone, courses)
	_arch(staff)
	var court := G.group(staff, "InnerCourt", Vector3(0, 0, 15.0))
	G.box(court, "CourtPaving", Vector3(0, -0.081, 0), Vector3(15.0, 0.22, 22), paving, true)
	for side in [-1.0, 1.0]:
		G.box(court, "CourtyardWing", Vector3(side * 8.8, 3.2, -1.06), Vector3(2.8, 6.4, 15.6), ochre, true)
		var light: Node3D = LAMP.instantiate()
		light.position = Vector3(side * 6.2, 0.03, 2.9)
		court.add_child(light, true)
		var windows: Array[Transform3D] = []
		for z in [-6.0, -3.2, 0.0, 3.2, 6.0]:
			for y in [2.0, 4.5]:
				windows.append(G.box_transform(Vector3(side * 7.38, y, z), Vector3(0.11, 1.38, 1.05)))
		G.batch(court, "CourtyardWindows", box, glass, windows)

func _curve(x: float) -> float:
	# The terminal bays turn towards the square instead of forming an orthogonal block.
	return -10.8 * pow(x / 34.0, 2.0)

func _section(parent: Node3D, outline: Array[Vector3]) -> void:
	var surface := _begin()
	for i in 4:
		var a := outline[i]
		var b := outline[(i + 1) % 4]
		_quad(surface, a, b, b + Vector3.UP * HEIGHT, a + Vector3.UP * HEIGHT)
	_quad(surface, outline[0]+Vector3.UP*HEIGHT, outline[1]+Vector3.UP*HEIGHT,
			outline[2]+Vector3.UP*HEIGHT, outline[3]+Vector3.UP*HEIGHT)
	_finish(parent, "CurvedWingBay", surface, ochre, true)

func _arch(parent: Node3D) -> void:
	var arch := G.group(parent, "TriumphalArch")
	var surface := _begin()
	for i in 24:
		var left := lerpf(-HALF_ARCH, HALF_ARCH, i / 24.0)
		var right := lerpf(-HALF_ARCH, HALF_ARCH, (i + 1) / 24.0)
		var a := Vector3(left, _soffit(left), -0.12)
		var b := Vector3(right, _soffit(right), -0.12)
		var c := b + Vector3.BACK * (DEPTH + 0.24)
		var d := a + Vector3.BACK * (DEPTH + 0.24)
		_quad(surface, a, d, c, b)
		_quad(surface, a, b, Vector3(b.x, HEIGHT, b.z), Vector3(a.x, HEIGHT, a.z))
		_quad(surface, d, Vector3(d.x, HEIGHT, d.z), Vector3(c.x, HEIGHT, c.z), c)
	_finish(arch, "Vault", surface, ochre, true)
	var ring: Array[Transform3D] = []
	for i in 19:
		var theta := PI * i / 18.0
		var at := Vector3(cos(theta) * 4.38, 4.1 + sin(theta) * 2.68, -0.22)
		var tangent := Vector2(-4.38*sin(theta), 2.68*cos(theta)).angle()
		ring.append(Transform3D(Basis(Vector3.BACK, tangent).scaled_local(Vector3(0.66, 0.32, 0.25)), at))
	G.batch(arch, "ArchVoussoirs", box, stone, ring)
	for side in [-1.0, 1.0]:
		G.box(arch, "ArchPier", Vector3(side * 4.70, HEIGHT/2, DEPTH/2), Vector3(0.94, HEIGHT, DEPTH+0.14), ochre, true)
		for x in [5.00, 6.38]:
			var shaft := CylinderMesh.new()
			shaft.radial_segments = 10
			shaft.height = 7.2
			shaft.bottom_radius = 0.29
			shaft.top_radius = 0.24
			G.mesh_part(arch, "TriumphalColumn", Vector3(side*x, 4.5, -0.30), shaft, stone)
	G.box(arch, "TriumphalEntablature", Vector3(0, 9.13, -0.12), Vector3(14.2, 0.53, 1.0), stone)
	G.box(arch, "CentralAttic", Vector3(0, 11.4, 2.0), Vector3(14.2, 1.75, 4.25), ochre)
	G.box(arch, "AtticCornice", Vector3(0, 12.32, 2.0), Vector3(14.55, 0.23, 4.46), stone)
	_quadriga(arch)

func _quadriga(arch: Node3D) -> void:
	var figures := SphereMesh.new()
	figures.radial_segments = 10
	figures.rings = 6
	G.box(arch, "BronzeChariot", Vector3(0, 12.77, 1.64), Vector3(2.55, 0.72, 1.16), bronze)
	for x in [-2.15, -1.29, -0.43, 0.43, 1.29, 2.15]:
		G.mesh_part(arch, "Horse", Vector3(x, 13.02, 0.44), figures, bronze).scale = Vector3(0.44, 0.59, 1.36)
		G.mesh_part(arch, "RaisedNeck", Vector3(x, 13.39, -0.10), figures, bronze).scale = Vector3(0.29, 0.75, 0.35)
		G.mesh_part(arch, "HorseHead", Vector3(x, 13.69, -0.33), figures, bronze).scale = Vector3(0.29, 0.32, 0.51)
		for z in [0.15, 0.76]:
			for side in [-1, 1]:
				G.box(arch, "HorseLeg", Vector3(x+side*0.135, 12.63, z), Vector3(0.09, 0.63, 0.10), bronze)
	G.mesh_part(arch, "Victory", Vector3(0, 13.7, 1.65), figures, bronze).scale = Vector3(0.53, 1.37, 0.37)
	G.mesh_part(arch, "VictoryHead", Vector3(0, 14.51, 1.64), figures, bronze).scale = Vector3(0.29, 0.38, 0.30)
	for side in [-1, 1]:
		G.mesh_part(arch, "VictoryWing", Vector3(side*0.50, 14.1, 1.75), figures, bronze).scale = Vector3(0.68, 1.14, 0.19)

func _soffit(x: float) -> float:
	return 4.1 + 2.54 * sqrt(maxf(0.0, 1.0 - pow(x / HALF_ARCH, 2.0)))

func _begin() -> SurfaceTool:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	s.set_smooth_group(-1)
	return s

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a,b,c,a,c,d]:
		surface.add_vertex(v)

func _finish(parent: Node3D, label: String, surface: SurfaceTool, material: Material, solid: bool) -> void:
	surface.generate_normals()
	var mesh := surface.commit()
	G.mesh_part(parent, label, Vector3.ZERO, mesh, material)
	if solid:
		var body := StaticBody3D.new()
		body.name = label + "Collision"
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		collider.shape = shape
		body.add_child(collider)
		parent.add_child(body, true)
