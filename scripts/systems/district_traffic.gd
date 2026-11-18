extends Node3D

const Agent = preload("res://scripts/systems/traffic_agent.gd")
const DrivenCar = preload("res://scripts/vehicles/traffic_victoria.gd")
const Carriage = preload("res://scripts/vehicles/horse_carriage.gd")
const G = preload("res://scripts/world/district_geometry.gd")
const LANE_OFFSET := 2.20
const ROAD_Y := 0.056

var lanes: Dictionary[StringName, Path3D] = {}
var _preview: Node3D
var _fleet: Node3D
var _carriages: Node3D
var fleet_lanes: Array[Path3D] = []


func configure(avenue: Node3D, bypass: Node3D) -> void:
	var main: PackedVector3Array = avenue.get_meta(&"route_points")
	var outer: PackedVector3Array = bypass.get_meta(&"route_points")
	var main_points := _section(main, func(p: Vector3) -> bool: return p.z <= -33.0 and p.x >= -77.0)
	_add_lane(&"NevskyToBridge", _offset(main_points), "Bridge approach terminus on dry land")
	main_points.reverse()
	_add_lane(&"NevskyToDistrict", _offset(main_points))

	# The southern junction links each direction of Nevsky to its corresponding bypass lane.
	var approach := _section(main, func(p: Vector3) -> bool: return p.z <= -75.0 and p.z > -94.0)
	approach.append(Vector3(0, 0, -94))
	var arc_out := _offset(approach)
	arc_out.append_array(_turn(Vector3(-2.2, 0, -94), Vector3(-2.2, 0, -98.3),
			Vector3(-5.1, 0, -100.8), Vector3(-10, 0, -100.8)))
	var bypass_points := _section(outer, func(p: Vector3) -> bool: return p.x < -10.5 and p.z >= -195.0)
	arc_out.append_array(_offset(bypass_points))
	_add_lane(&"IsaacOuter", arc_out, "Stops before bridge-side merge")

	bypass_points.reverse()
	var arc_in := _offset(bypass_points)
	arc_in.append(Vector3(-10, 0, -105.2))
	arc_in.append_array(_turn(Vector3(-10, 0, -105.2), Vector3(-3.8, 0, -105.2),
			Vector3(2.2, 0, -101.5), Vector3(2.2, 0, -94)))
	approach.reverse()
	arc_in.append_array(_offset(approach))
	_add_lane(&"IsaacToNevsky", arc_in)

	var boulevard := _section(main, func(p: Vector3) -> bool: return p.z <= -41.0 and p.x >= -72.0)
	var quay := _section(outer, func(p: Vector3) -> bool: return p.x <= -22.0 and p.z >= -187.0)
	fleet_lanes = [_make_circuit("NevskyCircuit", boulevard), _make_circuit("IsaacCircuit", quay)]


func start_fleet() -> void:
	if is_instance_valid(_fleet):
		return
	_fleet = G.group(self, "TrafficFleet")
	var placements := [[0, 19.0], [0, 66.0], [0, 135.0], [0, 275.0], [1, 25.0], [1, 170.0]]
	for index in placements.size():
		var lane: Path3D = fleet_lanes[placements[index][0]]
		var agent := Agent.new()
		agent.name = "Victoria%02d" % (index + 1)
		_fleet.add_child(agent)
		agent.setup(lane, Agent.Profile.AUTOMOBILE, placements[index][1], true)
		var car := DrivenCar.new()
		car.name = "TrafficVictoria"
		car.paint_index = index % 5
		car.costume_index = index
		agent.add_child(car)


func start_carriages() -> void:
	if is_instance_valid(_carriages):
		return
	_carriages = G.group(self, "CarriageFleet")
	for index in 4:
		var lane := fleet_lanes[index / 2]
		var offsets := [42.0, 210.0, 70.0, 231.0]
		var agent := Agent.new()
		agent.name = "Carriage%02d" % (index + 1)
		_carriages.add_child(agent)
		agent.setup(lane, Agent.Profile.CARRIAGE, offsets[index], true)
		var model := Carriage.new()
		model.name = "HorseCarriage"
		model.livery = index
		agent.add_child(model)


func _make_circuit(label: String, centerline: PackedVector3Array) -> Path3D:
	var outward := _offset(centerline)
	centerline.reverse()
	var inward := _offset(centerline)
	var loop := outward.duplicate()
	_append_uturn(loop, inward)
	loop.append_array(inward.slice(1))
	_append_uturn(loop, outward)
	return _build_path(label, loop, true)


func _append_uturn(points: PackedVector3Array, next_lane: PackedVector3Array) -> void:
	var a := points[-1]
	var d := next_lane[0]
	var forward := points[-2].direction_to(a)
	var next_heading := d.direction_to(next_lane[1])
	points.append_array(_turn(a, a + forward * 3.05, d - next_heading * 3.05, d))



func create_agent(key: StringName, profile: Agent.Profile, offset := 0.0) -> Agent:
	var lane := lanes.get(key) as Path3D
	if not is_instance_valid(lane):
		return null
	var agent := Agent.new()
	add_child(agent, true)
	agent.setup(lane, profile, offset)
	return agent


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F7:
		set_debug_visible(not is_instance_valid(_preview))
		get_viewport().set_input_as_handled()


func set_debug_visible(enabled: bool) -> void:
	if enabled == is_instance_valid(_preview):
		return
	if not enabled:
		remove_child(_preview)
		_preview.queue_free()
		_preview = null
		return
	_preview = G.group(self, "TrafficDebug")
	var colors := [Color("#27e5e7"), Color("#f9af51"), Color("#89ed55"), Color("#e980eb")]
	var row := 0
	for key in lanes:
		_draw_lane(lanes[key], colors[row])
		row += 1


func _section(points: PackedVector3Array, keep: Callable) -> PackedVector3Array:
	var selected := PackedVector3Array()
	for point in points:
		if keep.call(point) and (selected.is_empty() or point.distance_to(selected[-1]) > 0.22):
			selected.append(point)
	return selected


func _offset(points: PackedVector3Array) -> PackedVector3Array:
	var offset := PackedVector3Array()
	for index in points.size():
		var tangent := (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		offset.append(points[index] - tangent.cross(Vector3.UP) * LANE_OFFSET)
	return offset


func _turn(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	for step in range(1, 13):
		points.append(a.bezier_interpolate(b, c, d, float(step) / 12.0))
	return points


func _add_lane(key: StringName, points: PackedVector3Array, terminal := "End of test lane") -> void:
	var path := _build_path(String(key), points)
	path.set_meta(&"terminal", terminal)
	lanes[key] = path


func _build_path(label: String, points: PackedVector3Array, closed := false) -> Path3D:
	var path := Path3D.new()
	path.name = label
	path.curve = Curve3D.new()
	path.curve.bake_interval = 0.27
	for i in points.size():
		var at := Vector3(points[i].x, ROAD_Y, points[i].z)
		if path.curve.point_count > 0 and at.distance_to(path.curve.get_point_position(path.curve.point_count - 1)) < 0.10:
			continue
		var before := points[points.size() - 2 if closed and i == 0 else maxi(0, i - 1)]
		var after := points[1 if closed and i == points.size() - 1 else mini(i + 1, points.size() - 1)]
		var direction := (after - before).normalized()
		path.curve.add_point(at, -direction * points[i].distance_to(before) / 3.0,
				direction * points[i].distance_to(after) / 3.0)
	add_child(path)
	return path


func _draw_lane(lane: Path3D, color: Color) -> void:
	var material := G.solid_material(color)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var strip := SurfaceTool.new()
	strip.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve := lane.curve
	var length := curve.get_baked_length()
	var count := ceili(length)
	for i in count:
		var a := curve.sample_baked(length * float(i) / count, true) + Vector3.UP * 0.13
		var b := curve.sample_baked(length * float(i + 1) / count, true) + Vector3.UP * 0.13
		var direction := (b - a).normalized()
		var side := direction.cross(Vector3.UP) * 0.11
		_triangle(strip, a - side, b - side, b + side)
		_triangle(strip, a - side, b + side, a + side)
		if i % 8 == 3:
			var tip := b + direction * 1.2
			_triangle(strip, b - side * 3.5, tip, b + side * 3.5)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	G.mesh_part(_preview, str(lane.name), Vector3.ZERO, strip.commit(), material).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var finish := curve.sample_baked(length) + Vector3.UP * 0.41
	G.box(_preview, "LaneTerminal", finish, Vector3(0.65, 0.70, 0.65), material).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
