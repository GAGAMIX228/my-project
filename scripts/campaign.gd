extends Control
## Стартовый экран: карта кампании и панель сборки. Выбираешь уровень на карте, собираешь героев, заклинания
## и башни внизу, нажимаешь «В бой». Пока играбельна только первая локация (орки).

const MAP_HEIGHT := 322.0

var selected := "orcs"
var _panel: LoadoutPanel
var _title: Label
var _sub: Label
var _stars: Array[IconView] = []
var _go: Button
var _total: Label
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	theme = Ui.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_plaque()
	_panel = LoadoutPanel.new()
	_panel.position = Vector2(0, MAP_HEIGHT)
	_panel.custom_minimum_size = Vector2(Defs.VIEW.x, Defs.VIEW.y - MAP_HEIGHT)
	_panel.size = _panel.custom_minimum_size
	_panel.add_theme_stylebox_override("panel", Ui.box(Ui.WOOD, Ui.GOLD_DARK, 0, 8, 4))
	add_child(_panel)
	_total = Ui.label("", 16, Ui.INK)
	_total.position = Vector2(Defs.VIEW.x - 150, 12)
	_total.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.0))
	_total.add_theme_constant_override("outline_size", 0)
	add_child(_total)
	_select(selected)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _level(id: String) -> Dictionary:
	for l: Dictionary in Defs.LEVELS:
		if l["id"] == id:
			return l
	return Defs.LEVELS[0]


# ---------- плашка выбранного уровня ----------

func _build_plaque() -> void:
	var plaque := PanelContainer.new()
	plaque.position = Vector2(250, 8)
	plaque.custom_minimum_size = Vector2(460, 0)
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
	_go.add_theme_font_size_override("font_size", 20)
	_go.add_theme_color_override("font_color", Ui.GOLD)
	_go.custom_minimum_size = Vector2(110, 0)
	_go.pressed.connect(start_battle)
	row.add_child(_go)
	add_child(plaque)


func _select(id: String) -> void:
	selected = id
	var l := _level(id)
	_title.text = l["name"]
	var stars := int(Game.level_stars.get(id, 0))
	for i in 3:
		_stars[i].filled = i < stars
	if l["playable"]:
		_sub.text = "  10 волн, враги: %s" % l["race"].to_lower()
		_go.disabled = false
		_go.text = "В бой"
	else:
		_sub.text = "  Скоро: %s" % l["race"].to_lower()
		_go.disabled = true
		_go.text = "Закрыто"
	var sum := 0
	for v in Game.level_stars.values():
		sum += int(v)
	_total.text = "Звёзды: %d" % sum


func start_battle() -> void:
	if not _level(selected)["playable"]:
		return
	Game.level_id = selected
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := (event as InputEventMouseButton).position
		for l: Dictionary in Defs.LEVELS:
			if (l["pos"] as Vector2).distance_to(p) < 28.0:
				_select(l["id"])
				return


# ---------- рисование карты ----------

func _draw() -> void:
	_rng.seed = 5
	var area := Rect2(0, 0, Defs.VIEW.x, MAP_HEIGHT)
	draw_rect(area, Ui.PARCHMENT)
	# пятна, как на старой бумаге
	for i in 60:
		var col := Color(0.55, 0.4, 0.18, 0.07) if _rng.randf() < 0.5 else Color(1, 0.95, 0.75, 0.10)
		Art.ellipse(self, Vector2(_rng.randf_range(0, area.size.x), _rng.randf_range(0, area.size.y)), _rng.randf_range(30, 120), _rng.randf_range(16, 60), col)
	# холмы и деревья
	for i in 46:
		var p := Vector2(_rng.randf_range(20, 940), _rng.randf_range(80, 300))
		if _near_node(p, 46.0):
			continue
		if _rng.randf() < 0.5:
			Art.tri(self, p + Vector2(-13, 6), p + Vector2(0, -12), p + Vector2(13, 6), Color("b89b63"))
			Art.tri(self, p + Vector2(-4, -4), p + Vector2(0, -12), p + Vector2(5, -3), Color("f1e2b8"))
		else:
			draw_circle(p + Vector2(0, -6), 8.0, Color("7f9a4e"))
			draw_rect(Rect2(p.x - 1.5, p.y - 2, 3, 8), Color("6b4a2a"))
	# дорога между локациями
	for i in Defs.LEVELS.size() - 1:
		var a: Vector2 = Defs.LEVELS[i]["pos"]
		var b: Vector2 = Defs.LEVELS[i + 1]["pos"]
		var dist := a.distance_to(b)
		var dir := (b - a) / dist
		var n := int(dist / 12.0)
		for k in range(1, n):
			draw_circle(a + dir * (k * 12.0), 2.6, Color("8a5f2a"))
	# рамка
	draw_rect(area, Ui.GOLD_DARK, false, 6.0)
	# локации
	for l: Dictionary in Defs.LEVELS:
		_draw_node(l)


func _near_node(p: Vector2, r: float) -> bool:
	for l: Dictionary in Defs.LEVELS:
		if (l["pos"] as Vector2).distance_to(p) < r:
			return true
	return p.y < 76.0 and p.x > 240.0 and p.x < 720.0


func _draw_node(l: Dictionary) -> void:
	var c: Vector2 = l["pos"]
	var playable: bool = l["playable"]
	var is_sel: bool = l["id"] == selected
	Art.ellipse(self, c + Vector2(0, 20), 26.0, 8.0, Color(0, 0, 0, 0.22))
	if is_sel:
		draw_arc(c, 30.0 + sin(_time * 4.0) * 1.5, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 0.9), 3.0, true)
	draw_circle(c, 24.0, Ui.WOOD_DARK if playable else Color("6b625a"))
	draw_arc(c, 24.0, 0.0, TAU, 32, Ui.GOLD if playable else Color("958a7a"), 3.0, true)
	if playable:
		Icons.draw(self, "flag", c, 14.0)
	else:
		Icons.draw(self, "lock", c, 11.0)
	var font := ThemeDB.fallback_font
	var name_y := c.y + 42.0
	draw_string_outline(font, Vector2(c.x - 60, name_y), l["race"], HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 4, Color(0.95, 0.9, 0.75, 0.9))
	draw_string(font, Vector2(c.x - 60, name_y), l["race"], HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Ui.INK)
	var stars := int(Game.level_stars.get(l["id"], 0))
	if playable:
		for i in 3:
			Icons.star(self, c + Vector2((i - 1) * 15.0, 62.0 - 0.0), 6.5, i < stars)
