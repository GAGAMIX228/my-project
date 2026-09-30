class_name Fx
extends Node2D
## Короткие эффекты: расходящееся кольцо и всплывающий текст (например, "+6" золота).

var kind := "ring"
var radius := 20.0
var color := Color.WHITE
var text := ""
var t := 0.0  # от 0 до 1, показывает, как далеко зашёл эффект


static func ring(pos: Vector2, radius: float, color: Color, duration := 0.35) -> void:
	if Game.fx_root == null:
		return
	var fx := Fx.new()
	fx.kind = "ring"
	fx.radius = radius
	fx.color = color
	fx.position = pos
	Game.fx_root.add_child(fx)
	fx._run(duration)


static func float_text(pos: Vector2, text: String, color := Color("ffe27a")) -> void:
	if Game.fx_root == null:
		return
	var fx := Fx.new()
	fx.kind = "text"
	fx.text = text
	fx.color = color
	fx.position = pos
	Game.fx_root.add_child(fx)
	fx._run(0.9)


func _run(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "t", 1.0, duration)
	tween.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if kind == "ring":
		var r := radius * (0.25 + 0.75 * t)
		var c := color
		c.a = 1.0 - t
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, 3.0, true)
		var fill := color
		fill.a = 0.12 * (1.0 - t)
		draw_circle(Vector2.ZERO, r, fill)
	else:
		var c := color
		c.a = 1.0 - t * t
		var shadow := Color(0.16, 0.1, 0.0, c.a * 0.75)
		var pos := Vector2(-30, -t * 22.0)
		var font := Ui.font()
		draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, 60, 15, shadow)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 60, 15, c)
