class_name Enemy
extends PathFollow2D
## Один орк. Он идёт по дороге (Path2D), получает урон и сам себя рисует.

const BODY := {
	"grunt": Color("5f9440"), "raider": Color("7fae4c"), "shield": Color("4c7d36"),
	"berserk": Color("6f9a3a"), "shaman": Color("5a8a44"), "warlock": Color("5f9440"),
	"gryph": Color("5f9440"), "chief": Color("3e6a2c"),
}

var type := "grunt"
var hp := 1.0
var max_hp := 1.0
var speed := 50.0
var armor := 0.0
var mres := 0.0
var gold := 0
var radius := 11.0
var leak := 1
var flying := false
var atk := 5.0
var blocker: Soldier = null   # боец, который держит этого орка
var dead := false
var stun := 0.0       # пока больше нуля, враг стоит на месте
var flash := 0.0      # короткая белая вспышка при попадании
var ice := 0.0        # пока больше нуля, враг заморожен (стоит и голубеет)
var burn := 0.0       # оставшееся время горения
var burn_dps := 0.0
var phase := 0.0
var face := 1.0
var _heal_timer := 1.5
var _atk_cd := 0.5
var _last_x := 0.0
var _origin := Vector2.ZERO


func setup(enemy_type: String) -> void:
	type = enemy_type
	var def: Dictionary = Defs.ENEMIES[type]
	max_hp = float(def["hp"]) * Defs.hp_scale * Game.hp_mult()
	hp = max_hp
	speed = float(def["speed"])
	armor = float(def["armor"])
	mres = float(def["mres"])
	gold = int(def["gold"])
	radius = float(def["radius"])
	leak = int(def["leak"])
	flying = bool(def["fly"])
	phase = randf() * 6.0


func _ready() -> void:
	rotates = false
	loop = false
	progress = 0.0
	add_to_group("enemies")
	_last_x = global_position.x


## Куда целиться: у летающих врагов центр выше земли.
func aim_point() -> Vector2:
	return global_position + Vector2(0, -24) if flying else global_position


## Где враг будет через dur секунд (мортира стреляет с упреждением).
func predict(dur: float) -> Vector2:
	if stun > 0.0:
		return global_position
	var road := get_parent() as Path2D
	var offset := minf(progress + speed * dur, road.curve.get_baked_length())
	return road.to_global(road.curve.sample_baked(offset))


func take_damage(amount: float, dtype: String, quiet := false) -> void:
	if dead:
		return
	var d := amount
	if dtype == "phys":
		d *= 1.0 - armor
	elif dtype == "magic":
		d *= 1.0 - mres
	hp -= d
	if not quiet:
		flash = 0.09
	if hp <= 0.0:
		_die()


## Оглушает врага не меньше чем на seconds секунд.
func stun_for(seconds: float) -> void:
	stun = maxf(stun, seconds)


## Замораживает: враг стоит и голубеет.
func freeze_for(seconds: float) -> void:
	stun_for(seconds)
	ice = maxf(ice, seconds)


## Отбрасывает назад по дороге.
func push_back(distance: float) -> void:
	progress = maxf(0.0, progress - distance)


## Поджигает: враг получает magic-урон burn_dps в секунду, пока горит.
func ignite(seconds: float, dps: float) -> void:
	burn = seconds
	burn_dps = dps


func _die() -> void:
	dead = true
	Game.add_gold(gold)
	Game.kills += 1
	Fx.float_text(aim_point() + Vector2(0, -radius - 8), "+%d" % gold)
	remove_from_group("enemies")
	queue_free()


func _escape() -> void:
	dead = true
	Game.lose_life(leak)
	Game.message.emit("Орк прорвался: −%d" % leak)
	Fx.ring(global_position + Vector2(-30, 0), 30.0, Color("ff6a5a"), 0.5)
	remove_from_group("enemies")
	queue_free()


func _process(delta: float) -> void:
	if dead:
		return
	phase += delta
	if flash > 0.0:
		flash -= delta
	if ice > 0.0:
		ice -= delta
	if burn > 0.0:
		burn -= delta
		take_damage(burn_dps * delta, "magic", true)
		if dead:
			return
	if type == "shaman":
		_heal_allies(delta)
	if stun > 0.0:
		stun -= delta
	elif _fight(delta):
		queue_redraw()
		return
	else:
		var enraged := type == "berserk" and hp < max_hp * 0.5
		progress += speed * (1.7 if enraged else 1.0) * delta
		if progress_ratio >= 1.0:
			_escape()
			return
	var dx := global_position.x - _last_x
	if absf(dx) > 0.01:
		face = signf(dx)
	_last_x = global_position.x
	queue_redraw()


## Если путь преградил боец, орк останавливается и дерётся с ним. Возвращает true, пока идёт бой.
func _fight(delta: float) -> bool:
	if flying or blocker == null:
		return false
	if not is_instance_valid(blocker) or blocker.dead:
		blocker = null
		return false
	if blocker.position.distance_to(global_position) >= 28.0:
		return false  # боец ещё подходит, орк пока идёт
	var enraged := type == "berserk" and hp < max_hp * 0.5
	face = -1.0 if blocker.position.x < global_position.x else 1.0
	_atk_cd -= delta
	if _atk_cd <= 0.0:
		_atk_cd = 0.7 if enraged else 1.0
		blocker.take_damage(atk * (1.5 if enraged else 1.0))
	return true


func _heal_allies(delta: float) -> void:
	_heal_timer -= delta
	if _heal_timer > 0.0:
		return
	_heal_timer = 2.4
	var healed := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other == null or other == self or other.dead:
			continue
		if other.hp < other.max_hp and other.global_position.distance_to(global_position) < 100.0:
			other.hp = minf(other.max_hp, other.hp + other.max_hp * 0.12)
			healed = true
	if healed:
		Fx.ring(global_position, 100.0, Color("7bd88f"), 0.5)


# ---------- рисование ----------

func _p(x: float, y: float) -> Vector2:
	return _origin + Vector2(x, y)


func _circ(x: float, y: float, r: float, color: Color) -> void:
	draw_circle(_p(x, y), r, color)


func _tri(x1: float, y1: float, x2: float, y2: float, x3: float, y3: float, color: Color) -> void:
	Art.tri(self, _p(x1, y1), _p(x2, y2), _p(x3, y3), color)


func _draw() -> void:
	var r := radius
	var f := face
	var bob := sin(phase * 6.0) * 1.6
	var lift := -24.0 if flying else 0.0
	_origin = Vector2(0, bob + lift)
	Art.ellipse(self, Vector2(0, r * 0.85), r * 1.05, r * 0.42, Color(0, 0, 0, 0.28))
	var body: Color = Color.WHITE if flash > 0.0 else BODY.get(type, Color("5f9440"))
	if type == "gryph":
		_draw_gryph(r, f, body)
	else:
		_draw_orc(r, f, body)
	if ice > 0.0:
		draw_circle(Vector2(0, lift - r * 0.25), r * 1.15, Color(0.66, 0.89, 1.0, 0.5))
	if stun > 0.0 and ice <= 0.0:
		for i in 3:
			var a := phase * 5.0 + i * 2.1
			draw_circle(Vector2(cos(a) * 9.0, lift - r * 1.5 + sin(a) * 3.0), 2.4, Color("ffe27a"))
	if burn > 0.0:
		Art.tri(self, Vector2(-4, lift - r * 0.3), Vector2(0, lift - r * 1.5 - sin(phase * 14.0) * 2.0), Vector2(4, lift - r * 0.3), Color(1.0, 0.54, 0.16, 0.8))
	if hp < max_hp:
		var bar := Color("e0523f") if type == "chief" else Color("d94a3a")
		Art.hp_bar(self, 0.0, lift - r - 12.0 + bob, maxf(20.0, r * 2.0), hp / max_hp, bar)


func _draw_gryph(r: float, f: float, body: Color) -> void:
	var wing := sin(phase * 13.0)
	var wing_col := Color("a37f4a")
	_tri(-r * 0.3, 2, -r * 2.3, -10 - wing * 9, -r * 0.4, 9, wing_col)
	_tri(r * 0.3, 2, r * 2.3, -10 - wing * 9, r * 0.4, 9, wing_col)
	Art.ellipse(self, _p(0, 6), r * 1.3, r * 0.7, Color.WHITE if flash > 0.0 else Color("8a6a3c"))
	_circ(f * r * 1.15, 4, r * 0.48, Color("8a6a3c"))
	_tri(f * r * 1.5, 3, f * r * 2.1, 5, f * r * 1.5, 8, Color("e8c04a"))
	_circ(0, -r * 0.5, r * 0.75, body)
	_circ(-r * 0.28, -r * 0.6, r * 0.2, Color.WHITE)
	_circ(r * 0.28, -r * 0.6, r * 0.2, Color.WHITE)
	_circ(-r * 0.28 + f, -r * 0.6, r * 0.09, Color("b01818"))
	_circ(r * 0.28 + f, -r * 0.6, r * 0.09, Color("b01818"))


func _draw_orc(r: float, f: float, body: Color) -> void:
	var hooded := type == "warlock" or type == "shaman"
	var er := r * 0.72 if hooded else r
	var white := flash > 0.0
	if type == "shield" or type == "chief":
		Art.rect(self, _origin.x + f * (r * 0.55) - 4.0, _origin.y - r * 0.9, 9.0, r * 1.5, Color("8b8f99"))
	if type == "warlock":
		_tri(-r * 1.1, r * 0.9, 0, -r * 1.2, r * 1.1, r * 0.9, Color.WHITE if white else Color("4f3f86"))
	if type == "shaman":
		_tri(-r * 1.05, r * 0.9, 0, -r * 1.1, r * 1.05, r * 0.9, Color.WHITE if white else Color("6b4a2e"))
	_circ(0, -r * 0.25, er, body)
	if type == "raider":
		Art.rect(self, _origin.x - r, _origin.y - r * 0.85, r * 2.0, 3.5, Color("b8342a"))
	if type == "berserk":
		var paint := Color("c2483a")
		draw_line(_p(-r * 0.8, -r * 0.8), _p(-r * 0.3, -r * 0.1), paint, 2.2)
		draw_line(_p(r * 0.8, -r * 0.8), _p(r * 0.3, -r * 0.1), paint, 2.2)
		_tri(-r * 0.35, -r * 1.15, 0, -r * 1.9, r * 0.35, -r * 1.15, paint)
	if type == "chief":
		draw_arc(_p(0, -r * 0.5), r * 0.95, PI, TAU, 16, Color("7a7d86"), r * 0.5)
		_tri(-r, -r * 0.6, -r - 6, -r * 1.6, -r * 0.55, -r * 1.05, Color("e9e2cc"))
		_tri(r, -r * 0.6, r + 6, -r * 1.6, r * 0.55, -r * 1.05, Color("e9e2cc"))
	# глаза
	var pupil := Color("c48bff") if type == "warlock" else Color("b01818")
	_circ(-er * 0.35, -er * 0.3, er * 0.22, Color.WHITE)
	_circ(er * 0.35, -er * 0.3, er * 0.22, Color.WHITE)
	_circ(-er * 0.35 + f, -er * 0.3, er * 0.1, pupil)
	_circ(er * 0.35 + f, -er * 0.3, er * 0.1, pupil)
	if not hooded:
		_tri(-r * 0.3, r * 0.1, -r * 0.12, r * 0.1, -r * 0.22, -r * 0.18, Color("f3efe0"))
		_tri(r * 0.3, r * 0.1, r * 0.12, r * 0.1, r * 0.22, -r * 0.18, Color("f3efe0"))
	# оружие
	if type == "shaman":
		draw_line(_p(f * r * 1.1, r * 0.9), _p(f * r * 1.1, -r * 1.3), Color("6b4a2e"), 2.4)
		_circ(f * r * 1.1, -r * 1.5, 4.0, Color("6ff0b0"))
	elif type == "warlock":
		var a := phase * 3.0
		_circ(cos(a) * r * 1.3, -r * 0.4 + sin(a) * 4.0, 3.4, Color("c48bff"))
	else:
		var steel := Color("9aa0a8")
		draw_line(_p(-f * r * 0.9, r * 0.2), _p(-f * r * 1.5, -r * 0.9), Color("4a3220"), 2.6)
		_tri(-f * r * 1.5, -r * 0.9, -f * r * 1.9, -r * 0.7, -f * r * 1.4, -r * 1.3, steel)
		if type == "berserk":
			draw_line(_p(f * r * 0.9, r * 0.2), _p(f * r * 1.5, -r * 0.9), Color("4a3220"), 2.6)
			_tri(f * r * 1.5, -r * 0.9, f * r * 1.9, -r * 0.7, f * r * 1.4, -r * 1.3, steel)
