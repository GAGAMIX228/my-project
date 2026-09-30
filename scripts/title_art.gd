class_name TitleArt
extends Control
## Картина на заставке: закат, горы, замок некроманта, море с осьминогом, наша башня, рыцарь, дракон и нежить.
## Всё нарисовано кодом и слегка движется. Позже сюда можно поставить настоящий рисунок.

var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_add_tower("archer", Vector2(160, 352), 3.4)
	_add_tower("mage", Vector2(282, 384), 2.7)
	_add_hero("tarn", Vector2(205, 482), 3.0)
	_add_hero("edrik", Vector2(345, 478), 4.2)
	_add_hero("ashgar", Vector2(570, 272), 3.0)


func _add_tower(kind: String, pos: Vector2, s: float) -> void:
	var tower := Tower.new()
	tower.setup(kind)
	tower.level = 3
	tower.show_level = false
	tower.position = pos
	tower.scale = Vector2(s, s)
	add_child(tower)


func _add_hero(id: String, pos: Vector2, s: float) -> void:
	var hero := HeroSprite.new()
	hero.hid = id
	hero.position = pos
	hero.scale = Vector2(s, s)
	add_child(hero)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	_rng.seed = 21
	_sky()
	_ridge(330.0, 90.0, 1.0, Color("6a6fb4"), true)
	_ridge(370.0, 70.0, 4.0, Color("55578f"), false)
	_castle(Vector2(765, 300))
	_sea()
	_kraken(Vector2(845, 392))
	_hills()
	_road()
	_wall()
	for i in 3:
		_skeleton(Vector2(690 + i * 46, 452 + (i % 2) * 14), 1.9, i * 1.3)
	_skeleton(Vector2(810, 478), 2.3, 0.7)
	_arrows()
	_fire()
	_bats()
	_foreground()
	_vignette()
	_logo()


# ---------- природа ----------

func _sky() -> void:
	var bands := 36
	var top := Color("1b2d68")
	var mid := Color("3f7fbd")
	var low := Color("f7bf72")
	for i in bands:
		var k := float(i) / float(bands - 1)
		var col := top.lerp(mid, minf(1.0, k * 1.6)) if k < 0.62 else mid.lerp(low, (k - 0.62) / 0.38)
		draw_rect(Rect2(0, Defs.VIEW.y * i / bands, Defs.VIEW.x, Defs.VIEW.y / bands + 1.0), col)
	# закатное солнце и лучи
	for i in 6:
		draw_circle(Vector2(430, 350), 150.0 - i * 22.0, Color(1.0, 0.85, 0.5, 0.07))
	draw_circle(Vector2(430, 350), 38.0, Color(1.0, 0.95, 0.75, 0.9))
	for i in 4:
		var a := -2.05 + i * 0.22 + sin(_t * 0.4 + i) * 0.02
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var o := Vector2(130, -30)
		draw_colored_polygon(PackedVector2Array([o, o + dir * 700.0 + side * 40.0, o + dir * 700.0 - side * 40.0]), Color(1.0, 0.95, 0.6, 0.07))


func _ridge(base_y: float, amp: float, seed_value: float, color: Color, snow: bool) -> void:
	var pts := PackedVector2Array()
	var xs := range(-20, 1000, 20)
	for x in xs:
		var y := base_y - amp * (0.5 + 0.28 * sin(x * 0.011 + seed_value) + 0.18 * sin(x * 0.029 + seed_value * 2.0) + 0.1 * sin(x * 0.071 + seed_value * 3.0))
		pts.append(Vector2(x, y))
		if snow and y < base_y - amp * 0.78:
			Art.tri(self, Vector2(x - 14, y + 16), Vector2(x, y - 3), Vector2(x + 14, y + 16), Color(1, 1, 1, 0.85))
	var poly := PackedVector2Array(pts)
	poly.append(Vector2(1000, 560))
	poly.append(Vector2(-20, 560))
	draw_colored_polygon(poly, color)


func _castle(base: Vector2) -> void:
	var dark := Color("2b2444")
	var darker := Color("1e1830")
	# туман и зелёный свет над замком
	for i in 5:
		draw_circle(base + Vector2(0, -60), 70.0 + i * 26.0 + sin(_t * 0.8 + i) * 4.0, Color(0.4, 0.95, 0.5, 0.05))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -120), base + Vector2(16, -120), base + Vector2(60, -330), base + Vector2(-60, -330)]), Color(0.45, 1.0, 0.55, 0.06 + 0.02 * sin(_t * 2.0)))
	Art.ellipse(self, base + Vector2(0, 8), 130.0, 26.0, Color("3a3a5e"))
	draw_rect(Rect2(base.x - 52, base.y - 70, 104, 76), dark)
	for tx in [-64.0, 64.0, -24.0, 24.0]:
		var h := 110.0 if absf(tx) > 30.0 else 140.0
		draw_rect(Rect2(base.x + tx - 13, base.y - h, 26, h + 6), darker if absf(tx) > 30.0 else dark)
		Art.tri(self, Vector2(base.x + tx - 18, base.y - h), Vector2(base.x + tx, base.y - h - 44), Vector2(base.x + tx + 18, base.y - h), Color("3b2f5c"))
		draw_circle(Vector2(base.x + tx, base.y - h + 22), 4.0, Color(0.5, 1.0, 0.6, 0.75 + 0.25 * sin(_t * 3.0 + tx)))
	draw_rect(Rect2(base.x - 10, base.y - 40, 20, 46), Color(0.45, 1.0, 0.55, 0.85))


func _sea() -> void:
	var shore := PackedVector2Array([Vector2(520, 560), Vector2(520, 440), Vector2(580, 412), Vector2(650, 408), Vector2(720, 392), Vector2(800, 372), Vector2(880, 368), Vector2(960, 352), Vector2(1000, 350), Vector2(1000, 560)])
	draw_colored_polygon(shore, Color("1f9ab5"))
	for i in 7:
		var y := 400.0 + i * 24.0
		var pts := PackedVector2Array()
		for x in range(520, 1000, 12):
			pts.append(Vector2(x, y + sin(x * 0.05 + _t * 1.6 + i) * 3.0))
		draw_polyline(pts, Color(1, 1, 1, 0.18), 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(520, 560), Vector2(520, 500), Vector2(1000, 470), Vector2(1000, 560)]), Color(0.05, 0.3, 0.5, 0.45))


func _kraken(base: Vector2) -> void:
	var skin := Color("7d3fa6")
	var dark := Color("56287a")
	# щупальца: одни тянутся вверх, другие бьют по берегу
	for i in 7:
		var dir := -1.0 if i % 2 == 0 else 1.0
		var reach := 90.0 + (i % 3) * 26.0
		var height := 120.0 + (i % 4) * 28.0
		var start := base + Vector2((i - 3) * 13.0, 18.0)
		var prev := start
		for k in range(1, 17):
			var f := k / 16.0
			var swing := sin(f * 5.0 + _t * 2.2 + i * 1.7) * 9.0 * f
			var p := start + Vector2(dir * reach * f * (0.5 + 0.5 * f) + swing, -height * sin(f * PI * 0.55) + f * f * 40.0)
			draw_line(prev, p, dark, lerpf(17.0, 4.0, f) + 3.0, true)
			draw_line(prev, p, skin, lerpf(17.0, 4.0, f), true)
			if k % 3 == 0:
				draw_circle(p + Vector2(0, 2), lerpf(3.0, 1.2, f), Color("e8b0d8"))
			prev = p
	Art.ellipse(self, base + Vector2(0, 26), 62.0, 14.0, Color(0.05, 0.25, 0.4, 0.6))
	Art.ellipse(self, base, 54.0, 46.0, skin)
	Art.ellipse(self, base + Vector2(-12, -14), 26.0, 16.0, Color(1, 1, 1, 0.16))
	for sx in [-1.0, 1.0]:
		draw_circle(base + Vector2(sx * 20.0, -4.0), 13.0, Color("fff7cf"))
		draw_circle(base + Vector2(sx * 20.0 - 2.0, -2.0), 6.0, Color("d8201a"))
		draw_line(base + Vector2(sx * 34.0, -20.0), base + Vector2(sx * 8.0, -11.0), Color("2a1040"), 4.0)
	draw_arc(base + Vector2(0, 14), 11.0, 0.3, PI - 0.3, 10, Color("2a1040"), 3.0, true)


func _hills() -> void:
	var back := PackedVector2Array()
	for x in range(-20, 620, 20):
		back.append(Vector2(x, 405 + sin(x * 0.012 + 1.0) * 22.0 + sin(x * 0.03) * 8.0))
	back.append(Vector2(620, 560))
	back.append(Vector2(-20, 560))
	draw_colored_polygon(back, Color("7dba58"))
	var front := PackedVector2Array()
	for x in range(-20, 720, 20):
		front.append(Vector2(x, 450 + sin(x * 0.01 + 3.0) * 18.0 + sin(x * 0.04 + 1.0) * 6.0))
	front.append(Vector2(720, 560))
	front.append(Vector2(-20, 560))
	draw_colored_polygon(front, Color("5da24a"))
	for i in 26:
		var x := _rng.randf_range(0, 640)
		_tree(Vector2(x, 400 + sin(x * 0.012 + 1.0) * 22.0 + _rng.randf_range(0, 16)), _rng.randf_range(0.7, 1.1))


func _tree(p: Vector2, s: float) -> void:
	draw_rect(Rect2(p.x - 2 * s, p.y - 4 * s, 4 * s, 10 * s), Color("5b3d22"))
	draw_circle(p + Vector2(0, -12 * s), 11 * s, Color("2f7a3a"))
	draw_circle(p + Vector2(-5 * s, -15 * s), 7 * s, Color("3f9147"))
	draw_circle(p + Vector2(5 * s, -10 * s), 6 * s, Color("2a6b34"))


func _road() -> void:
	var pts := PackedVector2Array([Vector2(440, 560), Vector2(455, 505), Vector2(520, 478), Vector2(600, 452), Vector2(670, 428), Vector2(720, 380), Vector2(745, 330)])
	draw_polyline(pts, Color("b48a4c"), 44.0, true)
	draw_polyline(pts, Color("e2c17f"), 36.0, true)
	for i in 10:
		var t := i / 9.0
		var p := pts[0].lerp(pts[pts.size() - 1], t)
		draw_circle(p + Vector2(sin(i * 3.0) * 8.0, 0), 2.0, Color("c39c5c"))


func _wall() -> void:
	# каменная стена между башнями
	var y := 392.0
	draw_rect(Rect2(170, y, 120, 40), Color("9a9488"))
	draw_rect(Rect2(170, y, 120, 8), Color("b3ad9f"))
	for i in 8:
		draw_rect(Rect2(170 + i * 15.0, y - 9, 10, 10), Color("8a8478"))
	# флаг на башне
	var flag_base := Vector2(160, 255)
	draw_line(flag_base, flag_base + Vector2(0, -44), Color("3d2614"), 3.0)
	var wave := sin(_t * 4.0) * 5.0
	draw_colored_polygon(PackedVector2Array([flag_base + Vector2(0, -44), flag_base + Vector2(34, -38 + wave), flag_base + Vector2(0, -24)]), Color("2f6fc0"))


func _skeleton(pos: Vector2, s: float, phase: float) -> void:
	var bob := sin(_t * 6.0 + phase) * 1.5 * s
	var bone := Color("efe6cf")
	var shade := Color("b7ab8c")
	Art.ellipse(self, pos + Vector2(0, 8 * s), 9 * s, 3 * s, Color(0, 0, 0, 0.3))
	var step := sin(_t * 6.0 + phase) * 4.0 * s
	draw_line(pos + Vector2(-3 * s, 0), pos + Vector2(-3 * s - step, 8 * s), shade, 2.0 * s)
	draw_line(pos + Vector2(3 * s, 0), pos + Vector2(3 * s + step, 8 * s), shade, 2.0 * s)
	draw_rect(Rect2(pos.x - 5 * s, pos.y - 12 * s + bob, 10 * s, 13 * s), shade)
	for k in 3:
		draw_line(pos + Vector2(-5 * s, (-9 + k * 4) * s + bob), pos + Vector2(5 * s, (-9 + k * 4) * s + bob), bone, 1.6 * s)
	draw_circle(pos + Vector2(0, -18 * s + bob), 6.5 * s, bone)
	draw_circle(pos + Vector2(-2.4 * s, -19 * s + bob), 1.7 * s, Color("2a1a30"))
	draw_circle(pos + Vector2(2.4 * s, -19 * s + bob), 1.7 * s, Color("2a1a30"))
	draw_circle(pos + Vector2(0, -19 * s + bob), 0.9 * s, Color(0.4, 1.0, 0.5, 0.9))
	draw_line(pos + Vector2(-5 * s, -8 * s + bob), pos + Vector2(-13 * s, -16 * s + bob), Color("a0a8b8"), 2.2 * s)
	draw_line(pos + Vector2(5 * s, -8 * s + bob), pos + Vector2(12 * s, -2 * s + bob), shade, 1.8 * s)


func _arrows() -> void:
	for i in 4:
		var f := fposmod(_t * 0.42 + i * 0.25, 1.0)
		var start := Vector2(180, 300)
		var end := Vector2(700 + i * 30, 450)
		var p := start.lerp(end, f) + Vector2(0, -sin(f * PI) * 170.0)
		var ahead := start.lerp(end, minf(1.0, f + 0.02)) + Vector2(0, -sin(minf(1.0, f + 0.02) * PI) * 170.0)
		var d := (ahead - p).normalized()
		draw_line(p - d * 16.0, p + d * 4.0, Color("4b2f14"), 2.4)
		Art.tri(self, p + d * 4.0 + Vector2(-d.y, d.x) * 3.5, p + d * 11.0, p + d * 4.0 - Vector2(-d.y, d.x) * 3.5, Color("d6dae0"))
		draw_line(p - d * 16.0, p - d * 26.0, Color(1, 1, 1, 0.25), 1.6)


func _fire() -> void:
	# дыхание дракона: дракон висит в (570, 272), пасть примерно в (636, 203)
	var mouth := Vector2(638, 203)
	var dir := (Vector2(820, 372) - mouth).normalized()
	var side := Vector2(-dir.y, dir.x)
	for i in 22:
		var u := fposmod(_t * 1.3 + i / 22.0, 1.0)
		var p := mouth + dir * u * 210.0 + side * sin(i * 7.0 + _t * 9.0) * u * 16.0
		var col := Color("fff2a0").lerp(Color("e0401a"), u)
		col.a = 0.9 * (1.0 - u * 0.8)
		draw_circle(p, 4.0 + u * 15.0, col)


func _bats() -> void:
	for i in 6:
		var p := Vector2(120 + i * 58.0 + sin(_t * 0.6 + i) * 30.0, 80 + (i % 3) * 38.0 + sin(_t * 1.4 + i * 2.0) * 10.0)
		var flap := sin(_t * 14.0 + i) * 6.0
		var c := Color(0.12, 0.1, 0.2, 0.9)
		Art.tri(self, p, p + Vector2(-16, -flap - 2), p + Vector2(-5, 4), c)
		Art.tri(self, p, p + Vector2(16, -flap - 2), p + Vector2(5, 4), c)
		draw_circle(p + Vector2(0, 1), 3.4, c)


func _foreground() -> void:
	# тёмные кусты слева внизу
	for i in 9:
		var x := -10.0 + i * 52.0
		var y := 520.0 + sin(i * 1.7) * 14.0
		draw_circle(Vector2(x, y), 54.0, Color("1f5a38"))
		draw_circle(Vector2(x + 10, y - 16), 34.0, Color("2a7444"))
		draw_circle(Vector2(x - 14, y - 22), 22.0, Color("348a50"))
	for i in 6:
		var x := 640.0 + i * 70.0
		draw_circle(Vector2(x, 548.0 + sin(i) * 6.0), 44.0, Color("2a7444"))
		draw_circle(Vector2(x + 8, 534.0), 28.0, Color("348a50"))


func _vignette() -> void:
	var dark := Color(0.04, 0.03, 0.08, 0.6)
	var clear := Color(0.04, 0.03, 0.08, 0.0)
	var w := Defs.VIEW.x
	var h := Defs.VIEW.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(170, 0), Vector2(170, h), Vector2(0, h)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(w - 170, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - 170, h)]), PackedColorArray([clear, dark, dark, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 120), Vector2(0, 120)]), PackedColorArray([dark, dark, clear, clear]))


# ---------- логотип ----------

func _shadowed(text: String, pos_y: float, font_size: int, fill: Color, glow: Color) -> void:
	var font := Ui.font()
	var origin := Vector2(0, pos_y)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, Defs.VIEW.x, font_size, 16, Color("2a1406"))
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, Defs.VIEW.x, font_size, 7, glow)
	draw_string(font, origin + Vector2(0, 4), text, HORIZONTAL_ALIGNMENT_CENTER, Defs.VIEW.x, font_size, fill.darkened(0.35))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, Defs.VIEW.x, font_size, fill)


func _logo() -> void:
	var cx := Defs.VIEW.x * 0.5
	# сияние за названием
	for i in 5:
		Art.ellipse(self, Vector2(cx, 120), 330.0 - i * 40.0, 88.0 - i * 10.0, Color(1.0, 0.85, 0.4, 0.05))
	# эмблема: золотой щит с камнем
	var e := Vector2(cx, 38)
	draw_circle(e, 27.0, Color("2a1406"))
	draw_circle(e, 23.0, Color("e6b84e"))
	draw_circle(e, 18.0, Color("8a6420"))
	Art.tri(self, e + Vector2(-11, -2), e + Vector2(0, -16), e + Vector2(11, -2), Color("7fe0ff"))
	Art.tri(self, e + Vector2(-11, -2), e + Vector2(0, 16), e + Vector2(11, -2), Color("2a9fd5"))
	Art.tri(self, e + Vector2(-11, -2), e + Vector2(0, -16), e + Vector2(0, -2), Color("d6f6ff"))
	# название из Defs.GAME_TITLE: первое слово сверху мельче, остальное снизу крупнее
	var words := Defs.GAME_TITLE.split(" ", false, 1)
	if words.size() > 1:
		_shadowed(words[0], 112.0, 58, Color("ffd24a"), Color("a0561a"))
		_shadowed(words[1], 184.0, 80, Color("ff9a3a"), Color("8a2a10"))
	else:
		_shadowed(words[0], 175.0, 84, Color("ffd24a"), Color("a0561a"))
	var font := Ui.font()
	var ribbon_w := 380.0
	draw_rect(Rect2(cx - ribbon_w * 0.5, 203, ribbon_w, 26), Color("2a1406"))
	draw_rect(Rect2(cx - ribbon_w * 0.5 + 3, 206, ribbon_w - 6, 20), Color("6b2c1f"))
	draw_string(font, Vector2(cx - ribbon_w * 0.5, 221), Defs.GAME_SUBTITLE, HORIZONTAL_ALIGNMENT_CENTER, ribbon_w, 14, Color("f6e7c1"))
