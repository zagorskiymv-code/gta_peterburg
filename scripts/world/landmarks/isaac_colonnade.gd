@tool
extends Node3D

const G = preload("res://scripts/world/district_geometry.gd")
const FLOOR_HEIGHT := 24.06
const INNER_RADIUS := 9.85
const OUTER_RADIUS := 11.57
const SECTIONS := 64
const ENTRY_RADIUS := 1.75

var stone := G.solid_material(Color("#827f74"))
var iron := G.solid_material(Color("#272d2c"))
var ground_stop: Marker3D
var upper_stop: Marker3D
var player: CharacterBody3D
var prompt: Label
var request_pending := false


func _ready() -> void:
	_build_lookout()
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process_unhandled_key_input(false)
		return
	var layer := CanvasLayer.new()
	prompt = Label.new()
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -280
	prompt.offset_right = 280
	prompt.offset_top = -95
	prompt.offset_bottom = -62
	prompt.add_theme_color_override(&"font_outline_color", Color("#201b17"))
	prompt.add_theme_constant_override(&"outline_size", 7)
	prompt.add_theme_font_size_override(&"font_size", 22)
	layer.add_child(prompt)
	add_child(layer)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"district_explorer") as CharacterBody3D
		if player == null:
			return
	if player.is_dead:
		prompt.hide()
		request_pending = false
		return
	var going_up := _near(ground_stop)
	var going_down := _near(upper_stop)
	prompt.visible = going_up or going_down
	prompt.text = "Нажмите E, чтобы подняться на колоннаду" if going_up else "Нажмите E, чтобы спуститься"
	if request_pending:
		request_pending = false
		if going_up or going_down:
			_transfer(upper_stop if going_up else ground_stop)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if is_instance_valid(player) and (_near(ground_stop) or _near(upper_stop)):
			request_pending = true
			get_viewport().set_input_as_handled()


func _near(marker: Marker3D) -> bool:
	return player.global_position.distance_to(marker.global_position) < ENTRY_RADIUS


func _transfer(marker: Marker3D) -> void:
	var destination := marker.global_position
	var world := get_world_3d().direct_space_state
	var floor_hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(
			destination + Vector3.UP * 0.18, destination - Vector3.UP * 0.28, 1, [player.get_rid()]))
	if floor_hit.is_empty() or floor_hit.normal.y < 0.9:
		return
	var shape_node := player.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = Transform3D(shape_node.global_basis, floor_hit.position + shape_node.position + Vector3.UP * 0.045)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	if not world.intersect_shape(query, 1).is_empty():
		return
	player.global_position = floor_hit.position + Vector3.UP * 0.045
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _build_lookout() -> void:
	ground_stop = _marker("LowerDoor", Vector3(20.5, 0.06, 24.275))
	upper_stop = _marker("UpperDoor", Vector3(0, FLOOR_HEIGHT + 0.08, 10.68))
	# The doorway itself is part of the south masonry and exposes only a shallow niche.
	_sign(self, "КОЛОННАДА", Vector3(20.5, 2.84, 22.825))
	_sign(self, "СПУСКЪ  ↓", Vector3(0, FLOOR_HEIGHT + 1.0, 9.79))
	var floor_mesh := _surface()
	var guards := _surface()
	var masonry_mesh := _surface()
	var spindles: Array[Transform3D] = []
	for i in SECTIONS:
		var a := TAU * i / SECTIONS
		var b := TAU * (i + 1) / SECTIONS
		var ia := _radial(a, INNER_RADIUS, FLOOR_HEIGHT)
		var ib := _radial(b, INNER_RADIUS, FLOOR_HEIGHT)
		var oa := _radial(a, OUTER_RADIUS, FLOOR_HEIGHT)
		var ob := _radial(b, OUTER_RADIUS, FLOOR_HEIGHT)
		_quad(floor_mesh, ia, oa, ob, ib)
		for radius in [INNER_RADIUS, OUTER_RADIUS]:
			var from := _radial(a, radius, FLOOR_HEIGHT)
			var to := _radial(b, radius, FLOOR_HEIGHT)
			var rise := Vector3.UP * 1.38
			_quad(guards, from, to, to + rise, from + rise)
			_quad(masonry_mesh, from, to, to - Vector3.UP * 0.35, from - Vector3.UP * 0.35)
			_quad(masonry_mesh, from, from - Vector3.UP * 0.35, to - Vector3.UP * 0.35, to)
			var tangent := to - from
			var beam := Basis.looking_at(tangent, Vector3.UP)
			for y in [0.12, 1.38]:
				spindles.append(Transform3D(beam.scaled_local(Vector3(0.038, 0.045, tangent.length() + 0.02)),
						(from + to) * 0.5 + Vector3.UP * y))
			spindles.append(G.box_transform(from + Vector3.UP * 0.69, Vector3(0.039, 1.38, 0.039)))
	_finish("ColonnadeFloor", floor_mesh, stone, true)
	_finish("ColonnadeStoneEdge", masonry_mesh, stone, false)
	_finish("ColonnadeGuards", guards, null, true)
	G.batch(self, "CastIronSpindles", BoxMesh.new(), iron, spindles)


func _marker(label: String, at: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = at
	add_child(marker)
	return marker


func _sign(parent: Node3D, caption: String, at: Vector3) -> void:
	G.box(parent, "EnamelPlaque", at + Vector3.FORWARD * 0.036, Vector3(1.37, 0.25, 0.065), iron)
	var label := Label3D.new()
	label.text = caption
	label.font_size = 34
	label.pixel_size = 0.005
	label.outline_size = 0
	label.position = at + Vector3.BACK * 0.006
	label.modulate = Color("#f2dec0")
	parent.add_child(label)


func _radial(angle: float, radius: float, y: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(vertex)


func _finish(title: String, surface: SurfaceTool, material: Material, solid: bool) -> void:
	surface.generate_normals()
	var mesh := surface.commit()
	if material:
		G.mesh_part(self, title, Vector3.ZERO, mesh, material)
	if solid:
		var body := StaticBody3D.new()
		body.name = title + "Collision"
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = material == null
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
