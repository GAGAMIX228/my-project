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
var _art: Sprite2D = null              # настоящая картинка башни (assets/art/towers/<вид>_<уровень>.png)
var _shoot_art: AnimatedSprite2D = null   # анимация выстрела (towers/<вид>_<уровень>_shoot/shoot_00.png ...)


func setup(tower_kind: String) -> void:
	kind = tower_kind
	invested = int(Defs.TOWERS[kind]["cost"])


func _ready() -> void:
	_refresh_art()


## Ставит настоящую картинку текущего уровня, если она есть. Иначе башня рисует себя кодом.
func _refresh_art() -> void:
	if _art != null:
		_art.queue_free()
		_art = null
	if _shoot_art != null:
		_shoot_art.queue_free()
		_shoot_art = null
	var tex := ArtPack.texture("towers/%s_%d.png" % [kind, level])
	if tex == null:
		return
	var scale_value := 0.5
	_art = Sprite2D.new()
	_art.texture = tex
	_art.scale = Vector2(scale_value, scale_value)
	_art.offset = Vector2(0, -tex.get_height() * 0.5)   # низ картинки стоит на площадке
	_art.position = Vector2(0, 6)
	add_child(_art)
	var dir := "towers/%s_%d_shoot" % [kind, level]
	if ArtPack.has_frames(dir):
		_shoot_art = ArtPack.make_sprite(dir, Vector2(0, 6))
		_shoot_art.visible = false
		_shoot_art.animation_finished.connect(func():
			_shoot_art.visible = false
			_art.visible = true)
		add_child(_shoot_art)


## Играет анимацию выстрела, если она нарисована.
func _play_shoot_art() -> void:
	if _shoot_art == null or not _shoot_art.sprite_frames.has_animation("shoot"):
		return
	_art.visible = false
	_shoot_art.visible = true
	_shoot_art.play("shoot")


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
	_refresh_art()
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
	_play_shoot_art()
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
	if _art != null:
		if show_level:
			for i in level:
				draw_circle(Vector2(-(level - 1) * 5.0 + i * 10.0, 14), 3.4, Art.OUTLINE)
				draw_circle(Vector2(-(level - 1) * 5.0 + i * 10.0, 14), 2.4, Color("f4c542"))
		return
	Art.blob_shadow(self, Vector2(0, 7), 28.0)
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
			draw_circle(Vector2(-(level - 1) * 5.0 + i * 10.0, 14), 3.4, Art.OUTLINE)
			draw_circle(Vector2(-(level - 1) * 5.0 + i * 10.0, 14), 2.4, Color("f4c542"))


const STONE := Color("a39d90")
const STONE_LIGHT := Color("c4beb0")
const STONE_DARK := Color("6f6a60")
const GOLD := Color("e6b84e")


## Кладка: камень с тёмными швами (ряды блоков со сдвигом).
func _stone_wall(rect: Rect2, base: Color, rows: int) -> void:
	draw_rect(Rect2(rect.position - Vector2(1.5, 1.5), rect.size + Vector2(3, 3)), Art.OUTLINE)
	draw_rect(rect, base)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.3, rect.size.y)), base.lightened(0.14))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.75, 0), Vector2(rect.size.x * 0.25, rect.size.y)), base.darkened(0.14))
	var seam := base.darkened(0.3)
	for i in range(1, rows):
		var y := rect.position.y + rect.size.y * i / rows
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), seam, 1.0)
		var shift := 0.0 if i % 2 == 0 else 5.0
		var x := rect.position.x + shift + 5.0
		while x < rect.end.x - 1.0:
			draw_line(Vector2(x, y), Vector2(x, y - rect.size.y / rows), seam, 1.0)
			x += 10.0


func _draw_archer() -> void:
	_stone_wall(Rect2(-14, -14, 28, 18), STONE, 3)
	# деревянная башенка с навесом
	draw_rect(Rect2(-14.5, -35.5, 29, 23), Art.OUTLINE)
	draw_rect(Rect2(-13, -34, 26, 21), Color("93602f"))
	for i in 4:
		draw_line(Vector2(-13 + i * 6.5, -34), Vector2(-13 + i * 6.5, -13), Color("6b4220"), 1.2)
	draw_rect(Rect2(-17, -37, 34, 5), Color("6b4220"))
	draw_rect(Rect2(-5, -28, 10, 8), Color("2a1a0c"))
	# крыша из черепицы
	Art.outlined_poly(self, [Vector2(-21, -36), Vector2(0, -57), Vector2(21, -36)], Color("c2472f"), 1.6)
	for i in 3:
		var y := -40.0 - i * 6.0
		draw_line(Vector2(-16 + i * 5, y), Vector2(16 - i * 5, y), Color("8f2e1c"), 1.2)
	Art.tri(self, Vector2(-21, -36), Vector2(0, -57), Vector2(-7, -36), Color(1, 1, 1, 0.14))
	if level >= 2:
		draw_line(Vector2(17, -58), Vector2(17, -36), Art.OUTLINE, 3.0)
		var wave := sin(_time * 5.0) * 2.0
		Art.outlined_poly(self, [Vector2(17, -58), Vector2(28, -55 + wave), Vector2(17, -50)], Color("2f6fc0"), 1.0)
	if level >= 3:
		draw_line(Vector2(-21, -36), Vector2(0, -57), GOLD, 2.0)
		draw_line(Vector2(0, -57), Vector2(21, -36), GOLD, 2.0)
		Art.outlined_circle(self, Vector2(0, -59), 2.6, GOLD, 1.0)
	# лучник выглядывает и целится
	var look := Vector2(cos(_angle), sin(_angle))
	Art.outlined_circle(self, Vector2(look.x * 4.0, -24), 4.2, Color("f2d2a4"), 1.2)
	Art.half_disc(self, Vector2(look.x * 4.0, -24.5), 4.6, Color("3f7a3a"))
	draw_arc(Vector2(look.x * 10.0, -24 + look.y * 4.0), 5.0, _angle - 1.2, _angle + 1.2, 10, Art.OUTLINE, 3.2, true)
	draw_arc(Vector2(look.x * 10.0, -24 + look.y * 4.0), 5.0, _angle - 1.2, _angle + 1.2, 10, Color("8a5a32"), 1.6, true)


func _draw_mage() -> void:
	_stone_wall(Rect2(-12, -46, 24, 50), Color("8a84a8"), 6)
	# окна светятся
	var glow := 0.65 + 0.25 * sin(_time * 3.0)
	for y in [-34.0, -18.0]:
		draw_rect(Rect2(-3, y, 6, 9), Art.OUTLINE)
		draw_rect(Rect2(-2, y + 1, 4, 7), Color(0.78, 0.65, 1.0, glow))
	draw_rect(Rect2(-16.5, -49, 33, 7), Art.OUTLINE)
	draw_rect(Rect2(-15, -47.5, 30, 5), Color("6f6993"))
	Art.outlined_poly(self, [Vector2(-14, -48), Vector2(0, -68), Vector2(14, -48)], Color("4a3d9a"), 1.6)
	Art.tri(self, Vector2(-14, -48), Vector2(0, -68), Vector2(-5, -48), Color(1, 1, 1, 0.16))
	# парящий кристалл
	var bob := sin(_time * 2.2) * 2.0
	var c := Vector2(0, -80 + bob)
	draw_circle(c, 11.0 + sin(_time * 4.0), Color(0.85, 0.72, 1.0, 0.25))
	Art.outlined_poly(self, [c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)], Color("c9a6ff"), 1.4)
	Art.tri(self, c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 0), Color("ecdcff"))
	if level >= 2:
		for i in 2:
			var a := _time * 2.0 + i * PI
			var p := c + Vector2(cos(a) * 14.0, sin(a) * 4.0)
			draw_circle(p, 2.6, Color("e9dcff"))
	if level >= 3:
		draw_rect(Rect2(-12, -24, 24, 3), GOLD)
		draw_rect(Rect2(-15, -49, 30, 2), GOLD)
		for i in 3:
			var a := -_time * 1.6 + i * TAU / 3.0
			draw_circle(c + Vector2(cos(a) * 19.0, sin(a) * 6.0), 2.0, GOLD)


func _draw_mortar() -> void:
	# каменная площадка и мешки с песком
	Art.outlined_ellipse(self, Vector2(0, -4), 24, 12, Color("77737c"))
	Art.outlined_ellipse(self, Vector2(0, -8), 22, 11, Color("8f8b94"), 0.0)
	for i in 9:
		var a := PI * 0.05 + PI * 0.9 * i / 8.0
		Art.outlined_ellipse(self, Vector2(cos(a) * 21.0, 1.0 + sin(a) * 8.0 - 4.0), 5.0, 3.2, Color("c9ac72"), 1.0)
	var kick := _recoil * 10.0 if _recoil > 0.0 else 0.0
	draw_set_transform(Vector2(0, -14), _angle, Vector2.ONE)
	var thick := 6.0 + (level - 1) * 1.0
	draw_rect(Rect2(-4 - kick - 1, -thick - 1, 30 + 2, thick * 2 + 2), Art.OUTLINE)
	draw_rect(Rect2(-4 - kick, -thick, 30, thick * 2), Color("3a383f"))
	draw_rect(Rect2(-4 - kick, -thick, 30, thick * 0.6), Color("56535c"))
	draw_rect(Rect2(20 - kick, -thick - 2, 8, thick * 2 + 4), Color("26252a"))
	if level >= 3:
		draw_rect(Rect2(8 - kick, -thick, 4, thick * 2), GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Art.outlined_circle(self, Vector2(0, -14), 8.0, Color("5a5760"), 1.6)
	Art.outlined_circle(self, Vector2(-2, -16), 3.0, Color("7a7782"), 0.0)
	if _recoil > 0.0:
		var t := _recoil / 0.15
		var muzzle := Vector2(0, -14) + Vector2(cos(_angle), sin(_angle)) * 30.0
		draw_circle(muzzle, 7.0 * (1.2 - t * 0.3), Color(1.0, 0.8, 0.4, 0.8 * t))
		draw_circle(muzzle + Vector2(0, -8.0 * (1.0 - t)), 6.0, Color(0.7, 0.7, 0.7, 0.45 * t))


func _draw_barracks() -> void:
	# боковые башенки с 2 уровня
	if level >= 2:
		for x in [-24.0, 24.0]:
			_stone_wall(Rect2(x - 6, -30, 12, 34), STONE.darkened(0.06), 4)
			Art.outlined_poly(self, [Vector2(x - 8, -30), Vector2(x, -42), Vector2(x + 8, -30)], Color("2f6fc0"), 1.3)
	_stone_wall(Rect2(-20, -26, 40, 30), STONE, 4)
	# зубцы
	for i in 4:
		draw_rect(Rect2(-20.5 + i * 11, -33.5, 9, 9), Art.OUTLINE)
		draw_rect(Rect2(-19 + i * 11, -32, 6, 7), STONE_DARK)
		draw_rect(Rect2(-19 + i * 11, -32, 3, 7), STONE)
	# ворота
	draw_rect(Rect2(-7.5, -17.5, 15, 22), Art.OUTLINE)
	draw_rect(Rect2(-6, -16, 12, 20), Color("5a3a1e"))
	draw_arc(Vector2(0, -16), 6.0, PI, TAU, 10, Art.OUTLINE, 1.6, true)
	draw_line(Vector2(0, -16), Vector2(0, 4), Color("3a2412"), 1.2)
	# знамя
	draw_line(Vector2(0, -33), Vector2(0, -56), Art.OUTLINE, 3.5)
	var wave := sin(_time * 4.0) * 2.0
	var cloth := Color("2f6fc0") if level < 3 else Color("3a7ad0")
	Art.outlined_poly(self, [Vector2(0, -56), Vector2(17, -51 + wave), Vector2(14, -47), Vector2(17, -43 - wave), Vector2(0, -40)], cloth, 1.3)
	draw_circle(Vector2(6, -48), 2.6, Color("f4c542"))
	if level >= 3:
		draw_line(Vector2(-20, -26), Vector2(20, -26), GOLD, 2.0)
		Art.outlined_circle(self, Vector2(0, -58), 2.6, GOLD, 1.0)
