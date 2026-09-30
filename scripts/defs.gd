class_name Defs
extends RefCounted
## Все цифры игры лежат здесь. Поменяй число, и игра изменится.

const START_GOLD := 220
const START_LIVES := 20
const VIEW := Vector2(960, 540)

## Здоровье каждого врага берётся из таблицы ENEMIES как есть: оно не растёт ни с номером волны,
## ни со сложностью. Эта переменная нужна только автотестам, чтобы пробовать другие значения (tests/sim.gd).
static var hp_scale := 1.0

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
## Особенности (необязательные): range, shot_dmg, shot_rate: стреляет по бойцам и героям; aura: радиус,
## в котором орки рядом идут на 30% быстрее; regen: сколько здоровья в секунду возвращает, если его не бьют.
const ENEMIES := {
	"grunt": {"name": "Орк-воин", "hp": 57, "speed": 55.0, "armor": 0.0, "mres": 0.0, "gold": 6, "radius": 11.0, "leak": 1, "atk": 5, "fly": false},
	"raider": {"name": "Волчий наездник", "hp": 36, "speed": 97.0, "armor": 0.0, "mres": 0.0, "gold": 5, "radius": 9.0, "leak": 1, "atk": 3, "fly": false},
	"shield": {"name": "Орк-щитоносец", "hp": 164, "speed": 44.0, "armor": 0.5, "mres": 0.0, "gold": 14, "radius": 13.0, "leak": 2, "atk": 7, "fly": false},
	"berserk": {"name": "Орк-берсерк", "hp": 136, "speed": 47.0, "armor": 0.1, "mres": 0.0, "gold": 13, "radius": 12.0, "leak": 2, "atk": 8, "fly": false},
	"shaman": {"name": "Орк-шаман", "hp": 87, "speed": 46.0, "armor": 0.0, "mres": 0.0, "gold": 16, "radius": 11.0, "leak": 1, "atk": 3, "fly": false},
	"warlock": {"name": "Орк-колдун", "hp": 100, "speed": 50.0, "armor": 0.0, "mres": 0.65, "gold": 14, "radius": 11.0, "leak": 1, "atk": 6, "fly": false},
	"gryph": {"name": "Орк на грифе", "hp": 69, "speed": 88.0, "armor": 0.0, "mres": 0.0, "gold": 12, "radius": 11.0, "leak": 2, "atk": 0, "fly": true},
	"archer": {"name": "Орк-лучник", "hp": 49, "speed": 52.0, "armor": 0.0, "mres": 0.0, "gold": 9, "radius": 10.0, "leak": 1, "atk": 3, "fly": false, "range": 130.0, "shot_dmg": 4.0, "shot_rate": 1.7},
	"brute": {"name": "Орк-громила", "hp": 294, "speed": 36.0, "armor": 0.25, "mres": 0.0, "gold": 22, "radius": 16.0, "leak": 3, "atk": 15, "fly": false},
	"banner": {"name": "Орк-знаменосец", "hp": 105, "speed": 46.0, "armor": 0.1, "mres": 0.0, "gold": 18, "radius": 11.0, "leak": 1, "atk": 4, "fly": false, "aura": 95.0},
	"troll": {"name": "Тролль", "hp": 231, "speed": 42.0, "armor": 0.0, "mres": 0.25, "gold": 24, "radius": 15.0, "leak": 3, "atk": 12, "fly": false, "regen": 6.0},
	"chief": {"name": "Вождь орков", "hp": 1228, "speed": 34.0, "armor": 0.35, "mres": 0.2, "gold": 120, "radius": 19.0, "leak": 5, "atk": 16, "fly": false},
}

## Башни людей. У каждой три уровня. upgrades: цена улучшения до 2-го и до 3-го уровня.
const TOWERS := {
	"archer": {
		"name": "Лучники", "cost": 60, "upgrades": [50, 95],
		"blurb": "Быстрые стрелы, физический урон, бьют и по воздуху",
		"levels": [
			{"dmg": 8.0, "range": 150.0, "rate": 0.7},
			{"dmg": 12.0, "range": 160.0, "rate": 0.65},
			{"dmg": 17.0, "range": 172.0, "rate": 0.6},
		],
	},
	"barracks": {
		"name": "Казарма рыцарей", "cost": 75, "upgrades": [60, 100],
		"blurb": "Рыцари перекрывают дорогу и дерутся",
		"levels": [
			{"n": 2, "hp": 70.0, "dmg": 6.0, "rate": 0.85, "range": 115.0},
			{"n": 2, "hp": 105.0, "dmg": 9.0, "rate": 0.8, "range": 128.0},
			{"n": 3, "hp": 140.0, "dmg": 13.0, "rate": 0.75, "range": 140.0},
		],
	},
	"mage": {
		"name": "Башня магов", "cost": 85, "upgrades": [70, 120],
		"blurb": "Магия, игнорирует броню, бьёт и по воздуху",
		"levels": [
			{"dmg": 18.0, "range": 135.0, "rate": 1.2},
			{"dmg": 30.0, "range": 145.0, "rate": 1.1},
			{"dmg": 46.0, "range": 155.0, "rate": 1.0},
		],
	},
	"mortar": {
		"name": "Мортира", "cost": 100, "upgrades": [75, 130],
		"blurb": "Медленно, урон по площади, только по земле",
		"levels": [
			{"dmg": 26.0, "range": 185.0, "rate": 2.5, "min_range": 50.0, "splash": 46.0},
			{"dmg": 40.0, "range": 195.0, "rate": 2.3, "min_range": 50.0, "splash": 52.0},
			{"dmg": 60.0, "range": 205.0, "rate": 2.1, "min_range": 50.0, "splash": 58.0},
		],
	},
}
const TOWER_ORDER := ["archer", "barracks", "mage", "mortar"]

## Волны: [тип врага, сколько, пауза между ними в секундах, когда начинает идти (секунды от старта волны)].
## Четвёртое число необязательное: без него группа идёт после предыдущей. С ним группы идут вперемешку.
const WAVES := [
	[["grunt", 7, 1.3]],
	[["grunt", 9, 1.2, 0.0], ["raider", 6, 1.4, 4.0]],
	[["raider", 8, 1.2, 0.0], ["archer", 5, 2.6, 2.0], ["grunt", 8, 1.5, 5.0]],
	[["shield", 5, 3.0, 0.0], ["grunt", 11, 1.2, 2.0], ["archer", 5, 2.6, 6.0]],
	[["gryph", 8, 1.8, 0.0], ["grunt", 9, 1.4, 3.0], ["banner", 1, 1.0, 8.0]],
	[["warlock", 5, 2.6, 0.0], ["shield", 5, 2.6, 4.0], ["raider", 8, 1.3, 6.0], ["archer", 5, 2.6, 10.0]],
	[["brute", 3, 6.0, 0.0], ["grunt", 12, 1.2, 3.0], ["shaman", 3, 3.0, 6.0], ["banner", 1, 1.0, 12.0]],
	[["gryph", 9, 1.6, 0.0], ["troll", 3, 6.0, 4.0], ["warlock", 5, 2.6, 8.0], ["archer", 6, 2.2, 12.0]],
	[["berserk", 8, 2.0, 0.0], ["shaman", 5, 3.0, 5.0], ["brute", 3, 6.0, 8.0], ["shield", 6, 2.6, 12.0], ["raider", 9, 1.2, 16.0], ["banner", 3, 6.0, 18.0]],
	[["chief", 1, 1.0, 0.0], ["troll", 3, 5.0, 4.0], ["berserk", 5, 2.6, 6.0], ["shaman", 5, 3.0, 10.0], ["gryph", 8, 1.6, 12.0], ["shield", 6, 2.6, 16.0], ["banner", 1, 1.0, 20.0], ["archer", 6, 2.2, 24.0]],
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

## Название игры. Рабочее: поменяй здесь, и оно изменится на заставке.
const GAME_TITLE := "СТРАЖИ РАССВЕТА"
const GAME_SUBTITLE := "Союз рас против Древней Тьмы"

## Сложности. count: во сколько раз больше или меньше врагов в волнах, gold: стартовое золото.
## Здоровье врагов от сложности не зависит. «Боец» это сложность, под которую подобран баланс.
const DIFFICULTIES := {
	"novice": {"name": "Новичок", "count": 0.8, "gold": 260, "info": "Врагов меньше, золота больше. Чтобы освоиться."},
	"fighter": {"name": "Боец", "count": 1.0, "gold": 220, "info": "Как задумано. Внимательная игра побеждает."},
	"veteran": {"name": "Ветеран", "count": 1.4, "gold": 200, "info": "Врагов больше, золота меньше. Для тех, кто уверен."},
}
const DIFFICULTY_ORDER := ["novice", "fighter", "veteran"]
const SAVE_SLOTS := 3

## Области карты: лес, затем другие земли, море и в конце кладбище некроманта.
## Локации кампании. playable: уровень уже есть в игре. pos: место на карте. biome: где стоит (для рисунка).
const LEVELS := [
	{"id": "orcs", "name": "Орочий лес", "race": "Орки", "biome": "forest", "playable": true, "pos": Vector2(90, 300)},
	{"id": "goblins", "name": "Гоблинские топи", "race": "Гоблины", "biome": "swamp", "playable": false, "pos": Vector2(190, 395)},
	{"id": "shamans", "name": "Рощи предков", "race": "Шаманы", "biome": "forest", "playable": false, "pos": Vector2(280, 290)},
	{"id": "ogres", "name": "Холмы огров", "race": "Огры", "biome": "hills", "playable": false, "pos": Vector2(345, 185)},
	{"id": "yetis", "name": "Ледяные пики", "race": "Йети", "biome": "snow", "playable": false, "pos": Vector2(455, 110)},
	{"id": "gnomes", "name": "Подгорье", "race": "Гномы", "biome": "snow", "playable": false, "pos": Vector2(550, 215)},
	{"id": "minotaurs", "name": "Лабиринт песков", "race": "Минотавры", "biome": "desert", "playable": false, "pos": Vector2(620, 340)},
	{"id": "dragons", "name": "Вулканы драконов", "race": "Драконы", "biome": "volcano", "playable": false, "pos": Vector2(715, 195)},
	{"id": "octopus", "name": "Залив глубин", "race": "Осьминоги", "biome": "sea", "playable": false, "pos": Vector2(775, 405)},
	{"id": "necromancer", "name": "Кладбище Тьмы", "race": "Нежить", "biome": "grave", "playable": false, "pos": Vector2(880, 270)},
]
