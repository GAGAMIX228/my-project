class_name Soldier
extends Node2D
## Боец. Стоит на своём месте (post), перехватывает орков, которые проходят рядом,
## останавливает их и дерётся. Если погибает, через несколько секунд возвращается.
## Бывает временным (призыв рыцарей, духи): такой исчезает, когда кончается время или он погиб.
## От этого класса наследуется Hero.

var owner_tower: Tower
var hp := 70.0
var max_hp := 70.0
var dmg := 6.0
var rate := 0.85
var engage := 85.0   # на каком расстоянии от своего места он замечает врагов
var speed := 95.0
var post := Vector2.ZERO
var color := Color("4a78c4")
var dead := false
var respawn := 0.0
var respawn_time := 9.0
var regen := 2.0     # сколько здоровья в секунду он возвращает, когда не дерётся
var temp := false    # временный боец
var life := 0.0      # сколько секунд осталось жить временному бойцу
var target: Enemy = null
var face := 1.0
var radius := 9.0

var _cd := 0.0
var _swing := 0.0
var _hurt := 0.0


func _ready() -> void:
	add_to_group("soldiers")


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	_hurt = 0.12
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	_drop_target()
	Fx.ring(position, 18.0, Color("9db8ff"), 0.3)
	if temp:
		queue_free()
		return
	respawn = respawn_time
	visible = false


func _drop_target() -> void:
	if is_instance_valid(target) and target.blocker == self:
		target.blocker = null
	target = null


func _process(delta: float) -> void:
	if _hurt > 0.0:
		_hurt -= delta
	if _swing > 0.0:
		_swing -= delta
	_tick(delta)
	if dead:
		respawn -= delta
		if respawn <= 0.0:
			dead = false
			hp = max_hp
			position = post
			visible = true
			Fx.ring(position, 20.0, Color("bcd4ff"), 0.35)
		return
	if temp:
		life -= delta
		if life <= 0.0:
			_drop_target()
			Fx.ring(position, 16.0, color, 0.3)
			queue_free()
			return
	_act(delta)
	queue_redraw()


## Что-то, что нужно делать каждый кадр, даже когда боец мёртв (у героя это перезарядка).
func _tick(_delta: float) -> void:
	pass


## Сколько урона наносит удар и через сколько секунд следующий: x это урон, y это пауза.
func _melee_stats() -> Vector2:
	return Vector2(dmg, rate)


## Поведение бойца: заметить врага, подойти и ударить, а если врага нет, вернуться на место.
func _act(delta: float) -> void:
	_cd -= delta
	if target != null:
		if not is_instance_valid(target) or target.dead or target.blocker != self \
				or target.global_position.distance_to(post) > engage * 1.7:
			_drop_target()
	if target == null:
		_find_target()
	if target != null:
		var to_enemy := target.global_position - position
		var d := to_enemy.length()
		face = signf(to_enemy.x) if absf(to_enemy.x) > 0.1 else face
		if d > 22.0:
			position += to_enemy / d * minf(d - 20.0, speed * delta)
		elif _cd <= 0.0:
			var stats := _melee_stats()
			_cd = stats.y
			_swing = 0.18
			target.take_damage(stats.x, "phys")
	else:
		_walk_to_post(delta)
		hp = minf(max_hp, hp + regen * delta)


func _walk_to_post(delta: float) -> void:
	var to_post := post - position
	var d := to_post.length()
	if d > 1.5:
		position += to_post / d * minf(d, speed * delta)
		face = signf(to_post.x) if absf(to_post.x) > 0.1 else face


func _find_target() -> void:
	var best: Enemy = null
	var best_d := 1e9
	for e in Game.enemies():
		if e.flying:
			continue
		if e.blocker != null and is_instance_valid(e.blocker) and not e.blocker.dead:
			continue
		var d := e.global_position.distance_to(post)
		if d < engage and d < best_d:
			best = e
			best_d = d
	if best != null:
		target = best
		best.blocker = self


func _draw() -> void:
	var r := radius
	Art.ellipse(self, Vector2(0, r * 0.8), r, r * 0.4, Color(0, 0, 0, 0.25))
	var body := Color.WHITE if _hurt > 0.0 else color
	draw_circle(Vector2(0, -2), r, body)
	draw_arc(Vector2(0, -2), r, 0.0, TAU, 20, Color("22386b"), 1.3, true)
	draw_arc(Vector2(0, -4), r * 0.82, PI, TAU, 14, Color("b7bcc8"), r * 0.5)
	draw_rect(Rect2(-2, -4, 4, 5), Color("2a2a33"))
	draw_rect(Rect2(-face * (r + 1) - 3, -6, 6, 11), Color("e2b53c"))
	var swing := 1.0 if _swing > 0.0 else 0.0
	draw_line(Vector2(face * (r - 2), 2), Vector2(face * (r + 11 + swing * 4), -8 + swing * 10), Color("e9edf2"), 2.4)
	if hp < max_hp:
		Art.hp_bar(self, 0.0, -r - 8.0, 20.0, hp / max_hp, Color("59c46a"))
