extends Node2D
## Главный узел уровня: собирает карту, запускает волны и обрабатывает нажатия мышью.

@onready var ground_road: Path2D = $GroundRoad
@onready var air_road: Path2D = $AirRoad
@onready var pads_root: Node2D = $Pads
@onready var towers_root: Node2D = $Towers
@onready var units_root: Node2D = $Units
@onready var projectiles_root: Node2D = $Projectiles
@onready var fx_root: Node2D = $Fx
@onready var hud: Hud = $Hud

var pads: Array[Pad] = []
var queue: Array = []  # ожидающие появления враги: {"t": время, "type": тип}
var clock := 0.0
var selected: Pad = null
var hovered: Pad = null
var heroes: Array[Hero] = []
var hero_index := -1   # какой герой выбран (-1: никто). Ему адресовано следующее нажатие на землю
var spellbook: Spellbook


func _ready() -> void:
	Game.reset()
	Game.fx_root = fx_root
	Game.proj_root = projectiles_root
	Game.units_root = units_root
	Engine.time_scale = 1.0
	get_tree().paused = false

	var curve := Curve2D.new()
	for p: Vector2 in Defs.PATH:
		curve.add_point(p)
	Game.road = curve
	ground_road.curve = curve
	air_road.curve = curve

	for i in Defs.PADS.size():
		var pad := Pad.new()
		pad.index = i
		pad.position = Defs.PADS[i]
		pads_root.add_child(pad)
		pads.append(pad)

	_create_heroes()
	spellbook = Spellbook.new()
	spellbook.setup(Game.loadout_spells)
	add_child(spellbook)
	hud.bind(spellbook, heroes)
	hud.spell_pressed.connect(func(i: int): spellbook.arm(Game.loadout_spells[i]))
	hud.ability_pressed.connect(use_ability)
	hud.hero_pressed.connect(toggle_hero)
	hud.map_requested.connect(_to_map)
	hud.wave_requested.connect(start_wave)
	hud.speed_toggled.connect(_toggle_speed)
	hud.pause_toggled.connect(_toggle_pause)
	hud.build_requested.connect(build_tower)
	hud.upgrade_requested.connect(upgrade_tower)
	hud.sell_requested.connect(sell_tower)
	hud.restart_requested.connect(_restart)
	Game.finished.connect(_on_finished)
	Game.message.emit("Построй башни на каменных площадках и запусти волну")
	_update_info()


# ---------- герои ----------

func _create_heroes() -> void:
	for i in Game.loadout_heroes.size():
		var hero := Hero.new()
		var start: Vector2 = Game.road_nearest(Defs.HERO_START[i])["pos"]
		hero.setup(Game.loadout_heroes[i], start)
		units_root.add_child(hero)
		heroes.append(hero)


## Выбирает героя (или снимает выбор, если index равен -1).
func select_hero(index: int) -> void:
	hero_index = index if index >= 0 and index < heroes.size() else -1
	for i in heroes.size():
		heroes[i].selected = i == hero_index
		heroes[i].queue_redraw()


## Нажатие на портрет: выбрать, а если уже выбран, то снять выбор.
func toggle_hero(index: int) -> void:
	select_hero(-1 if index == hero_index else index)


## Пробел: выбрать следующего героя (первый пробел первого, второй пробел второго и так по кругу).
func select_next_hero() -> void:
	if heroes.is_empty():
		return
	select_hero((hero_index + 1) % heroes.size())


func use_ability(index: int) -> bool:
	if index < 0 or index >= heroes.size():
		return false
	return heroes[index].use_ability()


func _hero_at(point: Vector2) -> int:
	for i in heroes.size():
		var h := heroes[i]
		if h.dead:
			continue
		var lift := Vector2(0, -22) if h.flying else Vector2.ZERO
		if h.position.distance_to(point) < 24.0 or (h.position + lift).distance_to(point) < 24.0:
			return i
	return -1


# ---------- волны ----------

func can_start_wave() -> bool:
	return not Game.over and Game.wave < Defs.WAVES.size() and queue.is_empty()


func start_wave() -> bool:
	if not can_start_wave():
		return false
	var early := _alive_enemies() > 0
	var t := clock + 0.4
	for group in Defs.WAVES[Game.wave]:
		var type: String = group[0]
		var count: int = group[1]
		var gap: float = group[2]
		for i in count:
			queue.append({"t": t, "type": type})
			t += gap
		t += 2.2
	queue.sort_custom(func(a, b): return a["t"] < b["t"])
	Game.wave += 1
	Game.wave_changed.emit(Game.wave, Defs.WAVES.size())
	if early:
		Game.add_gold(15)
		Game.message.emit("Досрочный вызов: +15 золота")
	else:
		Game.message.emit("Волна %d идёт" % Game.wave)
	_update_info()
	return true


func _spawn(type: String) -> void:
	var enemy := Enemy.new()
	enemy.setup(type)
	var road := air_road if Defs.ENEMIES[type]["fly"] else ground_road
	road.add_child(enemy)


func _alive_enemies() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.dead:
			n += 1
	return n


func _update_info() -> void:
	if Game.wave < Defs.WAVES.size():
		var names: Array[String] = []
		for group in Defs.WAVES[Game.wave]:
			var n: String = Defs.ENEMIES[group[0]]["name"]
			names.append(n if group[1] == 1 else "%s ×%d" % [n, group[1]])
		var text := "Впереди волна %d: %s." % [Game.wave + 1, ", ".join(names)]
		hud.set_info(("Орки выходят из лагеря. " if not queue.is_empty() else "") + text)
	else:
		hud.set_info("Последняя волна уже идёт.")


func _process(delta: float) -> void:
	clock += delta
	var spawned := false
	while not queue.is_empty() and queue[0]["t"] <= clock:
		_spawn(queue.pop_front()["type"])
		spawned = true
	if queue.is_empty() and spawned:
		_update_info()
	hud.set_wave_button(
		"Волны закончились" if Game.wave >= Defs.WAVES.size() else "Начать волну %d" % (Game.wave + 1),
		can_start_wave())
	if not Game.over and Game.wave >= Defs.WAVES.size() and queue.is_empty() and _alive_enemies() == 0:
		Game.win()
	_update_hover()


# ---------- нажатия ----------

func _update_hover() -> void:
	var pad := _pad_at(get_global_mouse_position())
	if pad != hovered:
		if hovered != null:
			hovered.hover = false
			_show_range(hovered, hovered == selected)
		hovered = pad
		if hovered != null:
			hovered.hover = true
			_show_range(hovered, true)


func _pad_at(pos: Vector2) -> Pad:
	for pad in pads:
		if pad.position.distance_to(pos) < 30.0:
			return pad
	return null


func _show_range(pad: Pad, on: bool) -> void:
	if pad.tower != null:
		pad.tower.show_range = on


func _unhandled_input(event: InputEvent) -> void:
	if Game.over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event as InputEventKey)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		spellbook.cancel()
		_select(null)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = (make_input_local(event) as InputEventMouseButton).position
		# выбрано заклинание: нажатие на карту применяет его
		if spellbook.armed != "":
			spellbook.cast(spellbook.armed, point)
			return
		var pad := _pad_at(point)
		# выбрана казарма, и нажали внутри её синего круга: отправляем бойцов туда
		if pad == null and selected != null and selected.tower != null and selected.tower.kind == "barracks":
			var barracks := selected.tower
			if barracks.position.distance_to(point) <= float(barracks.stat()["range"]):
				barracks.set_rally(point)
				return
		if pad != null:
			_select(null if pad == selected else pad)
			return
		if selected != null:
			_select(null)
			return
		# ни площадка, ни меню: нажали на героя (выбрать) или на землю (отправить выбранного героя)
		var near := _hero_at(point)
		if near >= 0:
			select_hero(near)
		elif hero_index >= 0:
			# приказ выдан: герой отвязывается, следующий клик его уже не двигает
			heroes[hero_index].set_post(point)
			select_hero(-1)


func _on_key(event: InputEventKey) -> void:
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			var i: int = event.keycode - KEY_1
			if i < Game.loadout_spells.size():
				spellbook.arm(Game.loadout_spells[i])
		KEY_4, KEY_5:
			use_ability(event.keycode - KEY_4)
		KEY_SPACE:
			select_next_hero()
		KEY_ENTER, KEY_KP_ENTER:
			start_wave()
		KEY_ESCAPE:
			spellbook.cancel()
			select_hero(-1)
			_select(null)


func _select(pad: Pad) -> void:
	if selected != null:
		selected.selected = false
		_show_range(selected, selected == hovered)
	selected = pad
	if pad == null:
		hud.close_menu()
	else:
		pad.selected = true
		_show_range(pad, true)
		hud.open_menu(pad)


# ---------- башни ----------

func build_tower(pad: Pad, kind: String) -> bool:
	if pad.tower != null:
		return false
	if not Game.spend(int(Defs.TOWERS[kind]["cost"])):
		return false
	var tower := Tower.new()
	tower.setup(kind)
	tower.position = pad.position
	towers_root.add_child(tower)
	pad.tower = tower
	tower.activate()
	pad.queue_redraw()
	Fx.ring(pad.position, 30.0, Color.WHITE)
	_select(null)
	return true


func upgrade_tower(pad: Pad) -> bool:
	var tower := pad.tower
	if tower == null or tower.upgrade_cost() < 0:
		return false
	if not Game.spend(tower.upgrade_cost()):
		return false
	tower.upgrade()
	Fx.ring(pad.position, 34.0, Color("ffe27a"), 0.4)
	hud.refresh_menu()
	return true


func sell_tower(pad: Pad) -> void:
	var tower := pad.tower
	if tower == null:
		return
	Game.add_gold(tower.sell_value())
	tower.dispose()
	pad.tower = null
	pad.queue_redraw()
	Fx.ring(pad.position, 30.0, Color("ff9a8a"), 0.3)
	_select(null)


# ---------- скорость, пауза, конец ----------

func _toggle_speed() -> void:
	Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else 1.0
	hud.set_speed_text(Engine.time_scale)


func _toggle_pause() -> void:
	if Game.over:
		return
	get_tree().paused = not get_tree().paused
	hud.set_pause_text(get_tree().paused)


func _on_finished(_win: bool, _stars: int) -> void:
	get_tree().paused = true


func _to_map() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/campaign.tscn")


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
