class_name Spellbook
extends Node2D
## Заклинания игрока: перезарядки, режим прицеливания, сами эффекты и круг-подсказка под мышью.
## Все числа заклинаний лежат в Defs.SPELLS.

var spells: Array[String] = []        # три выбранных заклинания, по порядку клавиш 1, 2, 3
var cooldown := {}                    # id -> сколько секунд осталось до готовности
var armed := ""                       # выбранное заклинание, которое ждёт нажатия на карту

var _meteors: Array = []              # падающие метеориты: {"pos", "left", "next"}
var _clock := 0.0


func setup(ids: Array[String]) -> void:
	spells = ids.duplicate()
	for id in spells:
		cooldown[id] = 0.0
	z_index = 50


## Доля перезарядки, которая осталась: 1 сразу после применения, 0 когда готово.
func cooldown_fraction(id: String) -> float:
	return float(cooldown.get(id, 0.0)) / float(Defs.SPELLS[id]["cd"])


func is_ready(id: String) -> bool:
	return float(cooldown.get(id, 0.0)) <= 0.0


func _process(delta: float) -> void:
	_clock += delta
	for id in cooldown:
		cooldown[id] = maxf(0.0, float(cooldown[id]) - delta)
	for m in _meteors:
		m["left_t"] += delta
		while m["left"] > 0 and m["left_t"] >= m["next"]:
			m["next"] += float(Defs.SPELLS["meteors"]["gap"])
			m["left"] -= 1
			_drop_meteor(m["pos"])
	_meteors = _meteors.filter(func(m): return m["left"] > 0)
	if Game.over:
		armed = ""
	queue_redraw()


## Нажали кнопку заклинания: заклинания без прицела срабатывают сразу, остальным нужно нажать на карту.
func arm(id: String) -> void:
	if Game.over or not Defs.SPELLS.has(id):
		return
	if not is_ready(id):
		Game.message.emit("Заклинание ещё перезаряжается")
		return
	if Defs.SPELLS[id]["aim"] == "none":
		armed = ""
		cast(id, Vector2.ZERO)
		return
	armed = "" if armed == id else id
	if armed != "":
		Game.message.emit("Выбери место на дороге" if Defs.SPELLS[id]["aim"] == "road" else "Выбери место на карте")


func cancel() -> void:
	armed = ""


## Применяет заклинание в точке. Возвращает true, если получилось.
func cast(id: String, point: Vector2) -> bool:
	if Game.over or not is_ready(id):
		return false
	var d: Dictionary = Defs.SPELLS[id]
	var ok := false
	match id:
		"knights", "reinforce":
			ok = _summon(point, d)
		"meteors":
			_meteors.append({"pos": point, "left": int(d["n"]), "left_t": 0.0, "next": 0.15})
			Fx.ring(point, float(d["r"]), Color(1.0, 0.55, 0.24, 0.9), 0.6)
			ok = true
		"quake":
			for e in Combat.area(Vector2(480, 270), 4000.0, false):
				e.stun_for(float(d["stun"]))
				e.take_damage(float(d["dmg"]), "phys")
			Fx.ring(Defs.VIEW * 0.5, 420.0, Color("d9a95c"), 0.7)
			ok = true
		"frost":
			for e in Combat.area(point, float(d["r"]), true):
				e.freeze_for(float(d["stun"]))
				e.take_damage(float(d["dmg"]), "magic")
			Fx.ring(point, float(d["r"]), Color("9fe3ff"), 0.5)
			ok = true
		"wrath":
			for e in Combat.area(point, float(d["r"]), true):
				e.take_damage(float(d["dmg"]), "magic")
			Fx.ring(point, float(d["r"]), Color("fff3a8"), 0.5)
			ok = true
		"wave":
			for e in Combat.area(point, float(d["r"]), false):
				e.push_back(float(d["push"]))
				e.take_damage(float(d["dmg"]), "magic")
			Fx.ring(point, float(d["r"]), Color("5fb4ff"), 0.55)
			ok = true
		"fireball":
			for e in Combat.area(point, float(d["r"]), true):
				e.take_damage(float(d["dmg"]), "magic")
				e.ignite(float(d["burn"]), float(d["burn_dps"]))
			Fx.ring(point, float(d["r"]), Color("ff7a2a"), 0.6)
			ok = true
	if ok:
		cooldown[id] = float(d["cd"])
		armed = ""
	return ok


## Призывает бойцов на дорогу рядом с точкой.
func _summon(point: Vector2, d: Dictionary) -> bool:
	var near := Game.road_nearest(point)
	if float(near["dist"]) > 70.0:
		Game.message.emit("Призывать можно только на дорогу")
		return false
	var pos: Vector2 = near["pos"]
	var dir: Vector2 = near["dir"]
	var n := int(d["n"])
	for i in n:
		var off := (i - (n - 1) / 2.0) * 24.0
		var s := Soldier.new()
		s.temp = true
		s.life = float(d["life"])
		s.max_hp = float(d["hp"])
		s.hp = s.max_hp
		s.dmg = float(d["dmg"])
		s.rate = float(d["rate"])
		s.color = d["color"]
		s.post = pos + Vector2(-dir.y, dir.x) * off
		s.position = s.post + Vector2(0, -30)
		Game.units_root.add_child(s)
	Fx.ring(pos, 40.0, d["color"], 0.45)
	return true


func _drop_meteor(center: Vector2) -> void:
	var d: Dictionary = Defs.SPELLS["meteors"]
	var target := center + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * float(d["r"])
	var p := Projectile.new()
	p.kind = "meteor"
	p.dmg = float(d["dmg"])
	p.dtype = "pure"
	p.splash = float(d["boom"])
	p.boom_color = Color("ff8a3a")
	Game.proj_root.add_child(p)
	p.launch_shell(target + Vector2(140, -380), target, 0.6)


# ---------- рисование: круг-подсказка под мышью ----------

func _draw() -> void:
	if armed == "":
		return
	var mouse := get_global_mouse_position()
	if mouse.x < -50.0:
		return
	var d: Dictionary = Defs.SPELLS[armed]
	if d["aim"] == "area":
		Art.dashed_circle(self, mouse, float(d["r"]), Color(1.0, 0.75, 0.35, 0.95))
	else:
		var near := Game.road_nearest(mouse)
		var ok := float(near["dist"]) <= 70.0
		var at: Vector2 = near["pos"] if ok else mouse
		Art.dashed_circle(self, at, 26.0, Color(0.67, 0.8, 1.0, 0.95) if ok else Color(1.0, 0.43, 0.35, 0.95))
