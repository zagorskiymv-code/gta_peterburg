extends Node3D

signal finished

const Period = preload("res://scripts/ui/period_theme.gd")
const Visual = preload("res://scripts/player/historical_character_visual.gd")

var _hero: Visual
var _contact: Visual
var _game_camera: Camera3D
var _hud: CanvasLayer
var _pause_menu: CanvasLayer
var _pause_mode: ProcessMode
var _hero_yaw: float
var _contact_yaw: float
var _speaker: Label
var _caption: Label
var _contact_name: String
var _lines: PackedStringArray
var _line := -1
var _elapsed := 0.0
var _duration := 0.0
var _subject: Node3D
const INSPECTION_TIME := 2.6


func start(player: Node3D, npc: Node3D, hud: CanvasLayer, pause_menu: CanvasLayer,
		contact_name: String, lines: PackedStringArray, subject: Node3D = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hero = player.get_node("CharacterVisual")
	_contact = npc.get_node("CharacterVisual")
	_hero_yaw = _hero.rotation.y
	_contact_yaw = _contact.rotation.y
	_hero.leave_seat()
	_contact.leave_seat()
	_hud = hud
	_pause_menu = pause_menu
	_pause_mode = pause_menu.process_mode
	_contact_name = contact_name
	_lines = lines
	_subject = subject
	_game_camera = get_viewport().get_camera_3d()

	var axis := (npc.global_position - player.global_position).slide(Vector3.UP).normalized()
	_hero.global_rotation.y = atan2(-axis.x, -axis.z)
	_contact.global_rotation.y = atan2(axis.x, axis.z)
	_frame_characters(player, npc, axis)
	_build_subtitles()
	_pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.hide()
	get_tree().paused = true
	if _subject:
		_speaker.text = _contact_name
		_caption.text = "Фролов осматривает коня."
	else:
		_next_line()


func _frame_characters(player: Node3D, npc: Node3D, axis: Vector3) -> void:
	var focus := (player.global_position + npc.global_position) * 0.5 + Vector3.UP * 1.22
	if _subject:
		focus = focus.lerp(_subject.global_position + Vector3.UP * 1.15, 0.32)
	var across := axis.cross(Vector3.UP)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = sphere
	clearance.transform.origin = focus
	clearance.collision_mask = 1 | 4 | 8
	clearance.exclude = [player.get_rid(), npc.get_rid()]
	if _subject is CollisionObject3D:
		clearance.exclude = [player.get_rid(), npc.get_rid(), _subject.get_rid()]
	var space := get_world_3d().direct_space_state
	var best := Vector3.ZERO
	for side in [1.0, -1.0]:
		clearance.motion = (across * side * (5.0 if _subject else 3.7) + axis * 0.35 + Vector3.UP * 0.53)
		var safe := space.cast_motion(clearance)[0]
		var candidate := clearance.motion * safe * 0.97
		if candidate.length_squared() > best.length_squared():
			best = candidate
	if best.length() < 2.45:
		return
	var camera := Camera3D.new()
	camera.name = "ConversationCamera"
	camera.fov = 53.0
	add_child(camera)
	camera.global_position = focus + best
	camera.look_at(focus)
	camera.make_current()


func _build_subtitles() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 28
	add_child(ui)
	var margin := MarginContainer.new()
	ui.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -154
	margin.offset_bottom = -30
	margin.offset_left = 20
	margin.offset_right = -20
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size.x = minf(660.0, get_viewport().get_visible_rect().size.x - 40.0)
	card.add_theme_stylebox_override("panel", Period.framed(Period.DARK, Period.BRASS, Vector4(20, 12, 20, 14)))
	center.add_child(card)
	var stack := VBoxContainer.new()
	card.add_child(stack)
	_speaker = _label(17, Period.BRASS_LIGHT)
	_caption = _label(23, Period.CREAM)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_speaker)
	stack.add_child(_caption)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Period.typeface())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _next_line() -> void:
	_line += 1
	if _line == _lines.size():
		_finish()
		return
	_elapsed = 0.0
	_speaker.text = _contact_name if _line % 2 == 0 else "Герой"
	_caption.text = _lines[_line]
	_duration = clampf(float(_caption.text.length()) / 17.0 + 0.8, 2.55, 6.4)


func _process(delta: float) -> void:
	if _line < 0:
		_elapsed += delta
		var glance := (_subject.global_position - _contact.global_position).slide(Vector3.UP)
		_contact.global_rotation.y = lerp_angle(_contact.global_rotation.y, atan2(-glance.x, -glance.z),
				minf(delta * 5.0, 1.0))
		_contact.pose_inspect(_elapsed, INSPECTION_TIME)
		if _elapsed >= INSPECTION_TIME:
			var toward_hero := (_hero.global_position - _contact.global_position).slide(Vector3.UP)
			_contact.global_rotation.y = atan2(-toward_hero.x, -toward_hero.z)
			_contact.upper_body.rotation.x = 0.0
			_next_line()
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_next_line()
		return
	var contact_speaks := _line % 2 == 0
	_hero.pose_conversation(_elapsed, _duration, not contact_speaks)
	_contact.pose_conversation(_elapsed, _duration, contact_speaks)


func _finish() -> void:
	_hero.leave_seat()
	_contact.leave_seat()
	_hero.rotation.y = _hero_yaw
	_contact.rotation.y = _contact_yaw
	_game_camera.make_current()
	_pause_menu.process_mode = _pause_mode
	_hud.show()
	get_tree().paused = false
	finished.emit()
	queue_free()
