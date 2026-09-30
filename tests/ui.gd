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


func _process(_delta: float) -> void:
	frames += 1
	if frames < 3:
		return
	frames = 0
	match step:
		0:
			# экран сборки
			prep = (load("res://scenes/prep.tscn") as PackedScene).instantiate()
			add_child(prep)
			step = 1
		1:
			check(Game.loadout_heroes.size() == 2 and Game.loadout_spells.size() == 3, "по умолчанию выбрано 2 героя и 3 заклинания")
			prep._toggle(Game.loadout_heroes, "kara", 2)
			check(",".join(Game.loadout_heroes) == "tarn,kara", "третий герой вытесняет самого раннего выбранного: %s" % str(Game.loadout_heroes))
			prep._toggle(Game.loadout_heroes, "kara", 2)
			check(prep._go.disabled, "с одним героем кнопка «В бой» выключена")
			prep._toggle(Game.loadout_heroes, "edrik", 2)
			check(not prep._go.disabled, "с двумя героями кнопка «В бой» включена")
			prep.queue_free()
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
			check(main.heroes[0].selected and not main.heroes[1].selected, "сначала выбран первый герой")
			_click(main.heroes[1].position)
			step = 4
		4:
			check(main.hero_index == 1 and main.heroes[1].selected, "нажатие на героя выбирает его")
			_click(Vector2(600, 480))
			step = 5
		5:
			check(main.heroes[1].post.distance_to(Vector2(600, 480)) < 1.0, "нажатие на землю отправляет выбранного героя")
			check(main.heroes[0].post.distance_to(Vector2(600, 480)) > 50.0, "второй герой остался на месте")
			_key(KEY_1)
			step = 6
		6:
			check(main.spellbook.armed == "knights", "клавиша 1 выбирает заклинание призыва")
			_click(Vector2(600, 480))  # это не дорога
			step = 7
		7:
			check(main.spellbook.armed == "knights", "нажатие мимо дороги не применяет призыв")
			var before := get_tree().get_nodes_in_group("soldiers").size()
			_click(Vector2(300, 400))
			var after := get_tree().get_nodes_in_group("soldiers").size()
			check(after == before + 2, "нажатие на дорогу призывает двух рыцарей (%d -> %d)" % [before, after])
			check(main.spellbook.armed == "" and not main.spellbook.is_ready("knights"), "заклинание ушло на перезарядку")
			_key(KEY_1)
			step = 8
		8:
			check(main.spellbook.armed == "", "пока заклинание перезаряжается, его нельзя выбрать")
			_key(KEY_2)
			step = 9
		9:
			check(not main.spellbook.is_ready("quake"), "землетрясение срабатывает сразу, без выбора места")
			_key(KEY_3)
			step = 10
		10:
			check(main.spellbook.armed == "wave", "клавиша 3 выбирает волну глубин")
			_click(Vector2(0, 0), MOUSE_BUTTON_RIGHT)
			step = 11
		11:
			check(main.spellbook.armed == "", "правая кнопка отменяет выбор")
			check(main.heroes[0].use_ability() == false, "способность без врагов не срабатывает")
			check(main.heroes[0].ability_cd == 0.0, "и перезарядку не запускает")
			# бой: две башни и герои против первой волны
			main.build_tower(main.pads[1], "archer")
			main.build_tower(main.pads[4], "mage")
			main.start_wave()
			Engine.time_scale = 8.0
			step = 12
		12:
			if main.queue.is_empty() and Game.enemies().is_empty():
				Engine.time_scale = 1.0
				check(Game.kills >= 3, "герои и башни убивают орков первой волны (убито %d из 6, жизни %d)" % [Game.kills, Game.lives])
				step = 13
		13:
			var hero: Hero = main.heroes[0]
			hero.take_damage(9999.0)
			check(hero.dead and hero.respawn > 0.0, "погибший герой ждёт возрождения")
			step = 14
		14:
			Engine.time_scale = 30.0
			if not main.heroes[0].dead:
				Engine.time_scale = 1.0
				check(main.heroes[0].hp == main.heroes[0].max_hp, "герой возродился со здоровьем")
				step = 15
		15:
			print("Итог: %s" % ("всё прошло" if failures == 0 else "провалено проверок: %d" % failures))
			get_tree().quit(1 if failures > 0 else 0)
