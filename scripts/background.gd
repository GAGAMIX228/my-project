extends Node2D
## Фон уровня: трава, дорога, деревья, лагерь орков и ворота.
## Рисуется один раз кодом. Позже сюда можно поставить нарисованную карту.

var _rng := RandomNumberGenerator.new()


func _draw() -> void:
	# готовый фон уровня (assets/art/levels/<id>/background.png), если он есть
	var picture := ArtPack.texture("levels/%s/background.png" % Game.level_id)
	if picture != null:
		draw_texture_rect(picture, Rect2(Vector2.ZERO, Defs.VIEW), false)
		return
	_rng.seed = 11
	_draw_grass()
	_draw_pond(Vector2(812, 96))
	_draw_road()
	_draw_road_edge()
	_draw_decor()
	_draw_camp()
	_draw_gate()
	_draw_light()


func _rand(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func _draw_grass() -> void:
	var view := Defs.VIEW
	# плавный переход цвета сверху вниз
	var steps := 27
	for i in steps:
		var k := float(i) / float(steps - 1)
		var col := Color("78ad52").lerp(Color("5f9646"), k)
		draw_rect(Rect2(0, view.y * i / steps, view.x, view.y / steps + 1.0), col)
	for i in 90:
		var col := Color(1, 1, 0.86, 0.06) if _rng.randf() < 0.5 else Color(0.06, 0.24, 0.08, 0.08)
		Art.ellipse(self, Vector2(_rand(0, view.x), _rand(0, view.y)), _rand(24, 104), _rand(14, 56), col)


func _road_line(width: float, color: Color) -> void:
	var pts := PackedVector2Array(Defs.PATH)
	draw_polyline(pts, color, width, true)
	for p in pts:
		draw_circle(p, width * 0.5, color)


func _draw_road() -> void:
	_road_line(58.0, Color("5a3d22"))
	_road_line(50.0, Color("c9a568"))
	_road_line(38.0, Color("dcbf85"))
	var total := _path_length()
	for i in 280:
		var p := _pos_at(_rand(0, total))
		var off := _rand(-18, 18)
		var col := Color(0.47, 0.35, 0.2, 0.35) if _rng.randf() < 0.5 else Color(1, 0.94, 0.78, 0.35)
		Art.ellipse(self, p.pos + Vector2(-p.dir.y, p.dir.x) * off, _rand(1.5, 4.0), _rand(1.0, 2.6), col)


## Каменная кромка вдоль дороги и пучки травы по обочинам.
func _draw_road_edge() -> void:
	var total := _path_length()
	var d := 0.0
	while d < total:
		var q := _pos_at(d)
		var normal := Vector2(-q.dir.y, q.dir.x)
		for side in [-1.0, 1.0]:
			var p: Vector2 = q.pos + normal * side * (26.0 + _rand(-1.5, 1.5))
			var r := _rand(2.6, 4.4)
			Art.ellipse(self, p + Vector2(0, 1.5), r * 1.2, r * 0.7, Color(0, 0, 0, 0.25))
			Art.ellipse(self, p, r * 1.15, r * 0.8, Color("6f6a5e"))
			Art.ellipse(self, p + Vector2(-0.6, -0.8), r * 0.85, r * 0.5, Color("a8a395"))
		d += _rand(9.0, 15.0)
	# пучки травы у дороги
	for i in 170:
		var q := _pos_at(_rand(0, total))
		var normal := Vector2(-q.dir.y, q.dir.x)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var p: Vector2 = q.pos + normal * side * _rand(30.0, 40.0)
		var c := Color("3f8a3a") if _rng.randf() < 0.6 else Color("56a84a")
		draw_line(p, p + Vector2(-2.5, -6), c, 1.6)
		draw_line(p, p + Vector2(0.5, -8), c, 1.6)
		draw_line(p, p + Vector2(3, -5), c, 1.6)


func _path_length() -> float:
	var total := 0.0
	for i in Defs.PATH.size() - 1:
		total += Defs.PATH[i].distance_to(Defs.PATH[i + 1])
	return total


## Точка на дороге на расстоянии d от начала и направление движения там.
func _pos_at(d: float) -> Dictionary:
	var left := d
	for i in Defs.PATH.size() - 1:
		var a: Vector2 = Defs.PATH[i]
		var b: Vector2 = Defs.PATH[i + 1]
		var len := a.distance_to(b)
		if left <= len:
			var dir := (b - a) / len
			return {"pos": a + dir * left, "dir": dir}
		left -= len
	return {"pos": Defs.PATH[Defs.PATH.size() - 1], "dir": Vector2.RIGHT}


func _dist_to_road(p: Vector2) -> float:
	var best := 1e9
	for i in Defs.PATH.size() - 1:
		var a: Vector2 = Defs.PATH[i]
		var b: Vector2 = Defs.PATH[i + 1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, q.distance_to(p))
	return best


func _draw_decor() -> void:
	var view := Defs.VIEW
	for i in 160:
		var p := Vector2(_rand(0, view.x), _rand(0, view.y))
		if _dist_to_road(p) < 40.0:
			continue
		var c := Color(0.12, 0.31, 0.12, 0.5)
		draw_line(p, p + Vector2(-2, -5), c, 1.4)
		draw_line(p, p + Vector2(2, -6), c, 1.4)
		draw_line(p, p + Vector2(5, -3), c, 1.4)
	var items: Array = []
	for i in 190:
		var p := Vector2(_rand(10, view.x - 10), _rand(20, view.y - 10))
		var roll := _rng.randf()
		var kind := "oak" if roll < 0.36 else ("pine" if roll < 0.56 else ("bush" if roll < 0.74 else ("flowers" if roll < 0.88 else "rock")))
		var s := _rand(0.8, 1.3)
		if _dist_to_road(p) < 54.0:
			continue
		var near_pad := false
		for pad: Vector2 in Defs.PADS:
			if pad.distance_to(p) < 52.0:
				near_pad = true
		if near_pad or (p.x > 890 and p.y > 340) or (p.x < 200 and p.y < 110) or p.distance_to(Vector2(812, 96)) < 78.0:
			continue
		var crowded := false
		for o in items:
			if o["p"].distance_to(p) < (38.0 if kind in ["oak", "pine"] else 24.0):
				crowded = true
		if crowded:
			continue
		items.append({"p": p, "kind": kind, "s": s})
	items.sort_custom(func(a, b): return a["p"].y < b["p"].y)
	for o in items:
		match o["kind"]:
			"oak": _draw_tree(o["p"], o["s"])
			"pine": _draw_pine(o["p"], o["s"])
			"bush": _draw_bush(o["p"], o["s"])
			"flowers": _draw_flowers(o["p"])
			_: _draw_rock(o["p"], o["s"])


func _draw_tree(p: Vector2, s: float) -> void:
	Art.blob_shadow(self, p + Vector2(0, 7), 20 * s)
	draw_rect(Rect2(p.x - 3.6 * s, p.y - 9 * s, 7.2 * s, 16 * s), Art.OUTLINE)
	draw_rect(Rect2(p.x - 2.6 * s, p.y - 8 * s, 5.2 * s, 14 * s), Color("7a5430"))
	draw_rect(Rect2(p.x - 2.6 * s, p.y - 8 * s, 2 * s, 14 * s), Color("93683c"))
	Art.outlined_circle(self, p + Vector2(-10, -17) * s, 12 * s, Color("2f6b34"), 1.6)
	Art.outlined_circle(self, p + Vector2(10, -16) * s, 12 * s, Color("3a7d3c"), 1.6)
	Art.outlined_circle(self, p + Vector2(0, -27) * s, 14.5 * s, Color("4a9445"), 1.6)
	draw_circle(p + Vector2(-4, -31) * s, 7 * s, Color(1, 1, 0.78, 0.22))
	draw_circle(p + Vector2(-12, -19) * s, 4 * s, Color(1, 1, 0.78, 0.12))


func _draw_pine(p: Vector2, s: float) -> void:
	Art.blob_shadow(self, p + Vector2(0, 7), 17 * s)
	draw_rect(Rect2(p.x - 2.5 * s, p.y - 4 * s, 5 * s, 11 * s), Color("5a3d22"))
	for i in 3:
		var y := p.y - 4 * s - i * 11 * s
		var w := (17.0 - i * 4.0) * s
		Art.outlined_poly(self, [Vector2(p.x - w, y), Vector2(p.x, y - 19 * s), Vector2(p.x + w, y)], Color("2c6a45").lightened(i * 0.06), 1.5)
		Art.tri(self, Vector2(p.x - w, y), Vector2(p.x, y - 19 * s), Vector2(p.x - w * 0.25, y - 2 * s), Color(1, 1, 0.85, 0.14))


func _draw_bush(p: Vector2, s: float) -> void:
	Art.blob_shadow(self, p + Vector2(0, 4), 13 * s)
	Art.outlined_circle(self, p + Vector2(-6, -4) * s, 7 * s, Color("3c8a3a"), 1.4)
	Art.outlined_circle(self, p + Vector2(6, -4) * s, 7 * s, Color("3c8a3a"), 1.4)
	Art.outlined_circle(self, p + Vector2(0, -8) * s, 8 * s, Color("4ea046"), 1.4)
	draw_circle(p + Vector2(-2, -11) * s, 3.5 * s, Color(1, 1, 0.8, 0.2))
	if _rng.randf() < 0.5:
		for i in 3:
			draw_circle(p + Vector2(_rand(-8, 8), _rand(-12, -3)) * s, 1.4, Color("e8506a"))


func _draw_flowers(p: Vector2) -> void:
	var colors := [Color("ffffff"), Color("ffe27a"), Color("ff9ab5"), Color("b7a6ff")]
	var c: Color = colors[_rng.randi() % colors.size()]
	for i in 5:
		var q := p + Vector2(_rand(-9, 9), _rand(-5, 5))
		draw_line(q, q + Vector2(0, 4), Color("3f8a3a"), 1.2)
		draw_circle(q, 2.2, c)
		draw_circle(q, 0.9, Color("ffd24a"))


func _draw_pond(c: Vector2) -> void:
	Art.outlined_ellipse(self, c, 58, 30, Color("a8a08a"), 2.0)
	Art.ellipse(self, c + Vector2(0, 1), 52, 25, Color("2f8fb0"))
	Art.ellipse(self, c + Vector2(-4, -3), 40, 17, Color("46a8c8"))
	draw_arc(c + Vector2(-14, -6), 14, PI * 1.05, PI * 1.6, 10, Color(1, 1, 1, 0.45), 2.0, true)
	for lily in [Vector2(14, 4), Vector2(28, -6), Vector2(-26, 8)]:
		Art.ellipse(self, c + lily, 7, 3.6, Color("4fa04a"))
		draw_circle(c + lily + Vector2(1, -1), 1.6, Color("ff9ab5"))
	for reed in [Vector2(-52, 6), Vector2(-46, 12), Vector2(50, 8), Vector2(44, 14)]:
		draw_line(c + reed, c + reed + Vector2(1, -16), Color("4f7a34"), 2.0)
		draw_circle(c + reed + Vector2(1, -17), 2.4, Color("6b4a2a"))


## Мягкое тёплое освещение сверху слева и затемнение по краям.
func _draw_light() -> void:
	var w := Defs.VIEW.x
	var h := Defs.VIEW.y
	for i in 5:
		Art.ellipse(self, Vector2(120, 60), 420.0 - i * 70.0, 260.0 - i * 40.0, Color(1.0, 0.95, 0.7, 0.035))
	var dark := Color(0.02, 0.06, 0.03, 0.28)
	var clear := Color(0.02, 0.06, 0.03, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(90, 0), Vector2(90, h), Vector2(0, h)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(w - 90, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - 90, h)]), PackedColorArray([clear, dark, dark, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, h - 70), Vector2(w, h - 70), Vector2(w, h), Vector2(0, h)]), PackedColorArray([clear, clear, dark, dark]))


func _draw_rock(p: Vector2, s: float) -> void:
	Art.blob_shadow(self, p + Vector2(0, 4), 14 * s)
	Art.outlined_ellipse(self, p + Vector2(0, -2), 12 * s, 8 * s, Color("8b8f88"), 1.5)
	Art.ellipse(self, p + Vector2(-3, -5) * s, 6 * s, 4 * s, Color("a7aca4"))
	Art.ellipse(self, p + Vector2(4, 0) * s, 5 * s, 3 * s, Color("767a74"))


func _draw_camp() -> void:
	for tent in [[Vector2(52, 62), 1.0], [Vector2(128, 52), 0.85]]:
		var p: Vector2 = tent[0]
		var s: float = tent[1]
		Art.ellipse(self, p + Vector2(0, 20 * s), 34 * s, 9 * s, Color(0, 0, 0, 0.2))
		Art.tri(self, p + Vector2(-32, 18) * s, p + Vector2(0, -30) * s, p + Vector2(32, 18) * s, Color("7a4a2c"))
		Art.tri(self, p + Vector2(-9, 18) * s, p + Vector2(0, -4) * s, p + Vector2(9, 18) * s, Color("5a341e"))
		draw_line(p + Vector2(0, -30) * s, p + Vector2(0, -46) * s, Color("3d2614"), 2.0)
		Art.tri(self, p + Vector2(0, -46) * s, p + Vector2(16, -41) * s, p + Vector2(0, -35) * s, Color("a62f24"))


func _draw_gate() -> void:
	for base in [Vector2(928, 380), Vector2(928, 460)]:
		Art.ellipse(self, base + Vector2(0, 24), 22, 7, Color(0, 0, 0, 0.25))
		draw_rect(Rect2(base.x - 15, base.y - 26, 30, 50), Color("9a9a92"))
		draw_rect(Rect2(base.x - 15, base.y - 26, 10, 50), Color("b4b4ac"))
		for i in 3:
			draw_rect(Rect2(base.x - 15 + i * 11, base.y - 33, 8, 8), Color("7c7c75"))
		draw_rect(Rect2(base.x - 5, base.y - 10, 10, 18), Color("2f5fa8"))
