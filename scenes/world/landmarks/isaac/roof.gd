@tool
extends MeshInstance3D

const EAVE := Vector2(21.64, 24.69)
const EAVE_HEIGHT := 20.57
const STONE_TOE_RADIUS := 13.23
const STONE_TOE_HEIGHT := 22.0
const PANELS_PER_FACE := 32
const STATIONS := [0.0, 0.33, 0.58, 0.81, 1.0]
const RIDGE_HEIGHTS := [0.0, 1.42, 1.25, 0.39, 0.0]
const VALLEY_DEPTHS := [0.0, -0.18, -0.26, -0.14, 0.0]

@export var roof_material: Material
@export var seam_material: Material
@export var show_seams := true


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	var copper := _surface(roof_material)
	var seams := _surface(seam_material)
	for face in 4:
		for panel in PANELS_PER_FACE:
			for row in range(STATIONS.size() - 1):
				var left := float(panel) / PANELS_PER_FACE
				var right := float(panel + 1) / PANELS_PER_FACE
				var a := _point(face, left, row)
				var b := _point(face, right, row)
				var c := _point(face, right, row + 1)
				var d := _point(face, left, row + 1)
				_quad(copper, a, b, c, d)
				if show_seams:
					_seam(seams, a, b, c, d, panel == 0)
	var result := copper.commit()
	if show_seams:
		seams.commit(result)
	mesh = result


func _point(face: int, span: float, row: int) -> Vector3:
	var half_width := EAVE.x if face % 2 == 0 else EAVE.y
	var depth := EAVE.y if face % 2 == 0 else EAVE.x
	var across := (span * 2.0 - 1.0) * half_width
	var edge := Vector2(across, depth).rotated(-face * PI / 2.0)
	var foot := edge.normalized() * STONE_TOE_RADIUS
	var t: float = STATIONS[row]
	var plan := edge.lerp(foot, t)
	# Each portico axis has a distinct raised line. The four shoulders fold
	# down at the diagonal valleys, and all faces share the same circular toe.
	var ridge := maxf(1.0 - absf(span * 2.0 - 1.0) * 2.3, 0.0)
	var valley := smoothstep(0.52, 1.0, absf(span * 2.0 - 1.0))
	var rise: float = ridge * RIDGE_HEIGHTS[row] + valley * VALLEY_DEPTHS[row]
	var height := lerpf(EAVE_HEIGHT, STONE_TOE_HEIGHT, t) + rise
	return Vector3(plan.x, height, plan.y)


func _surface(material: Material) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	return surface


func _seam(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, valley: bool) -> void:
	# Fold the seam up from the actual panel edge, leaving the roof surface intact.
	var height := Vector3.UP * 0.027
	var width := 0.10 if valley else 0.052
	var a_offset := a.move_toward(b, width)
	var d_offset := d.move_toward(c, width)
	_quad(surface, a + height, a_offset + height, d_offset + height, d + height)
	_quad(surface, a_offset + height, a_offset, d_offset, d_offset + height)


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# Share the area-weighted normal across each panel bay so its internal
	# triangulation stays invisible while the height breaks retain their edges.
	var normal := ((b - a).cross(c - a) + (c - a).cross(d - a)).normalized()
	for vertex: Vector3 in [a, c, b, a, d, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)
