class_name Tower
extends Node2D
## Башня. Сама находит врага в радиусе, стреляет и рисует себя.

var kind := "archer"
var level := 1  # от 1 до 3
var invested := 0  # сколько золота вложено (для продажи)
var show_range := false
var show_level := true   # жёлтые точки уровня под башней
var rally := Vector2.ZERO           # только у казармы: куда встают бойцы
var soldiers: Array[Soldier] = []   # только у казармы
var _cd := 0.3
var _angle := -1.2
var _recoil := 0.0
var _time := 0.0


func setup(tower_kind: String) -> void:
	kind = tower_kind
	invested = int(Defs.TOWERS[kind]["cost"])


func stat() -> Dictionary:
	return Defs.TOWERS[kind]["levels"][level - 1]


## Цена следующего улучшения или -1, если уровень уже максимальный.
func upgrade_cost() -> int:
	if level >= 3:
		return -1
	return int(Defs.TOWERS[kind]["upgrades"][level - 1])


func upgrade() -> void:
	invested += upgrade_cost()
	level += 1
	if kind == "barracks":
		_sync_soldiers()


func sell_value() -> int:
	return roundi(invested * 0.7)


## Вызывается после того, как башня поставлена на карту. Казарма здесь создаёт бойцов.
func activate() -> void:
	if kind != "barracks":
		return
	rally = Game.road.get_closest_point(position)
	_sync_soldiers()


## Убирает башню вместе с её бойцами.
func dispose() -> void:
	for s in soldiers:
		if is_instance_valid(s):
			s.queue_free()
	queue_free()


## Перемещает бойцов казармы. Точка не может быть дальше круга действия.
func set_rally(point: Vector2) -> void:
	var offset := point - position
	var limit := float(stat()["range"]) - 6.0
	if offset.length() > limit:
		point = position + offset.normalized() * limit
	rally = Vector2(clampf(point.x, 14.0, Defs.VIEW.x - 14.0), clampf(point.y, 14.0, Defs.VIEW.y - 14.0))
	_place_posts()
	Fx.ring(rally, 20.0, Color("8fc0ff"), 0.35)


func _sync_soldiers() -> void:
	var s := stat()
	while soldiers.size() < int(s["n"]):
		var soldier := Soldier.new()
		soldier.owner_tower = self
		soldier.position = position + Vector2(0, 8)
		Game.units_root.add_child(soldier)
		soldiers.append(soldier)
	for soldier in soldiers:
		soldier.max_hp = float(s["hp"])
		soldier.hp = soldier.max_hp
		soldier.dmg = float(s["dmg"])
		soldier.rate = float(s["rate"])
	_place_posts()


func _place_posts() -> void:
	var offsets := [Vector2(-13, 0), Vector2(13, 0)]
	if soldiers.size() == 3:
		offsets = [Vector2(-19, 5), Vector2(0, -8), Vector2(19, 5)]
	for i in soldiers.size():
		soldiers[i].post = rally + offsets[i]


func _process(delta: float) -> void:
	_time += delta
	if _recoil > 0.0:
		_recoil -= delta
	if kind == "barracks":
		queue_redraw()
		return
	_cd -= delta
	if _cd <= 0.0:
		var s := stat()
		var enemy := _pick_target(s)
		if enemy != null:
			_fire(enemy, s)
	queue_redraw()


## Выбирает врага в радиусе, который ушёл по дороге дальше всех.
func _pick_target(s: Dictionary) -> Enemy:
	var best: Enemy = null
	var min_range: float = s.get("min_range", 0.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		if kind == "mortar" and e.flying:
			continue
		var d := global_position.distance_to(e.aim_point())
		if d <= float(s["range"]) and d >= min_range and (best == null or e.progress > best.progress):
			best = e
	return best


func _fire(enemy: Enemy, s: Dictionary) -> void:
	_cd = float(s["rate"])
	_recoil = 0.15
	_angle = (enemy.aim_point() - global_position).angle()
	var p := Projectile.new()
	p.kind = "shell" if kind == "mortar" else ("arrow" if kind == "archer" else "orb")
	p.dmg = float(s["dmg"])
	Game.proj_root.add_child(p)
	match kind:
		"archer":
			p.dtype = "phys"
			p.speed = 520.0
			p.launch_homing(global_position + Vector2(0, -26), enemy)
		"mage":
			p.dtype = "magic"
			p.speed = 340.0
			p.launch_homing(global_position + Vector2(0, -40), enemy)
		"mortar":
			p.dtype = "phys"
			p.splash = float(s["splash"])
			p.launch_shell(global_position + Vector2(0, -12), enemy.predict(0.9), 0.9)


# ---------- рисование ----------

func _draw() -> void:
	if show_range:
		var range_px: float = stat()["range"]
		if kind == "barracks":
			# синий круг: внутри него можно переставлять бойцов
			draw_circle(Vector2.ZERO, range_px, Color(0.5, 0.71, 1.0, 0.13))
			Art.dashed_circle(self, Vector2.ZERO, range_px, Color(0.55, 0.75, 1.0, 0.95))
			var flag := rally - position
			Art.dashed_circle(self, flag, 20.0, Color(1, 1, 1, 0.7), 2.0)
			draw_line(flag + Vector2(0, 4), flag + Vector2(0, -24), Color("3d2614"), 2.0)
			Art.tri(self, flag + Vector2(0, -24), flag + Vector2(15, -19), flag + Vector2(0, -13), Color("2f6fc0"))
		else:
			draw_circle(Vector2.ZERO, range_px, Color(1, 1, 1, 0.14))
			draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 72, Color(1, 1, 1, 0.7), 2.0, true)
	Art.ellipse(self, Vector2(0, 5), 23, 10, Color(0, 0, 0, 0.25))
	match kind:
		"archer":
			_draw_archer()
		"barracks":
			_draw_barracks()
		"mage":
			_draw_mage()
		"mortar":
			_draw_mortar()
	if show_level:
		for i in level:
			draw_circle(Vector2(-(level - 1) * 5.0 + i * 10.0, 13), 3.0, Color("f4c542"))


func _draw_archer() -> void:
	Art.rect(self, -12, -28, 24, 32, Color("8a5a32"))
	Art.rect(self, -12, -28, 24, 7, Color("a8703e"))
	Art.tri(self, Vector2(-19, -28), Vector2(0, -48), Vector2(19, -28), Color("b8442e"))
	Art.tri(self, Vector2(-19, -28), Vector2(0, -48), Vector2(-6, -28), Color("cf5a40"))
	var look := Vector2(cos(_angle), sin(_angle))
	draw_circle(Vector2(look.x * 4.0, -33), 4.2, Color("f2d2a4"))
	draw_arc(Vector2(look.x * 9.0, -33 + look.y * 4.0), 5.0, _angle - 1.2, _angle + 1.2, 10, Color("4b2f14"), 1.6)


func _draw_mage() -> void:
	Art.rect(self, -12, -38, 24, 42, Color("6a54b8"))
	Art.rect(self, -12, -38, 8, 42, Color("8470d0"))
	Art.tri(self, Vector2(-17, -38), Vector2(0, -62), Vector2(17, -38), Color("3e2f86"))
	Art.tri(self, Vector2(-17, -38), Vector2(0, -62), Vector2(-5, -38), Color("5641a8"))
	var pulse := 5.0 + sin(_time * 4.0) * 1.2
	draw_circle(Vector2(0, -50), pulse + 6.0, Color(0.85, 0.76, 1.0, 0.28))
	draw_circle(Vector2(0, -50), pulse, Color("c9a6ff"))
	Art.rect(self, -4, -16, 8, 14, Color("2b2058"))


func _draw_mortar() -> void:
	Art.ellipse(self, Vector2(0, -6), 20, 12, Color("4d4a52"))
	Art.ellipse(self, Vector2(0, -10), 20, 12, Color("66636c"))
	var kick := _recoil * 10.0 if _recoil > 0.0 else 0.0
	draw_set_transform(Vector2(0, -14), _angle, Vector2.ONE)
	draw_rect(Rect2(-4 - kick, -6, 30, 12), Color("2f2d33"))
	draw_rect(Rect2(20 - kick, -8, 8, 16), Color("1f1e23"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, -14), 8.0, Color("54515a"))


func _draw_barracks() -> void:
	Art.rect(self, -20, -24, 40, 28, Color("9a9488"))
	Art.rect(self, -20, -24, 14, 28, Color("b3ad9f"))
	for i in 4:
		Art.rect(self, -20 + i * 11, -31, 8, 8, Color("7c776c"))
	Art.rect(self, -6, -12, 12, 16, Color("4a2f1a"))
	draw_line(Vector2(14, -31), Vector2(14, -50), Color("3d2614"), 2.0)
	Art.tri(self, Vector2(14, -50), Vector2(30, -45), Vector2(14, -39), Color("2f6fc0"))
