extends Node
## Автотест: бот проходит уровень без окна и печатает результат.
## Запуск: godot --headless --path . res://tests/sim.tscn -- smart [герои] [заклинания]
## Режимы (порядок построек и поведение):
##   smart   строит и улучшает башни, использует способности героев и заклинания (внимательный игрок)
##   medium  как smart, но герои стоят на местах, куда их поставили в начале боя
##   passive то же, но не трогает способности, заклинания и героев (пассивный игрок)
##   lazy    четыре башни без улучшений, без способностей
##   old, oldbar, nobar: старые порядки построек с первого этапа (без героев не считаются)
## Герои и заклинания через запятую: -- smart edrik,kara knights,meteors,wave
## Здоровье орков можно подменить: HP_SCALE=1.3 godot ... Сложность: DIFFICULTY=novice|fighter|veteran

var main: Node
var mode := "smart"
var elapsed := 0.0
var last_call := -100.0
var last_print := 0.0
var last_act := 0.0
var order := [
	[1, "archer"], [2, "barracks"], [4, "mage"], [5, "archer"], [8, "mortar"], [7, "archer"],
	[3, "mage"], [9, "barracks"], [6, "archer"], [0, "archer"], [10, "mortar"],
]


func _ready() -> void:
	Game.persist = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # игра ставит паузу в конце, а тест должен успеть напечатать итог
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	if args.size() > 1:
		Game.loadout_heroes.assign(Array(args[1].split(",")))
	if args.size() > 2:
		Game.loadout_spells.assign(Array(args[2].split(",")))
	if mode == "old" or mode == "oldbar":
		# порядок, на котором проверялся первый этап игры (без казармы)
		order = [[1, "archer"], [2, "mage"], [4, "archer"], [5, "mortar"], [7, "archer"], [8, "mage"],
			[3, "archer"], [9, "mortar"], [6, "archer"], [0, "mage"], [10, "archer"]]
		if mode == "oldbar":
			order[1] = [2, "barracks"]
			order[5] = [8, "barracks"]
	if mode.begins_with("nobar"):
		for spec in order:
			if spec[1] == "barracks":
				spec[1] = "archer"
	var level := OS.get_environment("DIFFICULTY")   # novice, fighter или veteran
	if level != "":
		Game.difficulty = level
	var counts := OS.get_environment("COUNT_SCALE")
	if counts != "":
		Game.count_test_scale = float(counts)
	var scale := OS.get_environment("HP_SCALE")
	if scale != "":
		Defs.hp_scale = float(scale)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Engine.time_scale = 6.0  # после запуска уровня, он сам ставит скорость 1


func _process(delta: float) -> void:
	elapsed += delta
	var g := get_node("/root/Game")
	if g.over or elapsed > 4000.0:
		var stars := 0
		if g.over and g.lives > 0:
			stars = 3 if g.lives >= 18 else (2 if g.lives >= 10 else 1)
		print("РЕЗУЛЬТАТ hp=%.2f врагов×%.2f сложность=%s mode=%s героев=%s заклинаний=%s: %s, волна %d, жизни %d, убито %d, звёзды %d, время %d с" % [
			Defs.hp_scale, Game.count_test_scale, Game.difficulty, mode, ",".join(Game.loadout_heroes), ",".join(Game.loadout_spells),
			"победа" if (g.over and g.lives > 0) else ("поражение" if g.over else "таймаут"),
			g.wave, g.lives, g.kills, stars, int(elapsed)])
		get_tree().quit(0)
		return
	if elapsed - last_print > 60.0:
		last_print = elapsed
		print("t=%d волна=%d жизни=%d золото=%d fps=%d" % [int(elapsed), g.wave, g.lives, g.gold, Engine.get_frames_per_second()])
	if main.can_start_wave() and Game.enemies().size() < 3 and elapsed - last_call > 5.0:
		if main.start_wave():
			last_call = elapsed
	var limit := 4 if mode == "lazy" else 11
	for i in limit:
		var spec: Array = order[i]
		var pad: Pad = main.pads[spec[0]]
		if pad.tower == null:
			main.build_tower(pad, spec[1])
			break
	if mode != "lazy" and g.gold > 150:
		for pad: Pad in main.pads:
			if pad.tower != null and pad.tower.level < 3:
				main.upgrade_tower(pad)
				break
	if (mode == "smart" or mode == "medium") and elapsed - last_act > 0.5:
		last_act = elapsed
		_play_heroes_and_spells()


## Внимательный игрок: способности по готовности, заклинания в гущу врагов, герои у дороги.
func _play_heroes_and_spells() -> void:
	var enemies: Array[Enemy] = Game.enemies()
	if enemies.is_empty():
		return
	for i in main.heroes.size():
		var h: Hero = main.heroes[i]
		if h.ability_cd <= 0.0 and not h.dead:
			main.use_ability(i)
		if mode == "smart":
			_place_hero(h, enemies)
	var book: Spellbook = main.spellbook
	for id in book.spells:
		if not book.is_ready(id):
			continue
		var d: Dictionary = Defs.SPELLS[id]
		var lead := _leader(enemies)
		var cluster := Combat.best_cluster(Vector2(480, 270), 2000.0, float(d.get("r", 60.0)), true)
		match id:
			"knights", "reinforce":
				if lead != null and lead.progress > 250.0:
					book.cast(id, lead.global_position)
			"quake":
				if enemies.size() >= 6:
					book.cast(id, Vector2.ZERO)
			"meteors", "wrath", "fireball", "frost", "wave":
				if cluster != null and _count_near(enemies, cluster, float(d.get("r", 60.0))) >= 3:
					book.cast(id, cluster.global_position)


func _leader(enemies: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	for e in enemies:
		if best == null or e.progress > best.progress:
			best = e
	return best


func _count_near(enemies: Array[Enemy], center: Enemy, radius: float) -> int:
	var n := 0
	for e in enemies:
		if e.global_position.distance_to(center.global_position) <= radius:
			n += 1
	return n


## Ближние герои встают на дорогу перед самым дальним врагом, дальние стоят сзади них.
func _place_hero(h: Hero, enemies: Array[Enemy]) -> void:
	var lead := _leader(enemies)
	if lead == null:
		return
	var offset := clampf(lead.progress - (60.0 if h.is_ranged() else 0.0), 20.0, Game.road.get_baked_length() - 40.0)
	var road_point := Game.road.sample_baked(offset)
	var spot := road_point
	if h.is_ranged():
		spot = road_point + Vector2(0, -40)
	if h.post.distance_to(spot) > 60.0:
		h.set_post(spot)
