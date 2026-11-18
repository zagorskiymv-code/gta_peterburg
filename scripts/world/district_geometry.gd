@tool
extends RefCounted


static func solid_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


static func group(parent: Node3D, label: String, center := Vector3.ZERO) -> Node3D:
	var child := Node3D.new()
	child.name = label
	child.position = center
	parent.add_child(child, true)
	return child


static func box(parent: Node3D, label: String, center: Vector3, size: Vector3,
		material: Material, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := mesh_part(parent, label, center, mesh, material)
	if solid:
		collider(parent, label + "Collision", center, size)
	return part


static func mesh_part(parent: Node3D, label: String, center: Vector3,
		mesh: Mesh, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.position = center
	part.mesh = mesh
	part.material_override = material
	parent.add_child(part, true)
	return part


static func collider(parent: Node3D, label: String, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body, true)


static func batch(parent: Node3D, label: String, mesh: Mesh, material: Material,
		transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	var instances := MultiMeshInstance3D.new()
	instances.name = label
	instances.multimesh = multi
	instances.material_override = material
	parent.add_child(instances, true)


static func box_transform(center: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), center)
