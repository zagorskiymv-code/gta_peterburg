extends SceneTree
## Run with godot --headless --path . --script res://scripts/tools/validate_city_layout.gd

const DISTRICT := "res://scenes/world/petersburg_district.tscn"
const CONTACT_TOLERANCE := 0.12
const BUILDING_BODIES := [
	"MasonryCollision", "FacadeCollision", "MarbleBodyCollision", "GranitePlinthCollision",
	"StylobateCollision", "WinterPalaceMasonryCollision", "MuseumBodyCollision",
	"StationMasonryCollision", "BrickHallCollision", "MasonryPierCollision",
	"CourtyardWingCollision", "ArchPierCollision", "AdmiraltyGatewayPierCollision", "HollandGatewayPierCollision", "ArchSideExtensionCollision",
]

class Envelope:
	var path: String
	var owner: Node
	var center: Vector3
	var half: Vector3
	var axes: Array[Vector2]

	func _init(node: Node3D, local_bounds: AABB, structure: Node) -> void:
		path = str(node.get_path())
		owner = structure
		var transform := node.global_transform
		center = transform * local_bounds.get_center()
		half = local_bounds.size * transform.basis.get_scale().abs() * 0.5
		axes = [Vector2(transform.basis.x.x, transform.basis.x.z).normalized(),
				Vector2(transform.basis.z.x, transform.basis.z.z).normalized()]

	func intersects(other: Envelope, tolerance := CONTACT_TOLERANCE) -> bool:
		var offset := other.center - center
		if half.y + other.half.y - absf(offset.y) <= tolerance:
			return false
		var horizontal := Vector2(offset.x, offset.z)
		# All tested volumes are upright. SAT rejects false positives from rotated world AABBs.
		for axis in axes + other.axes:
			var radius := _radius(axis) + other._radius(axis)
			if radius - absf(horizontal.dot(axis)) <= tolerance:
				return false
		return true

	func _radius(axis: Vector2) -> float:
		return half.x * absf(axes[0].dot(axis)) + half.z * absf(axes[1].dot(axis))


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file(DISTRICT) != OK:
		quit(1)
		return
	await scene_changed
	await physics_frame
	var buildings: Array[Envelope] = []
	var props: Array[Envelope] = []
	var singer := current_scene.get_node("Landmarks/SingerHouse/SingerMasonry") as MeshInstance3D
	buildings.append(Envelope.new(singer, singer.get_aabb(), singer.get_parent()))
	var errors := 0
	var facades := 0
	for shape_node: CollisionShape3D in current_scene.find_children("*", "CollisionShape3D", true, false):
		var shape := shape_node.shape as BoxShape3D
		if shape == null:
			continue
		var body := shape_node.get_parent()
		var label := str(body.name)
		var local_bounds := AABB(-shape.size * 0.5, shape.size)
		if _has_prefix(label, BUILDING_BODIES):
			var structure := body.get_parent()
			if "SaintIsaacsCathedral" in str(structure.get_path()):
				structure = current_scene.get_node("Landmarks/SaintIsaacsCathedral")
			var envelope := Envelope.new(shape_node, local_bounds, structure)
			buildings.append(envelope)
			if label == "FacadeCollision":
				var facade := structure.get_node_or_null("Facade") as MeshInstance3D
				if facade == null or not _same_box(envelope, Envelope.new(facade, facade.get_aabb(), structure)):
					printerr("COLLIDER SIZE: ", structure.get_path())
					errors += 1
			if label in ["MasonryCollision", "FacadeCollision"]:
				facades += 1
				if not _has_windows_on_each_side(structure):
					printerr("FACADE: ", structure.get_path())
					errors += 1
		elif _has_prefix(label, ["Trunk", "LindenTrunk", "BenchBody", "Cargo", "AtlasPedestal", "PedestalCollision"]):
			props.append(Envelope.new(shape_node, local_bounds, body))
	for node: Node3D in current_scene.find_children("*", "StaticBody3D", true, false):
		if node.name == "PostBody":
			props.append(Envelope.new(node, AABB(Vector3(-0.13, 0, -0.13), Vector3(0.26, 2.55, 0.26)), node))
	var horse := current_scene.get_node_or_null("Landmarks/SaintIsaacGarden/NicholasIMonument/BronzeHorseAndRider") as MeshInstance3D
	if horse == null:
		printerr("HORSE: missing equestrian statue")
		errors += 1
	else:
		var horse_bounds := Envelope.new(horse, horse.get_aabb(), horse)
		props.append(horse_bounds)
		var monument := horse.get_parent()
		var cap := monument.get_node("PedestalCap") as MeshInstance3D
		var cap_top := (cap.global_transform * cap.get_aabb()).end.y
		var hoof_level := horse_bounds.center.y - horse_bounds.half.y
		var floor_at_horse := horse.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(horse.global_position, horse.global_position - Vector3.UP * 5, 1))
		if floor_at_horse.is_empty() or absf(hoof_level - cap_top) > 0.09:
			printerr("HORSE: missing support or horse below ground")
			errors += 1
		else:
			print("Horse: ", horse.global_position)

	for prop in props:
		if prop.center.y - prop.half.y < -0.30:
			printerr("PROP GRADE: ", prop.path)
			errors += 1

	for i in buildings.size():
		var first := buildings[i]
		if first.center.y - first.half.y < -0.40:
			printerr("GRADE: ", first.path)
			errors += 1
		for j in range(i + 1, buildings.size()):
			var second := buildings[j]
			if first.owner == second.owner:
				continue
			if first.intersects(second):
				printerr("STRUCTURE: ", first.path, " + ", second.path)
				errors += 1
		for prop in props:
			if first.intersects(prop, 0.045):
				printerr("PROP: ", first.path, " + ", prop.path)
				errors += 1
	errors += _check_nevsky(buildings)
	errors += _check_new_landmarks(buildings, props)
	errors += _check_reconstruction()
	print("Checked %d structural volumes, %d facades, %d props. Findings: %d." %
			[buildings.size(), facades, props.size(), errors])
	quit(1 if errors else 0)


func _same_box(first: Envelope, second: Envelope) -> bool:
	return first.center.is_equal_approx(second.center) and first.half.is_equal_approx(second.half)


func _has_prefix(label: String, prefixes: Array) -> bool:
	for prefix: String in prefixes:
		if label.begins_with(prefix):
			return true
	return false


func _has_windows_on_each_side(building: Node3D) -> bool:
	var glazing := building.get_node_or_null("WindowsGlass") as MultiMeshInstance3D
	var windows: Array[Transform3D] = []
	var floors := int(building.get_meta(&"facade_floors", 0))
	if glazing:
		# The dummy rendering backend doesn't expose per-instance transforms back to callers.
		windows = building.get_meta(&"facade_window_transforms", [])
		if windows.size() != glazing.multimesh.instance_count:
			return false
	else:
		var instances := building.find_children("*", "Node3D", true, false)
		for child: Node3D in instances:
			if child.scene_file_path == "res://scenes/world/props/facade_window.tscn":
				windows.append(building.global_transform.affine_inverse() * child.global_transform)
		floors = 2
	var directions := {}
	for placement in windows:
		var forward := placement.basis.z.normalized()
		var side := Vector2i(roundi(forward.x), roundi(forward.z))
		if not directions.has(side):
			directions[side] = {}
		directions[side][roundi(placement.origin.y * 10)] = true
	for levels: Dictionary in directions.values():
		if levels.size() < floors:
			return false
	return directions.size() == 4



func _check_nevsky(buildings: Array[Envelope]) -> int:
	var avenue := current_scene.get_node_or_null("NevskyProspekt/Avenue") as Node3D
	var bridge := current_scene.get_node_or_null("NevskyProspekt/NevaBridge") as Node3D
	var square := current_scene.get_node_or_null("Landmarks/IsaacStoneParvis") as MeshInstance3D
	var church := current_scene.get_node_or_null("Landmarks/SaintIsaacsCathedral/MarbleBody") as MeshInstance3D
	if avenue == null or bridge == null or square == null or church == null:
		printerr("NEVSKY: missing route, bridge or square")
		return 1

	var points: PackedVector3Array = avenue.get_meta(&"route_points")
	var widths: PackedFloat32Array = avenue.get_meta(&"route_half_widths")
	var bypass_mouth: Vector2 = avenue.get_meta(&"bypass_road_mouth")
	var bridge_deck := bridge.get_node("BridgeRoad") as MeshInstance3D
	var bridge_bounds := bridge_deck.get_aabb()
	bridge_bounds.position.x = -11.0
	bridge_bounds.size.x = 22.0
	bridge_bounds.size.y += 2.3
	var bridge_envelope := Envelope.new(bridge_deck, bridge_bounds, bridge)
	var square_bounds := square.get_aabb()
	square_bounds.size.y += 3.0
	var square_envelope := Envelope.new(square, square_bounds, square)
	var church_bounds := church.get_aabb().grow(24.5)
	var buffer := Envelope.new(church, church_bounds, church)
	var errors := 0
	for building in buildings:
		if building.intersects(bridge_envelope):
			printerr("BRIDGE OVERLAP: ", building.path)
			errors += 1
		if not "SaintIsaacsCathedral" in building.path and (
				building.intersects(square_envelope) or building.intersects(buffer)):
			printerr("ISAAC CLEARANCE: ", building.path)
			errors += 1
		for i in points.size() - 1:
			var a := avenue.to_global(points[i])
			var b := avenue.to_global(points[i + 1])
			if _crosses_strip(building, a, b, (widths[i] + widths[i + 1]) * 0.5 + 4.0):
				printerr("AVENUE OVERLAP: ", building.path)
				errors += 1
				break

	var world := avenue.get_world_3d().direct_space_state
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var side := (b - a).normalized().cross(Vector3.UP)
		var mid := (a + b) * 0.5
		var offset := (widths[i] + widths[i + 1]) * 0.5 + 2.0
		for distance in [-offset, 0.0, offset]:
			var sample := avenue.to_global(mid + side * distance)
			var surfaces := ["NevskyRoadCollision", "NevskySidewalksCollision"]
			if distance < 0.0 and mid.z > bypass_mouth.x and mid.z < bypass_mouth.y:
				surfaces = ["BypassRoadCollision"]
			if not _road_support(world, sample, surfaces):
				printerr("UNSUPPORTED AVENUE SAMPLE: ", sample)
				errors += 1
	for meters in range(1, 132, 2):
		for x in [-9.0, 0.0, 9.0]:
			var point := bridge.to_global(Vector3(x, 0, -meters))
			if meters > 50 and meters < 82:
				if meters >= 57 and meters <= 75 and not world.intersect_ray(
						PhysicsRayQueryParameters3D.create(point + Vector3.UP * 18, point - Vector3.UP * 1.9, 1)).is_empty():
					printerr("OBSTRUCTED OPEN SPAN: ", point)
					errors += 1
			elif not _road_support(world, point, ["BridgeRoadCollision", "BridgeFootwaysCollision"]):
				printerr("UNSUPPORTED BRIDGE SAMPLE: ", point)
				errors += 1
	for label in ["NearLeaf", "FarLeaf"]:
		var leaf := bridge.get_node(label + "/RaisedDeck") as Node3D
		var point := leaf.to_global(Vector3(0, 0, -8))
		var hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP, 1))
		if absf(leaf.rotation_degrees.x - 70.0) > 0.02 or hit.is_empty() or hit.collider.name != "TimberDeckCollision":
			printerr("BASCULE LEAF COLLISION: ", label)
			errors += 1
	if bridge.has_node("ClosedCrossing"):
		printerr("LEGACY BARRIER STILL PRESENT")
		errors += 1

	return errors


func _crosses_strip(building: Envelope, a: Vector3, b: Vector3, half_width: float) -> bool:
	var delta := Vector2(b.x - a.x, b.z - a.z)
	if delta.length_squared() < 0.00001:
		return false
	var axis := delta.normalized()
	var across := axis.orthogonal()
	var offset := Vector2(building.center.x, building.center.z) - Vector2(a.x + b.x, a.z + b.z) * 0.5
	for direction in building.axes + [axis, across]:
		var strip_radius := absf(axis.dot(direction)) * delta.length() * 0.5 + absf(across.dot(direction)) * half_width
		if building._radius(direction) + strip_radius - absf(offset.dot(direction)) <= 0.18:
			return false
	return true


func _road_support(world: PhysicsDirectSpaceState3D, point: Vector3, valid: Array) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.2, point - Vector3.UP * 0.20, 1)
	var hit := world.intersect_ray(ray)
	return not hit.is_empty() and hit.collider.name in valid

func _check_new_landmarks(buildings: Array[Envelope], props: Array[Envelope]) -> int:
	var bypass := current_scene.get_node("NevskyProspekt/IsaacBypass") as Node3D
	var bridge := current_scene.get_node("NevskyProspekt/NevaBridge") as Node3D
	var ship := current_scene.get_node("Landmarks/CruiserAurora") as Node3D
	var colonnade := current_scene.get_node("Landmarks/SaintIsaacsCathedral/ColonnadeAccess") as Node3D
	var world := bridge.get_world_3d().direct_space_state
	var points: PackedVector3Array = bypass.get_meta(&"route_points")
	var errors := 0
	for object in buildings + props:
		for i in points.size() - 1:
			if _crosses_strip(object, bypass.to_global(points[i]), bypass.to_global(points[i + 1]), 4.55):
				printerr("BYPASS OBSTRUCTION: ", object.path)
				errors += 1
				break
	for i in points.size() - 1:
		var sample := bypass.to_global((points[i] + points[i + 1]) * 0.5)
		if not _road_support(world, sample, ["BypassRoadCollision", "NevskyRoadCollision", "NevskySidewalksCollision"]):
			printerr("BYPASS FLOOR: ", sample)
			errors += 1
	var hull_node := ship.get_node("ArmouredHull") as MeshInstance3D
	var hull := Envelope.new(hull_node, hull_node.get_aabb(), ship)
	var river_bridge := Envelope.new(bridge, AABB(Vector3(-11, -4, -132), Vector3(22, 8, 132)), bridge)
	if hull.intersects(river_bridge) or hull.center.x + hull._radius(Vector2.RIGHT) > -92.0:
		printerr("AURORA: hull touches the bridge or shore")
		errors += 1

	var scarlet := current_scene.get_node("Landmarks/ScarletSailsShip") as Node3D
	# Include the small vertical heave and rolling sails in the clearance envelope.
	var red_ship := Envelope.new(scarlet, AABB(Vector3(-5.5, -2.0, -30), Vector3(11, 23, 57)), scarlet)
	if red_ship.intersects(river_bridge) or red_ship.intersects(hull) or red_ship.center.x + red_ship._radius(Vector2.RIGHT) > -92:
		printerr("SCARLET SAILS: ship touches bridge, shore or Aurora")
		errors += 1

	var staff := current_scene.get_node("Landmarks/GeneralStaff") as Node3D
	for z in range(-195, -163, 2):
		var route := Vector3(staff.global_position.x, 0.05, z)
		var headroom := world.intersect_ray(PhysicsRayQueryParameters3D.create(
				route + Vector3.UP * 0.75, route + Vector3.UP * 2.0, 1))
		var floor_hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(
				route + Vector3.UP * 0.24, route - Vector3.UP * 0.25, 1))
		if not headroom.is_empty() or floor_hit.is_empty():
			printerr("GENERAL STAFF PASSAGE: ", route)
			errors += 1

	for depth in [-3.5, -2.0, -0.6, 0.15, 1.0, 3.0]:
		for x in [-10.45, -8.2, 0.0, 8.2, 10.45]:
			var sample := bridge.to_global(Vector3(x, 0.0, -depth))
			if not _road_support(world, sample, ["ShoreLandingCollision", "BridgeRoadCollision",
					"BridgeFootwaysCollision", "NevskyRoadCollision", "NevskySidewalksCollision"]):
				printerr("SHORE DECK GAP: ", sample)
				errors += 1

	for depth in [0.26, 1.2, 3.0, 12.0, 24.0, 46.5]:
		for side in [-1.0, 1.0]:
			var rail_height := 0.73 + 1.65 * sin(PI * depth / 132.0)
			var from := bridge.to_global(Vector3(side * 10.4, rail_height, -depth))
			var to := bridge.to_global(Vector3(side * 11.72, rail_height, -depth))
			var hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			if hit.is_empty() or not str(hit.collider.name).begins_with("RailCollision") and not str(hit.collider.name).begins_with("GraniteReturn"):
				printerr("BRIDGE RAIL GAP: ", side, " ", depth)
				errors += 1

	for i in 64:
		var angle := TAU * (i + 0.42) / 64.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var origin := colonnade.to_global(direction * 11.2 + Vector3.UP * 24.06)
		if not _road_support(world, origin, ["ColonnadeFloorCollision"]):
			printerr("COLONNADE FLOOR GAP: ", i)
			errors += 1
		for radius in [9.4, 13.0]:
			var from := origin + Vector3.UP
			var to := colonnade.to_global(direction * radius + Vector3.UP * 25.06)
			var hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			if hit.is_empty() or hit.collider.name != "ColonnadeGuardsCollision":
				printerr("COLONNADE RAIL GAP: ", i)
				errors += 1
	var player := current_scene.get_node("PlayerSpawn/Player") as CharacterBody3D
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape
	for label in ["LowerDoor", "UpperDoor"]:
		var marker := colonnade.get_node(label) as Marker3D
		var point := marker.global_position
		var ground := world.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.18,
				point - Vector3.UP * 0.28, 1, [player.get_rid()]))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform.origin = point + Vector3.UP * 0.92
		query.collision_mask = player.collision_mask
		query.exclude = [player.get_rid()]
		if ground.is_empty() or not world.intersect_shape(query, 1).is_empty():
			printerr("COLONNADE UNSAFE STOP: ", label)
			errors += 1
	return errors

func _check_reconstruction() -> int:
	var district := current_scene as Node3D
	var space := district.get_world_3d().direct_space_state
	var island := district.get_node("Landmarks/NewHolland")
	var background := district.get_node("BackgroundCity") as Node3D
	var errors := 0
	if island.find_children("WaterDeathZone*", "Area3D", false, false).size() != 4:
		printerr("NEW HOLLAND: missing water zones")
		errors += 1
	errors += _check_background_footprints(background)
	if not background.find_children("*", "StaticBody3D", true, false).is_empty():
		printerr("BACKGROUND: decorative buildings should not create physics bodies")
		errors += 1
	for point in [Vector3(26.5,0,93), Vector3(26.5,0,98), Vector3(30.5,0,122),
			Vector3(30.5,0,126), Vector3(-66,0,-254), Vector3(-66,0,-237)]:
		var bounds := Vector3(point.x,1.54,point.z)
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(bounds, point-Vector3.UP*0.20, 1))
		if floor_hit.is_empty() or absf(floor_hit.position.y)>0.17:
			printerr("RECONSTRUCTION ROUTE: ", point)
			errors += 1
	return errors

func _check_background_footprints(background: Node3D) -> int:
	var ground: Array[Vector4] = background.get_meta(&"dry_ground")
	var shore: PackedVector2Array = background.get_meta(&"west_shore")
	var errors := 0
	for node: Node3D in background.find_children("StreetFront*", "Node3D", true, false):
		var length: float = node.get_meta(&"frontage_length")
		var depth: float = node.get_meta(&"frontage_depth")
		var dry := true
		for i in 9:
			for side in [0.0, depth]:
				var point := node.to_global(Vector3(length*i/8.0, 0, side))
				if not _background_is_dry(Vector2(point.x,point.z), ground, shore):
					dry = false
					break
			if not dry:
				break
		if not dry:
			printerr("DISTANT FRONTAGE OVER WATER: ", node.global_position)
			errors += 1
	return errors


func _background_is_dry(point: Vector2, ground: Array[Vector4], shore: PackedVector2Array) -> bool:
	for rect in ground:
		if Rect2(rect.x,rect.y,rect.z-rect.x,rect.w-rect.y).has_point(point):
			return true
	for i in shore.size()-1:
		var a := shore[i]
		var b := shore[i+1]
		if point.y >= a.y and point.y <= b.y:
			var bank_x := lerpf(a.x,b.x,inverse_lerp(a.y,b.y,point.y))
			return point.x <= bank_x-0.3
	return false
