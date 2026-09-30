class_name Defs
extends RefCounted
## Все цифры игры лежат здесь. Поменяй число, и игра изменится.

const START_GOLD := 220
const START_LIVES := 20
const VIEW := Vector2(960, 540)

## Общий коэффициент здоровья врагов. Им настраивается сложность. Это переменная, а не константа,
## чтобы автотесты могли пробовать разные значения (см. tests/sim.gd).
static var hp_scale := 1.3

## Дорога, по которой идут орки (точки поворота).
const PATH := [
	Vector2(-30, 130), Vector2(170, 130), Vector2(170, 400), Vector2(420, 400),
	Vector2(420, 150), Vector2(690, 150), Vector2(690, 420), Vector2(990, 420),
]

## Каменные площадки, на которых можно строить башни.
const PADS := [
	Vector2(95, 265), Vector2(245, 215), Vector2(300, 340), Vector2(300, 448),
	Vector2(350, 240), Vector2(495, 270), Vector2(555, 85), Vector2(555, 215),
	Vector2(625, 300), Vector2(765, 300), Vector2(850, 350),
]

## Враги. hp: здоровье, speed: пикселей в секунду, armor: доля физического урона,
## которую враг не пропускает, mres: то же для магии, leak: сколько жизней отнимет, если дойдёт.
const ENEMIES := {
	"grunt": {"name": "Орк-воин", "hp": 82, "speed": 55.0, "armor": 0.0, "mres": 0.0, "gold": 6, "radius": 11.0, "leak": 1, "atk": 5, "fly": false},
	"raider": {"name": "Волчий наездник", "hp": 51, "speed": 97.0, "armor": 0.0, "mres": 0.0, "gold": 5, "radius": 9.0, "leak": 1, "atk": 3, "fly": false},
	"shield": {"name": "Орк-щитоносец", "hp": 234, "speed": 44.0, "armor": 0.5, "mres": 0.0, "gold": 14, "radius": 13.0, "leak": 2, "atk": 7, "fly": false},
	"berserk": {"name": "Орк-берсерк", "hp": 195, "speed": 47.0, "armor": 0.1, "mres": 0.0, "gold": 13, "radius": 12.0, "leak": 2, "atk": 8, "fly": false},
	"shaman": {"name": "Орк-шаман", "hp": 124, "speed": 46.0, "armor": 0.0, "mres": 0.0, "gold": 16, "radius": 11.0, "leak": 1, "atk": 3, "fly": false},
	"warlock": {"name": "Орк-колдун", "hp": 143, "speed": 50.0, "armor": 0.0, "mres": 0.65, "gold": 14, "radius": 11.0, "leak": 1, "atk": 6, "fly": false},
	"gryph": {"name": "Орк на грифе", "hp": 98, "speed": 88.0, "armor": 0.0, "mres": 0.0, "gold": 12, "radius": 11.0, "leak": 2, "atk": 0, "fly": true},
	"chief": {"name": "Вождь орков", "hp": 1755, "speed": 34.0, "armor": 0.35, "mres": 0.2, "gold": 120, "radius": 19.0, "leak": 5, "atk": 16, "fly": false},
}

## Башни людей. У каждой три уровня. upgrades: цена улучшения до 2-го и до 3-го уровня.
const TOWERS := {
	"archer": {
		"name": "Лучники", "cost": 70, "upgrades": [60, 110],
		"blurb": "Быстрые стрелы, физический урон, бьют и по воздуху",
		"levels": [
			{"dmg": 8.0, "range": 150.0, "rate": 0.7},
			{"dmg": 12.0, "range": 160.0, "rate": 0.65},
			{"dmg": 17.0, "range": 172.0, "rate": 0.6},
		],
	},
	"barracks": {
		"name": "Казарма рыцарей", "cost": 90, "upgrades": [70, 120],
		"blurb": "Рыцари перекрывают дорогу и дерутся",
		"levels": [
			{"n": 2, "hp": 70.0, "dmg": 6.0, "rate": 0.85, "range": 115.0},
			{"n": 2, "hp": 105.0, "dmg": 9.0, "rate": 0.8, "range": 128.0},
			{"n": 3, "hp": 140.0, "dmg": 13.0, "rate": 0.75, "range": 140.0},
		],
	},
	"mage": {
		"name": "Башня магов", "cost": 100, "upgrades": [80, 140],
		"blurb": "Магия, игнорирует броню, бьёт и по воздуху",
		"levels": [
			{"dmg": 18.0, "range": 135.0, "rate": 1.2},
			{"dmg": 30.0, "range": 145.0, "rate": 1.1},
			{"dmg": 46.0, "range": 155.0, "rate": 1.0},
		],
	},
	"mortar": {
		"name": "Мортира", "cost": 120, "upgrades": [90, 150],
		"blurb": "Медленно, урон по площади, только по земле",
		"levels": [
			{"dmg": 26.0, "range": 185.0, "rate": 2.5, "min_range": 50.0, "splash": 46.0},
			{"dmg": 40.0, "range": 195.0, "rate": 2.3, "min_range": 50.0, "splash": 52.0},
			{"dmg": 60.0, "range": 205.0, "rate": 2.1, "min_range": 50.0, "splash": 58.0},
		],
	},
}
const TOWER_ORDER := ["archer", "barracks", "mage", "mortar"]

## Волны: [тип врага, сколько, пауза между ними в секундах].
const WAVES := [
	[["grunt", 6, 1.3]],
	[["grunt", 8, 1.0], ["raider", 3, 0.8]],
	[["raider", 8, 0.75], ["grunt", 5, 1.0]],
	[["shield", 3, 2.2], ["grunt", 9, 0.9]],
	[["gryph", 5, 1.3], ["grunt", 8, 0.9]],
	[["warlock", 4, 1.8], ["shield", 3, 1.8], ["raider", 6, 0.6]],
	[["berserk", 4, 1.8], ["grunt", 10, 0.7], ["shaman", 2, 1.8]],
	[["gryph", 8, 0.9], ["shield", 5, 1.4], ["warlock", 3, 1.6]],
	[["berserk", 6, 1.3], ["shaman", 3, 1.5], ["shield", 6, 1.3], ["raider", 8, 0.5]],
	[["chief", 1, 1.0], ["berserk", 3, 1.5], ["shaman", 3, 1.5], ["gryph", 5, 1.0], ["shield", 4, 1.3]],
]

## Герои. kind: melee (ближний бой), ranged (дальний), dragon (летает и стреляет).
## hp: здоровье, dmg и rate: урон и пауза между ударами, engage: на каком расстоянии от места ближний герой
## замечает врагов, range: дальность стрельбы, respawn: через сколько секунд он вернётся после гибели.
## ab: способность. cd: перезарядка, остальные числа нужны самой способности (см. hero.gd).
const HEROES := {
	"edrik": {"name": "Эдрик", "role": "Рыцарь", "kind": "melee", "color": Color("4a78c4"), "hp": 220.0, "dmg": 12.0, "rate": 0.7,
		"speed": 110.0, "engage": 100.0, "radius": 11.0, "respawn": 12.0,
		"ab": {"name": "Рывок щитом", "cd": 14.0, "reach": 260.0, "radius": 80.0, "stun": 2.4, "dmg": 30.0,
			"info": "Бросается на ближайшего врага, оглушает и бьёт всех рядом"}},
	"grum": {"name": "Грум", "role": "Огр-страж", "kind": "melee", "color": Color("b58542"), "hp": 340.0, "dmg": 20.0, "rate": 1.1,
		"speed": 85.0, "engage": 95.0, "radius": 14.0, "respawn": 14.0,
		"ab": {"name": "Удар о землю", "cd": 16.0, "radius": 125.0, "stun": 2.6, "dmg": 20.0,
			"info": "Оглушает всех наземных врагов вокруг"}},
	"kara": {"name": "Кара", "role": "Орк-берсерк", "kind": "melee", "color": Color("5f9440"), "hp": 180.0, "dmg": 10.0, "rate": 0.55,
		"speed": 120.0, "engage": 100.0, "radius": 11.0, "respawn": 12.0,
		"ab": {"name": "Ярость", "cd": 18.0, "time": 8.0,
			"info": "На 8 секунд бьёт быстрее и сильнее. Чем меньше здоровья, тем сильнее удары"}},
	"tarn": {"name": "Тарн", "role": "Следопыт", "kind": "ranged", "color": Color("4f9a55"), "hp": 130.0, "dmg": 13.0, "rate": 0.85,
		"range": 170.0, "speed": 105.0, "radius": 10.0, "respawn": 12.0, "shot": "arrow", "dtype": "phys",
		"ab": {"name": "Точный выстрел", "cd": 11.0, "reach": 340.0, "dmg": 150.0,
			"info": "Огромный урон самому живучему врагу рядом"}},
	"xol": {"name": "Ксол", "role": "Маг глубин", "kind": "ranged", "color": Color("2a9fb5"), "hp": 110.0, "dmg": 15.0, "rate": 1.0,
		"range": 155.0, "speed": 100.0, "radius": 10.0, "respawn": 12.0, "shot": "orb", "dtype": "magic", "col": Color("7fe0ff"),
		"ab": {"name": "Ледяной шквал", "cd": 14.0, "reach": 270.0, "radius": 75.0, "stun": 1.6, "dmg": 45.0,
			"info": "Урон по площади и заморозка"}},
	"ishta": {"name": "Ишта", "role": "Шаманка предков", "kind": "ranged", "color": Color("8b5fc0"), "hp": 110.0, "dmg": 11.0, "rate": 0.9,
		"range": 155.0, "speed": 100.0, "radius": 10.0, "respawn": 12.0, "shot": "orb", "dtype": "magic", "col": Color("d9b8ff"),
		"ab": {"name": "Призыв духов", "cd": 20.0, "n": 3, "life": 10.0, "hp": 60.0, "dmg": 8.0, "rate": 0.8,
			"info": "Три духа сражаются рядом 10 секунд"}},
	"ashgar": {"name": "Ашгар", "role": "Огненный дракон", "kind": "dragon", "color": Color("e2662a"), "hp": 200.0, "dmg": 14.0, "rate": 0.8,
		"range": 135.0, "speed": 150.0, "radius": 14.0, "respawn": 18.0, "shot": "orb", "dtype": "magic", "col": Color("ff9a3a"),
		"ab": {"name": "Огненный шторм", "cd": 16.0, "reach": 270.0, "radius": 85.0, "dmg": 30.0, "burn": 4.0, "burn_dps": 9.0,
			"info": "Огонь по площади, враги горят несколько секунд"}},
	"morven": {"name": "Морвен", "role": "Костяной дракон", "kind": "dragon", "color": Color("cfc9b3"), "hp": 200.0, "dmg": 16.0, "rate": 0.9,
		"range": 115.0, "speed": 150.0, "radius": 14.0, "respawn": 18.0, "shot": "orb", "dtype": "pure", "col": Color("b9ffd0"),
		"ab": {"name": "Жатва душ", "cd": 14.0, "radius": 130.0, "dmg": 16.0, "heal": 10.0, "heal_max": 90.0,
			"info": "Отнимает здоровье у врагов рядом и лечит себя"}},
	"zefira": {"name": "Зефира", "role": "Драконица-маг", "kind": "dragon", "color": Color("5db6e8"), "hp": 180.0, "dmg": 13.0, "rate": 0.8,
		"range": 170.0, "speed": 150.0, "radius": 14.0, "respawn": 18.0, "shot": "orb", "dtype": "magic", "col": Color("c8f0ff"),
		"ab": {"name": "Ураган", "cd": 15.0, "radius": 145.0, "push": 110.0, "dmg": 12.0,
			"info": "Отбрасывает наземных врагов назад по дороге"}},
}
const HERO_ORDER := ["edrik", "grum", "kara", "tarn", "xol", "ishta", "ashgar", "morven", "zefira"]
const KIND_TEXT := {"melee": "ближний бой", "ranged": "дальний бой", "dragon": "летает"}

## Где герои встают в начале боя (ближайшие точки дороги к этим местам).
const HERO_START := [Vector2(300, 400), Vector2(420, 280)]

## Заклинания. aim: road (нужна дорога), area (любое место на карте), none (срабатывает сразу).
## cd: перезарядка в секундах, r: радиус действия. Остальные числа нужны самому заклинанию (см. spellbook.gd).
const SPELLS := {
	"knights": {"name": "Призыв рыцарей", "race": "Люди", "cd": 22.0, "aim": "road",
		"n": 2, "hp": 95.0, "dmg": 9.0, "rate": 0.8, "life": 16.0, "color": Color("4a78c4"),
		"info": "Два рыцаря на дороге на 16 секунд"},
	"meteors": {"name": "Метеориты", "race": "Люди", "cd": 45.0, "aim": "area", "r": 62.0,
		"n": 6, "gap": 0.28, "boom": 44.0, "dmg": 44.0,
		"info": "Шесть метеоритов, чистый урон по земле"},
	"reinforce": {"name": "Подкрепление", "race": "Орки", "cd": 18.0, "aim": "road",
		"n": 3, "hp": 80.0, "dmg": 8.0, "rate": 0.8, "life": 14.0, "color": Color("5f9440"),
		"info": "Три орка-бойца на дороге на 14 секунд"},
	"quake": {"name": "Землетрясение", "race": "Огры", "cd": 50.0, "aim": "none",
		"stun": 2.0, "dmg": 15.0,
		"info": "Оглушает всех наземных врагов на 2 секунды"},
	"frost": {"name": "Ледяная буря", "race": "Йети", "cd": 35.0, "aim": "area", "r": 90.0,
		"stun": 3.0, "dmg": 8.0,
		"info": "Враги в зоне замерзают на 3 секунды"},
	"wrath": {"name": "Гнев предков", "race": "Шаманы", "cd": 28.0, "aim": "area", "r": 80.0,
		"dmg": 45.0,
		"info": "Волна света: магический урон по области"},
	"wave": {"name": "Волна глубин", "race": "Осьминоги", "cd": 30.0, "aim": "area", "r": 110.0,
		"push": 140.0, "dmg": 12.0,
		"info": "Отбрасывает наземных врагов назад по дороге"},
	"fireball": {"name": "Огненный метеор", "race": "Драконы", "cd": 50.0, "aim": "area", "r": 75.0,
		"dmg": 95.0, "burn": 5.0, "burn_dps": 10.0,
		"info": "Большой урон по площади, враги горят"},
}
const SPELL_ORDER := ["knights", "meteors", "reinforce", "quake", "frost", "wrath", "wave", "fireball"]

## Башни рас, которых в игре пока нет. Показываются на экране сборки закрытыми.
const FUTURE_TOWERS := [
	["Застава", "Орки"], ["Метатели валунов", "Огры"], ["Казарма стрелков", "Гоблины"], ["Храм глубин", "Осьминоги"],
	["Башня духов", "Шаманы"], ["Ледяная башня", "Йети"], ["Молниевая башня", "Гномы"], ["Баллиста", "Гномы"],
	["Палач", "Минотавры"], ["Гнездо дракона", "Драконы"],
]

## Локации кампании (на карте). playable: уровень уже есть в игре. pos: место на карте.
const LEVELS := [
	{"id": "orcs", "name": "Земли орков", "race": "Орки", "playable": true, "pos": Vector2(70, 215)},
	{"id": "ogres", "name": "Горы огров", "race": "Огры", "playable": false, "pos": Vector2(170, 115)},
	{"id": "goblins", "name": "Болота гоблинов", "race": "Гоблины", "playable": false, "pos": Vector2(270, 215)},
	{"id": "octopus", "name": "Глубины", "race": "Осьминоги", "playable": false, "pos": Vector2(370, 115)},
	{"id": "shamans", "name": "Земли предков", "race": "Шаманы", "playable": false, "pos": Vector2(470, 215)},
	{"id": "yetis", "name": "Ледяные пики", "race": "Йети", "playable": false, "pos": Vector2(570, 115)},
	{"id": "gnomes", "name": "Подгорье", "race": "Гномы", "playable": false, "pos": Vector2(670, 215)},
	{"id": "minotaurs", "name": "Лабиринт", "race": "Минотавры", "playable": false, "pos": Vector2(770, 115)},
	{"id": "dragons", "name": "Гнездовье драконов", "race": "Драконы", "playable": false, "pos": Vector2(870, 215)},
]
