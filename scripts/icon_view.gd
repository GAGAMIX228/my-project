class_name IconView
extends Control
## Маленький значок (сердце, монета, звезда...) для плашек интерфейса. Рисуется кодом через Icons.

var icon_id := "heart":
	set(value):
		icon_id = value
		queue_redraw()
var filled := true:      # для звезды: закрашена или пустая
	set(value):
		filled = value
		queue_redraw()


func _init(id := "heart", diameter := 22.0) -> void:
	icon_id = id
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	if icon_id == "star":
		Icons.star(self, c, minf(size.x, size.y) * 0.5, filled)
	else:
		Icons.draw(self, icon_id, c, minf(size.x, size.y) * 0.5)
