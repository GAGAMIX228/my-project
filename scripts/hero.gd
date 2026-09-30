class_name Hero
extends Soldier
## Герой. Ближние герои дерутся как бойцы казармы (блокируют врагов), дальние и драконы стреляют.
## Игрок выбирает героя, нажимает на землю, и герой идёт туда (post). У героя есть способность с перезарядкой.
## Все числа героя лежат в Defs.HEROES.

var hid := "edrik"
var def: Dictionary = {}
var flying := false
var selected := false
var ability_cd := 0.0   # сколько секунд осталось до готовности способности
var rage := 0.0         # оставшееся время ярости (только у Кары)

var _shot_cd := 0.0
var _time := 0.0


## Вызывается до добавления героя на карту.
func setup(hero_id: String, start: Vector2) -> void:
	hid = hero_id
	def = Defs.HEROES[hid]
	max_hp = float(def["hp"])
	hp = max_hp
	dmg = float(def["dmg"])
	rate = float(def["rate"])
	speed = float(def["speed"])
	engage = float(def.get("engage", 90.0))
	radius = float(def["radius"])
	respawn_time = float(def["respawn"])
	color = def["color"]
	flying = def["kind"] == "dragon"
	regen = 4.0 if def["kind"] == "melee" else 3.0
	position = start
	post = start


func _ready() -> void:
	# героя не считаем «бойцом казармы», поэтому в группу soldiers его не добавляем
	add_to_group("heroes")
	if flying:
		z_index = 1
	_setup_art()


func _art_dir() -> String:
	return "heroes/%s" % hid


func _art_feet() -> Vector2:
	return Vector2(0, -6.0) if flying else Vector2(0, radius * 0.8)


func is_ranged() -> bool:
	return def["kind"] != "melee"


## Отправляет героя в точку.
func set_post(point: Vector2) -> void:
	post = Vector2(clampf(point.x, 12.0, Defs.VIEW.x - 12.0), clampf(point.y, 12.0, Defs.VIEW.y - 12.0))
	if dead:
		position = post
	Fx.ring(post, 16.0, Color("ffe27a"), 0.3)


func _die() -> void:
	super._die()
	# мёртвый герой остаётся на месте и показывает, через сколько вернётся
	visible = true
	position = post
	Game.message.emit("%s пал и вернётся через %d с" % [def["name"], int(respawn_time)])


func _tick(delta: float) -> void:
	_time += delta
	if ability_cd > 0.0:
		ability_cd -= delta
	if rage > 0.0:
		rage -= delta
	if dead:
		queue_redraw()


func _melee_stats() -> Vector2:
	if hid != "kara":
		return Vector2(dmg, rate)
	# Кара: чем меньше здоровья, тем сильнее и быстрее бьёт
	var m := 1.0 + (1.0 - hp / max_hp) * 0.9
	var d := dmg * m
	var r := rate / m
	if rage > 0.0:
		d *= 1.4
		r *= 0.7
	return Vector2(d, r)


func _act(delta: float) -> void:
	if is_ranged():
		_shoot(delta)
	else:
		super._act(delta)


## Дальний герой идёт на своё место и стреляет во врага, который ушёл по дороге дальше всех.
func _shoot(delta: float) -> void:
	_shot_cd -= delta
	_walk_to_post(delta)
	hp = minf(max_hp, hp + regen * delta)
	if _shot_cd > 0.0:
		return
	var best: Enemy = null
	for e in Game.enemies():
		if e.aim_point().distance_to(position) <= float(def["range"]) and (best == null or e.progress > best.progress):
			best = e
	if best == null:
		return
	_shot_cd = float(def["rate"])
	_swing = 0.15
	face = 1.0 if best.global_position.x >= position.x else -1.0
	var arrow: bool = def["shot"] == "arrow"
	var p := Projectile.new()
	p.kind = "arrow" if arrow else "orb"
	p.dmg = float(def["dmg"])
	p.dtype = def["dtype"]
	p.speed = 520.0 if arrow else 360.0
	p.color = def.get("col", Color("c9a6ff"))
	Game.proj_root.add_child(p)
	p.launch_homing(position + Vector2(0, -22 if flying else -12), best)


# ---------- способности ----------

## Использует способность. Возвращает false, если не вышло (перезарядка, некого бить).
func use_ability() -> bool:
	if Game.over:
		return false
	if dead:
		Game.message.emit("%s восстанавливается" % def["name"])
		return false
	if ability_cd > 0.0:
		Game.message.emit("Способность перезаряжается")
		return false
	var ab: Dictionary = def["ab"]
	var ok := false
	match hid:
		"edrik": ok = _dash(ab)
		"grum": ok = _stomp(ab)
		"kara":
			rage = float(ab["time"])
			Fx.ring(position, 44.0, Color("ff6a4a"), 0.45)
			ok = true
		"tarn": ok = _aimed_shot(ab)
		"xol": ok = _frost_burst(ab)
		"ishta": ok = _call_spirits(ab)
		"ashgar": ok = _fire_storm(ab)
		"morven": ok = _harvest(ab)
		"zefira": ok = _hurricane(ab)
	if ok:
		ability_cd = float(ab["cd"])
	return ok


func _no_enemies() -> bool:
	Game.message.emit("Рядом нет врагов")
	return false


## Эдрик: прыгает к ближайшему наземному врагу, оглушает и бьёт всех рядом.
func _dash(ab: Dictionary) -> bool:
	var best: Enemy = null
	var best_d := float(ab["reach"])
	for e in Game.enemies():
		if e.flying:
			continue
		var d := e.global_position.distance_to(position)
		if d < best_d:
			best = e
			best_d = d
	if best == null:
		return _no_enemies()
	_drop_target()
	var away := (position - best.global_position).normalized()
	position = best.global_position + away * 20.0
	post = position
	for e in Combat.area(position, float(ab["radius"]), false):
		e.stun_for(float(ab["stun"]))
		e.take_damage(float(ab["dmg"]), "phys")
	Fx.ring(position, float(ab["radius"]), Color("ffe27a"), 0.4)
	return true


## Грум: оглушает всех наземных врагов вокруг.
func _stomp(ab: Dictionary) -> bool:
	var list := Combat.area(position, float(ab["radius"]), false)
	if list.is_empty():
		return _no_enemies()
	for e in list:
		e.stun_for(float(ab["stun"]))
		e.take_damage(float(ab["dmg"]), "phys")
	Fx.ring(position, float(ab["radius"]), Color("d9a95c"), 0.5)
	return true


## Тарн: огромный урон самому здоровому врагу рядом.
func _aimed_shot(ab: Dictionary) -> bool:
	var best: Enemy = null
	for e in Game.enemies():
		if e.aim_point().distance_to(position) > float(ab["reach"]):
			continue
		if best == null or e.hp > best.hp:
			best = e
	if best == null:
		return _no_enemies()
	var p := Projectile.new()
	p.kind = "arrow"
	p.big = true
	p.dmg = float(ab["dmg"])
	p.dtype = "phys"
	p.speed = 760.0
	Game.proj_root.add_child(p)
	p.launch_homing(position + Vector2(0, -12), best)
	return true


## Ксол: ледяной шквал в самой плотной группе врагов.
func _frost_burst(ab: Dictionary) -> bool:
	var c := Combat.best_cluster(position, float(ab["reach"]), float(ab["radius"]), true)
	if c == null:
		return _no_enemies()
	var center := c.aim_point()
	for e in Combat.area(center, float(ab["radius"]), true):
		e.freeze_for(float(ab["stun"]))
		e.take_damage(float(ab["dmg"]), "magic")
	Fx.ring(center, float(ab["radius"]), Color("9fe3ff"), 0.5)
	return true


## Ишта: три духа сражаются рядом.
func _call_spirits(ab: Dictionary) -> bool:
	for i in int(ab["n"]):
		var a := i * 2.1
		var s := Soldier.new()
		s.temp = true
		s.life = float(ab["life"])
		s.max_hp = float(ab["hp"])
		s.hp = s.max_hp
		s.dmg = float(ab["dmg"])
		s.rate = float(ab["rate"])
		s.color = Color("b78aff")
		s.engage = 95.0
		s.position = position
		s.post = post + Vector2(cos(a) * 26.0, sin(a) * 18.0)
		Game.units_root.add_child(s)
	Fx.ring(position, 50.0, Color("d9b8ff"), 0.5)
	return true


## Ашгар: огонь по группе врагов, они горят.
func _fire_storm(ab: Dictionary) -> bool:
	var c := Combat.best_cluster(position, float(ab["reach"]), float(ab["radius"]), true)
	if c == null:
		return _no_enemies()
	var center := c.aim_point()
	for e in Combat.area(center, float(ab["radius"]), true):
		e.take_damage(float(ab["dmg"]), "magic")
		e.ignite(float(ab["burn"]), float(ab["burn_dps"]))
	Fx.ring(center, float(ab["radius"]), Color("ff7a2a"), 0.55)
	return true


## Морвен: отнимает здоровье у врагов рядом и лечит себя.
func _harvest(ab: Dictionary) -> bool:
	var list := Combat.area(position, float(ab["radius"]), true)
	if list.is_empty():
		return _no_enemies()
	var heal := 0.0
	for e in list:
		e.take_damage(float(ab["dmg"]), "pure")
		heal += float(ab["heal"])
	hp = minf(max_hp, hp + minf(float(ab["heal_max"]), heal))
	Fx.ring(position, float(ab["radius"]), Color("b9ffd0"), 0.5)
	return true


## Зефира: ураган отбрасывает наземных врагов назад по дороге.
func _hurricane(ab: Dictionary) -> bool:
	var list := Combat.area(position, float(ab["radius"]), false)
	if list.is_empty():
		Game.message.emit("Рядом нет наземных врагов")
		return false
	for e in list:
		e.push_back(float(ab["push"]))
		e.take_damage(float(ab["dmg"]), "magic")
	Fx.ring(position, float(ab["radius"]), Color("c8f0ff"), 0.55)
	return true


# ---------- рисование ----------

func _draw() -> void:
	if dead:
		Art.label(self, Vector2(0, -22), "%s вернётся через %d с" % [def["name"], ceili(respawn)])
		return
	var r := radius
	if selected:
		Art.ellipse_outline(self, Vector2(0, 8 if flying else r * 0.8), r + 7.0, (r + 7.0) * 0.42, Color("ffe27a"), 2.5)
		if def.has("range"):
			Art.dashed_circle(self, post - position, float(def["range"]), Color(1.0, 0.89, 0.48, 0.5))
		if post.distance_to(position) > 8.0:
			var m := post - position
			draw_line(m + Vector2(-6, -6), m + Vector2(6, 6), Color(1.0, 0.89, 0.48, 0.85), 2.0)
			draw_line(m + Vector2(6, -6), m + Vector2(-6, 6), Color(1.0, 0.89, 0.48, 0.85), 2.0)
	var bar_y := -26.0 - 22.0 if flying else -r - (16.0 if hid == "edrik" or hid == "kara" else 14.0)
	if _sprite != null:
		Art.blob_shadow(self, Vector2(0, 8 if flying else r * 0.85), r * 1.3)
		bar_y = _sprite.position.y - float(_sprite.get_meta("height")) - 6.0
		if rage > 0.0:
			draw_circle(Vector2(0, _sprite.position.y - float(_sprite.get_meta("height")) * 0.5), r + 6.0, Color(1.0, 0.35, 0.23, 0.3))
	else:
		HeroArt.draw(self, hid, def, face, _hurt > 0.0, 1.0 if _swing > 0.0 else 0.0, rage > 0.0, _time)
	if hp < max_hp:
		Art.hp_bar(self, 0.0, bar_y, 26.0, hp / max_hp, Color("59c46a"))
	Art.label(self, Vector2(0, 26.0 if flying else r + 13.0), def["name"])
