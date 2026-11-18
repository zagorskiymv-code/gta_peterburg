extends Control

const Period = preload("res://scripts/ui/period_theme.gd")

const Plan = preload("res://scripts/ui/district_map_plan.gd")
const DISTRICT := Rect2(-267, -298, 371, 452)

var _plan: Plan
var _marker: Polygon2D
var _dragging := false
var _fit_zoom := 1.0
var _marker_world := Vector2.ZERO


func configure(source: Node2D, world: Node3D) -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_DRAG
	var paper := ColorRect.new()
	paper.color = Period.PAPER
	paper.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(paper)
	paper.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_plan = Plan.new()
	add_child(_plan)
	_plan.copy_geometry_from(source, world)
	var grain := Period.grain_overlay()
	add_child(grain)
	grain.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_marker = Polygon2D.new()
	_marker.polygon = PackedVector2Array([Vector2(0, -12), Vector2(8, 8), Vector2(0, 4), Vector2(-8, 8)])
	_marker.color = Period.BURGUNDY
	_marker.antialiased = true
	var outline := Line2D.new()
	outline.points = _marker.polygon
	outline.width = 1.7
	outline.default_color = Period.CREAM
	outline.closed = true
	_marker.add_child(outline)
	add_child(_marker)
	resized.connect(reset_view)
	mouse_exited.connect(func() -> void: _dragging = false)


func reset_view() -> void:
	if not _plan or size.x < 1.0 or size.y < 1.0:
		return
	var extent := DISTRICT.size * Plan.SCALE
	_fit_zoom = maxf(0.08, minf((size.x - 36.0) / extent.x, (size.y - 32.0) / extent.y))
	_plan.scale = Vector2.ONE * _fit_zoom
	_plan.position = size * 0.5 - DISTRICT.get_center() * Plan.SCALE * _fit_zoom
	queue_redraw()


func _process(_delta: float) -> void:
	if not _plan or not is_visible_in_tree():
		return
	_marker.position = _plan.position + _marker_world * _plan.scale


func show_player(position: Vector3, facing: Vector3) -> void:
	_marker_world = Plan.project(position)
	_marker.rotation = atan2(facing.x, -facing.z)
	_marker.position = _plan.position + _marker_world * _plan.scale


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var current := _plan.scale.x
			var factor := 1.18 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.18
			var zoom := clampf(current * factor, _fit_zoom * 0.65, _fit_zoom * 5.0)
			_plan.position = event.position - (event.position - _plan.position) * (zoom / current)
			_plan.scale = Vector2.ONE * zoom
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_plan.position += event.relative
		accept_event()
