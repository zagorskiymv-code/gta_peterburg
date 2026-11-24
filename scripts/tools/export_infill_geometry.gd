extends SceneTree
## godot --headless --script res://scripts/tools/export_infill_geometry.gd -- /tmp/infill-geometry.json

const Layout = preload("res://scripts/tools/validate_city_layout.gd")
const DISTRICT := "res://scenes/world/petersburg_district.tscn"


func _initialize() -> void:
	call_deferred("_export")


func _export() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or change_scene_to_file(DISTRICT) != OK:
		printerr("An output JSON path is required.")
		quit(1)
		return
	await scene_changed
	var background := current_scene.get_node("BackgroundCity")
	var result := {"buildings": [], "reservations": [], "blocks": [], "dry_ground": [], "west_shore": []}
	for bounds: Vector4 in background.get_meta(&"dry_ground"):
		result.dry_ground.append([bounds.x, bounds.y, bounds.z, bounds.w])
	for point: Vector2 in background.get_meta(&"west_shore"):
		result.west_shore.append([point.x, point.y])
	for row: Node3D in background.find_children("StreetFront*", "Node3D", true, false):
		if row.has_meta(&"block_depth"):
			_append(result.blocks, row, AABB(Vector3.ZERO, Vector3(
					row.get_meta(&"frontage_length"), 0, row.get_meta(&"block_depth"))), "block", 0)
		for lot: Dictionary in row.get_meta(&"building_footprints", []):
			var at: Vector2 = lot.center
			var size: Vector2 = lot.size
			var bounds := AABB(Vector3(at.x - size.x / 2, -0.12, at.y - size.y / 2),
					Vector3(size.x, 1, size.y))
			_append(result.buildings, row, bounds, "background", lot.floors)
	for shape_node: CollisionShape3D in current_scene.find_children("*", "CollisionShape3D", true, false):
		var box := shape_node.shape as BoxShape3D
		if box == null or shape_node.disabled:
			continue
		var body := shape_node.get_parent()
		var name_text := str(body.name)
		var structure := body.get_parent()
		var bounds := AABB(-box.size / 2, box.size)
		if _starts_with(name_text, Layout.BUILDING_BODIES):
			var masonry := structure.get_node_or_null("Masonry") as MeshInstance3D
			if masonry:
				_append(result.buildings, masonry, masonry.get_aabb(), "facade",
						int(structure.get_meta(&"facade_floors", 0)))
			else:
				_append(result.buildings, shape_node, bounds, "structural_collision", 0)
		elif box.size.y <= 0.45 and minf(box.size.x, box.size.z) >= 0.5:
			_append(result.reservations, shape_node, bounds, "surface", 0)
	var singer := current_scene.get_node("Landmarks/SingerHouse/SingerMasonry") as MeshInstance3D
	_append(result.buildings, singer, singer.get_aabb(), "landmark", 0)
	for mesh: MeshInstance3D in current_scene.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "PolygonMasonry":
			var outline: PackedVector2Array = mesh.get_parent().get_meta(&"plan_polygon")
			var polygon := []
			for corner in outline:
				var vertex := mesh.to_global(Vector3(corner.x, 0, corner.y))
				polygon.append([vertex.x, vertex.z])
			var center := mesh.global_transform * mesh.get_aabb().get_center()
			result.buildings.append({"path": str(mesh.get_path()), "polygon": polygon, "kind": "polygon",
					"position": [center.x, center.y, center.z], "rotation": mesh.global_rotation_degrees.y,
					"floors": int(mesh.get_parent().get_meta(&"facade_floors", 0))})
		var label := str(mesh.name)
		if mesh.mesh == null:
			continue
		if _starts_with(label, ["CrossStreetContinuation", "NorthernLaneContinuation",
				"SouthernAxialStreet", "SouthWestLane", "OuterQuayContinuation",
				"EastLongitudinalStreet", "NorthernCrossStreet", "SouthernCrossStreet"]):
			_append(result.reservations, mesh, mesh.get_aabb(), "surface", 0)
		elif _starts_with(label, ["NevskyRoad", "NevskySidewalks", "BypassRoad", "BypassSidewalks",
				"BridgeRoad", "BridgeFootways"]):
			_export_triangles(result.reservations, mesh)
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		printerr("Could not write geometry: ", args[0])
		quit(1)
		return
	file.store_string(JSON.stringify(result))
	quit()


func _starts_with(label: String, prefixes: Array) -> bool:
	for prefix: String in prefixes:
		if label.begins_with(prefix):
			return true
	return false


func _append(items: Array, node: Node3D, bounds: AABB, kind: String, floors: int) -> void:
	var polygon := []
	for corner in [Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.end.x, bounds.position.z),
			Vector2(bounds.end.x, bounds.end.z), Vector2(bounds.position.x, bounds.end.z)]:
		var point := node.to_global(Vector3(corner.x, bounds.position.y, corner.y))
		polygon.append([point.x, point.z])
	var center := node.to_global(Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z))
	items.append({"path": str(node.get_path()), "polygon": polygon, "kind": kind, "floors": floors,
			"position": [center.x, center.y, center.z], "rotation": node.global_rotation_degrees.y})


func _export_triangles(items: Array, mesh: MeshInstance3D) -> void:
	var faces := mesh.mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var polygon := []
		for j in 3:
			var point := mesh.to_global(faces[i + j])
			polygon.append([point.x, point.z])
		items.append({"path": str(mesh.get_path()), "polygon": polygon, "kind": "surface"})
