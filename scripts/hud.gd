class_name Hud
extends CanvasLayer
## Интерфейс боя: жизни, золото, волна, герои и заклинания внизу слева, круговое меню башен, экран конца боя.
## Всё собирается кодом. Оформление «дерево и золото» лежит в Ui, значки в Icons.

signal wave_requested
signal speed_toggled
signal pause_toggled
signal build_requested(pad: Pad, kind: String)
signal upgrade_requested(pad: Pad)
signal sell_requested(pad: Pad)
signal restart_requested
signal map_requested
signal spell_pressed(index: int)
signal hero_pressed(index: int)
signal ability_pressed(index: int)

const RING_RADIUS := 58.0
const SAFE_RECT := Rect2(30, 60, 900, 402)   # сюда должны попадать кнопки кругового меню

var _root: Control
var _lives: Label
var _gold: Label
var _wave: Label
var _info: Label
var _toast_panel: PanelContainer
var _toast: Label
var _toast_time := 0.0
var _wave_button: Button
var _speed_button: RoundButton
var _pause_button: RoundButton

var _book: Spellbook
var _heroes: Array[Hero] = []
var _spell_buttons: Array[RoundButton] = []
var _hero_widgets: Array[Dictionary] = []
var _bar_box: HBoxContainer

var _ring: Control
var _ring_info: PanelContainer
var _ring_title: Label
var _ring_text: Label
var _ring_default := ["", ""]
var _pad: Pad = null

var _end: PanelContainer
var _end_title: Label
var _end_text: Label
var _end_stars: Array[IconView] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Ui.make_theme()
	add_child(_root)
	_build_top()
	_build_bottom()
	_build_ring()
	_build_end()
	Game.gold_changed.connect(_on_gold)
	Game.lives_changed.connect(func(v: int): _lives.text = str(v))
	Game.wave_changed.connect(func(cur: int, total: int): _wave.text = "Волна %d / %d" % [cur, total])
	Game.message.connect(show_toast)
	Game.finished.connect(_on_finished)
	# после нажатия кнопка не должна забирать клавиши игры себе
	get_viewport().gui_focus_changed.connect(func(control: Control): control.release_focus())


func _process(delta: float) -> void:
	if _book != null:
		_update_controls()
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast_panel.modulate.a = clampf(_toast_time * 4.0, 0.0, 1.0)
		_toast_panel.visible = _toast_time > 0.0


# ---------- сборка интерфейса ----------

func _plaque(parent: Control, icon: String, text: String, min_width := 0.0) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.box(Color(Ui.WOOD_DARK.r, Ui.WOOD_DARK.g, Ui.WOOD_DARK.b, 0.92), Ui.GOLD_DARK, 16, 4, 3))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(IconView.new(icon, 24.0))
	var label := Ui.label(text, 17)
	label.custom_minimum_size.x = min_width
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	parent.add_child(panel)
	return label


func _build_top() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(8, 8)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(row)
	_lives = _plaque(row, "heart", "20", 24.0)
	_gold = _plaque(row, "coin", "220", 40.0)
	_wave = _plaque(row, "flag", "Волна 0 / 10", 96.0)
	_info = Ui.label("", 14)
	_info.position = Vector2(12, 46)
	_info.custom_minimum_size.x = 640.0
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_info)
	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", Ui.box(Color(Ui.WOOD_DARK.r, Ui.WOOD_DARK.g, Ui.WOOD_DARK.b, 0.94), Ui.GOLD, 14, 6, 2))
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.position.y = 100
	_toast_panel.visible = false
	_toast = Ui.label("", 16)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast)
	_root.add_child(_toast_panel)
	# справа вверху: пауза, скорость, выход на карту
	var corner := HBoxContainer.new()
	corner.add_theme_constant_override("separation", 6)
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.offset_right = -8
	corner.offset_top = 8
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(corner)
	_speed_button = _corner_button(corner, "", "Скорость ×1 / ×2")
	_speed_button.center_text = "×1"
	_speed_button.pressed.connect(func(): speed_toggled.emit())
	_pause_button = _corner_button(corner, "pause", "Пауза")
	_pause_button.pressed.connect(func(): pause_toggled.emit())
	var back := _corner_button(corner, "back", "К карте (бой начнётся заново)")
	back.pressed.connect(func(): map_requested.emit())


func _corner_button(parent: Control, icon: String, tip: String) -> RoundButton:
	var b := RoundButton.new(icon, 40.0)
	b.tooltip_text = tip
	parent.add_child(b)
	return b


func _build_bottom() -> void:
	# слева внизу: герои, потом заклинания (их создаёт bind)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", Ui.box(Color(Ui.WOOD_DARK.r, Ui.WOOD_DARK.g, Ui.WOOD_DARK.b, 0.9), Ui.GOLD_DARK, 12, 5, 3))
	plate.anchor_top = 1.0
	plate.anchor_bottom = 1.0
	plate.offset_left = 8
	plate.offset_bottom = -8
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(plate)
	_bar_box = HBoxContainer.new()
	_bar_box.add_theme_constant_override("separation", 6)
	_bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_bar_box)
	# справа внизу: вызов волны
	_wave_button = Button.new()
	_wave_button.text = "Начать волну 1"
	_wave_button.tooltip_text = "Клавиша Enter. Если вызвать волну, пока орки ещё идут, +15 золота"
	_wave_button.add_theme_font_size_override("font_size", 18)
	_wave_button.add_theme_color_override("font_color", Ui.GOLD)
	_wave_button.add_theme_color_override("font_hover_color", Color("ffe08a"))
	_wave_button.anchor_left = 1.0
	_wave_button.anchor_right = 1.0
	_wave_button.anchor_top = 1.0
	_wave_button.anchor_bottom = 1.0
	_wave_button.offset_right = -8
	_wave_button.offset_bottom = -8
	_wave_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_wave_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_wave_button.pressed.connect(func(): wave_requested.emit())
	_root.add_child(_wave_button)


## Главный узел вызывает это, когда герои и заклинания уже созданы: строим кнопки.
func bind(book: Spellbook, heroes: Array[Hero]) -> void:
	_book = book
	_heroes = heroes
	for i in heroes.size():
		_bar_box.add_child(_make_hero_widget(i, heroes[i]))
	if not heroes.is_empty():
		var sep := VSeparator.new()
		sep.add_theme_constant_override("separation", 10)
		_bar_box.add_child(sep)
	for i in book.spells.size():
		var id := book.spells[i]
		var b := RoundButton.new("sp:" + id, 54.0)
		b.badge = str(i + 1)
		b.tooltip_text = "%s\n%s" % [Defs.SPELLS[id]["name"], Defs.SPELLS[id]["info"]]
		b.pressed.connect(func(): spell_pressed.emit(i))
		_bar_box.add_child(b)
		_spell_buttons.append(b)


func _make_hero_widget(i: int, hero: Hero) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var portrait := RoundButton.new("hero:" + hero.hid, 54.0)
	portrait.tooltip_text = "%s, %s\nНажми на героя, потом на землю: он пойдёт туда. Пробел выбирает героев по очереди." % [hero.def["name"], hero.def["role"]]
	portrait.pressed.connect(func(): hero_pressed.emit(i))
	col.add_child(portrait)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 7)
	bar.max_value = hero.max_hp
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	var ability := RoundButton.new("ab:" + hero.hid, 42.0)
	ability.badge = str(4 + i)
	ability.tooltip_text = "%s\n%s" % [hero.def["ab"]["name"], hero.def["ab"]["info"]]
	ability.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ability.pressed.connect(func(): ability_pressed.emit(i))
	row.add_child(ability)
	_hero_widgets.append({"portrait": portrait, "bar": bar, "ability": ability})
	return row


func _update_controls() -> void:
	for i in _spell_buttons.size():
		var id := _book.spells[i]
		var left := float(_book.cooldown.get(id, 0.0))
		_spell_buttons[i].set_state(_book.cooldown_fraction(id), "" if left <= 0.0 else str(ceili(left)), _book.armed == id)
	for i in _hero_widgets.size():
		var h := _heroes[i]
		var w: Dictionary = _hero_widgets[i]
		var bar: ProgressBar = w["bar"]
		bar.value = 0.0 if h.dead else maxf(0.0, h.hp)
		var portrait: RoundButton = w["portrait"]
		portrait.set_state(1.0 if h.dead else 0.0, str(ceili(h.respawn)) if h.dead else "", h.selected)
		var ability: RoundButton = w["ability"]
		ability.set_state(clampf(h.ability_cd / float(h.def["ab"]["cd"]), 0.0, 1.0), "" if h.ability_cd <= 0.0 else str(ceili(h.ability_cd)), false)


# ---------- то, что вызывает main.gd ----------

func set_info(text: String) -> void:
	_info.text = text


func set_wave_button(text: String, enabled: bool) -> void:
	_wave_button.text = text
	_wave_button.disabled = not enabled


func set_speed_text(speed: float) -> void:
	_speed_button.center_text = "×%d" % int(speed)
	_speed_button.queue_redraw()


func set_pause_text(paused: bool) -> void:
	_pause_button.icon_id = "play" if paused else "pause"
	_pause_button.queue_redraw()


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
	_clear_ring()
	_ring_info.visible = false


func refresh_menu() -> void:
	if _pad != null:
		_rebuild_menu()


# ---------- круговое меню башни ----------

func _build_ring() -> void:
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ring)
	_ring_info = PanelContainer.new()
	_ring_info.visible = false
	_ring_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_info.add_child(box)
	_ring_title = Ui.label("", 15, Ui.GOLD)
	_ring_text = Ui.label("", 12, Ui.CREAM)
	_ring_text.custom_minimum_size.x = 200.0
	_ring_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_ring_title)
	box.add_child(_ring_text)
	_root.add_child(_ring_info)


func _clear_ring() -> void:
	for c in _ring.get_children():
		_ring.remove_child(c)
		c.queue_free()


func _stat_line(tower: Tower) -> String:
	var s := tower.stat()
	if tower.kind == "barracks":
		return "Рыцарей: %d, здоровье %d, урон %d. Нажми внутри синего круга, чтобы отправить их туда." % [int(s["n"]), int(s["hp"]), int(s["dmg"])]
	return "Урон %d, дальность %d" % [int(s["dmg"]), int(s["range"])]


func _rebuild_menu() -> void:
	_clear_ring()
	var pad := _pad
	var tower := pad.tower
	var items: Array[Dictionary] = []
	if tower == null:
		_ring_default = ["Построить башню", "Наведи на башню, чтобы узнать о ней"]
		for kind in Game.loadout_towers:
			var d: Dictionary = Defs.TOWERS[kind]
			items.append({"icon": "tower:" + kind, "caption": str(d["cost"]), "dim": Game.gold < int(d["cost"]),
				"title": "%s — %d" % [d["name"], d["cost"]], "text": d["blurb"],
				"action": func(): build_requested.emit(pad, kind)})
	else:
		var d: Dictionary = Defs.TOWERS[tower.kind]
		_ring_default = ["%s, уровень %d из 3" % [d["name"], tower.level], _stat_line(tower)]
		var up := tower.upgrade_cost()
		if up > 0:
			items.append({"icon": "up", "caption": str(up), "dim": Game.gold < up,
				"title": "Улучшить — %d" % up, "text": "До уровня %d" % (tower.level + 1),
				"action": func(): upgrade_requested.emit(pad)})
		items.append({"icon": "coin", "caption": "+%d" % tower.sell_value(), "dim": false,
			"title": "Продать +%d" % tower.sell_value(), "text": "Возвращается 70% вложенного",
			"action": func(): sell_requested.emit(pad)})
	var center := pad.global_position + (Vector2(0, -22) if tower != null else Vector2.ZERO)
	var layout := _ring_layout(center, items.size())
	var top := 1e9
	var bottom := -1e9
	for i in items.size():
		var it: Dictionary = items[i]
		var b := RoundButton.new(it["icon"], 46.0)
		b.caption = it["caption"]
		b.dimmed = it["dim"]
		b.position = layout["points"][i] - Vector2(23, 23)
		var action: Callable = it["action"]
		b.pressed.connect(action)
		b.mouse_entered.connect(_set_info.bind(it["title"], it["text"]))
		b.mouse_exited.connect(_set_info.bind(_ring_default[0], _ring_default[1]))
		_ring.add_child(b)
		top = minf(top, b.position.y)
		bottom = maxf(bottom, b.position.y + 46.0 + 16.0)
	_set_info(_ring_default[0], _ring_default[1])
	_ring_info.visible = true
	_ring_info.reset_size()
	var size := _ring_info.get_combined_minimum_size()
	_ring_info.size = size
	var pos := Vector2(center.x - size.x * 0.5, top - size.y - 6.0)
	if pos.y < 50.0:
		pos.y = bottom + 4.0
	pos.x = clampf(pos.x, 6.0, Defs.VIEW.x - size.x - 6.0)
	pos.y = clampf(pos.y, 50.0, Defs.VIEW.y - size.y - 60.0)
	_ring_info.position = pos


func _set_info(title: String, text: String) -> void:
	_ring_title.text = title
	_ring_text.text = text
	_ring_info.reset_size()
	_ring_info.size = _ring_info.get_combined_minimum_size()


## Раскладывает n кнопок дугой вокруг точки. Выбирает сторону (вверх, вниз, вправо, влево), где всё помещается на экране.
func _ring_layout(center: Vector2, n: int) -> Dictionary:
	var step := deg_to_rad(62.0 if n <= 2 else 50.0)
	var best: Array = []
	for dir_deg in [-90.0, 90.0, 0.0, 180.0]:
		var pts: Array = []
		var ok := true
		for i in n:
			var a := deg_to_rad(dir_deg) + (i - (n - 1) / 2.0) * step
			var p := center + Vector2(cos(a), sin(a)) * RING_RADIUS
			pts.append(p)
			if not SAFE_RECT.has_point(p):
				ok = false
		if best.is_empty():
			best = pts
		if ok:
			best = pts
			break
	# не нашли идеальную сторону: сдвигаем кнопки внутрь безопасной зоны
	var fixed: Array = []
	for p: Vector2 in best:
		fixed.append(Vector2(clampf(p.x, SAFE_RECT.position.x, SAFE_RECT.end.x), clampf(p.y, SAFE_RECT.position.y, SAFE_RECT.end.y)))
	return {"points": fixed}


# ---------- конец боя ----------

func _build_end() -> void:
	_end = PanelContainer.new()
	_end.visible = false
	_end.add_theme_stylebox_override("panel", Ui.box(Color(Ui.WOOD.r, Ui.WOOD.g, Ui.WOOD.b, 0.98), Ui.GOLD, 14, 14, 4))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(320, 0)
	_end.add_child(box)
	_end_title = Ui.label("", 30, Ui.GOLD)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_title)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 6)
	for i in 3:
		var star := IconView.new("star", 46.0)
		stars.add_child(star)
		_end_stars.append(star)
	box.add_child(stars)
	_end_text = Ui.label("", 15)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_end_text)
	var again := Button.new()
	again.text = "Сыграть ещё раз"
	again.pressed.connect(func(): restart_requested.emit())
	box.add_child(again)
	var back := Button.new()
	back.text = "К карте (сменить героев и заклинания)"
	back.pressed.connect(func(): map_requested.emit())
	box.add_child(back)
	_root.add_child(_end)


func _on_gold(value: int) -> void:
	_gold.text = str(value)
	refresh_menu()


func _on_finished(win: bool, stars: int) -> void:
	close_menu()
	_end_title.text = "Победа!" if win else "Орки прорвались"
	for i in 3:
		_end_stars[i].filled = i < stars
		_end_stars[i].visible = win
	if win:
		_end_text.text = "Осталось жизней: %d. Побеждено орков: %d." % [Game.lives, Game.kills]
	else:
		_end_text.text = "Дошли до волны %d из %d. Побеждено орков: %d." % [Game.wave, Defs.WAVES.size(), Game.kills]
	_end.visible = true
	_end.reset_size()
	_end.position = (Defs.VIEW - _end.get_combined_minimum_size()) * 0.5
