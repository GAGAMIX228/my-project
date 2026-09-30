class_name Hud
extends CanvasLayer
## Интерфейс поверх игры: жизни, золото, волна, кнопки и меню башни.
## Пока он строится кодом. Позже его можно собрать мышкой в редакторе и красиво оформить.

signal wave_requested
signal speed_toggled
signal pause_toggled
signal build_requested(pad: Pad, kind: String)
signal upgrade_requested(pad: Pad)
signal sell_requested(pad: Pad)
signal restart_requested
signal prep_requested
signal spell_pressed(index: int)
signal hero_pressed(index: int)
signal ability_pressed(index: int)

const INK := Ui.INK
const INK_SOFT := Ui.INK_SOFT
const PANEL := Ui.PANEL
const LINE := Ui.LINE
const ACCENT := Ui.ACCENT

var _lives: Label
var _gold: Label
var _wave: Label
var _info: Label
var _toast_panel: PanelContainer
var _toast: Label
var _toast_time := 0.0
var _wave_button: Button
var _speed_button: Button
var _pause_button: Button
var _menu: PanelContainer
var _menu_box: VBoxContainer
var _pad: Pad = null
var _end: PanelContainer
var _end_title: Label
var _end_text: Label
var _end_stars: Label
var _book: Spellbook
var _heroes: Array[Hero] = []
var _spell_buttons: Array[CdButton] = []
var _hero_cards: Array[Dictionary] = []
var _spell_row: HBoxContainer
var _hero_row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Ui.make_theme()
	add_child(root)
	_build_top(root)
	_build_bottom(root)
	_build_menu(root)
	_build_end(root)
	Game.gold_changed.connect(_on_gold)
	Game.lives_changed.connect(func(v: int): _lives.text = "Жизни: %d" % v)
	Game.wave_changed.connect(func(cur: int, total: int): _wave.text = "Волна %d из %d" % [cur, total])
	Game.message.connect(show_toast)
	Game.finished.connect(_on_finished)
	# после нажатия кнопка не должна забирать пробел и клавиши игры себе
	get_viewport().gui_focus_changed.connect(func(control: Control): control.release_focus())


func _process(delta: float) -> void:
	if _book != null:
		_update_controls()
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast_panel.modulate.a = clampf(_toast_time * 4.0, 0.0, 1.0)
		_toast_panel.visible = _toast_time > 0.0


# ---------- оформление ----------

func _box(bg: Color, border: Color, radius := 10, margin := 8) -> StyleBoxFlat:
	return Ui.box(bg, border, radius, margin)


func _chip(parent: Control, text: String) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.1, 0.07, 0.8), Color(0, 0, 0, 0), 16, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	parent.add_child(panel)
	return label


func _build_top(root: Control) -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(10, 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	_lives = _chip(row, "Жизни: 20")
	_gold = _chip(row, "Золото: 220")
	_wave = _chip(row, "Волна 0 из 10")
	_info = Label.new()
	_info.position = Vector2(14, 48)
	_info.add_theme_color_override("font_color", Color.WHITE)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_info.add_theme_constant_override("outline_size", 4)
	_info.add_theme_font_size_override("font_size", 14)
	_info.custom_minimum_size.x = 600.0
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_info)
	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.1, 0.07, 0.86), Color(0, 0, 0, 0), 16, 6))
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.position.y = 100
	_toast_panel.visible = false
	_toast = Label.new()
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast)
	root.add_child(_toast_panel)


func _build_bottom(root: Control) -> void:
	# справа внизу: волна, скорость, пауза, сборка
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_right = -8
	row.offset_bottom = -8
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	_wave_button = _small_button("Начать волну 1", row)
	_wave_button.pressed.connect(func(): wave_requested.emit())
	_speed_button = _small_button("Скорость ×1", row)
	_speed_button.pressed.connect(func(): speed_toggled.emit())
	_pause_button = _small_button("Пауза", row)
	_pause_button.pressed.connect(func(): pause_toggled.emit())
	var prep := _small_button("Сборка", row)
	prep.pressed.connect(func(): prep_requested.emit())
	# слева внизу: кнопки заклинаний (их создаёт bind)
	_spell_row = HBoxContainer.new()
	_spell_row.add_theme_constant_override("separation", 6)
	_spell_row.anchor_top = 1.0
	_spell_row.anchor_bottom = 1.0
	_spell_row.offset_left = 8
	_spell_row.offset_bottom = -8
	_spell_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_spell_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_spell_row)
	# справа вверху: карточки героев (их создаёт bind)
	_hero_row = HBoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 6)
	_hero_row.anchor_left = 1.0
	_hero_row.anchor_right = 1.0
	_hero_row.offset_right = -8
	_hero_row.offset_top = 8
	_hero_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hero_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hero_row)


func _small_button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	parent.add_child(b)
	return b


## Главный узел вызывает это, когда герои и заклинания уже созданы: строим кнопки и карточки.
func bind(book: Spellbook, heroes: Array[Hero]) -> void:
	_book = book
	_heroes = heroes
	for i in book.spells.size():
		var id := book.spells[i]
		var b := CdButton.new()
		b.text = "%d  %s" % [i + 1, Defs.SPELLS[id]["name"]]
		b.add_theme_font_size_override("font_size", 14)
		b.tooltip_text = Defs.SPELLS[id]["info"]
		b.pressed.connect(func(): spell_pressed.emit(i))
		_spell_row.add_child(b)
		_spell_buttons.append(b)
	for i in heroes.size():
		_hero_row.add_child(_make_hero_card(i, heroes[i]))


func _make_hero_card(i: int, hero: Hero) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	var select := Button.new()
	select.text = "%s, %s" % [hero.def["name"], hero.def["role"]]
	select.add_theme_font_size_override("font_size", 13)
	select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select.clip_text = true
	select.custom_minimum_size.x = 150.0
	select.pressed.connect(func(): hero_pressed.emit(i))
	box.add_child(select)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = hero.max_hp
	bar.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 4, 0))
	bar.add_theme_stylebox_override("fill", _box(Color("59c46a"), Color(0, 0, 0, 0), 4, 0))
	box.add_child(bar)
	var state := _label("", 11, INK_SOFT)
	box.add_child(state)
	var ab := CdButton.new()
	ab.text = "%d  %s" % [4 + i, hero.def["ab"]["name"]]
	ab.add_theme_font_size_override("font_size", 13)
	ab.tooltip_text = hero.def["ab"]["info"]
	ab.pressed.connect(func(): ability_pressed.emit(i))
	box.add_child(ab)
	_hero_cards.append({"select": select, "bar": bar, "state": state, "ability": ab, "panel": card, "on": false})
	return card


func _card_style(selected: bool) -> StyleBoxFlat:
	return _box(Color("fff3cf") if selected else Color(0.96, 0.98, 0.97, 0.94), ACCENT if selected else LINE, 10, 6)


func _update_controls() -> void:
	for i in _spell_buttons.size():
		var id := _book.spells[i]
		_spell_buttons[i].set_state(_book.cooldown_fraction(id), _book.armed == id)
	for i in _hero_cards.size():
		var h := _heroes[i]
		var c: Dictionary = _hero_cards[i]
		c["bar"].value = maxf(0.0, h.hp) if not h.dead else 0.0
		var state: Label = c["state"]
		if h.dead:
			state.text = "вернётся через %d с" % ceili(h.respawn)
		elif h.ability_cd > 0.0:
			state.text = "способность: %d с" % ceili(h.ability_cd)
		else:
			state.text = "способность готова"
		c["ability"].set_state(clampf(h.ability_cd / float(h.def["ab"]["cd"]), 0.0, 1.0), false)
		var sel: Button = c["select"]
		var on := h.selected
		if on != c["on"]:
			c["on"] = on
			var panel: PanelContainer = c["panel"]
			panel.add_theme_stylebox_override("panel", _card_style(on))
		sel.text = "%s%s, %s" % ["▶ " if on else "", h.def["name"], h.def["role"]]


func _build_menu(root: Control) -> void:
	_menu = PanelContainer.new()
	_menu.visible = false
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 4)
	_menu.add_child(_menu_box)
	root.add_child(_menu)


func _build_end(root: Control) -> void:
	_end = PanelContainer.new()
	_end.visible = false
	_end.set_anchors_preset(Control.PRESET_CENTER)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(300, 0)
	_end.add_child(box)
	_end_title = Label.new()
	_end_title.add_theme_font_size_override("font_size", 28)
	_end_title.add_theme_color_override("font_color", INK)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_title)
	_end_stars = Label.new()
	_end_stars.add_theme_font_size_override("font_size", 20)
	_end_stars.add_theme_color_override("font_color", Color("a0710f"))
	_end_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_stars)
	_end_text = Label.new()
	_end_text.add_theme_color_override("font_color", INK_SOFT)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_end_text)
	var again := Button.new()
	again.text = "Сыграть ещё раз"
	again.pressed.connect(func(): restart_requested.emit())
	box.add_child(again)
	var back := Button.new()
	back.text = "Сменить героев и заклинания"
	back.pressed.connect(func(): prep_requested.emit())
	box.add_child(back)
	root.add_child(_end)


# ---------- то, что вызывает main.gd ----------

func set_info(text: String) -> void:
	_info.text = text


func set_wave_button(text: String, enabled: bool) -> void:
	_wave_button.text = text
	_wave_button.disabled = not enabled


func set_speed_text(speed: float) -> void:
	_speed_button.text = "Скорость ×%d" % int(speed)


func set_pause_text(paused: bool) -> void:
	_pause_button.text = "Продолжить" if paused else "Пауза"


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.4
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_panel.reset_size()
	var width := _toast_panel.get_combined_minimum_size().x
	_toast_panel.size.x = width
	_toast_panel.position.x = (Defs.VIEW.x - width) * 0.5


func open_menu(pad: Pad) -> void:
	_pad = pad
	_rebuild_menu()


func close_menu() -> void:
	_pad = null
	_menu.visible = false


func refresh_menu() -> void:
	if _pad != null:
		_rebuild_menu()


# ---------- меню башни ----------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rebuild_menu() -> void:
	for c in _menu_box.get_children():
		_menu_box.remove_child(c)
		c.queue_free()
	var pad := _pad
	var tower := pad.tower
	if tower == null:
		_menu_box.add_child(_label("Построить башню", 18, INK))
		for kind in Defs.TOWER_ORDER:
			var d: Dictionary = Defs.TOWERS[kind]
			var b := Button.new()
			b.text = "%s — %d" % [d["name"], d["cost"]]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if Game.gold < int(d["cost"]):
				b.modulate = Color(1, 1, 1, 0.55)
			b.pressed.connect(func(): build_requested.emit(pad, kind))
			_menu_box.add_child(b)
			_menu_box.add_child(_label(d["blurb"], 12, INK_SOFT))
	else:
		var d: Dictionary = Defs.TOWERS[tower.kind]
		var s := tower.stat()
		_menu_box.add_child(_label("%s, уровень %d из 3" % [d["name"], tower.level], 18, INK))
		if tower.kind == "barracks":
			_menu_box.add_child(_label("Рыцарей: %d, здоровье %d, урон %d" % [int(s["n"]), int(s["hp"]), int(s["dmg"])], 13, INK_SOFT))
			_menu_box.add_child(_label("Нажми внутри синего круга, чтобы отправить рыцарей туда.", 12, INK_SOFT))
		else:
			_menu_box.add_child(_label("Урон %d, дальность %d" % [int(s["dmg"]), int(s["range"])], 13, INK_SOFT))
		var up := tower.upgrade_cost()
		if up > 0:
			var ub := Button.new()
			ub.text = "Улучшить — %d" % up
			ub.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if Game.gold < up:
				ub.modulate = Color(1, 1, 1, 0.55)
			ub.pressed.connect(func(): upgrade_requested.emit(pad))
			_menu_box.add_child(ub)
		else:
			_menu_box.add_child(_label("Максимальный уровень", 13, INK_SOFT))
		var sb := Button.new()
		sb.text = "Продать +%d" % tower.sell_value()
		sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sb.pressed.connect(func(): sell_requested.emit(pad))
		_menu_box.add_child(sb)
	_menu.visible = true
	_menu.reset_size()
	var size := _menu.get_combined_minimum_size()
	_menu.size = size
	# над башней нужно больше места, чтобы меню не закрывало её саму
	var lift := 78.0 if tower != null else 34.0
	var pos := pad.global_position + Vector2(-size.x * 0.5, -size.y - lift)
	if pos.y < 64.0:
		# сверху не поместилось: ставим меню сбоку от площадки
		pos = Vector2(pad.global_position.x + 44.0, pad.global_position.y - size.y * 0.5)
		if pos.x + size.x > Defs.VIEW.x - 6.0:
			pos.x = pad.global_position.x - 44.0 - size.x
	pos.x = clampf(pos.x, 6.0, Defs.VIEW.x - size.x - 6.0)
	pos.y = clampf(pos.y, 64.0, Defs.VIEW.y - size.y - 60.0)
	_menu.position = pos


func _on_gold(value: int) -> void:
	_gold.text = "Золото: %d" % value
	refresh_menu()


func _on_finished(win: bool, stars: int) -> void:
	close_menu()
	_end_title.text = "Победа" if win else "Орки прорвались"
	_end_stars.text = "Звёзды: %d из 3" % stars if win else ""
	if win:
		_end_text.text = "Осталось жизней: %d. Побеждено орков: %d." % [Game.lives, Game.kills]
	else:
		_end_text.text = "Дошли до волны %d из %d. Побеждено орков: %d." % [Game.wave, Defs.WAVES.size(), Game.kills]
	_end.visible = true
	_end.reset_size()
	_end.position = (Defs.VIEW - _end.get_combined_minimum_size()) * 0.5
