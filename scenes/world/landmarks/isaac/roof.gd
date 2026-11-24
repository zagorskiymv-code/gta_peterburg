@tool
extends MeshInstance3D

const EAVE := Vector2(21.95, 19.45)
const INNER := Vector2(9.0, 8.6)
const EAVE_Y := 20.57
const INNER_Y := 20.99
const RIDGE_Y := 23.42

@export var roof_material: Material
@export var seam_material: Material
@export var masonry_material: Material


func _ready() -> void:
	var copper := _surface(roof_material)
	var seams := _surface(seam_material)
	var masonry := _surface(masonry_material)
	for face in 4:
		var basis := Basis(Vector3.UP, face * PI / 2.0)
		var end := EAVE.y if face % 2 == 0 else EAVE.x
		var width := EAVE.x if face % 2 == 0 else EAVE.y
		var inner_end := INNER.y if face % 2 == 0 else INNER.x
		var inner_width := INNER.x if face % 2 == 0 else INNER.y
		var outer_left := Vector3(-width, EAVE_Y, end)
		var outer_right := Vector3(width, EAVE_Y, end)
		var inner_left := Vector3(-inner_width, INNER_Y, inner_end)
		var inner_right := Vector3(inner_width, INNER_Y, inner_end)
		_panel(copper, seams, basis, outer_left, outer_right, inner_right, inner_left, 28)
		# Raised transverse volumes leave the lower hipped copper roof visible at the corners.
		var arm := 8.85 if face % 2 == 0 else 7.55
		var front := end - 1.46
		var back := inner_end - 0.8
		var near_ridge := Vector3(0, RIDGE_Y - 0.84, front)
		var far_ridge := Vector3(0, RIDGE_Y, back)
		var left_front := Vector3(-arm, 20.78, front)
		var right_front := Vector3(arm, 20.78, front)
		var left_back := Vector3(-arm + 0.68, 21.52, back)
		var right_back := Vector3(arm - 0.68, 21.52, back)
		_panel(copper, seams, basis, left_front, near_ridge, far_ridge, left_back, 12)
		_panel(copper, seams, basis, near_ridge, right_front, right_back, far_ridge, 12)
		_quad(seams, basis, near_ridge + Vector3(-0.09, 0.045, 0),
				near_ridge + Vector3(0.09, 0.045, 0), far_ridge + Vector3(0.09, 0.045, 0),
				far_ridge + Vector3(-0.09, 0.045, 0))
		for edge: Vector3 in [left_front, right_front]:
			var step := Vector3.RIGHT * 0.078
			var lower := edge + Vector3.UP * 0.04
			var upper := near_ridge + Vector3.UP * 0.04
			_quad(seams, basis, lower - step, upper - step, upper + step, lower + step)
		_triangle(masonry, basis, left_front, right_front, near_ridge)
		_quad(masonry, basis, left_front - Vector3.UP * 0.50, right_front - Vector3.UP * 0.50, right_front, left_front)
		_quad(masonry, basis, right_front - Vector3.UP, right_back - Vector3.UP, right_back, right_front)
		_quad(masonry, basis, left_back - Vector3.UP, left_front - Vector3.UP, left_front, left_back)

	_quad(copper, Basis.IDENTITY, Vector3(-INNER.x, INNER_Y, INNER.y),
			Vector3(INNER.x, INNER_Y, INNER.y), Vector3(INNER.x, INNER_Y, -INNER.y),
			Vector3(-INNER.x, INNER_Y, -INNER.y))
	mesh = ArrayMesh.new()
	for surface: SurfaceTool in [copper, seams, masonry]:
		surface.generate_normals()
		surface.commit(mesh)


func _surface(material: Material) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	return surface


func _panel(copper: SurfaceTool, seams: SurfaceTool, basis: Basis, a: Vector3,
		b: Vector3, c: Vector3, d: Vector3, count: int) -> void:
	_quad(copper, basis, a, b, c, d)
	for index in range(1, count):
		var t := float(index) / count
		var front := a.lerp(b, t) + Vector3.UP * 0.028
		var back := d.lerp(c, t) + Vector3.UP * 0.028
		var width := Vector3.RIGHT * 0.037
		_quad(seams, basis, front - width, front + width, back + width, back - width)
	for index in range(1, 6):
		var t := float(index) / 6.0
		var left := a.lerp(d, t) + Vector3.UP * 0.025
		var right := b.lerp(c, t) + Vector3.UP * 0.025
		_quad(seams, basis, left + Vector3.BACK * 0.015, right + Vector3.BACK * 0.015,
				right - Vector3.BACK * 0.015, left - Vector3.BACK * 0.015)


func _quad(surface: SurfaceTool, basis: Basis, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(surface, basis, a, b, c)
	_triangle(surface, basis, a, c, d)


func _triangle(surface: SurfaceTool, basis: Basis, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point: Vector3 in [a, c, b]:
		surface.add_vertex(basis * point)
