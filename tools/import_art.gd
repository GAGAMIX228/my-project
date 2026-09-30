extends SceneTree
## Импорт картинок из готовых наборов в assets/art: режет листы анимаций на кадры, обрезает по контуру,
## пишет meta.json. Запуск из папки проекта:
##   godot --headless --path . --script tools/import_art.gd
## Исходные наборы нужно распаковать в raw_art (эта папка не попадает в репозиторий):
##   raw_art/tiny_swords_free   содержимое «Tiny Swords (Free Pack)»
##   raw_art/tiny_swords_full   содержимое «Tiny Swords (Update 010)»
##   raw_art/tiny_rpg           папка «Characters(100x100 split)» из Tiny RPG Character Asset Pack
## Новый набор: добавь строки в таблицы ниже (кто из наших персонажей какой картинкой рисуется).

const OUT := "res://assets/art/"
const SWORDS := "res://raw_art/tiny_swords_free/Units/"
const RPG := "res://raw_art/tiny_rpg/"

## Кадры: [анимация, файл относительно набора, ширина ячейки, сколько кадров, ряд в листе].
## Tiny RPG Orc: ячейки 100×100, одна строка на анимацию.
const ORC := [["idle", "Orc/Orc/Orc_Idle.png", 100, 6, 0], ["walk", "Orc/Orc/Orc_Walk.png", 100, 8, 0], ["attack", "Orc/Orc/Orc_Attack01.png", 100, 6, 0], ["die", "Orc/Orc/Orc_Death.png", 100, 4, 0]]
const SOLDIER := [["idle", "Soldier/Soldier/Soldier_Idle.png", 100, 6, 0], ["walk", "Soldier/Soldier/Soldier_Walk.png", 100, 8, 0], ["attack", "Soldier/Soldier/Soldier_Attack01.png", 100, 6, 0], ["die", "Soldier/Soldier/Soldier_Death.png", 100, 4, 0]]


## Tiny Swords: ячейки 192×192. color: Blue, Red, Yellow, Purple, Black.
func _swords_warrior(color: String) -> Array:
	var d := "%s Units/Warrior/" % color
	return [["idle", d + "Warrior_Idle.png", 192, 8, 0], ["walk", d + "Warrior_Run.png", 192, 6, 0], ["attack", d + "Warrior_Attack1.png", 192, 4, 0]]


func _swords_archer(color: String) -> Array:
	var d := "%s Units/Archer/" % color
	return [["idle", d + "Archer_Idle.png", 192, 6, 0], ["walk", d + "Archer_Run.png", 192, 4, 0], ["attack", d + "Archer_Shoot.png", 192, 8, 0]]


func _swords_monk(color: String) -> Array:
	var d := "%s Units/Monk/" % color
	return [["idle", d + "Idle.png", 192, 6, 0], ["walk", d + "Run.png", 192, 4, 0], ["attack", d + "Heal.png", 192, 11, 0]]


func _swords_pawn(color: String) -> Array:
	var d := "%s Units/Pawn/" % color
	return [["idle", d + "Pawn_Idle.png", 192, 8, 0], ["walk", d + "Pawn_Run.png", 192, 6, 0], ["attack", d + "Pawn_Interact Axe.png", 192, 6, 0]]


func _initialize() -> void:
	_write("style.json", '{"pixel_art": true}')
	# враги: Tiny RPG Orc для орков (размер и оттенок делают разных), Tiny Swords для остальных
	_unit("enemies/grunt", RPG, ORC, 1.6)
	_unit("enemies/raider", RPG, ORC, 1.4, 13, [0.85, 0.95, 1.1])
	_unit("enemies/shield", SWORDS, _swords_warrior("Black"), 0.42)
	_unit("enemies/berserk", RPG, ORC, 1.7, 12, [1.15, 0.8, 0.75])
	_unit("enemies/shaman", SWORDS, _swords_monk("Red"), 0.42)
	_unit("enemies/warlock", SWORDS, _swords_monk("Black"), 0.42)
	_unit("enemies/archer", SWORDS, _swords_archer("Red"), 0.42)
	_unit("enemies/brute", RPG, ORC, 2.4, 8, [0.8, 0.95, 0.8])
	_unit("enemies/banner", SWORDS, _swords_pawn("Red"), 0.42)
	_unit("enemies/troll", RPG, ORC, 2.5, 8, [0.75, 0.85, 1.05])
	_unit("enemies/chief", RPG, ORC, 3.3, 8, [0.85, 0.95, 0.85])
	# герои (драконов пока нет, они рисуются кодом)
	_unit("heroes/edrik", SWORDS, _swords_warrior("Blue"), 0.46)
	_unit("heroes/grum", SWORDS, _swords_warrior("Yellow"), 0.56)
	_unit("heroes/kara", RPG, ORC, 1.7, 12, [1.15, 0.8, 0.75])
	_unit("heroes/tarn", SWORDS, _swords_archer("Blue"), 0.46)
	_unit("heroes/xol", SWORDS, _swords_monk("Blue"), 0.46)
	_unit("heroes/ishta", SWORDS, _swords_monk("Purple"), 0.46)
	for id in ["edrik", "grum", "kara", "tarn", "xol", "ishta"]:
		_portrait("heroes/" + id)
	# рыцари казармы
	_unit("soldiers/knight", RPG, SOLDIER, 1.6)
	_towers()
	print("Импорт закончен: ", ProjectSettings.globalize_path(OUT))
	quit()


func _path(rel: String) -> String:
	var p := ProjectSettings.globalize_path(OUT + rel)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir() if rel.contains(".") else p)
	return p


func _write(rel: String, text: String) -> void:
	var f := FileAccess.open(_path(rel), FileAccess.WRITE)
	f.store_string(text)


## Один персонаж: нарезаем кадры, обрезаем по общему контуру (ноги внизу по центру), пишем кадры и meta.json.
func _unit(dir: String, root: String, sheets: Array, scale_value: float, fps := 9, tint := [1, 1, 1]) -> void:
	var frames := {}
	var box := Rect2i()
	var first := true
	for spec: Array in sheets:
		var img := Image.load_from_file(ProjectSettings.globalize_path(root + spec[1]))
		if img == null:
			push_error("нет файла: %s" % (root + spec[1]))
			return
		var cell_w: int = spec[2]
		var cell_h := img.get_height() if spec[4] == 0 and img.get_height() <= cell_w * 2 else cell_w
		var list: Array = []
		for i in int(spec[3]):
			var cell := img.get_region(Rect2i(i * cell_w, int(spec[4]) * cell_h, cell_w, cell_h))
			list.append(cell)
			var used := cell.get_used_rect()
			if used.size.x > 0 and spec[0] != "die":
				box = used if first else box.merge(used)
				first = false
		frames[spec[0]] = list
	var cx := box.position.x + box.size.x / 2
	var half := maxi(cx - box.position.x, box.end.x - cx)
	var crop := Rect2i(cx - half, box.position.y, half * 2, box.size.y)
	for anim: String in frames:
		for i in (frames[anim] as Array).size():
			var cell: Image = frames[anim][i]
			# для гибели рамка может быть шире: дополняем прозрачным
			var out := Image.create(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
			out.blit_rect(cell, crop, Vector2i.ZERO)
			out.save_png(_path("%s/%s_%02d.png" % [dir, anim, i]))
	_write(dir + "/meta.json", JSON.stringify({"fps": fps, "scale": scale_value, "tint": tint}))


## Портрет для круглой кнопки: верх первого кадра стояния (голова и плечи), увеличенный в целое число раз, 128×128.
func _portrait(dir: String) -> void:
	var src := Image.load_from_file(_path(dir + "/idle_00.png"))
	var side := mini(src.get_width(), src.get_height())
	var top := src.get_region(Rect2i((src.get_width() - side) / 2, 0, side, side))
	var k := maxi(1, 128 / side)
	top.resize(side * k, side * k, Image.INTERPOLATE_NEAREST)
	var out := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	out.blit_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i((128 - top.get_width()) / 2, (128 - top.get_height()) / 2))
	out.save_png(_path(dir + "/portrait.png"))


## Башни: здания людей из Tiny Swords. Уровни отличаются цветом: 1 синий, 2 фиолетовый, 3 золотой (жёлтый).
## Картинка обрезается по контуру (низ здания стоит на площадке). Масштаб у каждой башни свой (towers/meta.json).
func _towers() -> void:
	var colors := ["Blue", "Purple", "Yellow"]
	var buildings := {"archer": "Archery", "barracks": "Barracks", "mage": "Monastery", "mortar": "Tower"}
	var scales := {"archer": 0.42, "barracks": 0.42, "mage": 0.36, "mortar": 0.45}
	for kind: String in buildings:
		for level in 3:
			var src := Image.load_from_file(ProjectSettings.globalize_path("res://raw_art/tiny_swords_free/Buildings/%s Buildings/%s.png" % [colors[level], buildings[kind]]))
			var used := src.get_used_rect()
			var img := src.get_region(used)
			img.save_png(_path("towers/%s_%d.png" % [kind, level + 1]))
			if level == 0:
				_icon("icons/tower_%s.png" % kind, img)
	_write("towers/meta.json", JSON.stringify({"scales": scales}))


## Значок для кнопки: картинка, вписанная в квадрат 128×128 без искажений.
func _icon(rel: String, src: Image) -> void:
	var k := minf(124.0 / src.get_width(), 124.0 / src.get_height())
	var img := src.duplicate()
	img.resize(maxi(1, int(src.get_width() * k)), maxi(1, int(src.get_height() * k)), Image.INTERPOLATE_NEAREST)
	var out := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((128 - img.get_width()) / 2, 126 - img.get_height()))
	out.save_png(_path(rel))
