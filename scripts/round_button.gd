class_name RoundButton
extends Button
## Круглая кнопка с иконкой, как в Kingdom Rush: заклинания, способности, портреты героев, кнопки меню.
## Умеет показывать перезарядку (тёмный сектор и число секунд), выбор (золотое кольцо),
## цифру клавиши и подпись снизу (например цену).

var icon_id := ""            # см. Icons; "hero:<id>" рисует портрет героя
var badge := ""              # цифра клавиши в углу
var caption := ""            # подпись под кнопкой (цена)
var center_text := ""        # текст в центре вместо иконки (например ×2)
var cooldown := 0.0          # доля перезарядки: 1 сразу после применения, 0 готово
var cooldown_text := ""      # число секунд поверх сектора
var selected := false        # золотое кольцо
var dimmed := false          # серая кнопка (не хватает золота, нельзя выбрать)
var ring_color := Ui.GOLD_DARK

var _overlay: Control
var _sprite: HeroSprite


func _init(id := "", diameter := 54.0) -> void:
	icon_id = id
	custom_minimum_size = Vector2(diameter, diameter)
	focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _ready() -> void:
	_overlay = Overlay.new()
	_overlay.button = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	if icon_id.begins_with("hero:"):
		_sprite = HeroSprite.attach(self, icon_id.substr(5), size * 0.5, size.x * 0.82)
		move_child(_overlay, -1)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	resized.connect(_on_resized)


func _on_resized() -> void:
	if _sprite != null:
		_sprite.position = size * 0.5 + Vector2(0, (24.0 if Defs.HEROES[_sprite.hid]["kind"] == "dragon" else 8.0) * _sprite.scale.x)
	queue_redraw()


## Обновляет вид кнопки. Перерисовывает, только если что-то изменилось.
func set_state(new_cooldown: float, new_text: String, new_selected: bool) -> void:
	if not is_equal_approx(new_cooldown, cooldown) or new_text != cooldown_text or new_selected != selected:
		cooldown = new_cooldown
		cooldown_text = new_text
		selected = new_selected
		queue_redraw()
		_overlay.queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var hot := is_hovered() and not disabled
	draw_circle(c + Vector2(0, 2), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, Ui.WOOD_DARK.lerp(Ui.WOOD_LIGHT, 0.5 if hot else 0.0))
	if icon_id != "" and not icon_id.begins_with("hero:"):
		Icons.draw(self, icon_id, c, r * 0.68)
	if center_text != "":
		var font := ThemeDB.fallback_font
		var fs := int(r * 0.8)
		draw_string_outline(font, Vector2(0, c.y + fs * 0.35), center_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, c.y + fs * 0.35), center_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Ui.CREAM)
	if dimmed:
		draw_circle(c, r, Color(0.1, 0.08, 0.06, 0.55))


## Верхний слой: перезарядка, кольцо, цифра клавиши и подпись рисуются поверх портрета героя.
class Overlay extends Control:
	var button: RoundButton

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var font := ThemeDB.fallback_font
		if button.cooldown > 0.0:
			# тёмный сектор: остаток перезарядки идёт по часовой стрелке от верха
			var pts := PackedVector2Array([c])
			var a0 := -PI / 2.0
			var a1 := a0 + TAU * button.cooldown
			var steps := maxi(3, int(48.0 * button.cooldown))
			for i in steps + 1:
				var a := a0 + (a1 - a0) * i / steps
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color(0.03, 0.02, 0.02, 0.62))
		var ring := Ui.GOLD if (button.selected or button.is_hovered()) else button.ring_color
		draw_arc(c, r, 0.0, TAU, 40, ring, 4.0 if button.selected else 3.0, true)
		if button.selected:
			draw_arc(c, r + 3.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.35, 0.55), 2.0, true)
		if button.cooldown_text != "":
			var fs := int(r * 0.85)
			draw_string_outline(font, Vector2(0, c.y + fs * 0.35), button.cooldown_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 4, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(0, c.y + fs * 0.35), button.cooldown_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)
		if button.badge != "":
			var bp := Vector2(size.x - 10.0, size.y - 9.0)
			draw_circle(bp, 8.0, Ui.WOOD_DARK)
			draw_arc(bp, 8.0, 0.0, TAU, 16, Ui.GOLD_DARK, 1.5, true)
			draw_string(font, bp + Vector2(-8, 4.5), button.badge, HORIZONTAL_ALIGNMENT_CENTER, 16, 12, Ui.CREAM)
		if button.caption != "":
			draw_string_outline(font, Vector2(-20, size.y + 13.0), button.caption, HORIZONTAL_ALIGNMENT_CENTER, size.x + 40.0, 13, 4, Color(0, 0, 0, 0.85))
			draw_string(font, Vector2(-20, size.y + 13.0), button.caption, HORIZONTAL_ALIGNMENT_CENTER, size.x + 40.0, 13, Ui.GOLD)
