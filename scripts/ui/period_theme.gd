extends RefCounted

const CREAM := Color("#f0dfb8")
const PAPER := Color("#e6d1a6")
const INK := Color("#322521")
const DARK := Color("#26191ceb")
const BURGUNDY := Color("#793946")
const BURGUNDY_DARK := Color("#502831")
const BRASS := Color("#ae8953")
const BRASS_LIGHT := Color("#dcbd83")
const MUTED := Color("#d5bf99")
const SHADOW := Color("#160f13c0")
const MAP_INKS := [Color("#9faea7"), Color("#ddc9a3"), Color("#b3b58c"),
		Color("#ead8ae"), Color("#786450"), Color("#ad9270")]

static var _font: SystemFont
static var _paper: ImageTexture
static var _grain: ImageTexture


static func typeface() -> SystemFont:
	if not _font:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "Noto Serif"])
		_font.font_weight = 600
	return _font


static func framed(background: Color, border: Color, margins: Vector4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	return style


static func paper(margins: Vector4) -> StyleBoxTexture:
	if not _paper:
		_paper = _make_paper()
	var style := StyleBoxTexture.new()
	style.texture = _paper
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 4.0)
		style.set_content_margin(side, margins[side])
	return style


static func grain_overlay() -> TextureRect:
	if not _grain:
		var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1899
		for y in 64:
			for x in 64:
				var value := rng.randf_range(0.0, 0.07)
				image.set_pixel(x, y, Color(INK, value))
		_grain = ImageTexture.create_from_image(image)
	var texture := TextureRect.new()
	texture.texture = _grain
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_TILE
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture


static func _make_paper() -> ImageTexture:
	var image := Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1899
	for y in 96:
		for x in 96:
			var border := mini(mini(x, 95 - x), mini(y, 95 - y))
			var grain := rng.randf_range(-0.07, 0.04)
			var cloud := sin(x * 0.15 + cos(y * 0.21)) * sin(y * 0.13) * 0.018
			var color := PAPER.lightened(grain + cloud)
			if border == 0:
				color = BRASS
			elif border == 1:
				color = PAPER.darkened(0.16)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
