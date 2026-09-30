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
var _phase := 0.0       # фаза шага для рисунка
var _sprite: AnimatedSprite2D = null   # настоящая картинка бойца, если она есть (assets/art)
var _moving := false
var _last_pos := Vector2.ZERO


func _ready() -> void:
	add_to_group("soldiers")
	_setup_art()


## Папка с настоящими анимациями этого бойца (у героя другая).
func _art_dir() -> String:
	return "soldiers/knight"


## Куда ставить ноги настоящего спрайта (у летающих героев выше земли).
func _art_feet() -> Vector2:
	return Vector2(0, radius * 0.8)


func _setup_art() -> void:
	_sprite = ArtPack.make_sprite(_art_dir(), _art_feet())
	if _sprite != null:
		add_child(_sprite)
		if temp and color != Color("4a78c4"):
			_sprite.modulate = color.lightened(0.55)   # призванные орки и духи окрашиваются


## Настоящая анимация: куда смотрит, стоит, идёт или бьёт.
func _update_sprite() -> void:
	_sprite.visible = not dead
	_sprite.flip_h = face < 0.0
	if _swing > 0.0:
		ArtPack.play(_sprite, "attack")
	elif _moving:
		ArtPack.play(_sprite, "walk")
	else:
		ArtPack.play(_sprite, "idle")
	if _hurt > 0.0:
		_sprite.modulate = Color(2.2, 2.2, 2.2)
	elif temp and color != Color("4a78c4"):
		_sprite.modulate = color.lightened(0.55)
	else:
		_sprite.modulate = Color.WHITE


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
	_moving = position.distance_to(_last_pos) > 0.05
	if _moving:
		_phase += delta * 11.0
	_last_pos = position
	if _sprite != null:
		_update_sprite()
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
	if _sprite != null:
		Art.blob_shadow(self, Vector2(0, r * 0.85), r * 1.25)
		if hp < max_hp:
			Art.hp_bar(self, 0.0, _sprite.position.y - float(_sprite.get_meta("height")) - 4.0, 20.0, hp / max_hp, Color("59c46a"))
		return
	var f := face
	var step := _phase
	Art.blob_shadow(self, Vector2(0, r * 0.85), r * 1.25)
	# ноги шагают, пока боец идёт
	Art.leg(self, Vector2(-r * 0.3, r * 0.1), step + PI, r * 0.7, Color("4a4f5c"), r * 0.42)
	Art.leg(self, Vector2(r * 0.3, r * 0.1), step, r * 0.7, Color("4a4f5c"), r * 0.42)
	var body := Color.WHITE if _hurt > 0.0 else color
	# щит за спиной
	Art.outlined_poly(self, [Vector2(-f * (r + 1) - 4, -r * 0.9), Vector2(-f * (r + 1) + 4, -r * 0.9), Vector2(-f * (r + 1) + 4, r * 0.2), Vector2(-f * (r + 1), r * 0.6), Vector2(-f * (r + 1) - 4, r * 0.2)], Color("e2b53c"), 1.3)
	Art.outlined_circle(self, Vector2(0, -r * 0.1), r, body, 1.6)
	_draw_helmet(r)
	var swing := 1.0 if _swing > 0.0 else 0.0
	var hand := Vector2(f * (r - 2), 2)
	var tip := Vector2(f * (r + 12 + swing * 5), -9 + swing * 11)
	Art.outlined_line(self, hand, tip, Color("e9edf2"), 2.4, 1.2)
	Art.outlined_circle(self, hand, 2.4, Color("d8dbe3"), 1.0)
	if hp < max_hp:
		Art.hp_bar(self, 0.0, -r - 12.0, 20.0, hp / max_hp, Color("59c46a"))


## Шлем с плюмажем и прорезью для глаз.
func _draw_helmet(r: float) -> void:
	Art.half_disc(self, Vector2(0, -r * 0.3), r * 0.92, Color("c4c9d4"))
	draw_arc(Vector2(0, -r * 0.3), r * 0.92, PI, TAU, 14, Art.OUTLINE, 1.5, true)
	draw_rect(Rect2(-r * 0.5, -r * 0.45, r, 2.4), Color("2a2a33"))
	Art.outlined_poly(self, [Vector2(-2.5, -r * 1.15), Vector2(0, -r * 1.75), Vector2(3.5, -r * 1.1)], Color("d8493a"), 1.0)
