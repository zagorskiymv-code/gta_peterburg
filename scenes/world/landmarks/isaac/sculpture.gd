@tool
extends MeshInstance3D

@export var patina: Material
@export var highlight: Material
@export var roof_figure := false
@export_range(0, 2) var pose := 0


func _ready() -> void:
	var dark := _surface(patina)
	var light := _surface(highlight)
	if roof_figure:
		var lean := [-0.16, 0.18, -0.04][pose] as float
		_figure(dark, light, Vector3.ZERO, 2.05, lean, 1.0)
		_wing(dark, Vector3(0, 0.92, -0.08), -1.0, 1.31)
		_wing(dark, Vector3(0, 0.92, -0.11), 1.0, 1.17 if pose == 1 else 1.38)
		if pose == 1:
			_limb(light, Vector3(0.63, 0.1, 0.18), Vector3(0.4, 2.30, 0.19), 0.05)
	else:
		# The backing band and low folds join the scattered masses into one composition.
		_limb(dark, Vector3(-13.56, 0.12, 0.09), Vector3(13.56, 0.12, 0.09), 0.17)
		_figure(dark, light, Vector3(0.0, 0.08, 0.22), 3.39, -0.09, 0.35)
		_wing(dark, Vector3(0, 0.61, 0.12), -1.0, 2.25)
		_wing(dark, Vector3(0, 0.61, 0.11), 1.0, 2.25)
		for side: float in [-1.0, 1.0]:
			_figure(dark, light, Vector3(side * 2.15, 0.12, 0.14), 2.58, -side * 0.24, 0.28)
			_figure(dark, light, Vector3(side * 4.20, 0.17, 0.10), 2.02, side * 0.34, 0.27)
			_figure(dark, light, Vector3(side * 6.42, 0.09, 0.13), 1.67, -side * 0.39, 0.32)
			_drapery(dark, light, side, 8.70, 0.98)
			_drapery(dark, light, side, 11.3, 0.59)
	mesh = ArrayMesh.new()
	for surface: SurfaceTool in [dark, light]:
		surface.commit(mesh)


func _surface(material: Material) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	return surface


func _figure(dark: SurfaceTool, light: SurfaceTool, foot: Vector3, height: float,
		lean: float, depth: float) -> void:
	var belt := foot + Vector3(lean * height * 0.45, height * 0.45, 0)
	var shoulder := foot + Vector3(lean * height * 0.81, height * 0.80, 0)
	var head := foot + Vector3(lean * height * 0.98, height * 0.91, 0.04)
	_ellipsoid(dark, foot + Vector3(0, height * 0.21, 0),
			Vector3(height * 0.25, height * 0.23, height * 0.15 * depth), 0.0)
	_ellipsoid(dark, belt.lerp(shoulder, 0.56),
			Vector3(height * 0.18, height * 0.24, height * 0.16 * depth), -lean)
	_ellipsoid(light, head, Vector3(height * 0.073, height * 0.092, height * 0.099 * depth), -lean)
	for index in 4:
		var across := (index - 1.5) * height * 0.122
		var fold_foot := foot + Vector3(across, height * 0.065, height * 0.11 * depth)
		_limb(light, fold_foot, belt + Vector3(across * 0.25, 0, height * 0.08 * depth), height * 0.027)
	for side: float in [-1.0, 1.0]:
		var upper := shoulder + Vector3(side * height * 0.13, -height * 0.05, 0.04)
		var elbow := belt + Vector3(side * height * 0.32, height * (0.16 if side < 0 else 0.29), 0.09)
		_limb(dark, upper, elbow, height * 0.058)
		_limb(light, elbow, elbow + Vector3(side * height * 0.11, height * 0.09, 0.02), height * 0.043)


func _drapery(dark: SurfaceTool, light: SurfaceTool, side: float, x: float, height: float) -> void:
	var hip := Vector3(x * side, height * 0.38, 0.13)
	var torso := hip + Vector3(-side * 1.0, height * 0.31, 0.1)
	_ellipsoid(dark, hip, Vector3(1.2, height * 0.34, 0.15), 0.12 * -side)
	_ellipsoid(dark, torso, Vector3(0.58, height * 0.34, 0.13), 0.48 * -side)
	_ellipsoid(light, torso + Vector3(-side * 0.57, height * 0.19, 0.04),
			Vector3(0.15, 0.17, 0.11), 0.0)
	for index in 3:
		_limb(light, hip + Vector3(side * 0.96, -height * 0.25 + index * 0.1, 0.13),
				torso + Vector3(side * 0.12, -height * 0.17 + index * 0.1, 0.11), 0.062)


func _wing(surface: SurfaceTool, root: Vector3, side: float, span: float) -> void:
	for index in 5:
		var t := float(index) / 4.0
		var tip := root + Vector3(side * span * (0.47 + t * 0.46), span * (0.93 - t * 0.62), -0.08)
		_limb(surface, root + Vector3(side * 0.18, 0.24 - t * 0.18, 0), tip, span * (0.16 - t * 0.075))


func _ellipsoid(surface: SurfaceTool, center: Vector3, radii: Vector3, angle: float) -> void:
	var basis := Basis(Vector3.BACK, angle).scaled_local(radii)
	_append(surface, _sphere(), Transform3D(basis, center))


func _limb(surface: SurfaceTool, from: Vector3, to: Vector3, radius: float) -> void:
	var direction := to - from
	if direction.is_zero_approx():
		return
	var axis := direction.normalized()
	var across := axis.cross(Vector3.BACK).normalized()
	var basis := Basis(across * radius, axis * (direction.length() * 0.58), across.cross(axis) * radius)
	_append(surface, _sphere(), Transform3D(basis, from.lerp(to, 0.5)))


static var sphere_arrays: Array

static func _sphere() -> Array:
	if sphere_arrays.is_empty():
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		sphere_arrays = sphere.get_mesh_arrays()
	return sphere_arrays


func _append(surface: SurfaceTool, arrays: Array, transform: Transform3D) -> void:
	var normal_basis := transform.basis.inverse().transposed()
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		surface.set_normal((normal_basis * normals[index]).normalized())
		surface.add_vertex(transform * positions[index])
