@tool
extends RefCounted

const Geometry = preload("res://scripts/world/district_geometry.gd")

var sphere := SphereMesh.new()


func _init() -> void:
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 7


func horse_and_rider() -> Mesh:
	var sculpt := SurfaceTool.new()
	sculpt.begin(Mesh.PRIMITIVE_TRIANGLES)
	_oval(sculpt, Vector3(0, 1.08, 0), Vector3(1.77, 0.81, 0.65), 26)
	_oval(sculpt, Vector3(-0.61, 0.83, 0), Vector3(0.72, 0.73, 0.64), 24)
	_oval(sculpt, Vector3(0.50, 1.30, 0), Vector3(0.73, 0.78, 0.66), 27)
	_link(sculpt, Vector3(0.48, 1.35, 0), Vector3(0.91, 2.14, 0), 0.47, 0.29)
	_oval(sculpt, Vector3(0.63, 1.80, 0), Vector3(0.19, 0.77, 0.35), -27)
	_oval(sculpt, Vector3(1.06, 2.13, 0), Vector3(0.56, 0.28, 0.30), -28)
	_oval(sculpt, Vector3(1.30, 2.01, 0), Vector3(0.30, 0.22, 0.24), -22)
	for side in [-1, 1]:
		var z: float = side * 0.23
		var offset: float = side * 0.08
		_link(sculpt, Vector3(0.90, 2.24, side * 0.10), Vector3(0.86, 2.46, side * 0.14), 0.105, 0.036)
		_link(sculpt, Vector3(-0.57, 0.92, z), Vector3(-0.27 + offset, 0.53, z), 0.25, 0.145)
		_link(sculpt, Vector3(-0.27 + offset, 0.53, z), Vector3(-0.65 + offset, 0.27, z), 0.14, 0.095)
		_link(sculpt, Vector3(-0.65 + offset, 0.27, z), Vector3(-0.68 + offset, 0.08, z), 0.095, 0.125)
		_oval(sculpt, Vector3(-0.65 + offset, 0.06, z), Vector3(0.22, 0.12, 0.16))
		_link(sculpt, Vector3(0.54, 1.24, z), Vector3(0.99 + offset, 1.30 + offset, z), 0.25, 0.13)
		_link(sculpt, Vector3(0.99 + offset, 1.30 + offset, z), Vector3(0.78 + offset, 0.99 + offset, z), 0.13, 0.095)
		_oval(sculpt, Vector3(0.75 + offset, 0.98 + offset, z), Vector3(0.16, 0.16, 0.15), -25)
		_link(sculpt, Vector3(-0.06, 1.49, side * 0.26), Vector3(0.17, 1.15, side * 0.39), 0.18, 0.13)
		_link(sculpt, Vector3(0.17, 1.15, side * 0.39), Vector3(0.02, 0.83, side * 0.40), 0.13, 0.10)
		_oval(sculpt, Vector3(0.10, 0.83, side * 0.40), Vector3(0.24, 0.12, 0.14))
		_link(sculpt, Vector3(-0.03, 2.03, side * 0.20), Vector3(0.20, 1.83, side * 0.22), 0.15, 0.105)
		_link(sculpt, Vector3(0.20, 1.83, side * 0.22), Vector3(0.46, 1.93, side * 0.18), 0.105, 0.09)
		_link(sculpt, Vector3(0.46, 1.93, side * 0.18), Vector3(1.18, 2.03, side * 0.12), 0.028, 0.023)
	_link(sculpt, Vector3(-0.85, 0.94, 0), Vector3(-1.15, 0.68, 0.05), 0.20, 0.145)
	_link(sculpt, Vector3(-1.15, 0.68, 0.05), Vector3(-1.39, 0.38, 0.14), 0.145, 0.055)
	_oval(sculpt, Vector3(-0.12, 1.80, 0), Vector3(0.35, 0.68, 0.49), -8)
	_oval(sculpt, Vector3(-0.08, 2.22, 0), Vector3(0.24, 0.30, 0.25))
	_oval(sculpt, Vector3(-0.08, 2.37, 0), Vector3(0.37, 0.17, 0.34), 1)
	return sculpt.commit()


func atlas() -> Mesh:
	var sculpt := SurfaceTool.new()
	sculpt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1, 1]:
		_link(sculpt, Vector3(side * 0.19, 0.19, 0), Vector3(side * 0.18, 1.66, 0), 0.31, 0.39)
		_oval(sculpt, Vector3(side * 0.19, 0.14, 0.09), Vector3(0.32, 0.23, 0.53))
		_link(sculpt, Vector3(side * 0.33, 2.43, 0), Vector3(side * 0.63, 2.65, 0), 0.33, 0.24)
		_link(sculpt, Vector3(side * 0.63, 2.65, 0), Vector3(side * 0.49, 3.20, 0.04), 0.24, 0.18)
		_oval(sculpt, Vector3(side * 0.49, 3.21, 0.04), Vector3(0.25, 0.21, 0.23))
	_oval(sculpt, Vector3(0, 1.51, 0), Vector3(0.71, 0.57, 0.45))
	_oval(sculpt, Vector3(0, 2.09, 0), Vector3(0.83, 1.06, 0.49))
	_oval(sculpt, Vector3(0, 2.75, 0.07), Vector3(0.38, 0.50, 0.38))
	return sculpt.commit()


func angel() -> Mesh:
	var sculpt := SurfaceTool.new()
	sculpt.begin(Mesh.PRIMITIVE_TRIANGLES)
	_link(sculpt, Vector3(0, 0.08, 0), Vector3(0, 0.89, 0), 0.65, 0.31)
	_oval(sculpt, Vector3(0, 1.03, 0), Vector3(0.56, 0.69, 0.39))
	_oval(sculpt, Vector3(0.03, 1.50, 0.05), Vector3(0.30, 0.38, 0.30), 10)
	_link(sculpt, Vector3(-0.22, 1.27, 0), Vector3(-0.45, 1.47, 0.05), 0.18, 0.13)
	_link(sculpt, Vector3(-0.45, 1.47, 0.05), Vector3(-0.53, 1.92, 0.10), 0.13, 0.095)
	_link(sculpt, Vector3(0.22, 1.27, 0), Vector3(0.58, 1.28, 0.09), 0.16, 0.10)
	for side in [-1, 1]:
		for feather in 5:
			_oval(sculpt, Vector3(side * (0.34 + 0.087 * feather), 1.31 + 0.065 * feather, -0.20),
					Vector3(0.32, 0.85 - feather * 0.065, 0.14), -side * (24 + feather * 8))
	for i in 10:
		_oval(sculpt, Vector3(0.42 * cos(i * 0.60), 0.08, 0.27 * sin(i * 0.60)),
				Vector3(0.21, 0.13, 0.16))
	return sculpt.commit()


func _oval(sculpt: SurfaceTool, center: Vector3, size: Vector3, angle := 0.0) -> void:
	var basis := Basis(Vector3.BACK, deg_to_rad(angle)).scaled_local(size)
	sculpt.append_from(sphere, 0, Transform3D(basis, center))


func _link(sculpt: SurfaceTool, start: Vector3, end: Vector3, base_diameter: float,
		tip_diameter: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 9
	mesh.bottom_radius = base_diameter * 0.5
	mesh.top_radius = tip_diameter * 0.5
	mesh.height = start.distance_to(end)
	var axis := (end - start).normalized()
	var rotation := Quaternion(Vector3.UP, axis)
	sculpt.append_from(mesh, 0, Transform3D(Basis(rotation), (start + end) * 0.5))
