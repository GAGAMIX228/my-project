class_name CdButton
extends Button
## Кнопка с перезарядкой: тёмная заливка показывает, сколько ещё ждать, рамка показывает, что кнопка выбрана.

var fraction := 0.0   # сколько перезарядки осталось: от 0 (готово) до 1
var armed := false    # заклинание выбрано и ждёт нажатия на карту


func set_state(new_fraction: float, new_armed: bool) -> void:
	if not is_equal_approx(new_fraction, fraction) or new_armed != armed:
		fraction = new_fraction
		armed = new_armed
		queue_redraw()


func _draw() -> void:
	if fraction > 0.0:
		draw_rect(Rect2(3, 3, (size.x - 6.0) * fraction, size.y - 6.0), Color(0.05, 0.1, 0.08, 0.3))
	if armed:
		draw_rect(Rect2(1, 1, size.x - 2.0, size.y - 2.0), Color("ffb02e"), false, 3.0)
