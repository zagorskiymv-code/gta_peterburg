extends CanvasLayer

const Period = preload("res://scripts/ui/period_theme.gd")

const Notifications = preload("res://scripts/ui/district_notifications.gd")
const Instrument = preload("res://scripts/ui/vehicle_instrument.gd")
const Minimap = preload("res://scripts/ui/district_minimap.gd")

const PARCHMENT := Period.CREAM
const GOLD := Period.BRASS
const INK := Period.INK
const INTRO_HINT := "WASD — ходьба · Shift — бег · Пробел — прыжок"
const AREAS := [
	[Rect2(-70, -281, 21, 24), "Служебный двор Адмиралтейства"],
	[Rect2(-82, -249, 32, 17), "Александровский сад"],
	[Rect2(-63, -234, 27, 19), "Торговые ряды"],
	[Rect2(-36, -266, 107, 74), "Дворцовая площадь"],
	[Rect2(4, 89, 60, 58), "Новая Голландия"],
	[Rect2(-83, -174, 71, 73), "Исаакиевская площадь"],
	[Rect2(40, -90, 32, 179), "Набережная канала"],
	[Rect2(-45, -190, 82, 38), "Адмиралтейский квартал"],
	[Rect2(-23, -152, 54, 177), "Невский проспект"],
	[Rect2(-90, 25, 180, 64), "Южные кварталы"],
]

@onready var _layout: Control = $Layout
var _player: CharacterBody3D
var _driving: Node
var _riding: Node
var _minimap: Minimap
var _instrument: Instrument
var _mission_card: PanelContainer
var _mission_title: Label
var _mission_goal: Label
var _health: ProgressBar
var _wallet: Label
var _hint: Label
var _hint_card: PanelContainer
var _notices: Notifications
var _paint := Period.typeface()
var _area_announced_at: Dictionary[String, float] = {}
var _clock := 0.0
var _hint_fade: Tween
var _health_fade: Tween
var _shown_area := ""
var _hint_target := ""
var _area_candidate := ""
var _candidate_time := 0.0
var _intro_left := 8.0
var _sample_time := 0.0
var _was_dead := false


func configure(player: CharacterBody3D, driving: Node, riding: Node) -> void:
	_player = player
	_driving = driving
	_riding = riding

	var health_card := _card(Period.DARK, Period.BRASS, Vector4(12, 9, 12, 10))
	health_card.name = "Health"
	_layout.add_child(health_card)
	_pin(health_card, Vector2(1, 0), Vector2(218, 61), Vector2(22, 21))
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	health_card.add_child(stack)
	stack.add_child(_label("Здоровье", 16, PARCHMENT))
	_health = ProgressBar.new()
	_health.name = "HealthBar"
	_health.show_percentage = false
	_health.value = 100
	_health.custom_minimum_size = Vector2(0, 10)
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health.add_theme_stylebox_override("background", _style(Period.BURGUNDY_DARK, Period.BRASS, Vector4.ZERO))
	_health.add_theme_stylebox_override("fill", _style(Period.BURGUNDY.lightened(0.12), Period.BRASS_LIGHT, Vector4.ZERO))
	stack.add_child(_health)
	var wallet_card := _card(Period.DARK, Period.BRASS, Vector4(12, 5, 12, 5))
	wallet_card.name = "Wallet"
	_layout.add_child(wallet_card)
	_pin(wallet_card, Vector2(1, 0), Vector2(128, 33), Vector2(22, 87))
	_wallet = _label("0 руб.", 16, Period.BRASS_LIGHT)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_card.add_child(_wallet)

	_notices = Notifications.new()
	_notices.name = "Notifications"
	_layout.add_child(_notices)
	_notices.configure(_paint)

	_hint_card = PanelContainer.new()
	_hint_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_card.add_theme_stylebox_override("panel", Period.paper(Vector4(12, 8, 12, 8)))
	_hint_card.name = "ControlsHint"
	_layout.add_child(_hint_card)
	_pin(_hint_card, Vector2(0, 1), Vector2(405, 38), Vector2(22, 23))
	_hint = _label("", 15, INK)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_card.add_child(_hint)
	_hint_card.modulate.a = 0.0
	_hint_card.hide()

	_minimap = Minimap.new()
	_minimap.name = "Minimap"
	_layout.add_child(_minimap)
	_minimap.configure(get_parent(), player, _paint)
	_instrument = Instrument.new()
	_instrument.name = "VehicleInstrument"
	_instrument.dial_font = _paint
	_instrument.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instrument.hide()
	_instrument.resized.connect(_instrument.queue_redraw)
	_layout.add_child(_instrument)
	_mission_card = _card(Period.DARK, Period.BRASS, Vector4(13, 9, 13, 10))
	_mission_card.name = "MissionStatus"
	_layout.add_child(_mission_card)
	var mission_lines := VBoxContainer.new()
	mission_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission_card.add_child(mission_lines)
	_mission_title = _label("", 17, Period.BRASS_LIGHT)
	_mission_goal = _label("", 15, Period.CREAM)
	_mission_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_lines.add_child(_mission_title)
	mission_lines.add_child(_mission_goal)
	_mission_card.hide()
	_layout.resized.connect(_fit)
	_fit()
	_layout.modulate.a = 0.0
	create_tween().tween_property(_layout, "modulate:a", 1.0, 0.38)
	_show_area(_area_at(_player.global_position))


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var vehicle = _driving.current_vehicle()
	if is_instance_valid(vehicle) and not _player.is_dead:
		_instrument.show()
		_instrument.show_speed(vehicle.display_name, vehicle.road_speed_kmh, delta)
	elif _instrument.visible:
		_instrument.hide()
		_instrument.clear_reading()
	_clock += delta
	_intro_left = maxf(0.0, _intro_left - delta)
	_sample_time += delta
	if _sample_time < 0.10:
		return
	var elapsed := _sample_time
	_sample_time = 0.0
	var dead: bool = _player.is_dead
	if dead != _was_dead:
		_was_dead = dead
		if _health_fade:
			_health_fade.kill()
		_health_fade = create_tween()
		_health_fade.tween_property(_health, "value", 0.0 if dead else 100.0, 0.30)
		if dead:
			_notices.hide()
		_minimap.visible = not dead
	if dead:
		_show_hint("")
		return

	var area := _area_at(_player.global_position)
	if area != _area_candidate:
		_area_candidate = area
		_candidate_time = 0.0
	else:
		_candidate_time += elapsed
	if area != _shown_area and _candidate_time >= 0.65:
		_show_area(area)

	var hint: String = _driving.hud_hint if not _driving.hud_hint.is_empty() else _riding.hud_hint
	if hint.is_empty() and _intro_left > 0.0 and not is_instance_valid(vehicle):
		hint = INTRO_HINT
	_show_hint(hint)


func _area_at(world: Vector3) -> String:
	var point := Vector2(world.x, world.z)
	if point.x < -90 and point.y < -191:
		return "Дворцовый мост"
	for area in AREAS:
		if area[0].has_point(point):
			return area[1]
	return "Литейная часть" if point.y < -95 and point.x > 30 else "Петербург"


func _show_area(area: String) -> void:
	_shown_area = area
	_notices.discard_pending_area()
	if _clock - _area_announced_at.get(area, -100.0) >= 20.0:
		_area_announced_at[area] = _clock
		_notices.post_area(area)


func set_wallet_balance(rubles: int) -> void:
	_wallet.text = "%d руб." % rubles


func set_mission_status(title: String, goal: String) -> void:
	_mission_title.text = title
	_mission_goal.text = goal
	_mission_card.visible = not title.is_empty()


func post_message(title: String, short_text: String, seconds: float = 3.0) -> void:
	_notices.post_message(title, short_text, seconds)

func _show_hint(text: String) -> void:
	if _hint_target == text:
		return
	_hint_target = text
	if _hint_fade:
		_hint_fade.kill()
	if not text.is_empty():
		_hint.text = text
		_hint_card.show()
	_hint_fade = create_tween()
	_hint_fade.tween_property(_hint_card, "modulate:a", 0.0 if text.is_empty() else 1.0, 0.24)
	if text.is_empty():
		_hint_fade.tween_callback(_hint_card.hide)


func _fit() -> void:
	var narrow := _layout.size.x < 760.0
	_pin(_mission_card, Vector2.ZERO, Vector2(246 if narrow else 290, 60), Vector2(18, 55))
	var notice_width := minf(420.0, _layout.size.x - 32.0)
	_pin(_notices, Vector2(0.5, 0.0), Vector2(notice_width, 55), Vector2(0, 94 if narrow else 27))
	_pin(_hint_card, Vector2(0, 1), Vector2(minf(440.0, maxf(200.0, _layout.size.x - 36.0)), 38),
			Vector2(18, 228 if narrow else 240))
	_pin(_instrument, Vector2.ONE, Vector2(162, 195), Vector2(18, 23))
	_pin(_minimap, Vector2(0, 1), Vector2(164, 164) if narrow else Vector2(198, 198), Vector2(18, 23))


func _pin(control: Control, anchor: Vector2, extent: Vector2, gap: Vector2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = gap.x * (1.0 - 2.0 * anchor.x) - extent.x * anchor.x
	control.offset_top = -extent.y - gap.y if anchor.y > 0 else gap.y
	control.offset_right = control.offset_left + extent.x
	control.offset_bottom = control.offset_top + extent.y
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN if anchor.y > 0 else Control.GROW_DIRECTION_END


func _label(content: String, pixels: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _paint)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", tint)
	return label


func _card(background: Color, line: Color, margins: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(background, line, margins))
	return panel


func _style(background: Color, line: Color, margins: Vector4) -> StyleBoxFlat:
	return Period.framed(background, line, margins)
