@tool
extends Node3D

@export var pier_inner: float
@export var pier_front: float


func _ready() -> void:
	# Leave the full front colonnade in place. Move the rear pair clear of the
	# masonry returns, with the same adjustment to their collision shapes.
	for index in 2:
		var x := (pier_inner - 1.25) * (-1.0 if index == 0 else 1.0)
		var column: Node3D = get_node("RearColumn%d" % index)
		var collision: Node3D = get_node("ColumnCollisions/RearShape%d" % index)
		column.position.x = x
		collision.position.x = x
	for child in get_children():
		var part := child as MeshInstance3D
		if part == null or part.mesh == null:
			continue
		var bounds := part.transform * part.mesh.get_aabb()
		if bounds.position.z >= pier_front:
			continue
		if bounds.position.x >= -pier_inner and bounds.end.x <= pier_inner:
			continue
		_trim_at_piers(part)


func _trim_at_piers(part: MeshInstance3D) -> void:
	var source := part.mesh
	var cut := ArrayMesh.new()
	var inverse := part.transform.affine_inverse()
	for index in source.get_surface_count():
		var arrays := source.surface_get_arrays(index)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(points.size())
			for vertex in points.size():
				indices[vertex] = vertex
		var output := SurfaceTool.new()
		output.begin(Mesh.PRIMITIVE_TRIANGLES)
		output.set_material(source.surface_get_material(index))
		for face in range(0, indices.size(), 3):
			var polygon: Array[Vertex] = []
			for corner in 3:
				var vertex := indices[face + corner]
				polygon.append(Vertex.new(part.transform * points[vertex], normals[vertex]))
			var left := _clip(polygon, Vector3.LEFT, pier_inner)
			var right := _clip(polygon, Vector3.RIGHT, pier_inner)
			var middle := _clip(_clip(polygon, Vector3.LEFT, -pier_inner), Vector3.RIGHT, -pier_inner)
			_emit(output, middle, inverse)
			_emit(output, _clip(left, Vector3.BACK, pier_front), inverse)
			_emit(output, _clip(right, Vector3.BACK, pier_front), inverse)
		var result := output.commit_to_arrays()
		if not result[Mesh.ARRAY_VERTEX].is_empty():
			cut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result)
			cut.surface_set_material(cut.get_surface_count() - 1, source.surface_get_material(index))
	part.mesh = cut if cut.get_surface_count() else null


func _clip(polygon: Array[Vertex], normal: Vector3, distance: float) -> Array[Vertex]:
	var result: Array[Vertex] = []
	if polygon.is_empty():
		return result
	var previous := polygon.back() as Vertex
	var from := previous.position.dot(normal) - distance
	for current in polygon:
		var to := current.position.dot(normal) - distance
		if (from >= 0.0) != (to >= 0.0):
			var t := from / (from - to)
			result.append(Vertex.new(previous.position.lerp(current.position, t),
					previous.normal.lerp(current.normal, t).normalized()))
		if to >= 0.0:
			result.append(current)
		previous = current
		from = to
	return result


func _emit(surface: SurfaceTool, polygon: Array[Vertex], inverse: Transform3D) -> void:
	for index in range(1, polygon.size() - 1):
		var a := polygon[0]
		var b := polygon[index]
		var c := polygon[index + 1]
		if (b.position - a.position).cross(c.position - a.position).is_zero_approx():
			continue
		for vertex: Vertex in [a, b, c]:
			surface.set_normal(vertex.normal)
			surface.add_vertex(inverse * vertex.position)


class Vertex:
	var position: Vector3
	var normal: Vector3

	func _init(at: Vector3, direction: Vector3) -> void:
		position = at
		normal = direction
