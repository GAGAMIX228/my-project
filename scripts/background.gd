extends Node2D
## Фон уровня: трава, дорога, деревья, лагерь орков и ворота.
## Рисуется один раз кодом. Позже сюда можно поставить нарисованную карту.

var _rng := RandomNumberGenerator.new()


func _draw() -> void:
	_rng.seed = 11
	_draw_grass()
	_draw_road()
	_draw_decor()
	_draw_camp()
	_draw_gate()


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
	for i in 90:
		var p := Vector2(_rand(10, view.x - 10), _rand(20, view.y - 10))
		var is_tree := _rng.randf() < 0.78
		var s := _rand(0.8, 1.3)
		if _dist_to_road(p) < 54.0:
			continue
		var near_pad := false
		for pad: Vector2 in Defs.PADS:
			if pad.distance_to(p) < 52.0:
				near_pad = true
		if near_pad or (p.x > 890 and p.y > 340) or (p.x < 200 and p.y < 110):
			continue
		var crowded := false
		for o in items:
			if o["p"].distance_to(p) < 38.0:
				crowded = true
		if crowded:
			continue
		items.append({"p": p, "tree": is_tree, "s": s})
	items.sort_custom(func(a, b): return a["p"].y < b["p"].y)
	for o in items:
		if o["tree"]:
			_draw_tree(o["p"], o["s"])
		else:
			_draw_rock(o["p"], o["s"])


func _draw_tree(p: Vector2, s: float) -> void:
	Art.ellipse(self, p + Vector2(0, 6), 17 * s, 6 * s, Color(0, 0, 0, 0.2))
	draw_rect(Rect2(p.x - 3 * s, p.y - 8 * s, 6 * s, 14 * s), Color("6b4a2a"))
	draw_circle(p + Vector2(-9, -16) * s, 12 * s, Color("2f6b34"))
	draw_circle(p + Vector2(9, -15) * s, 12 * s, Color("3a7d3c"))
	draw_circle(p + Vector2(0, -26) * s, 14 * s, Color("4a9445"))
	draw_circle(p + Vector2(-3, -30) * s, 6 * s, Color(1, 1, 0.78, 0.18))


func _draw_rock(p: Vector2, s: float) -> void:
	Art.ellipse(self, p + Vector2(0, 4), 13 * s, 5 * s, Color(0, 0, 0, 0.2))
	Art.ellipse(self, p + Vector2(0, -2), 12 * s, 8 * s, Color("8b8f88"))
	Art.ellipse(self, p + Vector2(-3, -5) * s, 6 * s, 4 * s, Color("a7aca4"))


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
