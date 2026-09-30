class_name Projectile
extends Node2D
## Стрела, магический шар, снаряд мортиры или метеорит.
## Стрела и шар летят за целью. Снаряд мортиры и метеорит летят в точку и взрываются.

var kind := "arrow"  # "arrow", "orb", "shell" или "meteor"
var target: Enemy
var dmg := 0.0
var dtype := "phys"  # "phys" физический, "magic" магический, "pure" чистый
var speed := 500.0
var color := Color("c9a6ff")
var splash := 0.0
var big := false     # мощная стрела (способность Тарна): рисуется крупнее
var boom_color := Color("ffcf7a")

var _end := Vector2.ZERO
var _start := Vector2.ZERO
var _t := 0.0
var _dur := 0.9


func launch_homing(from: Vector2, enemy: Enemy) -> void:
	position = from
	target = enemy
	_end = enemy.aim_point()


func launch_shell(from: Vector2, to: Vector2, duration: float) -> void:
	position = from
	_start = from
	_end = to
	_dur = duration


func _process(delta: float) -> void:
	if kind == "shell" or kind == "meteor":
		_t += delta
		var f := minf(1.0, _t / _dur)
		position = _start.lerp(_end, f)
		if kind == "shell":
			position += Vector2(0, -sin(f * PI) * 70.0)
		if f >= 1.0:
			_explode()
	else:
		if is_instance_valid(target) and not target.dead:
			_end = target.aim_point()
		var to_end := _end - position
		var dist := to_end.length()
		var step := speed * delta
		if dist <= step + 2.0:
			if is_instance_valid(target) and not target.dead:
				target.take_damage(dmg, dtype)
			var spark := Color("ffe27a") if big else (color if kind == "orb" else Color.WHITE)
			Fx.ring(_end, 20.0 if big else 9.0, spark, 0.18)
			queue_free()
			return
		position += to_end / dist * step
		rotation = to_end.angle()
	queue_redraw()


func _explode() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead or e.flying:
			continue
		var d := e.global_position.distance_to(_end)
		if d <= splash + e.radius:
			var falloff := 1.0 - minf(1.0, d / (splash + e.radius)) * 0.4
			e.take_damage(dmg * falloff, dtype)
	Fx.ring(_end, splash, boom_color, 0.4)
	queue_free()


func _draw() -> void:
	if kind == "arrow":
		if big:
			draw_line(Vector2(-16, 0), Vector2(7, 0), Color("ffd24a"), 3.4)
			Art.tri(self, Vector2(7, -3.5), Vector2(13, 0), Vector2(7, 3.5), Color("fff2b0"))
		else:
			draw_line(Vector2(-9, 0), Vector2(7, 0), Color("4b2f14"), 2.0)
			Art.tri(self, Vector2(7, -3), Vector2(13, 0), Vector2(7, 3), Color("cfd3d8"))
	elif kind == "meteor":
		var f := minf(1.0, _t / _dur)
		Art.ellipse(self, _start.lerp(_end, f) - position + Vector2(0, 4), 16.0, 6.0, Color(0, 0, 0, 0.25))
		draw_line(Vector2.ZERO, Vector2(46, -46), Color(1.0, 0.67, 0.24, 0.7), 7.0)
		draw_circle(Vector2.ZERO, 11.0, Color("ff8a2a"))
		draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 20, Color("ffd27a"), 2.0, true)
		draw_circle(Vector2(-2, -2), 5.0, Color("fff2c0"))
	elif kind == "orb":
		var glow := color
		glow.a = 0.3
		draw_circle(Vector2.ZERO, 10.0, glow)
		draw_circle(Vector2.ZERO, 5.0, color)
		draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 16, Color.WHITE, 1.0)
	else:
		# тень снаряда рисуем на земле, а сам снаряд в воздухе
		var f := minf(1.0, _t / _dur)
		var ground := _start.lerp(_end, f) - position
		Art.ellipse(self, ground + Vector2(0, 4), 6.0, 2.5, Color(0, 0, 0, 0.25))
		draw_circle(Vector2.ZERO, 5.0, Color("2b2a30"))
		draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 16, Color("777777"), 1.0)
