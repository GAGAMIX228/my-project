extends Node
## Проверка врагов: здоровье не растёт, число зависит от сложности, тролль лечится, знаменосец ускоряет, лучник стреляет.
## Запуск: godot --headless --path . res://tests/enemies.tscn
## Печатает «ОК» или «ОШИБКА: ...». Код выхода 1, если что-то не прошло.

var failures := 0
var step := 0
var t := 0.0
var main: Node
var troll: Enemy
var far_grunt: Enemy
var near_grunt: Enemy
var archer: Enemy
var min_hero_hp := 1e9


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.persist = false
	# здоровье и число врагов не должны зависеть от волны и сложности
	for level in Defs.DIFFICULTY_ORDER:
		Game.difficulty = level
		var e := Enemy.new()
		e.setup("grunt")
		check(is_equal_approx(e.max_hp, 82.0), "здоровье орка-воина 82 на сложности %s" % level)
		e.free()
	Game.difficulty = "novice"
	check(Game.group_count(10) == 8 and Game.group_count(1) == 1, "Новичок: врагов меньше (10 → 8), вождь один")
	Game.difficulty = "fighter"
	check(Game.group_count(10) == 10, "Боец: число врагов как в таблице")
	Game.difficulty = "veteran"
	check(Game.group_count(10) == 14, "Ветеран: врагов больше (10 → 14)")
	Game.difficulty = "fighter"
	for id: String in Defs.ENEMIES.keys():
		var d: Dictionary = Defs.ENEMIES[id]
		check(d.has("name") and d.has("hp") and d.has("speed"), "у врага %s есть название, здоровье и скорость" % id)
	for wave_index in Defs.WAVES.size():
		for group in Defs.WAVES[wave_index]:
			if not Defs.ENEMIES.has(group[0]):
				check(false, "в волне %d неизвестный враг %s" % [wave_index + 1, group[0]])
	var kinds := {}
	for wave in Defs.WAVES:
		var types := {}
		for group in wave:
			types[group[0]] = true
			kinds[group[0]] = true
		check(wave.size() == 1 or types.size() >= 2, "в волне есть разные воины")
	check(kinds.size() >= 11, "в волнах встречается не меньше 11 разных типов врагов (%d)" % kinds.size())
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Engine.time_scale = 6.0


func check(ok: bool, what: String) -> void:
	print(("ОК: " if ok else "ОШИБКА: ") + what)
	if not ok:
		failures += 1


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			# тролль: ранен, его не бьют
			main._spawn("troll")
			troll = Game.enemies()[0]
			troll.hp = 100.0
			troll.speed = 0.0
			troll.progress = 1700.0
			# двое орков: один рядом со знаменосцем, другой далеко
			main._spawn("banner")
			main._spawn("grunt")
			main._spawn("grunt")
			var list := Game.enemies()
			list[1].speed = 0.0
			list[1].progress = 1500.0
			near_grunt = list[2]
			near_grunt.speed = 0.0
			near_grunt.progress = 1520.0
			far_grunt = list[3]
			far_grunt.speed = 0.0
			far_grunt.progress = 80.0
			t = 0.0
			step = 1
		1:
			if t > 5.0:
				check(troll.hp > 100.0 + 15.0, "тролль лечится, если его не бьют (здоровье %d)" % int(troll.hp))
				check(near_grunt.buffed, "орк рядом со знаменосцем ускорен")
				check(not far_grunt.buffed, "орк вдали от знаменосца не ускорен")
				troll.take_damage(10.0, "phys")
				t = 0.0
				step = 2
		2:
			if t > 1.0:
				check(not troll.healing, "после удара тролль не лечится")
				for e in Game.enemies():
					e.queue_free()
				step = 3
				t = 0.0
		3:
			if t > 0.3:
				# лучник против героя
				main._spawn("archer")
				archer = Game.enemies()[0]
				archer.progress = 120.0
				min_hero_hp = 1e9
				t = 0.0
				step = 4
		4:
			var hurt := false
			for h: Hero in main.heroes:
				if h.hp < h.max_hp:
					hurt = true
			if hurt or t > 40.0:
				check(hurt, "орк-лучник ранит героя или бойца стрелой")
				step = 5
		5:
			print("Итог: %s" % ("всё прошло" if failures == 0 else "провалено проверок: %d" % failures))
			get_tree().quit(1 if failures > 0 else 0)
