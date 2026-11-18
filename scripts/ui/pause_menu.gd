extends CanvasLayer

const Period = preload("res://scripts/ui/period_theme.gd")

const MapView = preload("res://scripts/ui/pause_city_map.gd")
const Preferences = preload("res://scripts/ui/game_preferences.gd")
const GAME := "res://scenes/world/new_game.tscn"
const CONTINUE := "res://scenes/world/continue_game.tscn"
const Wallet = preload("res://scripts/systems/wallet.gd")
const MAIN := "res://scenes/ui/main_menu.tscn"
const GOLD := Period.BRASS_LIGHT
const INK := Period.INK

@export var main_menu := false

var _world: Node3D
var _player: CharacterBody3D
var _visual: Node3D
var _source: Node2D
var _map: MapView
var _overlay: Control
var _content: VBoxContainer
var _heading: Label
var _font := Period.typeface()
var _settings := Preferences.new()
var _pages: Dictionary[String, Control] = {}
var _is_open := false
var _leaving := false
var _prior_mouse := Input.MOUSE_MODE_CAPTURED
var _feedback: Label


func _ready() -> void:
	_settings.load_values()
	_settings.apply(get_tree().root)
	_build_shell()
	if main_menu:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_page("Главное меню")
	else:
		_overlay.hide()


func configure(world: Node3D, player: CharacterBody3D, plan: Node2D) -> void:
	_world = world
	_player = player
	_visual = player.get_node("CharacterVisual")
	_source = plan


func _input(event: InputEvent) -> void:
	if main_menu or _leaving or not event.is_action_pressed(&"ui_cancel", false) or not is_instance_valid(_player):
		return
	get_viewport().set_input_as_handled()
	if _is_open:
		_resume()
	else:
		_pause()


func _pause() -> void:
	_prior_mouse = Input.mouse_mode
	_is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_page("Пауза")
	_overlay.show()


func _resume() -> void:
	_is_open = false
	_overlay.hide()
	Input.mouse_mode = _prior_mouse
	get_tree().paused = false


func _change_scene(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred(path)


func _build_shell() -> void:
	_overlay = Control.new()
	_overlay.name = "MenuLayout"
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("#1b1111ed") if main_menu else Color("#171112e4")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	_overlay.add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 24)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _style(Period.DARK, GOLD, 17))
	margins.add_child(frame)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 18)
	frame.add_child(spread)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size.x = 231
	navigation.add_theme_constant_override("separation", 7)
	spread.add_child(navigation)
	navigation.add_child(_label("Петербургъ", 35, Period.CREAM))
	navigation.add_child(_label("1899", 20, GOLD))
	var rule := HSeparator.new()
	navigation.add_child(rule)
	if main_menu:
		var save := ConfigFile.new()
		if save.load(Wallet.SAVE_PATH) == OK and (save.has_section("campaign") or save.has_section("again_twenty_five")):
			navigation.add_child(_button("Продолжить сюжет", func() -> void: _change_scene(CONTINUE)))
		navigation.add_child(_button("Начать игру", func() -> void: _change_scene(GAME)))
	else:
		navigation.add_child(_button("Продолжить", _resume))
		navigation.add_child(_button("Карта", func() -> void: _page("Карта")))
		navigation.add_child(_button("Управление", func() -> void: _page("Управление")))
	navigation.add_child(_button("Настройки", func() -> void: _page("Настройки")))
	if not main_menu:
		navigation.add_child(_button("Выход в главное меню", func() -> void: _page("Главное меню")))

	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", Period.paper(Vector4(18, 18, 18, 18)))
	spread.add_child(paper)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	paper.add_child(_content)
	_heading = _label("", 31, INK)
	_content.add_child(_heading)


func _page(title: String) -> void:
	for page in _pages.values():
		page.hide()
	_heading.text = title
	if not _pages.has(title):
		var page := VBoxContainer.new()
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		_content.add_child(page)
		_pages[title] = page
		match title:
			"Карта":
				_build_map(page)
			"Управление":
				_build_controls(page)
			"Настройки":
				_build_settings(page)
			"Главное меню":
				if not main_menu:
					page.add_child(_label("Текущая поездка завершится.", 19, INK))
					page.add_child(_button("Выйти в главное меню", func() -> void: _change_scene(MAIN)))
					page.add_child(_button("Назад", func() -> void: _page("Пауза")))
			_:
				page.add_child(_label("Esc — вернуться в игру", 19, INK))
	_pages[title].show()
	if title == "Карта":
		_refresh_map()
		_map.reset_view.call_deferred()


func _build_map(page: Control) -> void:
	_map = MapView.new()
	_map.name = "CityMap"
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.custom_minimum_size.y = 176
	page.add_child(_map)
	_map.configure(_source, _world)
	var tools := HBoxContainer.new()
	page.add_child(tools)
	var hint := _label("Колесо — масштаб · Перетаскивание — обзор", 16, INK)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(hint)
	tools.add_child(_button("Вся карта", _map.reset_view))


func _refresh_map() -> void:
	var carrier := _visual.get_parent() as Node3D
	var target := _player if carrier == _player else carrier
	_map.show_player(target.global_position, -(_visual.global_basis.z if carrier == _player else carrier.global_basis.z))


func _build_controls(page: Control) -> void:
	for row in [
		["Пешком", "WASD — движение · Shift — бег · Пробел — прыжок"],
		["Автомобиль", "W/S — газ и задний ход · A/D — поворот · Пробел — тормоз"],
		["Лошадь", "WASD — движение · Shift — галоп · Пробел — прыжок"],
		["Велосипед", "WASD — движение · Пробел — тормоз"],
		["Общие", "Мышь — камера · E — взаимодействие, посадка и выход · Esc — пауза"],
	]:
		page.add_child(_label(row[0], 20, Period.BURGUNDY))
		page.add_child(_label(row[1], 16, INK))


func _build_settings(page: Control) -> void:
	_feedback = _label("", 15, INK)
	_slider(page, "Общая громкость", 0.0, 1.0, _settings.volume, func(value: float) -> void:
		_settings.volume = value
		_save_settings())
	_slider(page, "Масштаб 3D-рендера", 0.6, 1.0, _settings.render_scale, func(value: float) -> void:
		_settings.render_scale = value
		_save_settings())
	var sync := CheckButton.new()
	sync.text = "Вертикальная синхронизация"
	sync.button_pressed = _settings.vsync
	sync.add_theme_font_override("font", _font)
	sync.add_theme_font_size_override("font_size", 17)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		sync.add_theme_color_override(key, INK)
	sync.toggled.connect(func(value: bool) -> void:
		_settings.vsync = value
		_save_settings())
	page.add_child(sync)
	page.add_child(_feedback)


func _slider(page: Control, caption: String, minimum: float, maximum: float, initial: float, change: Callable) -> void:
	var label := _label("%s — %d%%" % [caption, roundi(initial * 100)], 18, INK)
	page.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = initial
	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%s — %d%%" % [caption, roundi(value * 100)]
		change.call(value))
	page.add_child(slider)


func _save_settings() -> void:
	_settings.apply(get_tree().root)
	_feedback.text = "" if _settings.save_values() == OK else "Не удалось сохранить настройки"


func _label(text: String, pixels: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", tint)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 36
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Period.CREAM)
	button.add_theme_stylebox_override("normal", _style(Period.BURGUNDY_DARK, Period.BRASS, 8))
	button.add_theme_stylebox_override("hover", _style(Period.BURGUNDY, GOLD, 8))
	button.add_theme_stylebox_override("pressed", _style(Period.BURGUNDY_DARK.lightened(0.07), GOLD, 8))
	button.pressed.connect(action)
	return button


func _style(background: Color, border: Color, inset: int) -> StyleBoxFlat:
	return Period.framed(background, border, Vector4(inset, inset, inset, inset))
