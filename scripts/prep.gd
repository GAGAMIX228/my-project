extends Control
## Экран сборки перед боем: выбрать двух героев и три заклинания.
## Пока все открыты. Когда появится кампания, здесь будут только открытые звёздами.

const HERO_COUNT := 2
const SPELL_COUNT := 3

var _hero_buttons := {}    # id -> Button
var _spell_buttons := {}
var _hero_title: Label
var _spell_title: Label
var _go: Button
var _hint: Label


func _ready() -> void:
	theme = Ui.make_theme()
	var bg := ColorRect.new()
	bg.color = Color("dfe9d6")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	root.add_child(Ui.label("Сборка перед боем", 26, Ui.INK))
	root.add_child(Ui.label("Выбери двух героев и три заклинания. Герои идут туда, куда нажмёшь на карте. Заклинания и способности можно вызвать клавишами 1–5.", 13, Ui.INK_SOFT))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	_hero_title = Ui.label("", 17, Ui.INK)
	_spell_title = Ui.label("", 17, Ui.INK)
	_fill_heroes(_build_column(columns, _hero_title, 3, 470.0))
	_fill_spells(_build_column(columns, _spell_title, 2, 430.0))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	_go = Button.new()
	_go.text = "В бой"
	_go.pressed.connect(_start_battle)
	footer.add_child(_go)
	_hint = Ui.label("", 13, Ui.INK_SOFT)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_hint)
	_refresh()


## Делает колонку с заголовком и сеткой карточек. Возвращает сетку, в которую нужно положить карточки.
func _build_column(parent: Control, title: Label, cols: int, width: float) -> GridContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = width
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	return grid


func _card(text: String, width: float) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(width, 0)
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _fill_heroes(grid: GridContainer) -> void:
	for id in Defs.HERO_ORDER:
		var d: Dictionary = Defs.HEROES[id]
		var text := "%s, %s\n%s\n%s: %s" % [d["name"], d["role"], Defs.KIND_TEXT[d["kind"]], d["ab"]["name"], d["ab"]["info"]]
		var b := _card(text, 148.0)
		b.button_pressed = id in Game.loadout_heroes
		b.pressed.connect(func(): _toggle(Game.loadout_heroes, id, HERO_COUNT))
		grid.add_child(b)
		_hero_buttons[id] = b


func _fill_spells(grid: GridContainer) -> void:
	for id in Defs.SPELL_ORDER:
		var d: Dictionary = Defs.SPELLS[id]
		var text := "%s\n%s, перезарядка %d с\n%s" % [d["name"], d["race"], int(d["cd"]), d["info"]]
		var b := _card(text, 208.0)
		b.button_pressed = id in Game.loadout_spells
		b.pressed.connect(func(): _toggle(Game.loadout_spells, id, SPELL_COUNT))
		grid.add_child(b)
		_spell_buttons[id] = b


## Нажатие на карточку: выбрать или снять. Если выбрано больше, чем можно, самый ранний выбор снимается.
func _toggle(list: Array[String], id: String, limit: int) -> void:
	if id in list:
		list.erase(id)
	else:
		list.append(id)
		if list.size() > limit:
			list.pop_front()
	_refresh()


func _refresh() -> void:
	for id in _hero_buttons:
		(_hero_buttons[id] as Button).set_pressed_no_signal(id in Game.loadout_heroes)
	for id in _spell_buttons:
		(_spell_buttons[id] as Button).set_pressed_no_signal(id in Game.loadout_spells)
	_hero_title.text = "Герои: выбрано %d из %d" % [Game.loadout_heroes.size(), HERO_COUNT]
	_spell_title.text = "Заклинания: выбрано %d из %d" % [Game.loadout_spells.size(), SPELL_COUNT]
	var ready := Game.loadout_heroes.size() == HERO_COUNT and Game.loadout_spells.size() == SPELL_COUNT
	_go.disabled = not ready
	_hint.text = "Всё готово." if ready else "Выбери двух героев и три заклинания."


func _start_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
