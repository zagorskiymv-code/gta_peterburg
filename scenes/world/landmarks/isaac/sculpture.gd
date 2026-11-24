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
		var lean: float = [-0.13, 0.20, -0.05][pose]
		_figure(dark, light, Vector3.ZERO, 2.10, lean, 0.89, pose)
		_wing(dark, light, Vector3(-0.09, 0.98, -0.17), -1.0, 1.40 if pose == 0 else 1.17)
		_wing(dark, light, Vector3(0.12, 1.02, -0.15), 1.0, 1.18 if pose == 0 else 1.37)
		if pose == 1:
			_limb(light, Vector3(0.76, 0.04, 0.19), Vector3(0.68, 2.48, 0.21), 0.041)
	else:
		_limb(dark, Vector3(-13.76, 0.14, 0.09), Vector3(13.76, 0.14, 0.09), 0.16)
		_figure(dark, light, Vector3(-0.27, 0.14, 0.28), 3.48, 0.04, 0.38, 1)
		_wing(dark, light, Vector3(-0.35, 0.82, 0.11), -1.0, 2.42)
		_wing(dark, light, Vector3(0.10, 0.68, 0.11), 1.0, 2.14)
		_figure(dark, light, Vector3(-2.44, 0.10, 0.20), 2.49, 0.24, 0.33, 0)
		_figure(dark, light, Vector3(2.22, 0.15, 0.23), 2.78, -0.23, 0.36, 2)
		_figure(dark, light, Vector3(-4.56, 0.14, 0.13), 2.06, 0.35, 0.32, 2)
		_figure(dark, light, Vector3(4.70, 0.12, 0.14), 1.94, -0.19, 0.32, 0)
		_figure(dark, light, Vector3(-6.41, 0.1, 0.13), 1.60, -0.15, 0.32, 1)
		_drapery(dark, light, 1.0, 7.00, 1.39)
		for side: float in [-1.0, 1.0]:
			_drapery(dark, light, side, 9.01, 0.88)
			_drapery(dark, light, side, 11.66, 0.48)
	mesh = ArrayMesh.new()
	for surface: SurfaceTool in [dark, light]:
		surface.commit(mesh)


func _surface(material: Material) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	return surface


func _figure(dark: SurfaceTool, light: SurfaceTool, foot: Vector3, height: float,
		lean: float, depth: float, gesture: int) -> void:
	var belt := foot + Vector3(lean * height * 0.45, height * 0.47, 0)
	var shoulder := foot + Vector3(lean * height * 0.81, height * 0.79, 0)
	var head := foot + Vector3(lean * height * 0.98, height * 0.91, 0.055)
	var hem := foot + Vector3(-lean * height * 0.24, height * 0.23, 0)
	_ellipsoid(dark, hem, Vector3(height * 0.22, height * 0.25, height * 0.15 * depth), lean)
	_ellipsoid(dark, belt.lerp(shoulder, 0.57),
			Vector3(height * 0.169, height * 0.242, height * 0.18 * depth), -lean)
	_limb(light, shoulder, head, height * 0.055)
	_head(dark, light, head, height, depth, -1.0 if lean < 0 else 1.0)
	var front := Vector3.BACK * (height * 0.138 * depth)
	_limb(light, hem + front + Vector3(-height * 0.11, -height * 0.16, 0),
			belt + front + Vector3(height * 0.018, -height * 0.02, 0), height * 0.033)
	_limb(light, hem + front + Vector3(height * 0.11, -height * 0.1, 0),
			belt + front + Vector3(height * 0.05, height * 0.02, 0), height * 0.024)
	_limb(dark, belt + front - Vector3.RIGHT * height * 0.14,
			shoulder + front + Vector3.RIGHT * height * 0.13, height * 0.057)
	var left := shoulder + Vector3(-0.117, -0.042, 0.015) * height
	var right := shoulder + Vector3(0.117, -0.044, 0.03) * height
	match gesture:
		0:
			_arm(dark, light, left, belt + Vector3(-0.24, 0.04, 0.09) * height,
					belt + Vector3(-0.16, -0.10, 0.14) * height, height)
			_arm(dark, light, right, belt + Vector3(0.28, 0.13, 0.08) * height,
					shoulder + Vector3(0.38, 0.02, 0.11) * height, height)
		1:
			_arm(dark, light, left, shoulder + Vector3(-0.31, -0.09, 0.067) * height,
					shoulder + Vector3(-0.38, 0.10, 0.08) * height, height)
			_arm(dark, light, right, belt + Vector3(0.23, -0.02, 0.066) * height,
					belt + Vector3(0.05, 0.03, 0.14) * height, height)
		2:
			_arm(dark, light, left, belt + Vector3(-0.225, 0.047, 0.075) * height,
					belt + Vector3(0.01, 0.13, 0.15) * height, height)
			_arm(dark, light, right, shoulder + Vector3(0.23, -0.17, 0.04) * height,
					shoulder + Vector3(0.31, -0.28, 0.02) * height, height)


func _head(dark: SurfaceTool, light: SurfaceTool, center: Vector3, height: float,
		depth: float, profile: float) -> void:
	var width := height * 0.059
	_ellipsoid(dark, center + Vector3(-0.14 * profile, 0.27, -0.15) * width,
			Vector3(width * 1.03, width * 1.32, width * (0.44 + depth * 0.54)), -profile * 0.22)
	_ellipsoid(light, center + Vector3(0.24 * profile, -0.21, 0.40) * width,
			Vector3(width * 0.74, width * 1.03, width * (0.31 + depth * 0.45)), -profile * 0.17)
	_ellipsoid(light, center + Vector3(0.93 * profile, -0.18, 0.75) * width,
			Vector3(width * 0.26, width * 0.29, width * 0.31), profile * 0.18)


func _arm(dark: SurfaceTool, light: SurfaceTool, shoulder: Vector3, elbow: Vector3,
		hand: Vector3, height: float) -> void:
	_limb(dark, shoulder, elbow, height * 0.061)
	_limb(light, elbow, hand, height * 0.041)
	_ellipsoid(light, hand, Vector3(0.036, 0.043, 0.033) * height, 0.0)


func _drapery(dark: SurfaceTool, light: SurfaceTool, side: float, x: float, height: float) -> void:
	var hip := Vector3(x * side, height * 0.38, 0.13)
	var torso := hip + Vector3(-side * 1.0, height * 0.31, 0.1)
	_ellipsoid(dark, hip, Vector3(1.2, height * 0.34, 0.15), 0.12 * -side)
	_ellipsoid(dark, torso, Vector3(0.58, height * 0.34, 0.13), 0.48 * -side)
	_ellipsoid(light, torso + Vector3(-side * 0.57, height * 0.19, 0.04),
			Vector3(0.15, 0.17, 0.11), 0.0)
	_limb(light, hip + Vector3(side * 1.02, -height * 0.17, 0.11),
			hip + Vector3(-side * 0.41, height * 0.21, 0.15), 0.061)
	_limb(light, hip + Vector3(side * 0.46, -height * 0.31, 0.14),
			torso + Vector3(side * 0.09, -height * 0.19, 0.15), 0.047)


func _wing(dark: SurfaceTool, light: SurfaceTool, root: Vector3, side: float, span: float) -> void:
	var shoulder := root + Vector3(side * 0.42, 0.56, -0.12) * span
	_ellipsoid(dark, shoulder, Vector3(0.38, 0.65, 0.12) * span, side * -0.48)
	for feather in 6:
		var t := float(feather) / 5.0
		var quill := root + Vector3(side * (0.15 + 0.28 * t), 0.44 - 0.28 * t, 0.025) * span
		var tip := root + Vector3(side * (0.69 + 0.35 * sin(PI * t)), 1.00 - 0.78 * t, -0.21) * span
		_limb(dark, quill, tip, span * (0.131 - 0.043 * t))
		if feather % 2 == 0:
			_limb(light, quill.lerp(tip, 0.24) + Vector3.BACK * span * 0.082,
					quill.lerp(tip, 0.81) + Vector3.BACK * span * 0.068, span * 0.028)


func _ellipsoid(surface: SurfaceTool, center: Vector3, radii: Vector3, angle: float) -> void:
	var basis := Basis(Vector3.BACK, angle).scaled_local(radii)
	_append(surface, _sphere(), Transform3D(basis, center))


func _limb(surface: SurfaceTool, from: Vector3, to: Vector3, radius: float) -> void:
	var direction := to - from
	if direction.is_zero_approx():
		return
	var axis := direction.normalized()
	var reference := Vector3.BACK if absf(axis.z) < 0.97 else Vector3.RIGHT
	var across := axis.cross(reference).normalized()
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
