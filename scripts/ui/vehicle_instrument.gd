extends Control

const Period = preload("res://scripts/ui/period_theme.gd")

const BRASS := Period.BRASS
const BRIGHT := Period.BRASS_LIGHT
const INK := Period.INK
const FACE := Period.CREAM
const SWEEP_START := 0.75 * PI
const SWEEP_END := 2.25 * PI

var dial_font: Font
var vehicle_name := ""
var speed_kmh := 0.0
var _needle := 0.0


func show_speed(title: String, actual_speed: float, delta: float) -> void:
	var previous_needle := _needle
	var changed_name := vehicle_name != title
	vehicle_name = title
	speed_kmh = actual_speed
	_needle = lerpf(_needle, speed_kmh, 1.0 - exp(-delta * 19.0))
	if changed_name or absf(previous_needle - _needle) > 0.005:
		queue_redraw()


func clear_reading() -> void:
	vehicle_name = ""
	speed_kmh = 0.0
	_needle = 0.0
	queue_redraw()


func needle_angle() -> float:
	return lerpf(SWEEP_START, SWEEP_END, clampf(_needle / 25.0, 0.0, 1.0))


func _draw() -> void:
	if not dial_font:
		return
	var center := Vector2(size.x * 0.5, 72)
	draw_circle(center + Vector2(0, 2), 67, Period.SHADOW, true, -1.0, true)
	draw_circle(center, 66, BRASS, true, -1.0, true)
	draw_arc(center, 64.5, 0.0, TAU, 48, BRIGHT, 1.5, true)
	draw_circle(center, 59.5, FACE, true, -1.0, true)
	draw_arc(center, 57.5, 0.0, TAU, 48, Period.BRASS.darkened(0.20), 1.0, true)
	for tick in 26:
		var mark := Vector2.from_angle(lerpf(SWEEP_START, SWEEP_END, float(tick) / 25.0))
		var major := tick % 5 == 0
		draw_line(center + mark * (43 if major else 48), center + mark * 53, INK, 1.4 if major else 0.85, true)
		if major:
			var caption_at := center + mark * 35 + Vector2(-9, 3.5)
			draw_string(dial_font, caption_at, str(tick), HORIZONTAL_ALIGNMENT_CENTER, 18, 11, INK)
	var angle := needle_angle()
	var direction := Vector2.from_angle(angle)
	draw_line(center - direction * 6.0, center + direction * 49.0, Period.BURGUNDY, 2.0, true)
	draw_circle(center, 3.5, BRASS, true, -1.0, true)
	draw_string(dial_font, center + Vector2(-26, 22), "км/ч",
			HORIZONTAL_ALIGNMENT_CENTER, 52, 12, INK)

	var plaque := Rect2(0, 145, size.x, 49)
	draw_rect(plaque, Period.DARK)
	draw_rect(plaque, BRASS, false, 1.0)
	draw_line(plaque.position, Vector2(plaque.end.x, plaque.position.y), BRIGHT, 1.0, true)
	draw_string(dial_font, Vector2(0, 165), vehicle_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, FACE)
	draw_string(dial_font, Vector2(0, 183), "E — Выйти", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, BRIGHT)
