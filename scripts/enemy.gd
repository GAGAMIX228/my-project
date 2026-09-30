class_name Enemy
extends PathFollow2D
## Один орк. Он идёт по дороге (Path2D), получает урон и сам себя рисует.

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
var regen := 0.0          # сколько здоровья в секунду возвращает, если его не бьют (тролль)
var shot_range := 0.0     # дальность выстрела по бойцам и героям (лучник), 0 значит не стреляет
var shot_dmg := 0.0
var shot_rate := 1.7
var aura := 0.0           # радиус, в котором орки рядом идут быстрее (знаменосец)
var buffed := false       # рядом знаменосец: идёт быстрее
var healing := false      # сейчас лечится (для рисунка)
var phase := 0.0
var face := 1.0
var _heal_timer := 1.5
var _since_hit := 99.0
var _shot_cd := 1.0
var _buff_timer := 0.0
var _sprite: AnimatedSprite2D = null   # настоящая картинка врага (assets/art/enemies/<тип>), если она есть
var _fighting := false
var _atk_cd := 0.5
var _last_x := 0.0


func setup(enemy_type: String) -> void:
	type = enemy_type
	var def: Dictionary = Defs.ENEMIES[type]
	max_hp = float(def["hp"]) * Defs.hp_scale
	hp = max_hp
	speed = float(def["speed"])
	armor = float(def["armor"])
	mres = float(def["mres"])
	gold = int(def["gold"])
	radius = float(def["radius"])
	leak = int(def["leak"])
	flying = bool(def["fly"])
	regen = float(def.get("regen", 0.0))
	shot_range = float(def.get("range", 0.0))
	shot_dmg = float(def.get("shot_dmg", 0.0))
	shot_rate = float(def.get("shot_rate", 1.7))
	aura = float(def.get("aura", 0.0))
	phase = randf() * 6.0


func _ready() -> void:
	rotates = false
	loop = false
	progress = 0.0
	add_to_group("enemies")
	_last_x = global_position.x
	_setup_art()


## Если для этого врага есть настоящая анимация, ставим её вместо рисования кодом.
func _setup_art() -> void:
	var lift := -24.0 if flying else 0.0
	_sprite = ArtPack.make_sprite("enemies/%s" % type, Vector2(0, radius * 0.85 + lift))
	if _sprite != null:
		add_child(_sprite)


## Обновляет настоящую анимацию: куда смотрит, идёт или дерётся, вспышка и заморозка.
func _update_sprite() -> void:
	_sprite.flip_h = face < 0.0
	if stun > 0.0:
		_sprite.pause()
	elif _fighting:
		ArtPack.play(_sprite, "attack")
	else:
		ArtPack.play(_sprite, "walk")
		_sprite.speed_scale = 1.3 if buffed else 1.0
	var tint: Color = _sprite.get_meta("tint", Color.WHITE)
	if flash > 0.0:
		_sprite.modulate = Color(2.2, 2.2, 2.2)
	elif ice > 0.0:
		_sprite.modulate = Color(0.7, 0.9, 1.25) * tint
	else:
		_sprite.modulate = tint


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
	_since_hit = 0.0
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
	if _sprite != null:
		_update_sprite()
	if flash > 0.0:
		flash -= delta
	if ice > 0.0:
		ice -= delta
	if burn > 0.0:
		burn -= delta
		take_damage(burn_dps * delta, "magic", true)
		if dead:
			return
	_since_hit += delta
	if type == "shaman":
		_heal_allies(delta)
	_regenerate(delta)
	_update_buff(delta)
	if shot_range > 0.0 and stun <= 0.0:
		_shoot_defenders(delta)
	if stun > 0.0:
		stun -= delta
	elif _fight(delta):
		queue_redraw()
		return
	else:
		var enraged := type == "berserk" and hp < max_hp * 0.5
		progress += speed * (1.7 if enraged else 1.0) * (1.3 if buffed else 1.0) * delta
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
	_fighting = false
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
	_fighting = true
	return true


## Тролль: если его 2,5 секунды не били, здоровье возвращается.
func _regenerate(delta: float) -> void:
	healing = regen > 0.0 and _since_hit > 2.5 and hp < max_hp
	if healing:
		hp = minf(max_hp, hp + regen * delta)


## Раз в 0,3 секунды проверяем, есть ли рядом знаменосец.
func _update_buff(delta: float) -> void:
	_buff_timer -= delta
	if _buff_timer > 0.0:
		return
	_buff_timer = 0.3
	buffed = false
	for e in Game.enemies():
		if e != self and e.aura > 0.0 and e.global_position.distance_to(global_position) <= e.aura:
			buffed = true
			return


## Лучник: стреляет по ближайшему бойцу или герою в радиусе и продолжает идти.
func _shoot_defenders(delta: float) -> void:
	_shot_cd -= delta
	if _shot_cd > 0.0:
		return
	var best: Soldier = null
	var best_d := shot_range
	for group in ["soldiers", "heroes"]:
		for node in get_tree().get_nodes_in_group(group):
			var unit := node as Soldier
			if unit == null or unit.dead:
				continue
			var d := unit.position.distance_to(global_position)
			if d < best_d:
				best = unit
				best_d = d
	if best == null:
		_shot_cd = 0.3
		return
	_shot_cd = shot_rate
	face = 1.0 if best.position.x >= global_position.x else -1.0
	var p := Projectile.new()
	p.kind = "arrow"
	p.dmg = shot_dmg
	p.dtype = "phys"
	p.speed = 380.0
	p.enemy_shot = true
	Game.proj_root.add_child(p)
	p.launch_homing(global_position + Vector2(0, -10), best)


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

func _draw() -> void:
	var r := radius
	var lift := -24.0 if flying else 0.0
	var enraged := type == "berserk" and hp < max_hp * 0.5
	var top := lift - r * 1.75   # над головой, сюда ставим полоску здоровья
	if _sprite != null:
		Art.blob_shadow(self, Vector2(0, r * 0.85), r * 1.15)
		top = _sprite.position.y - float(_sprite.get_meta("height")) - 2.0
		EnemyArt.sprite_effects(self, r, Vector2(0, r * 0.85 + lift), top, phase, enraged, buffed, healing, aura)
	else:
		EnemyArt.draw(self, type, r, face, phase, flash > 0.0, enraged, buffed, healing, aura)
	# головы находятся примерно на 1.55·r над центром врага
	if ice > 0.0 and _sprite == null:
		draw_circle(Vector2(0, lift - r * 0.4), r * 1.35, Color(0.66, 0.89, 1.0, 0.5))
	if stun > 0.0 and ice <= 0.0:
		for i in 3:
			var a := phase * 5.0 + i * 2.1
			draw_circle(Vector2(cos(a) * 9.0, top + 4.0 + sin(a) * 3.0), 2.4, Color("ffe27a"))
	if burn > 0.0:
		Art.tri(self, Vector2(-4, lift - r * 0.3), Vector2(0, lift - r * 1.5 - sin(phase * 14.0) * 2.0), Vector2(4, lift - r * 0.3), Color(1.0, 0.54, 0.16, 0.8))
	if hp < max_hp:
		var bar := Color("e0523f") if type == "chief" else Color("d94a3a")
		Art.hp_bar(self, 0.0, top - 4.0, maxf(20.0, r * 2.0), hp / max_hp, bar)
