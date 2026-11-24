@tool
extends MeshInstance3D

@export var outline: PackedVector2Array
@export var stone: Material
@export var frieze: Material

# Each point is (outward projection, elevation). Mitering the same profile at
# every vertex carries it through both the outside corners and the returns.
const FASCIA := [
	Vector2(0.015, 16.85), Vector2(0.155, 16.89), Vector2(0.155, 17.00),
	Vector2(0.035, 17.065),
]
const BELT := [
	Vector2(0.02, 19.13), Vector2(0.15, 19.17), Vector2(0.19, 19.25),
	Vector2(0.32, 19.30), Vector2(0.32, 19.48), Vector2(0.28, 19.53),
	Vector2(0.08, 19.58),
]
const COPING := [
	Vector2(0.02, 20.45), Vector2(0.12, 20.49), Vector2(0.17, 20.54),
	Vector2(0.17, 20.63), Vector2(0.0, 20.63),
]
const FRIEZE := [
	Vector2(0.015, 18.22), Vector2(0.105, 18.27),
	Vector2(0.105, 19.14), Vector2(0.015, 19.18),
]


func _ready() -> void:
	var result := ArrayMesh.new()
	_add_profiles(result, [FASCIA, BELT, COPING], stone)
	_add_profiles(result, [FRIEZE], frieze)
	mesh = result


func _add_profiles(result: ArrayMesh, profiles: Array, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for profile: Array in profiles:
		for index in outline.size():
			var next := (index + 1) % outline.size()
			for level in range(profile.size() - 1):
				var a := _point(index, profile[level])
				var b := _point(next, profile[level])
				var c := _point(next, profile[level + 1])
				var d := _point(index, profile[level + 1])
				for vertex: Vector3 in [a, c, b, a, d, c]:
					surface.add_vertex(vertex)
	surface.generate_normals()
	surface.commit(result)


func _point(index: int, profile: Vector2) -> Vector3:
	var size := outline.size()
	var point := outline[index]
	var previous := (point - outline[(index + size - 1) % size]).normalized()
	var next := (outline[(index + 1) % size] - point).normalized()
	var miter := Vector2(-previous.y - next.y, previous.x + next.x)
	var moved := point + miter * profile.x
	return Vector3(moved.x, profile.y, moved.y)
