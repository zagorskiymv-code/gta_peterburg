@tool
extends RefCounted

enum Kind { TENEMENT, MERCHANT, SHOP, CIVIC, WAREHOUSE }

const Geometry = preload("res://scripts/world/district_geometry.gd")
const BRICK := preload("res://materials/warehouse_brick.gdshader")
const WINDOW := preload("res://scenes/world/props/facade_window.tscn")

var unit_box := BoxMesh.new()
var trim := Geometry.solid_material(Color("#c4b49a"))
var stone := Geometry.solid_material(Color("#82786d"))
var brick_stack := Geometry.solid_material(Color("#87594b"))
var soot := Geometry.solid_material(Color("#544941"))
var doors_panel := Geometry.solid_material(Color("#614638"))
var iron := Geometry.solid_material(Color("#343b38"))
var drain := CylinderMesh.new()
var wood := Geometry.solid_material(Color("#4d3528"))
var window_parts: Array[MeshInstance3D] = []
var window_template: Node3D


func _init() -> void:
	drain.top_radius = 0.053
	drain.bottom_radius = 0.053
	drain.height = 1.0
	drain.radial_segments = 7
	window_template = WINDOW.instantiate()
	for child in window_template.get_children():
		if child is MeshInstance3D:
			window_parts.append(child)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(window_template):
		window_template.free()


func add_building(parent: Node3D, label: String, location: Vector2, yaw: float,
		size: Vector2, floors: int, kind: Kind, color: Color) -> void:
	var building := Geometry.group(parent, label, Vector3(location.x, -0.05, location.y))
	building.rotation_degrees.y = yaw
	var width := size.x
	var depth := size.y
	var front := depth * 0.5
	var floor_height := 2.85 if kind == Kind.WAREHOUSE else 2.65
	var height := 0.48 + floor_height * floors
	var tint := Color.from_hsv(color.h, minf(color.s * 1.32, 0.52), color.v * 0.88)
	var wall: Material = Geometry.solid_material(tint)
	if kind == Kind.WAREHOUSE:
		var brick := ShaderMaterial.new()
		brick.shader = BRICK
		brick.set_shader_parameter(&"brick_color", tint.lerp(Color("#95594a"), 0.58))
		wall = brick
	var variant := absi(roundi(location.x * 10.0) + roundi(location.y * 10.0))
	var roof_colors := ["#344642", "#4a4e56", "#60433a", "#465653"]
	var roof_color := Color("#594039") if kind == Kind.WAREHOUSE else Color(roof_colors[variant % roof_colors.size()])
	var roof_material := Geometry.solid_material(roof_color)
	Geometry.box(building, "Masonry", Vector3(0, height * 0.5, 0), Vector3(width, height, depth), wall, true)
	Geometry.box(building, "Plinth", Vector3(0, 0.23, 0), Vector3(width + 0.13, 0.46, depth + 0.13), stone)
	Geometry.box(building, "Cornice", Vector3(0, height - 0.10, 0), Vector3(width + 0.36, 0.28, depth + 0.36), trim)
	var roof: Mesh
	var pitched := PrismMesh.new()
	var rise := (1.75 if kind == Kind.WAREHOUSE else 1.12) + (variant % 5) * 0.13
	pitched.size = Vector3(depth + 0.26, rise, width + 0.28)
	var is_mansard := kind == Kind.TENEMENT and width >= 9.0 and variant % 3 != 1
	var is_hipped := kind == Kind.MERCHANT or kind == Kind.CIVIC
	roof = _trapezoid_roof(width, depth, rise, is_mansard) if is_mansard or is_hipped else pitched
	var roof_node := Geometry.mesh_part(building, "PitchedRoof", Vector3(0, height + rise * 0.5, 0), roof, roof_material)
	if not is_mansard and not is_hipped:
		roof_node.rotation_degrees.y = 90
	if is_mansard:
		for x in [-width * 0.27, 0.0, width * 0.27]:
			Geometry.box(building, "DormerCasing", Vector3(x,height+0.49,depth*0.5-0.34),
					Vector3(0.69,0.57,0.49), trim)
			Geometry.box(building, "DormerGlass", Vector3(x,height+0.51,depth*0.5-0.087),
					Vector3(0.42,0.36,0.05), iron)
	var stacks: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var count := 2 if width > 13.0 or (width > 8.0 and variant % 3 == 0) else 1
	for i in count:
		var x := width * (0.28 if i == 0 else -0.27)
		var shaft_height := 0.88 + ((variant + i) % 4) * 0.25
		var shaft_width := 0.70 if kind == Kind.WAREHOUSE else 0.48 + (variant % 2) * 0.11
		var base := height + rise * 0.58
		stacks.append(Geometry.box_transform(Vector3(x, base + shaft_height * 0.5, 0), Vector3(shaft_width, shaft_height, 0.58)))
		caps.append(Geometry.box_transform(Vector3(x, base + shaft_height, 0), Vector3(shaft_width + 0.12, 0.13, 0.69)))
	Geometry.batch(building, "BrickFlues", unit_box, brick_stack, stacks)
	Geometry.batch(building, "FlueCaps", unit_box, soot, caps)

	building.set_meta(&"facade_floors", floors)
	var window_transforms: Array[Transform3D] = []
	var trim_transforms: Array[Transform3D] = []
	var pipes: Array[Transform3D] = []
	var base_course: Array[Transform3D] = []
	var niche_jambs: Array[Transform3D] = []
	for side in 4:
		var orientation := Basis(Vector3.UP, side * PI * 0.5)
		var span := width if side % 2 == 0 else depth
		var wall_depth := depth * 0.5 if side % 2 == 0 else width * 0.5
		var side_transform := Transform3D(orientation, Vector3.ZERO)
		for index in 3:
			var y := 0.08 + float(index) * 0.245
			base_course.append(side_transform * Geometry.box_transform(
					Vector3(0, y, wall_depth + 0.006), Vector3(span + 0.10, 0.211, 0.12 - index * 0.015)))
		trim_transforms.append(side_transform * Geometry.box_transform(
				Vector3(0, height - 0.29, wall_depth + 0.06), Vector3(span + 0.16, 0.11, 0.18)))
		var bays := maxi(2, int(span / 2.15))
		if side == 0:
			bays |= 1
		for floor_index in floors:
			var y := 1.73 + floor_index * floor_height
			if floor_index > 0:
				trim_transforms.append(Transform3D(orientation, Vector3.ZERO) * Geometry.box_transform(
						Vector3(0, y - 1.02, wall_depth), Vector3(span, 0.13, 0.18)))
			for bay in bays:
				if side == 0 and floor_index == 0 and bay * 2 == bays - 1:
					continue
				var x := (float(bay) / float(bays - 1) - 0.5) * (span - 2.1)
				var dimensions := Vector3.ONE
				if kind == Kind.WAREHOUSE:
					dimensions = Vector3(0.82, 0.79, 1)
				elif floor_index == 0 and kind in [Kind.MERCHANT, Kind.SHOP] and side == 0:
					dimensions = Vector3(1.18, 1.13, 1)
				var placement := Vector3(x, y, wall_depth)
				window_transforms.append(Transform3D(orientation.scaled_local(dimensions), orientation * placement))
				if floor_index == 0:
					for jamb_side in [-1.0, 1.0]:
						var jamb := placement + Vector3(jamb_side * 0.47 * dimensions.x, 0, 0.15)
						niche_jambs.append(side_transform * Geometry.box_transform(
								jamb, Vector3(0.13, 1.40 * dimensions.y, 0.22)))
					if kind != Kind.WAREHOUSE:
						var key := placement + Vector3(0, 0.80 * dimensions.y, 0.15)
						trim_transforms.append(side_transform * Geometry.box_transform(
								key, Vector3(0.19, 0.23, 0.27)))
				if floor_index == 1 and kind == Kind.TENEMENT:
					trim_transforms.append(Transform3D(orientation, Vector3.ZERO) * Geometry.box_transform(
							placement + Vector3(0, 0.86, 0.125), Vector3(1.25, 0.15, 0.22)))
		if side == 0 or side == 2:
			for sign_x in [-1, 1]:
				var position := Vector3(sign_x * (span * 0.5 - 0.25), height * 0.5, wall_depth + 0.07)
				pipes.append(Transform3D(orientation.scaled_local(Vector3(1, height - 0.33, 1)), orientation * position))
				if kind in [Kind.TENEMENT, Kind.MERCHANT]:
					trim_transforms.append(Transform3D(orientation, Vector3.ZERO) * Geometry.box_transform(
							Vector3(position.x - sign_x * 0.13, height * 0.5, wall_depth + 0.065),
							Vector3(0.20, height - 0.55, 0.14)))
	Geometry.batch(building, "CutStoneBase", unit_box, stone, base_course)
	Geometry.batch(building, "WindowReveals", unit_box, trim, niche_jambs)
	Geometry.batch(building, "Downpipes", drain, iron, pipes)
	building.set_meta(&"facade_window_transforms", window_transforms)
	for part in window_parts:
		var transforms: Array[Transform3D] = []
		for placement in window_transforms:
			transforms.append(placement * part.transform)
		Geometry.batch(building, "Windows" + str(part.name), part.mesh, part.material_override, transforms)

	var portal := 2.2 if kind == Kind.WAREHOUSE else 1.28
	Geometry.box(building, "Portal", Vector3(0, 1.34, front + 0.08), Vector3(portal + 0.42, 2.65, 0.21), trim)
	Geometry.box(building, "DoubleDoor", Vector3(0, 1.26, front + 0.21), Vector3(portal, 2.45, 0.13), wood)
	Geometry.box(building, "DoorMeetingStile", Vector3(0, 1.26, front + 0.29), Vector3(0.065, 2.43, 0.05), iron)
	var panels: Array[Transform3D] = []
	for x in [-portal * 0.25, portal * 0.25]:
		for y in [0.59, 1.45, 2.00]:
			panels.append(Geometry.box_transform(Vector3(x, y, front + 0.29), Vector3(portal * 0.36, 0.29, 0.035)))
		panels.append(Geometry.box_transform(Vector3(x * 0.20, 1.10, front + 0.31), Vector3(0.04, 0.15, 0.055)))
	Geometry.batch(building, "DoorPanels", unit_box, doors_panel, panels)
	trim_transforms.append(Geometry.box_transform(Vector3(0, 2.68, front + 0.18), Vector3(portal + 0.62, 0.17, 0.40)))
	if kind == Kind.CIVIC or kind == Kind.MERCHANT:
		for side in [-1, 1]:
			var x: float = side * (width * 0.41 if kind == Kind.CIVIC else width * 0.46)
			trim_transforms.append(Geometry.box_transform(Vector3(x, height * 0.5, front + 0.14), Vector3(0.36, height - 0.3, 0.31)))
			trim_transforms.append(Geometry.box_transform(Vector3(x, height - 0.32, front + 0.17), Vector3(0.58, 0.22, 0.43)))
	if kind == Kind.MERCHANT and width >= 10.0:
		Geometry.box(building, "BalconySlab", Vector3(0, 3.65, front + 0.43), Vector3(2.6, 0.14, 0.90), stone)
		var rails: Array[Transform3D] = []
		for i in 9:
			var x := -1.18 + i * 0.295
			rails.append(Geometry.box_transform(Vector3(x, 4.04, front + 0.85), Vector3(0.045, 0.72, 0.045)))
		rails.append(Geometry.box_transform(Vector3(0, 4.41, front + 0.85), Vector3(2.49, 0.08, 0.075)))
		for x in [-1.2, 1.2]:
			rails.append(Geometry.box_transform(Vector3(x, 4.41, front + 0.45), Vector3(0.07, 0.08, 0.82)))
		Geometry.batch(building, "WroughtIronBalcony", unit_box, iron, rails)
	if kind == Kind.CIVIC:
		var shaft := CylinderMesh.new()
		shaft.radial_segments = 10
		shaft.top_radius = 0.16
		shaft.bottom_radius = 0.20
		shaft.height = height - 0.5
		var colonnade: Array[Transform3D] = []
		for x in [-0.23, -0.15, 0.15, 0.23]:
			colonnade.append(Transform3D(Basis.IDENTITY, Vector3(x * width, height * 0.5, front + 0.36)))
		Geometry.batch(building, "ClassicalColumns", shaft, trim, colonnade)
		var pediment := PrismMesh.new()
		pediment.size = Vector3(width * 0.54, 1.05, 0.45)
		Geometry.mesh_part(building, "CivicPediment", Vector3(0, height + 0.44, front + 0.17), pediment, trim)
	if kind == Kind.SHOP:
		Geometry.box(building, "Signboard", Vector3(0, 3.13, front + 0.15), Vector3(width - 1.25, 0.34, 0.16), roof_material)
		var sign_label := Label3D.new()
		sign_label.name = "HandPaintedSign"
		sign_label.position = Vector3(0, 3.13, front + 0.245)
		sign_label.text = "ТОРГОВАЯ  ЛАВКА"
		sign_label.font_size = 38
		sign_label.pixel_size = 0.005
		sign_label.outline_size = 0
		sign_label.modulate = Color("#eed7a0")
		building.add_child(sign_label)
	Geometry.batch(building, "StoneTrim", unit_box, trim, trim_transforms)


func _trapezoid_roof(width: float, depth: float, rise: float, mansard: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var base := Vector2(width+0.20,depth+0.20) * 0.5
	var crown := base * (Vector2(0.82,0.64) if mansard else Vector2(0.70,0.18))
	var bottom := [Vector3(-base.x,-rise*0.5,-base.y),Vector3(base.x,-rise*0.5,-base.y),
		Vector3(base.x,-rise*0.5,base.y),Vector3(-base.x,-rise*0.5,base.y)]
	var top := [Vector3(-crown.x,rise*0.5,-crown.y),Vector3(crown.x,rise*0.5,-crown.y),
		Vector3(crown.x,rise*0.5,crown.y),Vector3(-crown.x,rise*0.5,crown.y)]
	for i in 4:
		var j := (i+1)%4
		for point: Vector3 in [bottom[i],bottom[j],top[j],bottom[i],top[j],top[i]]:
			surface.add_vertex(point)
	for i in [0,1,2,0,2,3]:
		surface.add_vertex(top[i])
	surface.generate_normals()
	return surface.commit()
