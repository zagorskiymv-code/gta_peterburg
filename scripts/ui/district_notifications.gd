extends PanelContainer

const Period = preload("res://scripts/ui/period_theme.gd")

const FADE_IN := 0.32
const FADE_OUT := 0.60

var _title: Label
var _body: Label
var _messages: Array[Dictionary] = []
var _area: Dictionary = {}
var _animation: Tween


func configure(font: Font) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", Period.framed(Period.DARK, Period.BRASS, Vector4(20, 11, 20, 12)))
	var stack := VBoxContainer.new()
	stack.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	add_child(stack)
	_title = _label(font, 24, Period.CREAM)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body = _label(font, 16, Period.MUTED)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_title)
	stack.add_child(_body)
	hide()


func post_message(title: String, text: String, seconds: float = 3.0) -> void:
	if title.strip_edges().is_empty():
		return
	_messages.append({"title": title, "text": text, "seconds": maxf(0.15, seconds)})
	_advance()


func post_area(title: String) -> void:
	_area = {"title": title, "text": "", "seconds": 2.2}
	_advance()


func discard_pending_area() -> void:
	_area.clear()


func _advance() -> void:
	if _animation or (_messages.is_empty() and _area.is_empty()):
		return
	var next: Dictionary
	if not _messages.is_empty():
		next = _messages.pop_front()
	else:
		next = _area
		_area = {}
	_title.text = next.title
	_body.text = next.text
	_body.visible = not _body.text.is_empty()
	show()
	modulate.a = 0.0
	_animation = create_tween()
	_animation.tween_property(self, "modulate:a", 1.0, FADE_IN).set_ease(Tween.EASE_OUT)
	_animation.tween_interval(next.seconds)
	_animation.tween_property(self, "modulate:a", 0.0, FADE_OUT).set_ease(Tween.EASE_IN)
	_animation.finished.connect(_finish)


func _finish() -> void:
	_animation = null
	hide()
	_advance()


func _label(font: Font, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	return label
