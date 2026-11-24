@tool
extends MeshInstance3D

const EAVE := Vector2(21.6, 19.1)
const CROWN := Vector2(8.2, 7.2)
const EAVE_HEIGHT := 20.47
const CROWN_HEIGHT := 22.9
const PANEL_COUNT := 27

@export var roof_material: Material
@export var seam_material: Material


func _ready() -> void:
	var panels := SurfaceTool.new()
	var seams := SurfaceTool.new()
	panels.begin(Mesh.PRIMITIVE_TRIANGLES)
	seams.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 4:
		var along_x := side % 2 == 0
		var yaw := side * PI * 0.5
		var basis := Basis(Vector3.UP, yaw)
		var half_width := EAVE.x if along_x else EAVE.y
		var outer_depth := EAVE.y if along_x else EAVE.x
		var inner_width := CROWN.x if along_x else CROWN.y
		var inner_depth := CROWN.y if along_x else CROWN.x
		var a := basis * Vector3(-half_width, EAVE_HEIGHT, outer_depth)
		var b := basis * Vector3(half_width, EAVE_HEIGHT, outer_depth)
		var c := basis * Vector3(inner_width, CROWN_HEIGHT, inner_depth)
		var d := basis * Vector3(-inner_width, CROWN_HEIGHT, inner_depth)
		_quad(panels, a, b, c, d)
		for panel in range(1, PANEL_COUNT):
			var t := float(panel) / PANEL_COUNT
			var start := a.lerp(b, t) + Vector3.UP * 0.036
			var end := d.lerp(c, t) + Vector3.UP * 0.036
			var width := basis.x * 0.034
			_quad(seams, start - width, start + width, end + width, end - width)
	_quad(panels, Vector3(-CROWN.x, CROWN_HEIGHT, CROWN.y),
			Vector3(CROWN.x, CROWN_HEIGHT, CROWN.y), Vector3(CROWN.x, CROWN_HEIGHT, -CROWN.y),
			Vector3(-CROWN.x, CROWN_HEIGHT, -CROWN.y))
	panels.generate_normals()
	seams.generate_normals()
	panels.set_material(roof_material)
	seams.set_material(seam_material)
	mesh = seams.commit(panels.commit())


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex: Vector3 in [a, c, b, a, d, c]:
		surface.add_vertex(vertex)
