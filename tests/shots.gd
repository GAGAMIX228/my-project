extends Node
## Скриншоты для проверки глазами. Нужен виртуальный экран (см. CLAUDE.md, раздел 14).
## Запуск: ... res://tests/shots.tscn -- art (образцовые картинки на поле), template (шаблоны для художника в assets/art/_templates), enemies (все 12 врагов), title (заставка и окна), battle, campaign (карта и вкладки), menu (круговое меню башен), gallery (все герои)
## Куда сохранять: переменная окружения SHOTS_DIR, по умолчанию папка user://shots.

var main: Node
var mode := "battle"
var t := 0.0
var step := 0
var dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	Game.persist = false
	dir = OS.get_environment("SHOTS_DIR")
	if dir == "":
		dir = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var heroes := OS.get_environment("SHOTS_HEROES")   # например ashgar,morven
	if heroes != "":
		Game.loadout_heroes.assign(Array(heroes.split(",")))
	var art_root := OS.get_environment("ART_ROOT")   # папка с картинками для скриншота, например user://ts_demo
	if art_root != "":
		ArtPack.reset(art_root)
	if mode == "template":
		_make_templates()
		return
	if mode == "art":
		_make_sample_art()
	var scene := "res://scenes/main.tscn"
	if mode == "campaign":
		scene = "res://scenes/campaign.tscn"
	elif mode == "title":
		scene = "res://scenes/title.tscn"
		Game.persist = true
		Game.new_slot(1, "fighter")
		Game.level_stars["orcs"] = 3
		Game.save_progress()
	main = (load(scene) as PackedScene).instantiate()
	add_child(main)


## Все типы врагов в двух рядах: настоящие Enemy (как в бою), у каждого своя короткая дорога и скорость 0.
class EnemyGallery extends Node2D:
	func _ready() -> void:
		var types: Array = Defs.ENEMIES.keys()
		for i in types.size():
			var road := Path2D.new()
			road.curve = Curve2D.new()
			road.curve.add_point(Vector2.ZERO)
			road.curve.add_point(Vector2(3000, 0))
			road.position = Vector2(85 + (i % 6) * 158, 150 + (i / 6) * 220)
			add_child(road)
			var enemy := Enemy.new()
			enemy.setup(types[i])
			road.add_child(enemy)
			enemy.speed = 0.0
			enemy.face = 1.0
			if types[i] == "troll":
				enemy.hp = enemy.max_hp * 0.5
			var label := Label.new()
			label.text = Defs.ENEMIES[types[i]]["name"]
			label.position = Vector2(-70, 40)
			label.custom_minimum_size.x = 140
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_override("font", Ui.font())
			road.add_child(label)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 540), Color("7dba58"))


## Образцовые картинки (цветные фигуры с отметкой «ног») в user://art_test, чтобы проверить якоря и размеры.
func _make_sample_art() -> void:
	var dir := "user://art_test/"
	ArtPack.reset(dir)
	var specs := [
		["enemies/grunt/walk_00.png", 64, 90, Color("d94a3a")], ["enemies/grunt/walk_01.png", 64, 90, Color("e8604a")],
		["heroes/edrik/idle_00.png", 80, 120, Color("4a78c4")],
		["towers/archer_1.png", 120, 170, Color("8a5a32")],
		["towers/mage_1.png", 110, 220, Color("6a54b8")],
	]
	for spec: Array in specs:
		var path: String = dir + spec[0]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var img := Image.create(spec[1], spec[2], false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.fill_rect(Rect2i(4, 4, spec[1] - 8, spec[2] - 8), spec[3])
		img.fill_rect(Rect2i(0, spec[2] - 6, spec[1], 6), Color.WHITE)
		img.save_png(path)
	ArtPack.reset(dir)


## Шаблоны для художника: 1920×1080 с дорогой, площадками и зонами, которые закроет интерфейс.
var _template_frames := 0
var _template_views: Array = []


func _make_templates() -> void:
	var specs := [["level_orcs_guides.png", GuideLevel.new()], ["campaign_map_guides.png", GuideMap.new()], ["title_guides.png", GuideTitle.new()]]
	for spec: Array in specs:
		var view := SubViewport.new()
		view.size = Vector2i(1920, 1080)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var guide: Node2D = spec[1]
		guide.scale = Vector2(2, 2)
		view.add_child(guide)
		add_child(view)
		_template_views.append([view, spec[0]])


func _save_templates() -> void:
	var out := ProjectSettings.globalize_path("res://assets/art/_templates/")
	DirAccess.make_dir_recursive_absolute(out)
	for item: Array in _template_views:
		var img: Image = (item[0] as SubViewport).get_texture().get_image()
		img.save_png(out + item[1])
		print("шаблон ", out + item[1])
	get_tree().quit()


## Общее для шаблонов: подпись с обводкой и красная зона интерфейса.
class GuideBase extends Node2D:
	func label(pos: Vector2, text: String, size := 12, color := Color.WHITE) -> void:
		var font := Ui.font()
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.85))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	func ui_zone(rect: Rect2, text: String) -> void:
		draw_rect(rect, Color(0.9, 0.15, 0.1, 0.22))
		draw_rect(rect, Color(0.9, 0.15, 0.1, 0.8), false, 1.5)
		label(rect.position + Vector2(5, 14), text, 11, Color("ffd0c8"))


class GuideLevel extends GuideBase:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 540), Color("46703e"))
		draw_polyline(PackedVector2Array(Defs.PATH), Color("a98a52"), 58.0, true)
		draw_polyline(PackedVector2Array(Defs.PATH), Color("d6b67a"), 50.0, true)
		for p in Defs.PATH:
			draw_circle(p, 29.0, Color("a98a52"))
			draw_circle(p, 25.0, Color("d6b67a"))
		draw_polyline(PackedVector2Array(Defs.PATH), Color(1, 1, 1, 0.5), 1.5, true)
		for i in Defs.PADS.size():
			var pad: Vector2 = Defs.PADS[i]
			Art.ellipse(self, pad, 27, 12, Color(0.75, 0.72, 0.65))
			draw_rect(Rect2(pad.x - 24, pad.y - 58, 48, 58), Color(1, 1, 0.6, 0.35), false, 1.5)
			label(pad + Vector2(-5, 4), str(i + 1), 12, Color("2a1a0c"))
		draw_rect(Rect2(0, 0, 180, 110), Color(0.6, 0.3, 0.2, 0.25))
		label(Vector2(8, 100), "лагерь орков (декор)", 11)
		label(Vector2(930, 372), "ворота", 11)
		draw_rect(Rect2(912, 350, 48, 130), Color(0.6, 0.6, 0.9, 0.25))
		label(Defs.PATH[0] + Vector2(40, -34), "ВХОД ОРКОВ (слева за кадром)", 12, Color("ffe27a"))
		label(Vector2(820, 410), "ВЫХОД: отсюда отнимаются жизни", 11, Color("ffe27a"))
		ui_zone(Rect2(0, 0, 660, 80), "интерфейс: жизни, золото, волна, строка о волне")
		ui_zone(Rect2(730, 0, 230, 58), "кнопки: скорость, пауза, выход")
		ui_zone(Rect2(8, 462, 420, 78), "герои и заклинания")
		ui_zone(Rect2(780, 490, 172, 50), "кнопка волны")
		label(Vector2(220, 520), "Шаблон: дорога и площадки стоят строго на этих местах. Рисуй фон 1920x1080 поверх.", 11, Color("ffe27a"))


class GuideMap extends GuideBase:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 540), Color("707780"))
		var prev := Vector2.ZERO
		for i in Defs.LEVELS.size():
			var l: Dictionary = Defs.LEVELS[i]
			var c: Vector2 = l["pos"]
			if i > 0:
				draw_line(prev, c, Color(1, 1, 1, 0.5), 2.0)
			prev = c
			draw_circle(c, 24.0, Color("2a1406"))
			draw_circle(c, 20.0, Color("e6b84e"))
			label(c + Vector2(-4, 5), str(i + 1), 14, Color("2a1406"))
			label(c + Vector2(-40, 42), "%s (%s)" % [l["race"], l["biome"]], 11)
		ui_zone(Rect2(0, 0, 200, 60), "стрелка назад, звёзды")
		ui_zone(Rect2(262, 0, 470, 66), "плашка выбранного уровня")
		ui_zone(Rect2(0, 440, 960, 100), "нижняя панель: Герои, Башни, Заклинания")
		label(Vector2(250, 430), "Карта 1920x1080. Точки уровней стоят на этих местах, порядок по номерам.", 11, Color("ffe27a"))


class GuideTitle extends GuideBase:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 540), Color("405878"))
		ui_zone(Rect2(240, 10, 480, 235), "логотип и название (можно положить готовый logo.png)")
		ui_zone(Rect2(380, 362, 200, 130), "кнопки НАЧАТЬ и ВЫЙТИ")
		ui_zone(Rect2(0, 0, 100, 80), "настройки")
		label(Vector2(230, 520), "Заставка 1920x1080: главное действие оставь по бокам, центр внизу занят кнопками.", 11, Color("ffe27a"))


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/" + shot_name + ".png")
	print("снимок ", shot_name)


func _process(delta: float) -> void:
	t += delta
	if mode == "template":
		_template_frames += 1
		if _template_frames == 4:
			_save_templates()
		return
	if mode == "enemies":
		if step == 0 and t > 0.2:
			var gal := EnemyGallery.new()
			main.add_child(gal)
			main.get_node("Hud").visible = false
			main.get_node("Background").visible = false
			step = 1
			t = 0.0
		elif step == 1 and t > 0.6:
			_shot("enemies")
			get_tree().quit()
		return
	if mode == "gallery":
		if step == 0 and t > 0.3:
			for i in Defs.HERO_ORDER.size():
				var hero := Hero.new()
				hero.setup(Defs.HERO_ORDER[i], Vector2(90 + i * 100, 270))
				hero.face = 1.0 if i % 2 == 0 else -1.0
				hero.selected = i == 3
				main.units_root.add_child(hero)
				if i == 2:
					hero.rage = 5.0
				if i == 1:
					hero.hp = 100.0
			step = 1
			t = 0.0
		elif step == 1 and t > 0.5:
			_shot("gallery")
			get_tree().quit()
		return
	if mode == "title":
		if step == 0 and t > 0.6:
			_shot("title")
			main.entered.disconnect(main._go_campaign)
			main.show_slots()
			step = 1
			t = 0.0
		elif step == 1 and t > 0.3:
			_shot("slots")
			main.show_difficulty(2)
			step = 2
			t = 0.0
		elif step == 2 and t > 0.3:
			_shot("difficulty")
			main.show_settings()
			step = 3
			t = 0.0
		elif step == 3 and t > 0.3:
			_shot("settings")
			Game.delete_slot(1)
			get_tree().quit()
		return
	if mode == "campaign":
		if step == 0 and t > 0.5:
			Game.level_stars["orcs"] = 2
			main._select("orcs")
			_shot("campaign_map")
			main.toggle_tab("hero")
			step = 1
			t = 0.0
		elif step == 1 and t > 0.3:
			_shot("campaign_heroes")
			main._panel.assign("hero", "kara")
			main.toggle_tab("tower")
			step = 2
			t = 0.0
		elif step == 2 and t > 0.3:
			_shot("campaign_towers")
			main.toggle_tab("spell")
			step = 3
			t = 0.0
		elif step == 3 and t > 0.3:
			_shot("campaign_spells")
			get_tree().quit()
		return
	if mode == "menu":
		if step == 0 and t > 0.3:
			main.build_tower(main.pads[1], "archer")
			main._select(main.pads[2])
			step = 1
			t = 0.0
		elif step == 1 and t > 0.4:
			_shot("menu_build")
			main._select(main.pads[1])
			step = 2
			t = 0.0
		elif step == 2 and t > 0.4:
			_shot("menu_upgrade")
			main._select(main.pads[6])
			step = 3
			t = 0.0
		elif step == 3 and t > 0.4:
			_shot("menu_top")
			get_tree().quit()
		return
	var g := get_node("/root/Game")
	if step == 0 and t > 0.3:
		g.gold = 3000
		main.build_tower(main.pads[2], "barracks")
		main.build_tower(main.pads[1], "archer")
		main.build_tower(main.pads[4], "mage")
		main.upgrade_tower(main.pads[2])
		main.start_wave()
		Engine.time_scale = 3.0
		step = 1
		t = 0.0
	elif step == 1 and t > 3.0:
		Engine.time_scale = 1.0
		main.select_hero(1)
		main.heroes[1].set_post(Vector2(380, 330))
		main.select_hero(0)
		main.spellbook.arm("frost")
		t = 0.0
		step = 2
	elif step == 2 and t > 1.5:
		# мышь виртуального экрана стоит в углу, поэтому круг-подсказку проверяем отдельно
		main.use_ability(0)
		main.spellbook.cast("meteors", Vector2(300, 400))
		_shot("h01_battle")
		t = 0.0
		step = 3
	elif step == 3 and t > 0.5:
		_shot("h02_effects")
		print("убито: ", g.kills, ", жизни: ", g.lives)
		get_tree().quit()
