class_name Icons
extends RefCounted
## Значки для интерфейса, нарисованные кодом: сердце, монета, звезда, иконки башен, способностей и заклинаний.
## Все рисуются в круге радиуса r вокруг точки c. Позже их можно заменить настоящими картинками.
## Идентификаторы: heart, coin, flag, star, pause, play, speed, back, up, tower:<вид>, ab:<герой>, sp:<заклинание>.


static func _p(c: Vector2, r: float, x: float, y: float) -> Vector2:
	return c + Vector2(x, y) * r


static func _poly(ci: CanvasItem, c: Vector2, r: float, pts: Array, color: Color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(c + p * r)
	ci.draw_colored_polygon(out, color)


static func _flame(ci: CanvasItem, c: Vector2, r: float, outer: Color, inner: Color) -> void:
	_poly(ci, c, r, [Vector2(0, -0.95), Vector2(0.55, -0.1), Vector2(0.6, 0.35), Vector2(0.25, 0.85), Vector2(-0.25, 0.85), Vector2(-0.6, 0.35), Vector2(-0.5, -0.15), Vector2(-0.15, -0.35)], outer)
	_poly(ci, c, r, [Vector2(0, -0.35), Vector2(0.3, 0.2), Vector2(0.25, 0.65), Vector2(-0.25, 0.65), Vector2(-0.3, 0.2)], inner)


static func _snow(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	for i in 3:
		var a := PI * i / 3.0 + PI / 6.0
		var d := Vector2(cos(a), sin(a)) * r * 0.9
		ci.draw_line(c - d, c + d, color, maxf(1.5, r * 0.16))
		var tip := Vector2(cos(a), sin(a)) * r * 0.6
		var side := Vector2(-sin(a), cos(a)) * r * 0.22
		ci.draw_line(c + tip, c + tip * 1.3 + side, color, maxf(1.0, r * 0.1))
		ci.draw_line(c + tip, c + tip * 1.3 - side, color, maxf(1.0, r * 0.1))
		ci.draw_line(c - tip, c - tip * 1.3 + side, color, maxf(1.0, r * 0.1))
		ci.draw_line(c - tip, c - tip * 1.3 - side, color, maxf(1.0, r * 0.1))


static func _star(ci: CanvasItem, c: Vector2, r: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * i / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 if i % 2 == 0 else 0.45))
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, edge, maxf(1.0, r * 0.12), true)


## Звезда уровня: заполненная или пустая.
static func star(ci: CanvasItem, c: Vector2, r: float, filled: bool) -> void:
	if filled:
		_star(ci, c, r, Color("f4c542"), Color("8a5f0a"))
	else:
		_star(ci, c, r, Color(0.2, 0.15, 0.1, 0.55), Color(0.5, 0.42, 0.3, 0.8))


static func draw(ci: CanvasItem, id: String, c: Vector2, r: float) -> void:
	match id:
		"heart":
			ci.draw_circle(_p(c, r, -0.42, -0.28), r * 0.5, Color("e0483c"))
			ci.draw_circle(_p(c, r, 0.42, -0.28), r * 0.5, Color("e0483c"))
			_poly(ci, c, r, [Vector2(-0.88, -0.1), Vector2(0.88, -0.1), Vector2(0, 0.92)], Color("e0483c"))
			ci.draw_circle(_p(c, r, -0.5, -0.4), r * 0.16, Color(1, 1, 1, 0.55))
		"coin":
			ci.draw_circle(c, r * 0.9, Color("8a5f0a"))
			ci.draw_circle(c, r * 0.78, Color("f4c542"))
			ci.draw_arc(c, r * 0.5, 0.0, TAU, 20, Color("c48f1a"), maxf(1.0, r * 0.14), true)
			ci.draw_arc(c, r * 0.55, 3.6, 4.9, 8, Color(1, 1, 1, 0.6), maxf(1.0, r * 0.12), true)
		"flag":
			ci.draw_line(_p(c, r, -0.5, 0.9), _p(c, r, -0.5, -0.9), Color("3d2614"), maxf(1.5, r * 0.16))
			_poly(ci, c, r, [Vector2(-0.45, -0.9), Vector2(0.85, -0.4), Vector2(-0.45, 0.1)], Color("d8493a"))
		"star":
			_star(ci, c, r, Color("f4c542"), Color("8a5f0a"))
		"pause":
			ci.draw_rect(Rect2(_p(c, r, -0.55, -0.6), Vector2(r * 0.42, r * 1.2)), Color("f6e7c1"))
			ci.draw_rect(Rect2(_p(c, r, 0.13, -0.6), Vector2(r * 0.42, r * 1.2)), Color("f6e7c1"))
		"play":
			_poly(ci, c, r, [Vector2(-0.45, -0.65), Vector2(0.7, 0), Vector2(-0.45, 0.65)], Color("f6e7c1"))
		"speed":
			_poly(ci, c, r, [Vector2(-0.8, -0.55), Vector2(0.0, 0), Vector2(-0.8, 0.55)], Color("f6e7c1"))
			_poly(ci, c, r, [Vector2(0.0, -0.55), Vector2(0.8, 0), Vector2(0.0, 0.55)], Color("f6e7c1"))
		"back":
			_poly(ci, c, r, [Vector2(-0.8, 0), Vector2(-0.1, -0.6), Vector2(-0.1, -0.22), Vector2(0.75, -0.22), Vector2(0.75, 0.22), Vector2(-0.1, 0.22), Vector2(-0.1, 0.6)], Color("f6e7c1"))
		"up":
			_poly(ci, c, r, [Vector2(0, -0.85), Vector2(0.75, 0.0), Vector2(0.28, 0.0), Vector2(0.28, 0.8), Vector2(-0.28, 0.8), Vector2(-0.28, 0.0), Vector2(-0.75, 0.0)], Color("7bd88f"))
		"lock":
			ci.draw_arc(_p(c, r, 0, -0.2), r * 0.42, PI, TAU, 12, Color("cfc4a8"), maxf(2.0, r * 0.18), true)
			ci.draw_rect(Rect2(_p(c, r, -0.62, -0.2), Vector2(r * 1.24, r * 0.95)), Color("b7a97f"))
			ci.draw_circle(_p(c, r, 0, 0.2), r * 0.14, Color("4a3322"))
		"tower:archer":
			ci.draw_rect(Rect2(_p(c, r, -0.4, -0.3), Vector2(r * 0.8, r * 1.15)), Color("8a5a32"))
			_poly(ci, c, r, [Vector2(-0.65, -0.3), Vector2(0, -0.95), Vector2(0.65, -0.3)], Color("b8442e"))
			ci.draw_circle(_p(c, r, 0, -0.05), r * 0.14, Color("2a1a0c"))
		"tower:barracks":
			ci.draw_rect(Rect2(_p(c, r, -0.7, -0.35), Vector2(r * 1.4, r * 1.2)), Color("9a9488"))
			for i in 3:
				ci.draw_rect(Rect2(_p(c, r, -0.7 + i * 0.5, -0.6), Vector2(r * 0.4, r * 0.28)), Color("7c776c"))
			ci.draw_rect(Rect2(_p(c, r, -0.2, 0.2), Vector2(r * 0.4, r * 0.65)), Color("4a2f1a"))
			_poly(ci, c, r, [Vector2(0.4, -0.6), Vector2(0.95, -0.85), Vector2(0.4, -1.0)], Color("2f6fc0"))
		"tower:mage":
			ci.draw_rect(Rect2(_p(c, r, -0.38, -0.4), Vector2(r * 0.76, r * 1.3)), Color("6a54b8"))
			_poly(ci, c, r, [Vector2(-0.6, -0.4), Vector2(0, -1.0), Vector2(0.6, -0.4)], Color("3e2f86"))
			ci.draw_circle(_p(c, r, 0, -0.7), r * 0.2, Color("c9a6ff"))
		"tower:mortar":
			Art.ellipse(ci, _p(c, r, 0, 0.3), r * 0.8, r * 0.4, Color("4d4a52"))
			ci.draw_line(_p(c, r, -0.2, 0.15), _p(c, r, 0.55, -0.6), Color("2f2d33"), maxf(3.0, r * 0.45))
			ci.draw_circle(_p(c, r, -0.1, 0.1), r * 0.3, Color("66636c"))
		"ab:edrik":
			_poly(ci, c, r, [Vector2(-0.55, -0.7), Vector2(0.55, -0.7), Vector2(0.55, 0.1), Vector2(0, 0.85), Vector2(-0.55, 0.1)], Color("4a78c4"))
			ci.draw_line(_p(c, r, 0, -0.6), _p(c, r, 0, 0.6), Color("e2b53c"), maxf(2.0, r * 0.2))
			ci.draw_line(_p(c, r, -0.4, -0.15), _p(c, r, 0.4, -0.15), Color("e2b53c"), maxf(2.0, r * 0.2))
		"ab:grum":
			ci.draw_arc(c, r * 0.35, 0.0, TAU, 16, Color("d9a95c"), maxf(2.0, r * 0.16), true)
			ci.draw_arc(c, r * 0.7, 0.0, TAU, 20, Color("d9a95c"), maxf(2.0, r * 0.14), true)
			ci.draw_line(_p(c, r, -0.2, -0.1), _p(c, r, 0.1, 0.25), Color("5a3a16"), maxf(2.0, r * 0.16))
			ci.draw_line(_p(c, r, 0.1, 0.25), _p(c, r, 0.0, 0.5), Color("5a3a16"), maxf(2.0, r * 0.16))
		"ab:kara":
			_flame(ci, c, r, Color("e0483c"), Color("ffb03a"))
		"ab:tarn":
			ci.draw_arc(c, r * 0.65, 0.0, TAU, 20, Color("f6e7c1"), maxf(1.5, r * 0.14), true)
			ci.draw_line(_p(c, r, -0.9, 0), _p(c, r, 0.9, 0), Color("f6e7c1"), maxf(1.5, r * 0.12))
			ci.draw_line(_p(c, r, 0, -0.9), _p(c, r, 0, 0.9), Color("f6e7c1"), maxf(1.5, r * 0.12))
			ci.draw_circle(c, r * 0.16, Color("e0483c"))
		"ab:xol", "sp:frost":
			_snow(ci, c, r * 0.95, Color("bfeaff"))
		"ab:ishta":
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				var g := _p(c, r, cos(a) * 0.5, sin(a) * 0.45)
				ci.draw_circle(g, r * 0.3, Color("d9b8ff"))
				ci.draw_circle(g + Vector2(-r * 0.1, -r * 0.04), r * 0.06, Color("2a1a44"))
				ci.draw_circle(g + Vector2(r * 0.1, -r * 0.04), r * 0.06, Color("2a1a44"))
		"ab:ashgar":
			ci.draw_arc(c, r * 0.85, 0.0, TAU, 24, Color("ff7a2a"), maxf(1.5, r * 0.12), true)
			_flame(ci, c, r * 0.7, Color("ff7a2a"), Color("ffd27a"))
		"ab:morven":
			ci.draw_circle(_p(c, r, 0, -0.1), r * 0.62, Color("cfc9b3"))
			ci.draw_rect(Rect2(_p(c, r, -0.32, 0.3), Vector2(r * 0.64, r * 0.4)), Color("cfc9b3"))
			ci.draw_circle(_p(c, r, -0.25, -0.12), r * 0.16, Color("2a4a30"))
			ci.draw_circle(_p(c, r, 0.25, -0.12), r * 0.16, Color("2a4a30"))
			ci.draw_arc(c, r * 0.9, 0.3, 2.8, 12, Color("b9ffd0"), maxf(1.5, r * 0.12), true)
		"ab:zefira", "sp:wave":
			var col := Color("c8f0ff") if id == "ab:zefira" else Color("5fb4ff")
			for i in 3:
				var y := (i - 1) * 0.5
				ci.draw_arc(_p(c, r, -0.3, y), r * 0.42, PI * 0.9, PI * 2.1, 10, col, maxf(2.0, r * 0.16), true)
				ci.draw_arc(_p(c, r, 0.3, y), r * 0.42, PI * 0.9, PI * 2.1, 10, col, maxf(2.0, r * 0.16), true)
		"sp:knights":
			ci.draw_circle(_p(c, r, 0, 0.05), r * 0.72, Color("b7bcc8"))
			ci.draw_rect(Rect2(_p(c, r, -0.55, 0.0), Vector2(r * 1.1, r * 0.22)), Color("2a2a33"))
			ci.draw_rect(Rect2(_p(c, r, -0.06, 0.0), Vector2(r * 0.12, r * 0.7)), Color("2a2a33"))
			_poly(ci, c, r, [Vector2(-0.15, -0.65), Vector2(0.1, -1.0), Vector2(0.4, -0.6)], Color("e0523f"))
		"sp:meteors", "sp:fireball":
			var big := id == "sp:fireball"
			ci.draw_line(_p(c, r, 0.85, -0.85), _p(c, r, 0.0, 0.0), Color(1.0, 0.67, 0.24, 0.7), maxf(3.0, r * 0.4))
			ci.draw_circle(_p(c, r, -0.15, 0.15), r * (0.55 if big else 0.42), Color("ff8a2a"))
			ci.draw_circle(_p(c, r, -0.22, 0.08), r * 0.22, Color("fff2c0"))
			if big:
				_flame(ci, _p(c, r, 0.35, -0.35), r * 0.4, Color("e0483c"), Color("ffb03a"))
		"sp:reinforce":
			ci.draw_circle(_p(c, r, 0, 0.05), r * 0.7, Color("5f9440"))
			ci.draw_circle(_p(c, r, -0.25, -0.1), r * 0.14, Color.WHITE)
			ci.draw_circle(_p(c, r, 0.25, -0.1), r * 0.14, Color.WHITE)
			_poly(ci, c, r, [Vector2(-0.3, 0.35), Vector2(-0.12, 0.35), Vector2(-0.22, 0.05)], Color("f3efe0"))
			_poly(ci, c, r, [Vector2(0.3, 0.35), Vector2(0.12, 0.35), Vector2(0.22, 0.05)], Color("f3efe0"))
			ci.draw_line(_p(c, r, -0.85, 0.7), _p(c, r, -0.4, 0.2), Color("d9dde3"), maxf(1.5, r * 0.14))
		"sp:quake":
			_poly(ci, c, r, [Vector2(-0.9, 0.2), Vector2(0.9, 0.2), Vector2(0.9, 0.8), Vector2(-0.9, 0.8)], Color("8a6a3c"))
			ci.draw_polyline(PackedVector2Array([_p(c, r, -0.1, -0.8), _p(c, r, 0.15, -0.3), _p(c, r, -0.15, 0.1), _p(c, r, 0.1, 0.7)]), Color("2a1a0c"), maxf(2.0, r * 0.18), true)
			_poly(ci, c, r, [Vector2(-0.7, 0.2), Vector2(-0.45, -0.3), Vector2(-0.25, 0.2)], Color("a8865a"))
		"sp:wrath":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.55, c + Vector2(cos(a), sin(a)) * r * 0.95, Color("fff3a8"), maxf(2.0, r * 0.14))
			ci.draw_circle(c, r * 0.42, Color("ffe27a"))
		_:
			ci.draw_circle(c, r * 0.5, Color("f6e7c1"))
