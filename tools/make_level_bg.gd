extends SceneTree
## Собирает пиксельный фон первого уровня (assets/art/levels/orcs/background.png, 1920×1080) из картинок Tiny Swords:
## трава, грунтовая дорога по Defs.PATH, деревья, кусты, камни, лагерь и ворота.
## Запуск: godot --headless --path . --script tools/make_level_bg.gd
## Нужна распакованная папка raw_art/tiny_swords_free (см. tools/import_art.gd).

const W := 1920
const H := 1080
const SRC := "res://raw_art/tiny_swords_free/Terrain/"
const FULL := "res://raw_art/tiny_swords_full/"
const OUT := "res://assets/art/levels/orcs/background.png"

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 7
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	_grass(img)
	_road(img)
	_scenery(img)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("Фон готов: ", ProjectSettings.globalize_path(OUT))
	quit()


func _load(rel: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(rel))
	if image == null:
		push_error("нет файла: " + rel)
	return image


func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## Трава: бесшовная плитка из набора и мягкие пятна светлее и темнее.
func _grass(img: Image) -> void:
	var sheet := _load(SRC + "Tileset/Tilemap_color3.png")
	var tile := sheet.get_region(Rect2i(64, 64, 64, 64))
	for ty in range(0, H, 64):
		for tx in range(0, W, 64):
			img.blit_rect(tile, Rect2i(0, 0, 64, 64), Vector2i(tx, ty))
	# пятна: блоки 32×32 чуть светлее или темнее
	for by in range(0, H, 32):
		for bx in range(0, W, 32):
			var n := _hash(bx / 32, by / 32)
			if n > 0.82 or n < 0.14:
				var k := 0.10 if n > 0.5 else -0.10
				for y in range(by, mini(by + 32, H)):
					for x in range(bx, mini(bx + 32, W)):
						var c := img.get_pixel(x, y)
						img.set_pixel(x, y, c.lightened(k) if k > 0.0 else c.darkened(-k))


## Расстояние (в пикселях фона) от точки до ломаной дороги.
func _road_dist(p: Vector2, pts: Array) -> float:
	var best := 1e9
	for i in pts.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		best = minf(best, q.distance_to(p))
	return best


## Дорога: грунт с крапинками, неровная тёмная кромка и тень на траве.
func _road(img: Image) -> void:
	var pts: Array = []
	for p: Vector2 in Defs.PATH:
		pts.append(p * 2.0)
	var dirt := [Color("cfae72"), Color("c6a367"), Color("d8b97f"), Color("bd985d")]
	var half := 54.0
	for y in H:
		for x in W:
			var p := Vector2(x, y)
			var d := _road_dist(p, pts)
			if d > half + 10.0:
				continue
			var wobble := (_hash(x / 6, y / 6) - 0.5) * 7.0
			var e := d + wobble
			if e < half - 7.0:
				var n := _hash(x / 2, y / 2)
				var c: Color = dirt[0]
				if n > 0.9:
					c = dirt[2]
				elif n > 0.7:
					c = dirt[1]
				elif n < 0.08:
					c = dirt[3]
				img.set_pixel(x, y, c)
			elif e < half - 2.0:
				img.set_pixel(x, y, Color("8f6e3f"))   # кромка
			elif e < half + 2.0:
				img.set_pixel(x, y, Color("3b2a1a"))   # контур
			elif e < half + 7.0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, c.darkened(0.25))   # тень на траве
	# камешки на дороге
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	for i in 140:
		var at := _rng.randf() * total
		var pos := Vector2.ZERO
		var left := at
		for j in pts.size() - 1:
			var seg: float = (pts[j] as Vector2).distance_to(pts[j + 1])
			if left <= seg:
				pos = (pts[j] as Vector2).lerp(pts[j + 1], left / seg)
				break
			left -= seg
		pos += Vector2(_rng.randf_range(-36, 36), _rng.randf_range(-36, 36))
		if _road_dist(pos, pts) < half - 14.0:
			_stone(img, Vector2i(pos))


func _stone(img: Image, at: Vector2i) -> void:
	for dy in 3:
		for dx in 5:
			if at.x + dx >= 0 and at.y + dy >= 0 and at.x + dx < W and at.y + dy < H:
				img.set_pixel(at.x + dx, at.y + dy, Color("9a8a78") if dy < 2 else Color("6e6152"))


## Деревья, кусты, камни, лагерь и ворота. Предметы рисуются сверху вниз.
func _scenery(img: Image) -> void:
	var pts: Array = []
	for p: Vector2 in Defs.PATH:
		pts.append(p * 2.0)
	var trees: Array = []
	for n in [1, 2, 3, 4]:
		var sheet := _load(SRC + "Resources/Wood/Trees/Tree%d.png" % n)
		trees.append(sheet.get_region(Rect2i(0, 0, 192, sheet.get_height())))
	var bushes: Array = []
	for n in [1, 2, 3, 4]:
		var sheet := _load(SRC + "Decorations/Bushes/Bushe%d.png" % n)
		bushes.append(sheet.get_region(Rect2i(0, 0, 128, 128)))
	var rocks: Array = []
	for n in [1, 2, 3, 4]:
		rocks.append(_load(SRC + "Decorations/Rocks/Rock%d.png" % n))
	var items: Array = []   # [y, картинка, куда]
	var placed: Array = []
	# [картинки, сколько, минимальное расстояние между предметами, высота кроны (пикселей фона)]
	var specs := [[trees, 30, 100.0, 170.0], [bushes, 55, 44.0, 40.0], [rocks, 24, 34.0, 20.0]]
	for spec: Array in specs:
		var count: int = spec[1]
		var tries := 0
		var done := 0
		while done < count and tries < count * 60:
			tries += 1
			var p := Vector2(_rng.randf_range(20, W - 20), _rng.randf_range(80, H - 20))
			if _road_dist(p, pts) < 54.0 + float(spec[2]):
				continue
			if p.x > 1780 and p.y > 680:
				continue   # у ворот
			if p.x < 360 and p.y < 230:
				continue   # у лагеря
			# крона нависает над землёй выше основания: проверяем несколько точек вдоль неё
			var blocked := false
			var crown: float = spec[3]
			for k in 5:
				var q := p - Vector2(0, crown * k / 4.0)
				if _road_dist(q, pts) < 54.0 + 26.0:
					blocked = true
				for pad: Vector2 in Defs.PADS:
					if (pad * 2.0).distance_to(q) < 74.0:
						blocked = true
			if blocked:
				continue
			var crowded := false
			for q: Vector2 in placed:
				if q.distance_to(p) < float(spec[2]) * 1.3:
					crowded = true
			if crowded:
				continue
			placed.append(p)
			var list: Array = spec[0]
			items.append([p.y, list[_rng.randi() % list.size()], p])
			done += 1
	# лагерь орков (вместо палаток дома гоблинов) и ворота
	var house := _load(FULL + "Factions/Goblins/Buildings/Wood_House/Goblin_House.png")
	items.append([120.0, house, Vector2(110, 130)])
	items.append([110.0, house, Vector2(260, 110)])
	var tower := _load("res://raw_art/tiny_swords_free/Buildings/Blue Buildings/Tower.png")
	tower.resize(tower.get_width() / 2, tower.get_height() / 2, Image.INTERPOLATE_NEAREST)
	items.append([760.0, tower, Vector2(1856, 760)])
	items.append([920.0, tower, Vector2(1856, 920)])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for item: Array in items:
		var src: Image = item[1]
		var at: Vector2 = item[2]
		# низ картинки ставим в точку (тень у ног)
		var dest := Vector2i(int(at.x) - src.get_width() / 2, int(at.y) - src.get_height() + 22)
		img.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), dest)
