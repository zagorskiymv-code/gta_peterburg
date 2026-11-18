extends Control

const Period = preload("res://scripts/ui/period_theme.gd")

const Plan = preload("res://scripts/ui/district_map_plan.gd")
var _plan: Plan
var _sheet: Control
var _arrow: Polygon2D
var _player: CharacterBody3D
var _visual: Node3D


func configure(world: Node3D, player: CharacterBody3D, font: Font) -> void:
	_player = player
	_visual = player.get_node("CharacterVisual") as Node3D
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := Panel.new()
	var brass := StyleBoxFlat.new()
	brass.bg_color = Period.BRASS
	brass.border_color = Period.BRASS_LIGHT
	brass.set_border_width_all(1)
	border.add_theme_stylebox_override("panel", brass)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sheet = Control.new()
	_sheet.clip_contents = true
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.offset_left = 3.0
	_sheet.offset_top = 3.0
	_sheet.offset_right = -3.0
	_sheet.offset_bottom = -3.0

	var paper := ColorRect.new()
	paper.color = Period.PAPER
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plan = Plan.new()
	_sheet.add_child(_plan)
	_plan.build(world, font)

	var grain := Period.grain_overlay()
	_sheet.add_child(grain)
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(0,-10), Vector2(7,7), Vector2(0,4), Vector2(-7,7)])
	_arrow.color = Period.BURGUNDY
	_arrow.antialiased = true
	var edge := Line2D.new()
	edge.points = _arrow.polygon
	edge.closed = true
	edge.width = 1.55
	edge.default_color = Period.CREAM
	edge.antialiased = true
	_arrow.add_child(edge)
	_sheet.add_child(_arrow)
	place_marker()


func _process(_delta: float) -> void:
	if is_instance_valid(_player) and is_instance_valid(_plan):
		place_marker()


func place_marker() -> void:
	var carrier := _visual.get_parent() as Node3D
	var target := _player if carrier == _player else carrier
	var forward := -(_visual.global_basis.z if carrier == _player else carrier.global_basis.z)
	_arrow.position = _sheet.size * 0.5
	_plan.position = _arrow.position - Plan.project(target.global_position)
	_arrow.rotation = atan2(forward.x, -forward.z)
