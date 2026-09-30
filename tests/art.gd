extends Node
## Проверка «розетки» для настоящих картинок (ArtPack): образцовые кадры подхватываются, без них игра рисует кодом.
## Запуск: godot --headless --path . res://tests/art.tscn
## Печатает «ОК» или «ОШИБКА: ...». Код выхода 1, если что-то не прошло.

const DIR := "user://art_test/"

var failures := 0
var step := 0
var main: Node
var enemy: Enemy
var tower: Tower


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.persist = false
	_remove_dir(DIR)
	# 1. без картинок: всё null, рисуем кодом
	ArtPack.reset(DIR)
	check(ArtPack.texture("icons/heart.png") == null, "нет файла: картинка null")
	check(not ArtPack.has_frames("enemies/grunt"), "нет папки: анимаций нет")
	# 2. образцовые кадры
	_make("enemies/grunt/walk_00.png", 64, 80, Color("e04040"))
	_make("enemies/grunt/walk_01.png", 64, 80, Color("40e040"))
	_make("enemies/grunt/walk_02.png", 64, 80, Color("4040e0"))
	_make("enemies/grunt/walk_03.png", 64, 80, Color("e0e040"))
	_make("enemies/grunt/attack_00.png", 64, 80, Color("e040e0"))
	_make("enemies/grunt/attack_01.png", 64, 80, Color("40e0e0"))
	_write("enemies/grunt/meta.json", '{"fps": 8, "scale": 0.5}')
	_make("heroes/edrik/idle_00.png", 80, 100, Color("4a78c4"))
	_make("heroes/edrik/walk_00.png", 80, 100, Color("6a98e4"))
	_make("heroes/edrik/attack_00.png", 80, 100, Color("ffffff"))
	_make("heroes/edrik/portrait.png", 128, 128, Color("4a78c4"))
	_make("soldiers/knight/idle_00.png", 60, 70, Color("8899aa"))
	_make("towers/archer_1.png", 120, 160, Color("8a5a32"))
	_make("towers/archer_1_shoot/shoot_00.png", 120, 160, Color("c08a52"))
	_make("towers/archer_1_shoot/shoot_01.png", 120, 160, Color("ffd080"))
	_make("levels/orcs/background.png", 1920, 1080, Color("5a9a45"))
	_make("icons/heart.png", 64, 64, Color("e0483c"))
	_make("projectiles/arrow.png", 40, 8, Color("4b2f14"))
	ArtPack.reset(DIR)
	var sf := ArtPack.frames("enemies/grunt")
	check(sf != null and sf.get_frame_count("walk") == 4 and sf.get_frame_count("attack") == 2, "кадры walk и attack собраны из файлов")
	check(is_equal_approx(sf.get_animation_speed("walk"), 8.0), "скорость анимации берётся из meta.json")
	check(sf.get_animation_loop("walk") and not sf.get_animation_loop("attack"), "walk повторяется, attack играет один раз")
	var rep := ArtPack.report()
	check("enemies/grunt/walk_*.png" in rep["found"] and "enemies/raider/walk_*.png" in rep["missing"], "отчёт различает найденное и отсутствующее")
	check("icons/heart.png" in rep["found"] and "campaign/map.png" in rep["missing"], "отчёт видит значки и карту")
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main._spawn("grunt")
	main._spawn("raider")
	enemy = Game.enemies()[0]
	check(enemy._sprite != null, "у орка-воина появился настоящий спрайт")
	check(Game.enemies()[1]._sprite == null, "у наездника картинок нет, он рисуется кодом")
	check(main.heroes[0]._sprite != null, "у Эдрика есть настоящий спрайт")
	check(main.heroes[1]._sprite == null, "у Тарна картинок нет, он рисуется кодом")
	Game.gold = 1000
	var pad: Pad = main.pads[1]
	main.build_tower(pad, "archer")
	tower = pad.tower
	check(tower._art != null and tower._shoot_art != null, "у башни есть картинка и анимация выстрела")
	main.upgrade_tower(pad)
	check(tower._art == null, "для 2 уровня картинки нет: башня снова рисуется кодом")
	check(ArtPack.texture("levels/orcs/background.png") != null, "фон уровня берётся из файла")
	Engine.time_scale = 1.0


func check(ok: bool, what: String) -> void:
	print(("ОК: " if ok else "ОШИБКА: ") + what)
	if not ok:
		failures += 1


func _process(_delta: float) -> void:
	match step:
		0:
			enemy.face = -1.0
			step = 1
		1:
			check(enemy._sprite.flip_h, "спрайт разворачивается вслед за врагом")
			check(enemy._sprite.animation == "walk", "идущий враг играет walk")
			enemy._fighting = true
			step = 2
		2:
			check(enemy._sprite.animation == "attack", "дерущийся враг играет attack")
			enemy._fighting = false
			enemy.stun = 2.0
			step = 3
		3:
			check(not enemy._sprite.is_playing(), "оглушённый враг замирает")
			# без картинок всё как раньше
			ArtPack.reset(DIR + "пусто/")
			main._spawn("grunt")
			var fresh: Enemy = Game.enemies()[Game.enemies().size() - 1]
			check(fresh._sprite == null, "без картинок враг рисуется кодом")
			_remove_dir(DIR)
			ArtPack.reset()
			print("Итог: %s" % ("всё прошло" if failures == 0 else "провалено проверок: %d" % failures))
			get_tree().quit(1 if failures > 0 else 0)


func _make(rel: String, w: int, h: int, color: Color) -> void:
	var path := DIR + rel
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


func _write(rel: String, text: String) -> void:
	var path := DIR + rel
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)


func _remove_dir(path: String) -> void:
	var access := DirAccess.open(path)
	if access == null:
		return
	for sub in access.get_directories():
		_remove_dir(path + sub + "/")
	for file in access.get_files():
		access.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
