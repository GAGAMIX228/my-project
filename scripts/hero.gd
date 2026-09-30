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

func _ball(x: float, y: float, r: float, fill: Color, outline := Color(0, 0, 0, 0), width := 1.0) -> void:
	draw_circle(Vector2(x, y), r, fill)
	if outline.a > 0.0:
		draw_arc(Vector2(x, y), r, 0.0, TAU, 20, outline, width, true)


func _draw() -> void:
	if dead:
		Art.label(self, Vector2(0, -22), "%s вернётся через %d с" % [def["name"], ceili(respawn)])
		return
	var r := radius
	var f := face
	if selected:
		Art.ellipse_outline(self, Vector2(0, 8 if flying else r * 0.8), r + 7.0, (r + 7.0) * 0.42, Color("ffe27a"), 2.5)
		if def.has("range"):
			Art.dashed_circle(self, post - position, float(def["range"]), Color(1.0, 0.89, 0.48, 0.5))
		if post.distance_to(position) > 8.0:
			var m := post - position
			draw_line(m + Vector2(-6, -6), m + Vector2(6, 6), Color(1.0, 0.89, 0.48, 0.85), 2.0)
			draw_line(m + Vector2(6, -6), m + Vector2(-6, 6), Color(1.0, 0.89, 0.48, 0.85), 2.0)
	if flying:
		_draw_dragon()
	else:
		Art.ellipse(self, Vector2(0, r * 0.8), r, r * 0.4, Color(0, 0, 0, 0.25))
		var body := Color.WHITE if _hurt > 0.0 else color
		var sw := 1.0 if _swing > 0.0 else 0.0
		match hid:
			"edrik": _draw_knight(r, f, body, sw)
			"grum": _draw_ogre(r, f, body, sw)
			"kara": _draw_orc(r, f, body, sw)
			"tarn": _draw_ranger(r, f, body)
			"xol": _draw_mage(r, f, body)
			_: _draw_shaman(r, body)
		if rage > 0.0:
			_ball(0, -2, r + 6.0, Color(1.0, 0.35, 0.23, 0.35))
		if hp < max_hp:
			var bar_y := -r - (16.0 if hid == "edrik" or hid == "kara" else 14.0)
			Art.hp_bar(self, 0.0, bar_y, 26.0, hp / max_hp, Color("59c46a"))
	Art.label(self, Vector2(0, 26.0 if flying else r + 13.0), def["name"])


func _draw_knight(r: float, f: float, body: Color, sw: float) -> void:
	_ball(0, -2, r, body, Color("22386b"), 1.3)
	Art.half_disc(self, Vector2(0, -4), r * 0.82, Color("d8dbe3"))
	draw_rect(Rect2(-2, -4, 4, 5), Color("2a2a33"))
	Art.tri(self, Vector2(-3, -r - 2), Vector2(0, -r - 12), Vector2(5, -r - 1), Color("e0523f"))
	draw_rect(Rect2(-f * (r + 1) - 3, -6, 6, 11), Color("e2b53c"))
	draw_line(Vector2(f * (r - 2), 2), Vector2(f * (r + 11 + sw * 4), -8 + sw * 10), Color("e9edf2"), 2.4)


func _draw_ogre(r: float, f: float, body: Color, sw: float) -> void:
	_ball(0, -2, r, body, Color("5a3a16"), 1.5)
	_ball(-4, -5, 2.2, Color.WHITE)
	_ball(4, -5, 2.2, Color.WHITE)
	_ball(-4, -5, 1.0, Color("222222"))
	_ball(4, -5, 1.0, Color("222222"))
	Art.tri(self, Vector2(-6, 2), Vector2(-3, 2), Vector2(-4.5, -3), Color("f3efe0"))
	Art.tri(self, Vector2(6, 2), Vector2(3, 2), Vector2(4.5, -3), Color("f3efe0"))
	draw_line(Vector2(f * (r - 2), 6), Vector2(f * (r + 12 + sw * 4), -10 + sw * 12), Color("5a3a16"), 4.0)
	_ball(f * (r + 13 + sw * 4), -11 + sw * 12, 5.0, Color("6b4a2a"), Color("3d2614"), 1.0)


func _draw_orc(r: float, f: float, body: Color, sw: float) -> void:
	_ball(0, -2, r, body, Color("274a1a"), 1.3)
	var paint := Color("c2483a")
	draw_line(Vector2(-6, -8), Vector2(-2, -3), paint, 2.0)
	draw_line(Vector2(6, -8), Vector2(2, -3), paint, 2.0)
	_ball(-3.5, -4, 2.0, Color.WHITE)
	_ball(3.5, -4, 2.0, Color.WHITE)
	_ball(-3.5, -4, 0.9, Color("b01818"))
	_ball(3.5, -4, 0.9, Color("b01818"))
	Art.tri(self, Vector2(-4, -r - 1), Vector2(0, -r - 10), Vector2(4, -r - 1), paint)
	var steel := Color("d9dde3")
	draw_line(Vector2(f * (r - 2), 2), Vector2(f * (r + 8 + sw * 4), -6 + sw * 9), steel, 2.6)
	draw_line(Vector2(-f * (r - 2), 2), Vector2(-f * (r + 6), -6), steel, 2.6)


func _draw_ranger(r: float, f: float, body: Color) -> void:
	_ball(0, -2, r, body, Color("25502a"), 1.3)
	Art.half_disc(self, Vector2(0, -4), r * 0.95, Color("2f6b34"))
	_ball(0, -1, r * 0.45, Color("f2d2a4"))
	var turn := 0.0 if f > 0.0 else PI
	draw_arc(Vector2(f * (r + 3), -2), 9.0, -1.3 + turn, 1.3 + turn, 12, Color("6b4a2a"), 2.2, true)


func _draw_mage(r: float, f: float, body: Color) -> void:
	_ball(0, -2, r, body, Color("155a68"), 1.3)
	Art.tri(self, Vector2(-r, -6), Vector2(0, -r - 16), Vector2(r, -6), Color("1b6f80"))
	_ball(0, -1, r * 0.42, Color("f2d2a4"))
	draw_line(Vector2(f * (r + 3), 8), Vector2(f * (r + 3), -16), Color("8b6b3a"), 2.4)
	_ball(f * (r + 3), -18, 4.0, Color("7fe0ff"), Color.WHITE, 1.0)


func _draw_shaman(r: float, body: Color) -> void:
	_ball(0, -2, r, body, Color("4a2f78"), 1.3)
	var feathers := [Color("e0523f"), Color("f0b93a"), Color("4da35a")]
	for i in range(-1, 2):
		Art.tri(self, Vector2(i * 5 - 2, -r + 1), Vector2(i * 6, -r - 11), Vector2(i * 5 + 3, -r + 1), feathers[i + 1])
	_ball(0, -1, r * 0.42, Color("f2d2a4"))
	for i in 2:
		var a := _time * 3.0 + i * 3.14
		_ball(cos(a) * (r + 6.0), -4.0 + sin(a) * 5.0, 3.0, Color("d9b8ff"), Color.WHITE, 1.0)


func _draw_dragon() -> void:
	var f := face
	var c: Color = color
	var y := -22.0
	var wing := sin(_time * 9.0 + position.x) * 0.5
	Art.ellipse(self, Vector2(0, 8), 18.0, 6.0, Color(0, 0, 0, 0.25))
	# хвост
	var tail := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		var p0 := Vector2(-f * 8.0, y + 3.0)
		var p1 := Vector2(-f * 24.0, y + 12.0)
		var p2 := Vector2(-f * 28.0, y - 2.0)
		tail.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	draw_polyline(tail, c, 5.0, true)
	var shade := Color("8d8874") if hid == "morven" else Color(0, 0, 0, 0.3)
	Art.tri(self, Vector2(-2, y - 2), Vector2(-18, y - 18 - wing * 12), Vector2(9, y - 5), c)
	Art.tri(self, Vector2(-2, y - 2), Vector2(-18, y - 18 - wing * 12), Vector2(-6, y - 4), shade)
	Art.tri(self, Vector2(2, y - 2), Vector2(16, y - 16 - wing * 12), Vector2(12, y - 2), c)
	Art.ellipse(self, Vector2(0, y), 13.0, 8.5, Color.WHITE if _hurt > 0.0 else c)
	Art.ellipse(self, Vector2(0, y + 2), 9.0, 5.0, Color(1, 1, 1, 0.28))
	_ball(f * 12.0, y - 3.0, 6.0, c)
	Art.tri(self, Vector2(f * 15.0, y - 3.0), Vector2(f * 22.0, y - 1.0), Vector2(f * 15.0, y + 2.0), c)
	_ball(f * 12.0, y - 5.0, 1.6, Color.WHITE)
	_ball(f * 12.5, y - 5.0, 0.8, Color("222222"))
	Art.tri(self, Vector2(f * 9.0, y - 8.0), Vector2(f * 8.0, y - 14.0), Vector2(f * 12.0, y - 8.0), Color("f0e6c8"))
	if hid == "morven":
		for i in range(-1, 2):
			draw_line(Vector2(i * 4.0, y - 6.0), Vector2(i * 4.0, y + 6.0), Color("6b6754"), 1.2)
	if rage > 0.0:
		_ball(0, y, 20.0, Color(1.0, 0.35, 0.23, 0.35))
	if hp < max_hp:
		Art.hp_bar(self, 0.0, y - 26.0, 26.0, hp / max_hp, Color("59c46a"))
