extends Control
## Карта кампании. Вверху плашка выбранного уровня с кнопкой «В бой», внизу панель с тремя большими кнопками:
## «Герои», «Башни», «Заклинания». Кнопка открывает раздел сборки, где выбираются слоты и карточки.

var selected := "orcs"
var _map: MapArt
var _nodes: MapNodes
var _panel: LoadoutPanel
var _tab_buttons := {}
var _title: Label
var _sub: Label
var _stars: Array[IconView] = []
var _go: Button
var _total: Label


func _ready() -> void:
	theme = Ui.make_theme()
	_map = MapArt.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_map)
	_nodes = MapNodes.new()
	_nodes.campaign = self
	_nodes.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_nodes)
	_build_plaque()
	_build_corner()
	_panel = LoadoutPanel.new()
	_panel.position = Vector2(14, 214)
	_panel.custom_minimum_size = Vector2(Defs.VIEW.x - 28.0, 244.0)
	_panel.size = _panel.custom_minimum_size
	_panel.visible = false
	_panel.closed.connect(close_tab)
	add_child(_panel)
	_build_bar()
	_select(selected)


func _level(id: String) -> Dictionary:
	for l: Dictionary in Defs.LEVELS:
		if l["id"] == id:
			return l
	return Defs.LEVELS[0]


# ---------- верхние плашки ----------

func _build_corner() -> void:
	var back := RoundButton.new("back", 42.0)
	back.position = Vector2(10, 8)
	back.tooltip_text = "В главное меню"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	add_child(back)
	var plaque := PanelContainer.new()
	plaque.position = Vector2(58, 10)
	plaque.add_theme_stylebox_override("panel", Ui.box(Color(Ui.WOOD_DARK.r, Ui.WOOD_DARK.g, Ui.WOOD_DARK.b, 0.92), Ui.GOLD_DARK, 16, 4, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	plaque.add_child(row)
	row.add_child(IconView.new("star", 26.0))
	_total = Ui.label("0", 18)
	_total.custom_minimum_size.x = 30.0
	row.add_child(_total)
	add_child(plaque)


func _build_plaque() -> void:
	var plaque := PanelContainer.new()
	plaque.position = Vector2(262, 8)
	plaque.custom_minimum_size = Vector2(470, 0)
	plaque.add_theme_stylebox_override("panel", Ui.box(Color(Ui.WOOD.r, Ui.WOOD.g, Ui.WOOD.b, 0.97), Ui.GOLD, 12, 6, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	plaque.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	_title = Ui.label("", 19, Ui.GOLD)
	col.add_child(_title)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	col.add_child(line)
	for i in 3:
		var star := IconView.new("star", 17.0)
		line.add_child(star)
		_stars.append(star)
	_sub = Ui.label("", 13, Ui.CREAM_SOFT)
	line.add_child(_sub)
	_go = Button.new()
	_go.text = "В бой"
	_go.focus_mode = Control.FOCUS_NONE
	_go.add_theme_font_size_override("font_size", 20)
	_go.add_theme_color_override("font_color", Ui.GOLD)
	_go.custom_minimum_size = Vector2(110, 0)
	_go.pressed.connect(start_battle)
	row.add_child(_go)
	add_child(plaque)


# ---------- нижняя панель ----------

func _build_bar() -> void:
	var bar := BottomBar.new()
	bar.position = Vector2(0, Defs.VIEW.y - BottomBar.HEIGHT)
	bar.size = Vector2(Defs.VIEW.x, BottomBar.HEIGHT)
	add_child(bar)
	var specs := [["hero", "Герои", "sp:knights"], ["tower", "Башни", "tower:barracks"], ["spell", "Заклинания", "ab:kara"]]
	for i in specs.size():
		var spec: Array = specs[i]
		var b := RoundButton.new(spec[2], 66.0)
		b.position = Vector2(Defs.VIEW.x * 0.5 + (i - 1) * 130.0 - 33.0, Defs.VIEW.y - BottomBar.HEIGHT - 26.0)
		b.caption = spec[1]
		b.caption_size = 17
		b.tooltip_text = "Выбрать: %s" % spec[1].to_lower()
		var kind: String = spec[0]
		b.pressed.connect(toggle_tab.bind(kind))
		add_child(b)
		_tab_buttons[kind] = b


## Открывает раздел сборки. Повторное нажатие на ту же кнопку закрывает его.
func toggle_tab(kind: String) -> void:
	if _panel.visible and _panel.kind == kind:
		close_tab()
		return
	_panel.show_tab(kind)
	_panel.visible = true
	for k: String in _tab_buttons:
		(_tab_buttons[k] as RoundButton).set_state(0.0, "", k == kind)


func close_tab() -> void:
	_panel.visible = false
	for k: String in _tab_buttons:
		(_tab_buttons[k] as RoundButton).set_state(0.0, "", false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_tab()


# ---------- выбор уровня ----------

func _select(id: String) -> void:
	selected = id
	var l := _level(id)
	var index := Defs.LEVELS.find(l)
	_title.text = l["name"]
	var stars := int(Game.level_stars.get(id, 0))
	for i in 3:
		_stars[i].filled = i < stars
	if not Game.level_unlocked(index):
		_sub.text = "  Закрыто: пройди предыдущую локацию"
		_go.disabled = true
		_go.text = "Закрыто"
	elif l["playable"]:
		_sub.text = "  10 волн, враги: %s" % l["race"].to_lower()
		_go.disabled = false
		_go.text = "В бой"
	else:
		_sub.text = "  Скоро: %s" % l["race"].to_lower()
		_go.disabled = true
		_go.text = "Скоро"
	_total.text = str(Game.total_stars())
	_nodes.queue_redraw()


func start_battle() -> void:
	var l := _level(selected)
	if not l["playable"] or not Game.level_unlocked(Defs.LEVELS.find(l)):
		return
	Game.level_id = selected
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## Слой с точками уровней и дорогой между ними. Рисуется каждый кадр, чтобы выбранная точка пульсировала.
class MapNodes extends Control:
	var campaign
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var p := (event as InputEventMouseButton).position
			for l: Dictionary in Defs.LEVELS:
				if (l["pos"] as Vector2).distance_to(p) < 28.0:
					campaign._select(l["id"])
					return

	func _draw() -> void:
		# дорога из точек
		for i in Defs.LEVELS.size() - 1:
			var a: Vector2 = Defs.LEVELS[i]["pos"]
			var b: Vector2 = Defs.LEVELS[i + 1]["pos"]
			var dist := a.distance_to(b)
			var dir := (b - a) / dist
			var done := Game.level_unlocked(i + 1)
			for k in range(2, int(dist / 11.0) - 1):
				var p := a + dir * (k * 11.0)
				draw_circle(p, 3.6, Color("2a1406"))
				draw_circle(p, 2.6, Color("ff6a4a") if done else Color("e8d8b0"))
		for i in Defs.LEVELS.size():
			_node(i, Defs.LEVELS[i])

	func _node(index: int, l: Dictionary) -> void:
		var c: Vector2 = l["pos"]
		var open := Game.level_unlocked(index)
		var playable: bool = l["playable"]
		var is_sel: bool = l["id"] == campaign.selected
		Art.ellipse(self, c + Vector2(0, 20), 24.0, 7.0, Color(0, 0, 0, 0.3))
		if is_sel:
			draw_arc(c, 30.0 + sin(_time * 4.0) * 1.5, 0.0, TAU, 32, Color(1.0, 0.88, 0.35, 0.95), 3.5, true)
		var live := open and playable
		draw_circle(c, 23.0, Color("2a1406"))
		draw_circle(c, 20.0, Ui.WOOD_DARK if live else (Color("4a4540") if open else Color("3f3a36")))
		draw_arc(c, 20.0, 0.0, TAU, 32, Ui.GOLD if live else Color("8c8273"), 3.0, true)
		if live:
			Icons.draw(self, "flag", c + Vector2(2, 0), 13.0)
		elif open:
			Icons.draw(self, "flag", c + Vector2(2, 0), 11.0)
		else:
			Icons.draw(self, "lock", c, 10.0)
		var font := Ui.font()
		var label_pos := Vector2(c.x - 70, c.y + 40.0)
		draw_string_outline(font, label_pos, l["race"], HORIZONTAL_ALIGNMENT_CENTER, 140, 13, 5, Color(0.1, 0.05, 0.02, 0.9))
		draw_string(font, label_pos, l["race"], HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Ui.CREAM)
		if live:
			var stars := int(Game.level_stars.get(l["id"], 0))
			for i in 3:
				Icons.star(self, c + Vector2((i - 1) * 16.0, -34.0 + abs(i - 1) * 4.0), 7.5, i < stars)


## Нижняя панель: тёмное дерево с золотой кромкой и заклёпками.
class BottomBar extends Control:
	const HEIGHT := 76.0

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color("241810"))
		draw_rect(Rect2(0, 0, size.x, 5), Ui.GOLD_DARK)
		draw_rect(Rect2(0, 5, size.x, 3), Color("4a3322"))
		for i in 5:
			draw_line(Vector2(0, 22 + i * 14), Vector2(size.x, 22 + i * 14), Color(0, 0, 0, 0.18), 1.5)
		for x in [14.0, size.x - 14.0]:
			draw_circle(Vector2(x, 22), 5.0, Ui.GOLD_DARK)
			draw_circle(Vector2(x - 1, 21), 2.0, Ui.GOLD)
