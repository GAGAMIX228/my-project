class_name HeroArt
extends RefCounted
## Рисунок героя (тело, оружие, дракон). Его используют и герой на поле (Hero), и портрет на кнопке (HeroSprite).
## Рисуем в точке (0, 0) на земле под героем. Число r это радиус тела.


static func _ball(ci: CanvasItem, x: float, y: float, r: float, fill: Color, outline := Color(0, 0, 0, 0), width := 1.0) -> void:
	ci.draw_circle(Vector2(x, y), r, fill)
	if outline.a > 0.0:
		ci.draw_arc(Vector2(x, y), r, 0.0, TAU, 20, outline, width, true)


## hurt: вспыхнуть белым, swing: 1 в момент удара, rage: есть ли ярость, t: время для анимации.
static func draw(ci: CanvasItem, hid: String, def: Dictionary, f: float, hurt: bool, swing: float, rage: bool, t: float, shadow := true) -> void:
	var r: float = def["radius"]
	var body: Color = Color.WHITE if hurt else def["color"]
	if def["kind"] == "dragon":
		_dragon(ci, hid, def, f, hurt, rage, t, shadow)
		return
	if shadow:
		Art.ellipse(ci, Vector2(0, r * 0.8), r, r * 0.4, Color(0, 0, 0, 0.25))
	match hid:
		"edrik": _knight(ci, r, f, body, swing)
		"grum": _ogre(ci, r, f, body, swing)
		"kara": _orc(ci, r, f, body, swing)
		"tarn": _ranger(ci, r, f, body)
		"xol": _mage(ci, r, f, body)
		_: _shaman(ci, r, body, t)
	if rage:
		_ball(ci, 0, -2, r + 6.0, Color(1.0, 0.35, 0.23, 0.35))


static func _knight(ci: CanvasItem, r: float, f: float, body: Color, sw: float) -> void:
	_ball(ci, 0, -2, r, body, Color("22386b"), 1.3)
	Art.half_disc(ci, Vector2(0, -4), r * 0.82, Color("d8dbe3"))
	ci.draw_rect(Rect2(-2, -4, 4, 5), Color("2a2a33"))
	Art.tri(ci, Vector2(-3, -r - 2), Vector2(0, -r - 12), Vector2(5, -r - 1), Color("e0523f"))
	ci.draw_rect(Rect2(-f * (r + 1) - 3, -6, 6, 11), Color("e2b53c"))
	ci.draw_line(Vector2(f * (r - 2), 2), Vector2(f * (r + 11 + sw * 4), -8 + sw * 10), Color("e9edf2"), 2.4)


static func _ogre(ci: CanvasItem, r: float, f: float, body: Color, sw: float) -> void:
	_ball(ci, 0, -2, r, body, Color("5a3a16"), 1.5)
	_ball(ci, -4, -5, 2.2, Color.WHITE)
	_ball(ci, 4, -5, 2.2, Color.WHITE)
	_ball(ci, -4, -5, 1.0, Color("222222"))
	_ball(ci, 4, -5, 1.0, Color("222222"))
	Art.tri(ci, Vector2(-6, 2), Vector2(-3, 2), Vector2(-4.5, -3), Color("f3efe0"))
	Art.tri(ci, Vector2(6, 2), Vector2(3, 2), Vector2(4.5, -3), Color("f3efe0"))
	ci.draw_line(Vector2(f * (r - 2), 6), Vector2(f * (r + 12 + sw * 4), -10 + sw * 12), Color("5a3a16"), 4.0)
	_ball(ci, f * (r + 13 + sw * 4), -11 + sw * 12, 5.0, Color("6b4a2a"), Color("3d2614"), 1.0)


static func _orc(ci: CanvasItem, r: float, f: float, body: Color, sw: float) -> void:
	_ball(ci, 0, -2, r, body, Color("274a1a"), 1.3)
	var paint := Color("c2483a")
	ci.draw_line(Vector2(-6, -8), Vector2(-2, -3), paint, 2.0)
	ci.draw_line(Vector2(6, -8), Vector2(2, -3), paint, 2.0)
	_ball(ci, -3.5, -4, 2.0, Color.WHITE)
	_ball(ci, 3.5, -4, 2.0, Color.WHITE)
	_ball(ci, -3.5, -4, 0.9, Color("b01818"))
	_ball(ci, 3.5, -4, 0.9, Color("b01818"))
	Art.tri(ci, Vector2(-4, -r - 1), Vector2(0, -r - 10), Vector2(4, -r - 1), paint)
	var steel := Color("d9dde3")
	ci.draw_line(Vector2(f * (r - 2), 2), Vector2(f * (r + 8 + sw * 4), -6 + sw * 9), steel, 2.6)
	ci.draw_line(Vector2(-f * (r - 2), 2), Vector2(-f * (r + 6), -6), steel, 2.6)


static func _ranger(ci: CanvasItem, r: float, f: float, body: Color) -> void:
	_ball(ci, 0, -2, r, body, Color("25502a"), 1.3)
	Art.half_disc(ci, Vector2(0, -4), r * 0.95, Color("2f6b34"))
	_ball(ci, 0, -1, r * 0.45, Color("f2d2a4"))
	var turn := 0.0 if f > 0.0 else PI
	ci.draw_arc(Vector2(f * (r + 3), -2), 9.0, -1.3 + turn, 1.3 + turn, 12, Color("6b4a2a"), 2.2, true)


static func _mage(ci: CanvasItem, r: float, f: float, body: Color) -> void:
	_ball(ci, 0, -2, r, body, Color("155a68"), 1.3)
	Art.tri(ci, Vector2(-r, -6), Vector2(0, -r - 16), Vector2(r, -6), Color("1b6f80"))
	_ball(ci, 0, -1, r * 0.42, Color("f2d2a4"))
	ci.draw_line(Vector2(f * (r + 3), 8), Vector2(f * (r + 3), -16), Color("8b6b3a"), 2.4)
	_ball(ci, f * (r + 3), -18, 4.0, Color("7fe0ff"), Color.WHITE, 1.0)


static func _shaman(ci: CanvasItem, r: float, body: Color, t: float) -> void:
	_ball(ci, 0, -2, r, body, Color("4a2f78"), 1.3)
	var feathers := [Color("e0523f"), Color("f0b93a"), Color("4da35a")]
	for i in range(-1, 2):
		Art.tri(ci, Vector2(i * 5 - 2, -r + 1), Vector2(i * 6, -r - 11), Vector2(i * 5 + 3, -r + 1), feathers[i + 1])
	_ball(ci, 0, -1, r * 0.42, Color("f2d2a4"))
	for i in 2:
		var a := t * 3.0 + i * 3.14
		_ball(ci, cos(a) * (r + 6.0), -4.0 + sin(a) * 5.0, 3.0, Color("d9b8ff"), Color.WHITE, 1.0)


static func _dragon(ci: CanvasItem, hid: String, def: Dictionary, f: float, hurt: bool, rage: bool, t: float, shadow: bool) -> void:
	var c: Color = def["color"]
	var y := -22.0
	var wing := sin(t * 9.0) * 0.5
	if shadow:
		Art.ellipse(ci, Vector2(0, 8), 18.0, 6.0, Color(0, 0, 0, 0.25))
	var tail := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		var p0 := Vector2(-f * 8.0, y + 3.0)
		var p1 := Vector2(-f * 24.0, y + 12.0)
		var p2 := Vector2(-f * 28.0, y - 2.0)
		tail.append(p0.lerp(p1, k).lerp(p1.lerp(p2, k), k))
	ci.draw_polyline(tail, c, 5.0, true)
	var shade := Color("8d8874") if hid == "morven" else Color(0, 0, 0, 0.3)
	Art.tri(ci, Vector2(-2, y - 2), Vector2(-18, y - 18 - wing * 12), Vector2(9, y - 5), c)
	Art.tri(ci, Vector2(-2, y - 2), Vector2(-18, y - 18 - wing * 12), Vector2(-6, y - 4), shade)
	Art.tri(ci, Vector2(2, y - 2), Vector2(16, y - 16 - wing * 12), Vector2(12, y - 2), c)
	Art.ellipse(ci, Vector2(0, y), 13.0, 8.5, Color.WHITE if hurt else c)
	Art.ellipse(ci, Vector2(0, y + 2), 9.0, 5.0, Color(1, 1, 1, 0.28))
	_ball(ci, f * 12.0, y - 3.0, 6.0, c)
	Art.tri(ci, Vector2(f * 15.0, y - 3.0), Vector2(f * 22.0, y - 1.0), Vector2(f * 15.0, y + 2.0), c)
	_ball(ci, f * 12.0, y - 5.0, 1.6, Color.WHITE)
	_ball(ci, f * 12.5, y - 5.0, 0.8, Color("222222"))
	Art.tri(ci, Vector2(f * 9.0, y - 8.0), Vector2(f * 8.0, y - 14.0), Vector2(f * 12.0, y - 8.0), Color("f0e6c8"))
	if hid == "morven":
		for i in range(-1, 2):
			ci.draw_line(Vector2(i * 4.0, y - 6.0), Vector2(i * 4.0, y + 6.0), Color("6b6754"), 1.2)
	if rage:
		_ball(ci, 0, y, 20.0, Color(1.0, 0.35, 0.23, 0.35))
