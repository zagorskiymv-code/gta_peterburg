@tool
extends MeshInstance3D

const RADIUS := 8.58
const RISE := 7.15
const RINGS := 24
const RIBS := 24
const SIDES_PER_RIB := 16

@export var shell_material: Material
@export var rib_material: Material


func _ready() -> void:
	var shell := SurfaceTool.new()
	var ribs := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	ribs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := RIBS * SIDES_PER_RIB
	for ring in RINGS:
		for side in sides:
			var surface := ribs if side % SIDES_PER_RIB in [0, SIDES_PER_RIB - 1] else shell
			var a := _point(ring, side, sides)
			var b := _point(ring, side + 1, sides)
			var c := _point(ring + 1, side + 1, sides)
			var d := _point(ring + 1, side, sides)
			surface.add_vertex(a)
			surface.add_vertex(b)
			surface.add_vertex(c)
			if ring < RINGS - 1:
				surface.add_vertex(a)
				surface.add_vertex(c)
				surface.add_vertex(d)
	shell.generate_normals()
	ribs.generate_normals()
	shell.set_material(shell_material)
	ribs.set_material(rib_material)
	mesh = ribs.commit(shell.commit())


func _point(ring: int, side: int, sides: int) -> Vector3:
	var pitch := PI * 0.5 * ring / RINGS
	var yaw := TAU * (side % sides) / sides
	var raised := 0.075 if side % SIDES_PER_RIB == 0 else 0.0
	var radius := (RADIUS + raised) * cos(pitch)
	return Vector3(radius * cos(yaw), RISE * sin(pitch), radius * sin(yaw))
