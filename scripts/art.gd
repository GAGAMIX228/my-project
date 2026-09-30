class_name Art
extends RefCounted
## Маленькие помощники для рисования. Пока вся графика рисуется кодом,
## позже её можно заменить настоящими картинками (спрайтами).
## Эти функции нужно вызывать только внутри _draw() того узла, который передан первым аргументом.


static func ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	ci.draw_circle(Vector2.ZERO, rx, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func ellipse_outline(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	ci.draw_arc(Vector2.ZERO, rx, 0.0, TAU, 48, color, width, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), color)


static func rect(ci: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), color)


static func hp_bar(ci: CanvasItem, center_x: float, y: float, width: float, fraction: float, color: Color) -> void:
	ci.draw_rect(Rect2(center_x - width * 0.5, y, width, 4.0), Color(0, 0, 0, 0.55))
	if fraction > 0.0:
		ci.draw_rect(Rect2(center_x - width * 0.5, y, width * clampf(fraction, 0.0, 1.0), 4.0), color)


static func dashed_circle(ci: CanvasItem, center: Vector2, radius: float, color: Color, width := 2.5) -> void:
	var dashes := maxi(16, int(radius / 4.0))
	for i in dashes:
		var a0 := TAU * i / dashes
		ci.draw_arc(center, radius, a0, a0 + TAU / dashes * 0.55, 4, color, width, true)


## Верхняя половина круга (шлем, капюшон).
static func half_disc(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	ci.draw_colored_polygon(pts, color)


## Надпись с тёмной обводкой, чтобы читалась на любом фоне.
static func label(ci: CanvasItem, pos: Vector2, text: String, size := 11) -> void:
	var font := Ui.font()
	ci.draw_string_outline(font, pos + Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, 4, Color(0, 0, 0, 0.7))
	ci.draw_string(font, pos + Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, Color.WHITE)


const OUTLINE := Color("1d1409")


## Круг с тёмной кромкой: так фигуры выглядят «мультяшно» и не сливаются с фоном.
static func outlined_circle(ci: CanvasItem, center: Vector2, radius: float, fill: Color, width := 1.6, outline := OUTLINE) -> void:
	ci.draw_circle(center, radius + width, outline)
	ci.draw_circle(center, radius, fill)


static func outlined_ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, fill: Color, width := 1.6, outline := OUTLINE) -> void:
	ellipse(ci, center, rx + width, ry + width, outline)
	ellipse(ci, center, rx, ry, fill)


## Многоугольник с тёмной кромкой.
static func outlined_poly(ci: CanvasItem, points: Array, fill: Color, width := 1.6, outline := OUTLINE) -> void:
	var pts := PackedVector2Array(points)
	ci.draw_colored_polygon(pts, fill)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	ci.draw_polyline(closed, outline, width, true)


## Толстая линия с тёмной кромкой (оружие, древко, конечности).
static func outlined_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float, outline_width := 1.4) -> void:
	ci.draw_line(a, b, OUTLINE, width + outline_width * 2.0)
	ci.draw_line(a, b, color, width)


## Нога, которая шагает: бедро в hip, стопа качается вперёд и назад по фазе phase.
static func leg(ci: CanvasItem, hip: Vector2, phase: float, length: float, color: Color, width: float) -> void:
	var foot := hip + Vector2(sin(phase) * length * 0.55, length - maxf(0.0, -cos(phase)) * length * 0.25)
	outlined_line(ci, hip, foot, color, width, 1.2)
	outlined_circle(ci, foot + Vector2(width * 0.2, 0), width * 0.6, color.darkened(0.25), 1.0)


static func blob_shadow(ci: CanvasItem, center: Vector2, rx: float) -> void:
	ellipse(ci, center, rx, rx * 0.36, Color(0, 0, 0, 0.3))
