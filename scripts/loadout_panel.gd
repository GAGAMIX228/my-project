class_name LoadoutPanel
extends PanelContainer
## Раздел сборки на экране карты: герои, башни или заклинания (какой именно, задаёт show_tab).
## Открывается кнопками нижней панели. Слева слоты (что идёт в бой), справа коллекция карточек. Нажми на слот, потом на карточку: карточка займёт этот слот.
## Если карточка уже стоит в другом слоте, они поменяются местами. Выбор хранится в Game.loadout_*.

signal changed
signal closed

const LIMITS := {"hero": 2, "tower": 5, "spell": 3}
const TAB_NAMES := {"hero": "Герои", "tower": "Башни", "spell": "Заклинания"}
const HINTS := {
	"hero": "Нажми на слот героя, потом на карточку: она займёт этот слот. Если герой уже стоит в другом слоте, они поменяются местами.",
	"tower": "Пока открыты только четыре башни людей, все они идут в бой. Остальные откроются за победы над расами.",
	"spell": "Нажми на слот заклинания, потом на карточку: она займёт этот слот. Клавиши в бою: 1, 2, 3 по порядку слотов.",
}

var kind := "hero"
var active := {"hero": 0, "spell": 0, "tower": 0}   # слот, в который попадёт следующая выбранная карточка

var _title: Label
var _slots_row: HBoxContainer
var _cards_row: HBoxContainer
var _info_title: Label
var _info_text: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_title = Ui.label("", 20, Ui.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := RoundButton.new("close", 30.0)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	box.add_child(body)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 6)
	body.add_child(_slots_row)
	body.add_child(VSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 122)
	body.add_child(scroll)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 6)
	scroll.add_child(_cards_row)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", Ui.box(Ui.WOOD_DARK, Ui.WOOD_LIGHT, 6, 4, 2))
	var info_box := HBoxContainer.new()
	info_box.add_theme_constant_override("separation", 10)
	info.add_child(info_box)
	_info_title = Ui.label("", 14, Ui.GOLD)
	_info_title.custom_minimum_size.x = 150.0
	_info_text = Ui.label("", 12, Ui.CREAM)
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_text.custom_minimum_size = Vector2(600, 32)
	info_box.add_child(_info_title)
	info_box.add_child(_info_text)
	box.add_child(info)
	_rebuild()


func show_tab(k: String) -> void:
	kind = k
	_rebuild()


## Выбирает слот, в который попадёт следующая карточка.
func select_slot(k: String, index: int) -> void:
	active[k] = index
	_rebuild()


## Кладёт героя, заклинание или башню в выбранный слот. Если он уже лежит в другом слоте, они меняются местами.
func assign(k: String, id: String) -> void:
	if k == "tower":
		return   # пока башен ровно четыре и все идут в бой
	var list := _loadout(k)
	var slot: int = active[k]
	var at := list.find(id)
	if at != slot:
		if at >= 0:
			list[at] = list[slot]
		list[slot] = id
		changed.emit()
	active[k] = (slot + 1) % list.size()
	_rebuild()


func _loadout(k: String) -> Array[String]:
	match k:
		"hero": return Game.loadout_heroes
		"spell": return Game.loadout_spells
	return Game.loadout_towers


func _all_ids(k: String) -> Array:
	match k:
		"hero": return Defs.HERO_ORDER
		"spell": return Defs.SPELL_ORDER
	return Defs.TOWER_ORDER


## Всё, что нужно показать про карточку: значок, подписи и подробный текст.
func _describe(k: String, id: String) -> Dictionary:
	if k == "hero":
		var d: Dictionary = Defs.HEROES[id]
		var ab: Dictionary = d["ab"]
		var short := {"melee": "ближний", "ranged": "дальний", "dragon": "дракон"}
		return {"icon": "hero:" + id, "title": d["name"], "sub": short[d["kind"]],
			"head": "%s, %s (%s)" % [d["name"], d["role"], Defs.KIND_TEXT[d["kind"]]],
			"text": "Здоровье %d. Способность «%s» (перезарядка %d с): %s." % [int(d["hp"]), ab["name"], int(ab["cd"]), ab["info"]]}
	if k == "spell":
		var d: Dictionary = Defs.SPELLS[id]
		return {"icon": "sp:" + id, "title": d["name"], "sub": d["race"],
			"head": d["name"], "text": "%s. Перезарядка %d с." % [d["info"], int(d["cd"])]}
	var d: Dictionary = Defs.TOWERS[id]
	return {"icon": "tower:" + id, "title": d["name"], "sub": "%d зол." % int(d["cost"]),
		"head": d["name"], "text": "%s. Цена %d, улучшения: %d и %d." % [d["blurb"], int(d["cost"]), int(d["upgrades"][0]), int(d["upgrades"][1])]}


func _rebuild() -> void:
	_title.text = "%s: выбрано %d из %d" % [TAB_NAMES[kind], _loadout(kind).size(), LIMITS[kind]]
	for row: Control in [_slots_row, _cards_row]:
		for c in row.get_children():
			row.remove_child(c)
			c.queue_free()
	var list := _loadout(kind)
	for i in LIMITS[kind]:
		var card: CardButton
		if i < list.size():
			var d := _describe(kind, list[i])
			card = CardButton.new(d["icon"], d["title"], d["sub"])
			card.badge = str(i + 1)
			_hover(card, d["head"], d["text"])
		else:
			card = CardButton.new("", "Закрыто", "нет башни")
			card.empty = true
			card.locked = true
			_hover(card, "Пустой слот", "Здесь появится башня, когда ты откроешь её в кампании.")
		card.active_slot = kind != "tower" and i == active[kind]
		card.pressed.connect(select_slot.bind(kind, i))
		_slots_row.add_child(card)
	for id: String in _all_ids(kind):
		var d := _describe(kind, id)
		var card := CardButton.new(d["icon"], d["title"], d["sub"])
		card.picked = id in list
		_hover(card, d["head"], d["text"])
		card.pressed.connect(assign.bind(kind, id))
		_cards_row.add_child(card)
	if kind == "tower":
		for t: Array in Defs.FUTURE_TOWERS:
			var card := CardButton.new("", t[0], t[1])
			card.locked = true
			_hover(card, t[0], "Башня народа «%s». Откроется после победы над ними." % t[1])
			_cards_row.add_child(card)
	_show_info("Сборка перед боем", HINTS[kind])


func _hover(card: CardButton, head: String, text: String) -> void:
	card.mouse_entered.connect(_show_info.bind(head, text))
	card.mouse_exited.connect(_show_info.bind("Сборка перед боем", HINTS[kind]))


func _show_info(head: String, text: String) -> void:
	_info_title.text = head
	_info_text.text = text
