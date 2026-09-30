extends Control
## Заставка: картина, кнопки «Начать» и «Выйти», настройки. «Начать» открывает выбор ячейки сохранения,
## «Новая игра» в пустой ячейке спрашивает сложность. Потом открывается карта кампании.

signal entered   # игра выбрана или создана, пора на карту

var _root: Control          # сюда кладутся окна
var _modal: Control = null


func _ready() -> void:
	theme = Ui.make_theme()
	entered.connect(_go_campaign)
	add_child(TitleArt.new())
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var start := _big_button("НАЧАТЬ", Vector2(390, 372), Vector2(180, 62), 30)
	start.pressed.connect(show_slots)
	var quit := _big_button("ВЫЙТИ", Vector2(415, 444), Vector2(130, 42), 20)
	quit.pressed.connect(func(): get_tree().quit())
	var gear := RoundButton.new("gear", 44.0)
	gear.position = Vector2(14, 10)
	gear.caption = "Настройки"
	gear.caption_size = 13
	gear.caption_color = Ui.CREAM
	gear.pressed.connect(show_settings)
	add_child(gear)
	move_child(_root, -1)   # окна должны лежать поверх кнопок


func _big_button(text: String, pos: Vector2, size_px: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = size_px
	b.size = size_px
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Ui.GOLD)
	b.add_theme_color_override("font_hover_color", Color("ffe08a"))
	b.add_theme_stylebox_override("normal", Ui.box(Ui.WOOD_LIGHT, Color("2a1406"), 10, 8, 4))
	b.add_theme_stylebox_override("hover", Ui.box(Color("84603c"), Ui.GOLD, 10, 8, 4))
	b.add_theme_stylebox_override("pressed", Ui.box(Color("57391f"), Ui.GOLD, 10, 8, 4))
	add_child(b)
	return b


# ---------- окна ----------

## Открывает окно с заголовком. Возвращает VBox, куда нужно класть содержимое.
func _open_modal(title: String, width := 540.0) -> VBoxContainer:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.box(Color(Ui.WOOD.r, Ui.WOOD.g, Ui.WOOD.b, 0.98), Ui.GOLD, 14, 14, 4))
	panel.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var t := Ui.label(title, 26, Ui.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := RoundButton.new("close", 34.0)
	close.pressed.connect(_close_modal)
	head.add_child(close)
	_modal.add_child(panel)
	_root.add_child(_modal)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	# окно по центру после того, как Godot посчитает размер
	panel.resized.connect(func(): panel.position = (Defs.VIEW - panel.size) * 0.5)
	return box


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_slots() -> void:
	var box := _open_modal("ВЫБЕРИТЕ ЯЧЕЙКУ")
	for n in range(1, Defs.SAVE_SLOTS + 1):
		box.add_child(_slot_row(n))


func _slot_row(n: int) -> Control:
	var info := Game.slot_info(n)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Ui.box(Ui.WOOD_DARK, Ui.WOOD_LIGHT, 8, 8, 3))
	row.custom_minimum_size = Vector2(0, 62)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)
	if not info["exists"]:
		var b := Button.new()
		b.text = "Новая игра"
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Ui.GOLD)
		b.pressed.connect(show_difficulty.bind(n))
		line.add_child(b)
		return row
	var play := Button.new()
	play.text = "Ячейка %d" % n
	play.focus_mode = Control.FOCUS_NONE
	play.custom_minimum_size = Vector2(160, 46)
	play.add_theme_font_size_override("font_size", 22)
	play.add_theme_color_override("font_color", Ui.GOLD)
	play.pressed.connect(open_slot.bind(n))
	line.add_child(play)
	var diff: Dictionary = Defs.DIFFICULTIES.get(info["difficulty"], Defs.DIFFICULTIES["fighter"])
	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", Ui.box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 8, 6, 0))
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	stats.add_child(srow)
	srow.add_child(IconView.new("star", 30.0))
	srow.add_child(Ui.label(str(info["stars"]), 22))
	var d := Ui.label(diff["name"], 16, Ui.CREAM_SOFT)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	srow.add_child(d)
	line.add_child(stats)
	var trash := RoundButton.new("trash", 40.0)
	trash.tooltip_text = "Удалить сохранение"
	trash.pressed.connect(confirm_delete.bind(n))
	line.add_child(trash)
	return row


func confirm_delete(n: int) -> void:
	var box := _open_modal("УДАЛИТЬ СОХРАНЕНИЕ?")
	box.add_child(Ui.label("Ячейка %d будет очищена, звёзды пропадут." % n, 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for spec in [["Удалить", true], ["Отмена", false]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		var really: bool = spec[1]
		b.pressed.connect(func():
			if really:
				Game.delete_slot(n)
			show_slots())
		row.add_child(b)


func show_difficulty(n: int) -> void:
	var box := _open_modal("СЛОЖНОСТЬ")
	for id: String in Defs.DIFFICULTY_ORDER:
		var d: Dictionary = Defs.DIFFICULTIES[id]
		var b := Button.new()
		b.text = "%s\n%s" % [d["name"].to_upper(), d["info"]]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 62)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(create_game.bind(n, id))
		box.add_child(b)
	var back := Button.new()
	back.text = "Назад"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(show_slots)
	box.add_child(back)


func show_settings() -> void:
	var box := _open_modal("НАСТРОЙКИ", 440.0)
	var full := CheckButton.new()
	full.text = "Полный экран"
	full.focus_mode = Control.FOCUS_NONE
	full.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	full.toggled.connect(func(on: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	box.add_child(full)
	box.add_child(Ui.label("Звук и музыка появятся позже.", 14, Ui.CREAM_SOFT))


# ---------- что происходит после выбора ----------

func open_slot(n: int) -> void:
	if Game.load_slot(n):
		entered.emit()


func create_game(n: int, difficulty: String) -> void:
	Game.new_slot(n, difficulty)
	entered.emit()


func _go_campaign() -> void:
	get_tree().change_scene_to_file("res://scenes/campaign.tscn")
