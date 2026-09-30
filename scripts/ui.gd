class_name Ui
extends RefCounted
## Общее оформление интерфейса: цвета, рамки и тема кнопок. Им пользуются HUD и экран сборки.

const INK := Color("12302a")
const INK_SOFT := Color("41615a")
const PANEL := Color("f6faf7")
const LINE := Color("b2c7be")
const ACCENT := Color("d69a22")


static func box(bg: Color, border: Color, radius := 10, margin := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin + 4
	sb.content_margin_right = margin + 4
	sb.content_margin_top = margin - 2
	sb.content_margin_bottom = margin - 2
	return sb


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 16
	th.set_stylebox("normal", "Button", box(PANEL, LINE))
	th.set_stylebox("hover", "Button", box(PANEL, ACCENT))
	th.set_stylebox("pressed", "Button", box(Color("fdf1cf"), ACCENT))
	th.set_stylebox("hover_pressed", "Button", box(Color("fdf1cf"), ACCENT))
	th.set_stylebox("disabled", "Button", box(Color("dde6e0"), LINE))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", INK)
	th.set_color("font_disabled_color", "Button", INK_SOFT)
	th.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 12, 8))
	return th


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
