class_name MapArt
extends Control
## Нарисованная кодом карта кампании: области (лес, болота, холмы, горы, пустыня, вулканы, море, кладбище)
## с деревьями, горами, волнами, надгробиями и замком некроманта. Области получаются «пятнами» вокруг опорных точек.
## Рисуется один раз. Позже сюда можно поставить готовую картинку карты.

## Опорные точки областей: [место, область]. Каждая точка карты принадлежит ближайшей (с небольшим искажением шумом).
const SEEDS := [
	[Vector2(40, 250), "forest"], [Vector2(120, 330), "forest"], [Vector2(130, 170), "forest"], [Vector2(240, 260), "forest"], [Vector2(290, 330), "forest"],
	[Vector2(190, 430), "swamp"], [Vector2(110, 490), "swamp"], [Vector2(260, 500), "swamp"],
	[Vector2(340, 170), "hills"], [Vector2(400, 270), "hills"], [Vector2(300, 90), "hills"],
	[Vector2(470, 100), "snow"], [Vector2(560, 130), "snow"], [Vector2(560, 230), "snow"], [Vector2(480, 190), "snow"],
	[Vector2(620, 350), "desert"], [Vector2(560, 440), "desert"], [Vector2(660, 290), "desert"],
	[Vector2(720, 190), "volcano"], [Vector2(790, 110), "volcano"], [Vector2(690, 90), "volcano"],
	[Vector2(790, 450), "sea"], [Vector2(880, 400), "sea"], [Vector2(700, 520), "sea"], [Vector2(920, 500), "sea"],
	[Vector2(890, 230), "grave"], [Vector2(920, 130), "grave"], [Vector2(850, 300), "grave"],
]
const COLORS := {
	"forest": Color("5d9b47"), "swamp": Color("66793f"), "hills": Color("98b95c"), "snow": Color("dbe6ee"),
	"desert": Color("e3c47d"), "volcano": Color("70473c"), "sea": Color("2b9cb9"), "grave": Color("5c5169"),
}

var _warp := FastNoiseLite.new()
var _shade := FastNoiseLite.new()
var _tex: ImageTexture
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warp.frequency = 0.011
	_warp.seed = 4
	_shade.frequency = 0.045
	_shade.seed = 9
	if ArtPack.texture("campaign/map.png") == null:
		_build_texture()


## Область в точке карты.
func biome_at(p: Vector2) -> String:
	return _nearest(p)[0]


## Ищет две ближайшие опорные точки: [область, расстояние до ближайшей, разность до второй, область второй].
func _nearest(p: Vector2) -> Array:
	var q := p + Vector2(_warp.get_noise_2d(p.x, p.y), _warp.get_noise_2d(p.x + 500.0, p.y + 300.0)) * 52.0
	var d1 := 1e9
	var d2 := 1e9
	var b1 := "forest"
	var b2 := "forest"
	for s: Array in SEEDS:
		var d := q.distance_to(s[0])
		if d < d1:
			d2 = d1
			b2 = b1
			d1 = d
			b1 = s[1]
		elif d < d2 and s[1] != b1:
			d2 = d
			b2 = s[1]
	return [b1, d1, d2 - d1, b2]


func _build_texture() -> void:
	var w := 480
	var h := 270
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var p := Vector2(x * 2.0, y * 2.0)
			var info := _nearest(p)
			var biome: String = info[0]
			var col: Color = COLORS[biome]
			var n := _shade.get_noise_2d(p.x, p.y)
			col = col.lightened(n * 0.10) if n > 0.0 else col.darkened(-n * 0.14)
			var gap: float = info[2]
			if gap < 9.0:
				var other: String = info[3]
				if biome == "sea" or other == "sea":
					col = Color("efe1a8").lerp(col, gap / 9.0) if biome != "sea" else Color("c9ecf0").lerp(col, gap / 9.0)
				else:
					col = col.darkened(0.12 * (1.0 - gap / 9.0))
			img.set_pixel(x, y, col)
	_tex = ImageTexture.create_from_image(img)


# ---------- рисование ----------

func _draw() -> void:
	# готовая карта (assets/art/campaign/map.png), если она есть
	var picture := ArtPack.texture("campaign/map.png")
	if picture != null:
		draw_texture_rect(picture, Rect2(Vector2.ZERO, Defs.VIEW), false)
		return
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, Defs.VIEW), false)
	_rng.seed = 12
	var items: Array = []   # [y, функция рисования]: рисуем сверху вниз, чтобы дальние предметы были под ближними
	_scatter(items, "forest", 70, func(p, s): _tree(Color("2f7a3a"), Color("3f9147"), p, s))
	_scatter(items, "swamp", 14, _dead_tree)
	_scatter(items, "swamp", 10, _puddle)
	_scatter(items, "swamp", 14, func(p, s): _tree(Color("59703a"), Color("6b8447"), p, s))
	_scatter(items, "hills", 14, _mound)
	_scatter(items, "hills", 6, _house)
	_scatter(items, "hills", 12, func(p, s): _tree(Color("4f8f3f"), Color("66a84c"), p, s))
	_scatter(items, "snow", 16, _mountain)
	_scatter(items, "snow", 22, _fir)
	_scatter(items, "desert", 10, _dune)
	_scatter(items, "desert", 9, _cactus)
	_scatter(items, "volcano", 5, _volcano)
	_scatter(items, "volcano", 14, _rock)
	_scatter(items, "sea", 60, _wave)
	_scatter(items, "grave", 24, _tomb)
	_scatter(items, "grave", 9, _dead_tree)
	_scatter(items, "grave", 5, _fog)
	items.append([420.0, _island.bind(Vector2(775, 422))])
	items.append([190.0, _necro_castle.bind(Vector2(900, 190))])
	items.append([262.0, _camp.bind(Vector2(56, 246))])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		it[1].call()
	_clouds()


func _scatter(items: Array, biome: String, count: int, fn: Callable) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 40:
		tries += 1
		var p := Vector2(_rng.randf_range(8.0, 952.0), _rng.randf_range(74.0, 458.0))
		if biome_at(p) != biome or _near_node(p, 40.0):
			continue
		var s := _rng.randf_range(0.75, 1.2)
		items.append([p.y, func(): fn.call(p, s)])
		placed += 1


func _near_node(p: Vector2, r: float) -> bool:
	for l: Dictionary in Defs.LEVELS:
		if (l["pos"] as Vector2).distance_to(p) < r:
			return true
	return false


func _tree(dark: Color, light: Color, p: Vector2, s: float) -> void:
	draw_rect(Rect2(p.x - 2 * s, p.y - 3 * s, 4 * s, 9 * s), Color("5b3d22"))
	draw_circle(p + Vector2(0, -11 * s), 10.5 * s, dark)
	draw_circle(p + Vector2(-4 * s, -14 * s), 6.5 * s, light)
	draw_circle(p + Vector2(5 * s, -9 * s), 5.5 * s, dark.darkened(0.12))


func _dead_tree(p: Vector2, s: float) -> void:
	var c := Color("3a2c22")
	draw_line(p, p + Vector2(0, -22 * s), c, 3.0 * s)
	draw_line(p + Vector2(0, -12 * s), p + Vector2(-9 * s, -22 * s), c, 2.0 * s)
	draw_line(p + Vector2(0, -16 * s), p + Vector2(8 * s, -26 * s), c, 2.0 * s)
	draw_line(p + Vector2(-5 * s, -17 * s), p + Vector2(-10 * s, -16 * s), c, 1.6 * s)


func _puddle(p: Vector2, s: float) -> void:
	Art.ellipse(self, p, 15 * s, 6 * s, Color("3f6f6a"))
	Art.ellipse(self, p + Vector2(-2, -1), 10 * s, 3.5 * s, Color("5b9a90"))


func _mound(p: Vector2, s: float) -> void:
	Art.ellipse(self, p + Vector2(0, 3), 22 * s, 8 * s, Color(0.3, 0.4, 0.15, 0.35))
	Art.ellipse(self, p, 21 * s, 10 * s, Color("a9c96c"))
	Art.ellipse(self, p + Vector2(-4, -3), 11 * s, 4 * s, Color("c6df8b"))


func _house(p: Vector2, s: float) -> void:
	draw_rect(Rect2(p.x - 7 * s, p.y - 8 * s, 14 * s, 10 * s), Color("efe0b8"))
	Art.tri(self, p + Vector2(-9, -8) * s, p + Vector2(0, -17 * s), p + Vector2(9, -8) * s, Color("b8442e"))
	draw_rect(Rect2(p.x - 2 * s, p.y - 4 * s, 4 * s, 6 * s), Color("5b3d22"))


func _mountain(p: Vector2, s: float) -> void:
	var w := 26.0 * s
	var h := 40.0 * s
	Art.tri(self, p + Vector2(-w, 0), p + Vector2(0, -h), p + Vector2(w, 0), Color("8b98aa"))
	Art.tri(self, p + Vector2(0, 0), p + Vector2(0, -h), p + Vector2(w, 0), Color("6f7d92"))
	Art.tri(self, p + Vector2(-w * 0.36, -h * 0.64), p + Vector2(0, -h), p + Vector2(w * 0.36, -h * 0.64), Color("f4f8fb"))


func _fir(p: Vector2, s: float) -> void:
	draw_rect(Rect2(p.x - 1.5 * s, p.y - 2, 3 * s, 7 * s), Color("4a3422"))
	for i in 3:
		var y := p.y - 4 * s - i * 8 * s
		var w := (13.0 - i * 3.0) * s
		Art.tri(self, Vector2(p.x - w, y), Vector2(p.x, y - 13 * s), Vector2(p.x + w, y), Color("2d6a4f"))
		Art.tri(self, Vector2(p.x - w * 0.5, y - 5 * s), Vector2(p.x, y - 13 * s), Vector2(p.x + w * 0.5, y - 5 * s), Color("eef5f8"))


func _dune(p: Vector2, s: float) -> void:
	Art.ellipse(self, p, 26 * s, 8 * s, Color("d2a95c"))
	Art.ellipse(self, p + Vector2(-4, -2), 22 * s, 6 * s, Color("ecd596"))


func _cactus(p: Vector2, s: float) -> void:
	var c := Color("4f8a45")
	draw_line(p, p + Vector2(0, -16 * s), c, 4.0 * s)
	draw_line(p + Vector2(0, -8 * s), p + Vector2(-6 * s, -8 * s), c, 3.0 * s)
	draw_line(p + Vector2(-6 * s, -8 * s), p + Vector2(-6 * s, -14 * s), c, 3.0 * s)
	draw_line(p + Vector2(0, -6 * s), p + Vector2(6 * s, -6 * s), c, 3.0 * s)
	draw_line(p + Vector2(6 * s, -6 * s), p + Vector2(6 * s, -11 * s), c, 3.0 * s)


func _volcano(p: Vector2, s: float) -> void:
	var w := 34.0 * s
	var h := 42.0 * s
	Art.tri(self, p + Vector2(-w, 0), p + Vector2(-w * 0.25, -h), p + Vector2(w * 0.25, -h), Color("4a2e2a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(-w * 0.25, -h), p + Vector2(w * 0.25, -h), p + Vector2(w, 0)]), Color("4a2e2a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.25, -h), p + Vector2(w * 0.25, -h), p + Vector2(w * 0.12, -h - 6 * s), p + Vector2(-w * 0.12, -h - 6 * s)]), Color("ff7a2a"))
	draw_line(p + Vector2(0, -h), p + Vector2(-6 * s, -h * 0.4), Color("ff9a3a"), 3.0 * s)
	draw_circle(p + Vector2(4 * s, -h - 16 * s), 7 * s, Color(0.3, 0.26, 0.26, 0.6))
	draw_circle(p + Vector2(-2 * s, -h - 26 * s), 9 * s, Color(0.3, 0.26, 0.26, 0.4))


func _rock(p: Vector2, s: float) -> void:
	Art.ellipse(self, p, 9 * s, 5 * s, Color("3d2925"))
	Art.ellipse(self, p + Vector2(-2, -2), 6 * s, 3 * s, Color("5d413a"))


func _wave(p: Vector2, s: float) -> void:
	draw_arc(p, 7 * s, PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.35), 1.6)
	draw_arc(p + Vector2(10 * s, 2), 5 * s, PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.25), 1.4)


func _tomb(p: Vector2, s: float) -> void:
	Art.ellipse(self, p + Vector2(0, 2), 8 * s, 3 * s, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(p.x - 5 * s, p.y - 12 * s, 10 * s, 13 * s), Color("9a9aa8"))
	draw_circle(p + Vector2(0, -12 * s), 5 * s, Color("9a9aa8"))
	draw_line(p + Vector2(0, -14 * s), p + Vector2(0, -7 * s), Color("56566a"), 1.6)
	draw_line(p + Vector2(-2.5 * s, -11 * s), p + Vector2(2.5 * s, -11 * s), Color("56566a"), 1.6)


func _fog(p: Vector2, s: float) -> void:
	for i in 4:
		draw_circle(p + Vector2(i * 12 - 18, sin(i) * 4) * s, (16 - i * 2) * s, Color(0.75, 1.0, 0.8, 0.12))


func _island(p: Vector2) -> void:
	Art.ellipse(self, p + Vector2(0, 4), 50, 20, Color("c9ecf0"))
	Art.ellipse(self, p, 44, 16, Color("efe1a8"))
	Art.ellipse(self, p + Vector2(0, -2), 34, 11, Color("f7ecc0"))
	draw_line(p + Vector2(28, 2), p + Vector2(31, -22), Color("6b4a2a"), 3.0)
	for a in [-0.4, 0.3, 1.0, 2.2, 2.9]:
		draw_line(p + Vector2(31, -22), p + Vector2(31, -22) + Vector2(cos(a), sin(a) - 0.3) * 13.0, Color("3f8a45"), 3.0)


func _camp(p: Vector2) -> void:
	for x in [-16.0, 14.0]:
		Art.tri(self, p + Vector2(x - 12, 6), p + Vector2(x, -18), p + Vector2(x + 12, 6), Color("8a5a3a"))
		Art.tri(self, p + Vector2(x - 3, 6), p + Vector2(x, -18), p + Vector2(x + 3, 6), Color("3d2614"))


func _necro_castle(p: Vector2) -> void:
	var dark := Color("2b2444")
	for i in 4:
		draw_circle(p + Vector2(0, -40), 50.0 + i * 16.0, Color(0.4, 0.95, 0.5, 0.05))
	Art.ellipse(self, p + Vector2(0, 6), 62, 14, Color("3a3a5e"))
	draw_rect(Rect2(p.x - 30, p.y - 36, 60, 42), dark)
	for tx in [-34.0, 34.0, 0.0]:
		var h := 52.0 if tx != 0.0 else 70.0
		draw_rect(Rect2(p.x + tx - 9, p.y - h, 18, h + 4), dark.darkened(0.15))
		Art.tri(self, Vector2(p.x + tx - 13, p.y - h), Vector2(p.x + tx, p.y - h - 26), Vector2(p.x + tx + 13, p.y - h), Color("3b2f5c"))
		draw_circle(Vector2(p.x + tx, p.y - h + 14), 2.6, Color("7dff95"))
	draw_rect(Rect2(p.x - 6, p.y - 20, 12, 26), Color(0.45, 1.0, 0.55, 0.85))


## Мягкие облака по краям, как будто карта висит в воздухе.
func _clouds() -> void:
	_rng.seed = 33
	for i in 46:
		var side := _rng.randi() % 4
		var p := Vector2(_rng.randf_range(0, 960), _rng.randf_range(0, 540))
		match side:
			0: p.y = _rng.randf_range(-20, 26)
			1: p.x = _rng.randf_range(-20, 26)
			2: p.x = _rng.randf_range(934, 980)
			3: p.y = _rng.randf_range(520, 560)
		Art.ellipse(self, p, _rng.randf_range(50, 110), _rng.randf_range(24, 50), Color(0.86, 0.9, 0.95, 0.30))
