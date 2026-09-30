class_name Pad
extends Node2D
## Каменная площадка, на которой можно построить башню.

var index := 0
var tower: Tower = null
var hover := false:
	set(value):
		if hover != value:
			hover = value
			queue_redraw()
var selected := false:
	set(value):
		if selected != value:
			selected = value
			queue_redraw()


func _draw() -> void:
	Art.ellipse(self, Vector2(0, 6), 28, 12, Color(0, 0, 0, 0.25))
	Art.ellipse(self, Vector2(0, 2), 27, 12, Color("7d7668"))
	Art.ellipse(self, Vector2(0, -1), 27, 12, Color("b7b09f"))
	Art.ellipse(self, Vector2(0, -2), 20, 8.5, Color("a29b8a"))
	if tower == null:
		var col := Color(1, 1, 1, 1.0) if (hover or selected) else Color(1.0, 0.94, 0.67, 0.75)
		Art.ellipse_outline(self, Vector2(0, -1), 27, 12, col, 2.5)
