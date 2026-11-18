extends CanvasLayer

const Period = preload("res://scripts/ui/period_theme.gd")


func _ready() -> void:
	var words: CenterContainer = $Words
	var lines: VBoxContainer = $Words/Lines
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", Period.framed(
			Period.DARK, Period.BRASS, Vector4.ZERO))
	words.add_child(card)
	words.move_child(card, 0)
	var title: Label = $Words/Lines/Title
	var subtitle: Label = $Words/Lines/Subtitle
	for label in [title, subtitle]:
		label.add_theme_font_override("font", Period.typeface())
	title.add_theme_color_override("font_color", Period.CREAM)
	subtitle.add_theme_color_override("font_color", Period.MUTED)
	lines.minimum_size_changed.connect(func() -> void:
		card.custom_minimum_size = lines.get_combined_minimum_size() + Vector2(76, 52))
	card.custom_minimum_size = lines.get_combined_minimum_size() + Vector2(76, 52)
