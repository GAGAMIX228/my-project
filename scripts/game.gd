extends Node
## Общие данные игры: золото, жизни, волна.
## К ним можно обратиться из любого скрипта: Game.gold, Game.lives и так далее.

signal gold_changed(value: int)
signal lives_changed(value: int)
signal wave_changed(current: int, total: int)
signal message(text: String)
signal finished(win: bool, stars: int)

var gold := 0
var lives := 0
var wave := 0  # сколько волн уже запущено
var kills := 0
var over := false

# Сюда main.gd записывает узлы, в которые складываются эффекты и снаряды.
var fx_root: Node2D
var proj_root: Node2D
var units_root: Node2D
var road: Curve2D

# Что игрок взял в бой на экране сборки: два героя и три заклинания.
var loadout_heroes: Array[String] = ["edrik", "tarn"]
var loadout_spells: Array[String] = ["knights", "meteors", "frost"]


func reset() -> void:
	gold = Defs.START_GOLD
	lives = Defs.START_LIVES
	wave = 0
	kills = 0
	over = false
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	wave_changed.emit(wave, Defs.WAVES.size())


func add_gold(value: int) -> void:
	gold += value
	gold_changed.emit(gold)


## Тратит золото. Если не хватает, говорит об этом и возвращает false.
func spend(value: int) -> bool:
	if gold < value:
		message.emit("Не хватает золота")
		return false
	gold -= value
	gold_changed.emit(gold)
	return true


func lose_life(count: int) -> void:
	if over:
		return
	lives = maxi(0, lives - count)
	lives_changed.emit(lives)
	if lives == 0:
		over = true
		finished.emit(false, 0)


func win() -> void:
	if over:
		return
	over = true
	var stars := 3 if lives >= 18 else (2 if lives >= 10 else 1)
	finished.emit(true, stars)


## Живые враги на карте.
func enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.dead:
			list.append(e)
	return list


## Ближайшая к точке точка дороги: pos (где она), dir (куда идёт дорога), dist (как далеко от точки).
func road_nearest(point: Vector2) -> Dictionary:
	var offset := road.get_closest_offset(point)
	var pos := road.sample_baked(offset)
	var ahead := road.sample_baked(minf(offset + 2.0, road.get_baked_length()))
	var behind := road.sample_baked(maxf(offset - 2.0, 0.0))
	var dir := (ahead - behind).normalized()
	return {"pos": pos, "dir": dir, "dist": pos.distance_to(point)}
