class_name Ui
extends RefCounted
## Общее оформление интерфейса в духе «дерево и золото»: цвета, рамки, тема кнопок.
## Им пользуются HUD боя, карта кампании и панель сборки.

const WOOD_DARK := Color("2b1c11")
const WOOD := Color("4a3322")
const WOOD_LIGHT := Color("6d4b2f")
const GOLD := Color("e6b84e")
const GOLD_DARK := Color("8a6420")
const CREAM := Color("f6e7c1")
const CREAM_SOFT := Color("cbb88a")
const PARCHMENT := Color("e6d3a3")
const INK := Color("3a2814")
const GREEN := Color("59c46a")
const RED := Color("d8493a")


static var _font: Font


## Шрифт игры (Russo One, лицензия OFL, лежит в assets/fonts).
static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/RussoOne-Regular.ttf") as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


## Рамка: заливка, золотая кромка, скругление.
static func box(fill: Color, border := GOLD_DARK, radius := 8, margin := 8, border_width := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin + 2
	sb.content_margin_right = margin + 2
	sb.content_margin_top = margin - 1
	sb.content_margin_bottom = margin - 1
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Деревянная панель.
static func panel(alpha := 0.96) -> StyleBoxFlat:
	return box(Color(WOOD.r, WOOD.g, WOOD.b, alpha), GOLD_DARK, 10, 8, 3)


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 16
	th.set_stylebox("normal", "Button", box(WOOD_LIGHT, GOLD_DARK, 8, 7))
	th.set_stylebox("hover", "Button", box(Color("84603c"), GOLD, 8, 7))
	th.set_stylebox("pressed", "Button", box(Color("57391f"), GOLD, 8, 7))
	th.set_stylebox("hover_pressed", "Button", box(Color("57391f"), GOLD, 8, 7))
	th.set_stylebox("disabled", "Button", box(Color("3a2c20"), Color("5a4630"), 8, 7))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", CREAM)
	th.set_color("font_disabled_color", "Button", Color("8f7f62"))
	th.set_stylebox("panel", "PanelContainer", panel())
	th.set_color("font_color", "Label", CREAM)
	th.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 4, 0, 0))
	th.set_stylebox("fill", "ProgressBar", box(GREEN, Color(0, 0, 0, 0), 4, 0, 0))
	return th


static func label(text: String, size: int, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.02, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	return l


## Подпись на свитке: тёмный текст без обводки.
static func ink_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	return l
