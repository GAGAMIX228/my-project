extends Node
## Проверка интерфейса без окна: экран сборки, переход в бой, выбор героя, приказы, заклинания клавишами.
## Запуск: godot --headless --path . res://tests/ui.tscn
## Печатает «ОК» или «ОШИБКА: ...» по каждой проверке и в конце итог. Код выхода 1, если что-то не прошло.

var failures := 0
var step := 0
var frames := 0
var prep: Node
var main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func check(ok: bool, what: String) -> void:
	print(("ОК: " if ok else "ОШИБКА: ") + what)
	if not ok:
		failures += 1


func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	get_viewport().push_input(move, true)
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = button
	ev.pressed = true
	get_viewport().push_input(ev, true)


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	get_viewport().push_input(ev, true)


## Ячейки сохранения, сложности и открытие уровней.
func _test_saves() -> void:
	Game.persist = true
	Game.delete_slot(3)
	check(not Game.slot_info(3)["exists"], "пустая ячейка определяется")
	Game.new_slot(3, "veteran")
	Game.level_stars["orcs"] = 2
	Game.save_progress()
	var info := Game.slot_info(3)
	check(info["exists"] and info["difficulty"] == "veteran" and info["stars"] == 2, "ячейка помнит сложность и звёзды")
	Game.level_stars = {}
	Game.difficulty = "fighter"
	check(Game.load_slot(3) and Game.difficulty == "veteran" and Game.level_stars.get("orcs", 0) == 2, "загрузка возвращает сложность и звёзды")
	check(Game.level_unlocked(0) and Game.level_unlocked(1) and not Game.level_unlocked(2), "звезда на уровне открывает следующий")
	Game.delete_slot(3)
	check(not Game.slot_info(3)["exists"], "удалённая ячейка пуста")
	Game.persist = false
	Game.slot = 0
	Game.level_stars = {}
	check(not Game.level_unlocked(1), "без звёзд второй уровень закрыт")
	Game.difficulty = "novice"
	Game.reset()
	check(Game.gold == 260 and is_equal_approx(Game.count_mult(), 0.8), "Новичок: больше золота, врагов меньше")
	Game.difficulty = "veteran"
	Game.reset()
	check(Game.gold == 200 and is_equal_approx(Game.count_mult(), 1.4), "Ветеран: меньше золота, врагов больше")
	Game.difficulty = "fighter"
	Game.reset()
	check(Game.gold == 220 and is_equal_approx(Game.count_mult(), 1.0), "Боец: стандартные значения")


## Заставка: создание игры в пустой ячейке.
func _test_title() -> void:
	var title: Control = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(title)
	title.entered.disconnect(title._go_campaign)
	Game.persist = true
	Game.delete_slot(2)
	title.show_slots()
	check(title._modal != null, "«Начать» открывает окно выбора ячейки")
	title.show_difficulty(2)
	title.create_game(2, "novice")
	check(Game.slot == 2 and Game.difficulty == "novice" and Game.slot_info(2)["exists"], "новая игра создаёт ячейку со сложностью")
	Game.delete_slot(2)
	Game.persist = false
	Game.difficulty = "fighter"
	title.queue_free()


func _process(_delta: float) -> void:
	frames += 1
	if frames < 3:
		return
	frames = 0
	match step:
		0:
			_test_saves()
			# карта кампании и панель сборки
			Game.persist = false
			Game.loadout_heroes.assign(["edrik", "tarn"])
			Game.loadout_spells.assign(["knights", "meteors", "frost"])
			prep = (load("res://scenes/campaign.tscn") as PackedScene).instantiate()
			add_child(prep)
			step = 1
		1:
			var panel: LoadoutPanel = prep._panel
			check(Game.loadout_heroes.size() == 2 and Game.loadout_spells.size() == 3, "по умолчанию выбрано 2 героя и 3 заклинания")
			check(panel.active["hero"] == 0, "сначала выбран первый слот героя")
			panel.assign("hero", "kara")
			check(",".join(Game.loadout_heroes) == "kara,tarn", "карточка занимает выбранный слот: %s" % str(Game.loadout_heroes))
			check(panel.active["hero"] == 1, "после выбора активным становится следующий слот")
			panel.select_slot("hero", 0)
			panel.assign("hero", "kara")
			check(",".join(Game.loadout_heroes) == "kara,tarn", "та же карточка в том же слоте ничего не меняет")
			panel.select_slot("hero", 1)
			panel.assign("hero", "kara")
			check(",".join(Game.loadout_heroes) == "tarn,kara", "карточка из другого слота меняется местами: %s" % str(Game.loadout_heroes))
			panel.select_slot("hero", 1)
			panel.assign("hero", "zefira")
			check(",".join(Game.loadout_heroes) == "tarn,zefira", "можно заменить конкретного героя: %s" % str(Game.loadout_heroes))
			panel.select_slot("spell", 2)
			panel.assign("spell", "fireball")
			check(",".join(Game.loadout_spells) == "knights,meteors,fireball", "можно заменить конкретное заклинание: %s" % str(Game.loadout_spells))
			panel.assign("tower", "mage")
			check(",".join(Game.loadout_towers) == "archer,barracks,mage,mortar", "башни пока не меняются")
			panel.show_tab("tower")
			check(panel.kind == "tower", "вкладка башен открывается")
			check(not prep._go.disabled and prep.selected == "orcs", "уровень орков выбран и доступен")
			prep._select("ogres")
			check(prep._go.disabled, "закрытый уровень нельзя запустить")
			prep.toggle_tab("spell")
			check(prep._panel.visible and prep._panel.kind == "spell", "кнопка «Заклинания» открывает раздел заклинаний")
			prep.toggle_tab("spell")
			check(not prep._panel.visible, "повторное нажатие закрывает раздел")
			prep.queue_free()
			_test_title()
			step = 2
		2:
			Game.loadout_heroes.assign(["edrik", "ishta"])
			Game.loadout_spells.assign(["knights", "quake", "wave"])
			main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
			add_child(main)
			step = 3
		3:
			check(main.heroes.size() == 2, "в бою два героя")
			check(main.heroes[0].hid == "edrik" and main.heroes[1].hid == "ishta", "герои те, что выбраны на экране сборки")
			check(",".join(main.spellbook.spells) == "knights,quake,wave", "заклинания те, что выбраны")
			check(main.hero_index == -1 and not main.heroes[0].selected, "в начале боя ни один герой не выбран")
			_key(KEY_SPACE)
			step = 4
		4:
			check(main.hero_index == 0 and main.heroes[0].selected, "первый пробел выбирает первого героя")
			_key(KEY_SPACE)
			step = 5
		5:
			check(main.hero_index == 1 and main.heroes[1].selected and not main.heroes[0].selected, "второй пробел выбирает второго героя")
			_click(Vector2(600, 480))
			step = 6
		6:
			check(main.heroes[1].post.distance_to(Vector2(600, 480)) < 1.0, "нажатие на землю отправляет выбранного героя")
			check(main.hero_index == -1 and not main.heroes[1].selected, "после приказа герой отвязывается")
			_click(Vector2(200, 500))
			step = 7
		7:
			check(main.heroes[1].post.distance_to(Vector2(600, 480)) < 1.0, "второй клик по земле героя уже не двигает")
			check(main.heroes[0].post.distance_to(Vector2(200, 500)) > 50.0, "и первого героя тоже")
			_click(main.heroes[0].position)
			step = 8
		8:
			check(main.hero_index == 0, "нажатие на героя на карте выбирает его")
			_key(KEY_ESCAPE)
			step = 9
		9:
			check(main.hero_index == -1, "Esc снимает выбор героя")
			_key(KEY_1)
			step = 10
		10:
			check(main.spellbook.armed == "knights", "клавиша 1 выбирает заклинание призыва")
			_click(Vector2(600, 480))  # это не дорога
			step = 11
		11:
			check(main.spellbook.armed == "knights", "нажатие мимо дороги не применяет призыв")
			var before := get_tree().get_nodes_in_group("soldiers").size()
			_click(Vector2(300, 400))
			var after := get_tree().get_nodes_in_group("soldiers").size()
			check(after == before + 2, "нажатие на дорогу призывает двух рыцарей (%d -> %d)" % [before, after])
			check(main.spellbook.armed == "" and not main.spellbook.is_ready("knights"), "заклинание ушло на перезарядку")
			_key(KEY_1)
			step = 12
		12:
			check(main.spellbook.armed == "", "пока заклинание перезаряжается, его нельзя выбрать")
			_key(KEY_2)
			step = 13
		13:
			check(not main.spellbook.is_ready("quake"), "землетрясение срабатывает сразу, без выбора места")
			_key(KEY_3)
			step = 14
		14:
			check(main.spellbook.armed == "wave", "клавиша 3 выбирает волну глубин")
			_click(Vector2(0, 0), MOUSE_BUTTON_RIGHT)
			step = 15
		15:
			check(main.spellbook.armed == "", "правая кнопка отменяет выбор")
			check(main.heroes[0].use_ability() == false, "способность без врагов не срабатывает")
			check(main.heroes[0].ability_cd == 0.0, "и перезарядку не запускает")
			# бой: две башни и герои против первой волны
			main.build_tower(main.pads[1], "archer")
			main.build_tower(main.pads[4], "mage")
			main.start_wave()
			Engine.time_scale = 8.0
			step = 16
		16:
			if main.queue.is_empty() and Game.enemies().is_empty():
				Engine.time_scale = 1.0
				check(Game.kills >= 3, "герои и башни убивают орков первой волны (убито %d из 6, жизни %d)" % [Game.kills, Game.lives])
				step = 17
		17:
			var hero: Hero = main.heroes[0]
			hero.take_damage(9999.0)
			check(hero.dead and hero.respawn > 0.0, "погибший герой ждёт возрождения")
			step = 18
		18:
			Engine.time_scale = 30.0
			if not main.heroes[0].dead:
				Engine.time_scale = 1.0
				check(main.heroes[0].hp == main.heroes[0].max_hp, "герой возродился со здоровьем")
				step = 19
		19:
			print("Итог: %s" % ("всё прошло" if failures == 0 else "провалено проверок: %d" % failures))
			get_tree().quit(1 if failures > 0 else 0)
