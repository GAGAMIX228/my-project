class_name CardButton
extends Button
## Карточка героя, заклинания или башни: портрет, название, подпись. Для слотов и для коллекции на экране сборки.

var icon_id := ""
var title := ""
var subtitle := ""
var badge := ""           # номер слота
var picked := false       # лежит в одном из слотов
var active_slot := false  # слот, в который сейчас попадёт выбранная карточка
var locked := false       # закрыто (пока не открыто в кампании)
var empty := false        # пустой слот


func _init(id := "", card_title := "", card_subtitle := "", width := 78.0) -> void:
	icon_id = id
	title = card_title
	subtitle = card_subtitle
	custom_minimum_size = Vector2(width, 112)
	focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _ready() -> void:
	if icon_id.begins_with("hero:"):
		HeroSprite.attach(self, icon_id.substr(5), Vector2(size.x * 0.5, 36), 54.0)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var hot := is_hovered()
	var fill := Ui.WOOD.lerp(Ui.WOOD_LIGHT, 0.6 if hot else 0.0)
	var border := Ui.GOLD if (picked or active_slot) else (Ui.GOLD.darkened(0.15) if hot else Ui.GOLD_DARK)
	if empty:
		fill = Ui.WOOD_DARK
	draw_style_box(Ui.box(fill, border, 8, 0, 4 if active_slot else 3), rect)
	if active_slot:
		draw_rect(rect.grow(2.0), Color(1.0, 0.85, 0.35, 0.5), false, 2.0)
	var c := Vector2(size.x * 0.5, 36)
	draw_circle(c, 27.0, Color(0.1, 0.06, 0.03, 0.75))
	if icon_id != "" and not icon_id.begins_with("hero:") and not empty:
		Icons.draw(self, icon_id, c, 21.0)
	if empty:
		draw_arc(c, 22.0, 0.0, TAU, 24, Color(0.6, 0.5, 0.35, 0.6), 2.0, true)
	if locked:
		draw_circle(c, 27.0, Color(0.05, 0.04, 0.03, 0.6))
		Icons.draw(self, "lock", c, 14.0)
	var font := Ui.font()
	var color := Ui.CREAM if not locked else Color("9c8d70")
	# длинное название переносим на вторую строку
	var lines := title.split(" ", false, 1) if title.length() > 9 else PackedStringArray([title])
	var y := 76.0
	for line in lines:
		draw_string(font, Vector2(2, y), line, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4.0, 12 if line.length() <= 9 else 10, color)
		y += 13.0
	draw_string(font, Vector2(2, 105.0), subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4.0, 10, Ui.CREAM_SOFT if not locked else Color("7a6d56"))
	if badge != "":
		draw_circle(Vector2(11, 11), 9.0, Ui.WOOD_DARK)
		draw_arc(Vector2(11, 11), 9.0, 0.0, TAU, 16, Ui.GOLD, 1.5, true)
		draw_string(font, Vector2(2, 15.5), badge, HORIZONTAL_ALIGNMENT_CENTER, 18, 12, Ui.CREAM)
	elif picked:
		draw_circle(Vector2(size.x - 11, 11), 9.0, Ui.GREEN.darkened(0.3))
		draw_string(font, Vector2(size.x - 20, 15.5), "✓", HORIZONTAL_ALIGNMENT_CENTER, 18, 12, Color.WHITE)
