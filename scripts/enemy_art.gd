class_name EnemyArt
extends RefCounted
## Рисунок врагов: у каждого типа свой облик, все с тёмным контуром, шагающими ногами и оружием.
## Рисуем от точки под ногами: y вверх отрицательный. r это радиус врага из Defs.ENEMIES.
## Центр врага (его позиция) лежит примерно на 0.85·r выше ног.

const SKIN := {
	"grunt": Color("6aa04a"), "raider": Color("83b556"), "shield": Color("5a8f3d"), "berserk": Color("78a043"),
	"shaman": Color("66974f"), "warlock": Color("6aa04a"), "gryph": Color("6aa04a"), "chief": Color("47762f"),
	"archer": Color("86bb5e"), "brute": Color("4f8a3a"), "banner": Color("6aa04a"), "troll": Color("8da3a8"),
}
const STEEL := Color("aeb6c0")
const STEEL_DARK := Color("6f7783")
const WOOD := Color("6b4a2a")


## white: вспышка при попадании. enraged: берсерк в ярости. buffed: рядом знаменосец. healing: тролль лечится.
## aura: радиус золотого круга знаменосца (0 если нет).
static func draw(ci: CanvasItem, type: String, r: float, f: float, ph: float, white: bool, enraged: bool, buffed: bool, healing: bool, aura: float) -> void:
	var g := r * 0.85
	var bob := sin(ph * 6.0) * 1.3
	var lift := -24.0 if type == "gryph" else 0.0
	Art.blob_shadow(ci, Vector2(0, g), r * 1.15)
	if aura > 0.0:
		Art.ellipse_outline(ci, Vector2(0, g), aura, aura * 0.42, Color(1.0, 0.85, 0.3, 0.28), 2.0)
	var o := Vector2(0, g + bob + lift)
	var skin: Color = SKIN.get(type, Color("6aa04a"))
	if enraged:
		var pulse := 0.25 + 0.15 * sin(ph * 14.0)
		ci.draw_circle(o + Vector2(0, -r), r * 1.6, Color(1.0, 0.2, 0.1, pulse))
	match type:
		"grunt": _grunt(ci, o, r, f, ph, skin, white)
		"raider": _raider(ci, o, r, f, ph, skin, white)
		"shield": _shield(ci, o, r, f, ph, skin, white)
		"berserk": _berserk(ci, o, r, f, ph, skin, white, enraged)
		"shaman": _robed(ci, o, r, f, ph, Color("7a5536"), Color("4a3a24"), skin, white, false)
		"warlock": _robed(ci, o, r, f, ph, Color("5a3f98"), Color("352560"), skin, white, true)
		"gryph": _gryph(ci, o, r, f, ph, skin, white)
		"chief": _chief(ci, o, r, f, ph, skin, white)
		"archer": _archer(ci, o, r, f, ph, skin, white)
		"brute": _brute(ci, o, r, f, ph, skin, white)
		"banner": _banner(ci, o, r, f, ph, skin, white)
		"troll": _troll(ci, o, r, f, ph, skin, white, healing)
		_: _grunt(ci, o, r, f, ph, skin, white)
	if buffed:
		# золотые искры: знаменосец подгоняет
		for i in 3:
			var a := ph * 4.0 + i * 2.1
			ci.draw_circle(o + Vector2(cos(a) * r * 0.9, -r * 2.0 + sin(a) * r * 0.3), 2.0, Color(1.0, 0.85, 0.3, 0.9))


## Эффекты вокруг настоящего спрайта (assets/art): круг знаменосца, ярость, искры ускорения, «плюсики» лечения.
## top: высота над землёй, где заканчивается голова спрайта (в локальных координатах врага, отрицательная).
static func sprite_effects(ci: CanvasItem, r: float, feet: Vector2, top: float, ph: float, enraged: bool, buffed: bool, healing: bool, aura: float) -> void:
	if aura > 0.0:
		Art.ellipse_outline(ci, feet, aura, aura * 0.42, Color(1.0, 0.85, 0.3, 0.28), 2.0)
	if enraged:
		ci.draw_circle(feet + Vector2(0, (top - feet.y) * 0.5), absf(top - feet.y) * 0.8, Color(1.0, 0.2, 0.1, 0.22 + 0.12 * sin(ph * 14.0)))
	if buffed:
		for i in 3:
			var a := ph * 4.0 + i * 2.1
			ci.draw_circle(Vector2(cos(a) * r * 0.9, top + sin(a) * r * 0.3), 2.0, Color(1.0, 0.85, 0.3, 0.9))
	if healing:
		for i in 3:
			var t := fposmod(ph * 0.9 + i / 3.0, 1.0)
			var p := Vector2((i - 1) * 0.6 * r, feet.y + (top - feet.y) * (0.3 + t * 0.6))
			var c := Color(0.4, 1.0, 0.5, 1.0 - t)
			ci.draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), c, 2.0)
			ci.draw_line(p + Vector2(0, -3), p + Vector2(0, 3), c, 2.0)


# ---------- общее тело орка ----------

## Тело орка: ноги, торс, руки, голова. Возвращает важные точки: hand (рука с оружием), back_hand, head.
static func _orc(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, cloth: Color, white: bool, legs := true, fat := 1.0) -> Dictionary:
	var sk := Color.WHITE if white else skin
	var cl := Color.WHITE if white else cloth
	var step := ph * 6.0
	if legs:
		Art.leg(ci, o + Vector2(-0.28 * r, -0.5 * r), step + PI, 0.5 * r, sk.darkened(0.3), 0.34 * r)
		Art.leg(ci, o + Vector2(0.28 * r, -0.5 * r), step, 0.5 * r, sk.darkened(0.3), 0.34 * r)
	var sw := sin(step) * 0.2 * r
	var back_hand := o + Vector2(-f * 0.78 * r * fat, -0.95 * r + sw)
	Art.outlined_line(ci, o + Vector2(-f * 0.45 * r * fat, -1.3 * r), back_hand, sk.darkened(0.15), 0.3 * r)
	Art.outlined_circle(ci, back_hand, 0.2 * r, sk.darkened(0.15), 1.0)
	Art.outlined_ellipse(ci, o + Vector2(0, -1.0 * r), 0.78 * r * fat, 0.7 * r, cl)
	ci.draw_line(o + Vector2(-0.7 * r * fat, -0.62 * r), o + Vector2(0.7 * r * fat, -0.62 * r), Color("2a1a0c"), maxf(1.5, 0.14 * r))
	var hand := o + Vector2(f * 0.82 * r * fat, -0.95 * r - sw)
	Art.outlined_line(ci, o + Vector2(f * 0.45 * r * fat, -1.3 * r), hand, sk, 0.3 * r)
	Art.outlined_circle(ci, hand, 0.22 * r, sk, 1.0)
	var hc := o + Vector2(f * 0.06 * r, -1.78 * r)
	for side in [-1.0, 1.0]:
		Art.outlined_poly(ci, [hc + Vector2(side * 0.5 * r, -0.12 * r), hc + Vector2(side * 0.98 * r, -0.42 * r), hc + Vector2(side * 0.6 * r, 0.14 * r)], sk, 1.0)
	Art.outlined_circle(ci, hc, 0.62 * r, sk)
	_face(ci, hc, r, f, white)
	return {"hand": hand, "back_hand": back_hand, "head": hc}


static func _face(ci: CanvasItem, hc: Vector2, r: float, f: float, white: bool) -> void:
	for side in [-1.0, 1.0]:
		var e := hc + Vector2(side * 0.24 * r + f * 0.05 * r, -0.06 * r)
		ci.draw_circle(e, 0.17 * r, Color.WHITE)
		ci.draw_circle(e + Vector2(f * 0.06 * r, 0.02 * r), 0.085 * r, Color("c81818"))
		ci.draw_line(e + Vector2(-side * 0.16 * r, -0.2 * r), e + Vector2(side * 0.18 * r, -0.12 * r), Color("20300f"), maxf(1.3, 0.1 * r))
	ci.draw_line(hc + Vector2(-0.2 * r, 0.28 * r), hc + Vector2(0.2 * r, 0.28 * r), Color("20300f"), maxf(1.2, 0.09 * r))
	for side in [-1.0, 1.0]:
		Art.tri(ci, hc + Vector2(side * 0.3 * r, 0.3 * r), hc + Vector2(side * 0.12 * r, 0.3 * r), hc + Vector2(side * 0.22 * r, 0.02 * r), Color("f6f0dc"))


static func _axe(ci: CanvasItem, hand: Vector2, f: float, r: float, big := 1.0) -> void:
	var tip := hand + Vector2(f * 0.5 * r, -1.25 * r * big)
	Art.outlined_line(ci, hand + Vector2(-f * 0.12 * r, 0.3 * r), tip, WOOD, 0.2 * r)
	Art.outlined_poly(ci, [tip + Vector2(0, -0.1 * r * big), tip + Vector2(f * 0.6 * r * big, -0.3 * r * big), tip + Vector2(f * 0.55 * r * big, 0.5 * r * big), tip + Vector2(0, 0.35 * r * big)], STEEL, 1.3)


# ---------- типы ----------

static func _grunt(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool) -> void:
	var pts := _orc(ci, o, r, f, ph, skin, Color("7a5230"), white)
	_axe(ci, pts["hand"], f, r)


static func _raider(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool) -> void:
	var wolf := Color.WHITE if white else Color("8b9098")
	var step := ph * 6.0
	# хвост и задние ноги
	Art.outlined_poly(ci, [o + Vector2(-f * 1.1 * r, -0.85 * r), o + Vector2(-f * 1.9 * r, -1.1 * r + sin(step) * 2.0), o + Vector2(-f * 1.2 * r, -0.55 * r)], wolf.darkened(0.15), 1.2)
	Art.leg(ci, o + Vector2(-0.8 * r, -0.6 * r), step + PI, 0.6 * r, wolf.darkened(0.3), 0.3 * r)
	Art.leg(ci, o + Vector2(0.7 * r, -0.6 * r), step, 0.6 * r, wolf.darkened(0.3), 0.3 * r)
	Art.outlined_ellipse(ci, o + Vector2(0, -0.85 * r), 1.25 * r, 0.6 * r, wolf)
	Art.outlined_ellipse(ci, o + Vector2(0, -0.7 * r), 0.9 * r, 0.3 * r, wolf.lightened(0.25), 0.0)
	Art.leg(ci, o + Vector2(-0.45 * r, -0.6 * r), step, 0.6 * r, wolf.darkened(0.15), 0.3 * r)
	Art.leg(ci, o + Vector2(0.95 * r, -0.6 * r), step + PI, 0.6 * r, wolf.darkened(0.15), 0.3 * r)
	var head := o + Vector2(f * 1.35 * r, -1.15 * r)
	Art.outlined_poly(ci, [head + Vector2(f * 0.3 * r, -0.05 * r), head + Vector2(f * 0.95 * r, 0.12 * r), head + Vector2(f * 0.3 * r, 0.34 * r)], wolf.lightened(0.15), 1.2)
	Art.outlined_circle(ci, head, 0.44 * r, wolf)
	Art.tri(ci, head + Vector2(-0.3 * r, -0.3 * r), head + Vector2(-0.15 * r, -0.85 * r), head + Vector2(0.1 * r, -0.4 * r), wolf.darkened(0.2))
	ci.draw_circle(head + Vector2(f * 0.12 * r, -0.1 * r), 0.1 * r, Color("ffd24a"))
	var pts := _orc(ci, o + Vector2(0, -0.78 * r), r * 0.78, f, ph, skin, Color("7a3a2a"), white, false)
	ci.draw_line(pts["head"] + Vector2(-0.6 * r * 0.78, -0.25 * r * 0.78), pts["head"] + Vector2(0.6 * r * 0.78, -0.25 * r * 0.78), Color("c0342a"), maxf(2.0, 0.18 * r))
	var hand: Vector2 = pts["hand"]
	Art.outlined_line(ci, hand + Vector2(-f * 0.3 * r, 0.5 * r), hand + Vector2(f * 1.0 * r, -1.0 * r), WOOD, 0.14 * r)
	Art.outlined_poly(ci, [hand + Vector2(f * 1.0 * r, -1.0 * r), hand + Vector2(f * 1.15 * r, -1.55 * r), hand + Vector2(f * 1.3 * r, -0.95 * r)], STEEL, 1.0)


static func _shield(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool) -> void:
	var pts := _orc(ci, o, r, f, ph, skin, Color("4a4f58"), white)
	var head: Vector2 = pts["head"]
	# стальной шлем с рогами
	Art.half_disc(ci, head + Vector2(0, -0.05 * r), 0.66 * r, STEEL)
	ci.draw_arc(head + Vector2(0, -0.05 * r), 0.66 * r, PI, TAU, 14, Art.OUTLINE, 1.4, true)
	for side in [-1.0, 1.0]:
		Art.outlined_poly(ci, [head + Vector2(side * 0.55 * r, -0.3 * r), head + Vector2(side * 0.95 * r, -0.95 * r), head + Vector2(side * 0.7 * r, -0.2 * r)], Color("f0ead0"), 1.0)
	# большой круглый щит спереди
	var sc: Vector2 = pts["hand"] + Vector2(f * 0.35 * r, -0.1 * r)
	Art.outlined_circle(ci, sc, 0.95 * r, STEEL_DARK, 1.8)
	ci.draw_arc(sc, 0.72 * r, 0.0, TAU, 20, STEEL, maxf(1.5, 0.12 * r), true)
	Art.outlined_circle(ci, sc, 0.28 * r, Color("c9a23a"), 1.2)
	var sword := pts["back_hand"] as Vector2
	Art.outlined_line(ci, sword, sword + Vector2(-f * 0.2 * r, -1.2 * r), STEEL, 0.15 * r)


static func _berserk(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool, enraged: bool) -> void:
	var pts := _orc(ci, o, r, f, ph * (1.6 if enraged else 1.0), skin, skin.darkened(0.05), white)
	var head: Vector2 = pts["head"]
	var paint := Color("c2342a")
	ci.draw_line(o + Vector2(-0.5 * r, -1.35 * r), o + Vector2(0.1 * r, -0.65 * r), paint, maxf(2.0, 0.14 * r))
	ci.draw_line(o + Vector2(0.5 * r, -1.35 * r), o + Vector2(-0.1 * r, -0.65 * r), paint, maxf(2.0, 0.14 * r))
	ci.draw_line(head + Vector2(-0.4 * r, -0.15 * r), head + Vector2(-0.1 * r, 0.2 * r), paint, maxf(1.6, 0.1 * r))
	ci.draw_line(head + Vector2(0.4 * r, -0.15 * r), head + Vector2(0.1 * r, 0.2 * r), paint, maxf(1.6, 0.1 * r))
	for i in range(-1, 2):
		Art.outlined_poly(ci, [head + Vector2(i * 0.22 * r - 0.12 * r, -0.55 * r), head + Vector2(i * 0.3 * r, -1.25 * r), head + Vector2(i * 0.22 * r + 0.12 * r, -0.55 * r)], paint, 1.0)
	_axe(ci, pts["hand"], f, r, 0.9)
	_axe(ci, pts["back_hand"], -f, r, 0.9)


## Шаман и колдун: балахон, капюшон, посох или парящие шары.
static func _robed(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, robe: Color, hood: Color, skin: Color, white: bool, dark_magic: bool) -> void:
	var rb := Color.WHITE if white else robe
	var hd := Color.WHITE if white else hood
	var sway := sin(ph * 6.0) * 0.06 * r
	Art.outlined_poly(ci, [o + Vector2(-1.0 * r, 0), o + Vector2(-0.45 * r + sway, -1.9 * r), o + Vector2(0.45 * r + sway, -1.9 * r), o + Vector2(1.0 * r, 0)], rb)
	ci.draw_line(o + Vector2(-0.7 * r, -0.65 * r), o + Vector2(0.7 * r, -0.65 * r), Color("2a1a0c"), maxf(1.5, 0.12 * r))
	var hc := o + Vector2(f * 0.05 * r + sway, -1.85 * r)
	Art.outlined_circle(ci, hc, 0.6 * r, hd)
	Art.outlined_circle(ci, hc + Vector2(f * 0.06 * r, 0.06 * r), 0.42 * r, Color("1a1208"), 0.0)
	var eye := Color("c48bff") if dark_magic else Color("ffd24a")
	ci.draw_circle(hc + Vector2(-0.16 * r + f * 0.08 * r, 0.02 * r), 0.09 * r, eye)
	ci.draw_circle(hc + Vector2(0.16 * r + f * 0.08 * r, 0.02 * r), 0.09 * r, eye)
	if dark_magic:
		Art.outlined_poly(ci, [hc + Vector2(-0.55 * r, -0.25 * r), hc + Vector2(0.0, -1.5 * r), hc + Vector2(0.55 * r, -0.25 * r)], hd, 1.2)
		for i in 3:
			var a := ph * 3.0 + i * 2.09
			var p := o + Vector2(cos(a) * 1.25 * r, -1.0 * r + sin(a) * 0.4 * r)
			ci.draw_circle(p, 0.3 * r, Color(0.75, 0.5, 1.0, 0.35))
			ci.draw_circle(p, 0.17 * r, Color("c48bff"))
	else:
		var hand := o + Vector2(f * 0.95 * r, -1.0 * r)
		Art.outlined_line(ci, hand + Vector2(0, 0.9 * r), hand + Vector2(0, -1.5 * r), WOOD, 0.16 * r)
		var glow := 0.6 + 0.3 * sin(ph * 5.0)
		ci.draw_circle(hand + Vector2(0, -1.65 * r), 0.55 * r, Color(0.4, 1.0, 0.7, 0.3 * glow))
		Art.outlined_circle(ci, hand + Vector2(0, -1.65 * r), 0.28 * r, Color("6ff0b0"), 1.2)
		for i in 3:
			var x := (i - 1) * 0.22 * r
			Art.outlined_poly(ci, [hc + Vector2(x - 0.1 * r, -0.5 * r), hc + Vector2(x, -1.15 * r), hc + Vector2(x + 0.1 * r, -0.5 * r)], [Color("e0523f"), Color("f0b93a"), Color("4da35a")][i], 0.8)


static func _gryph(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool) -> void:
	var wing := sin(ph * 13.0)
	var feather := Color.WHITE if white else Color("b98d52")
	var dark := Color("7a5a2e")
	var body := Color.WHITE if white else Color("a07a48")
	for side in [-1.0, 1.0]:
		var base := o + Vector2(side * 0.3 * r, -1.2 * r)
		Art.outlined_poly(ci, [base, base + Vector2(side * 2.3 * r, -1.4 * r - wing * 1.1 * r), base + Vector2(side * 2.7 * r, -0.2 * r - wing * 0.6 * r), base + Vector2(side * 1.8 * r, 0.5 * r), base + Vector2(side * 0.2 * r, 0.3 * r)], feather, 1.4)
		ci.draw_line(base + Vector2(side * 0.4 * r, 0), base + Vector2(side * 2.4 * r, -0.4 * r - wing * 0.7 * r), dark, 1.6)
	Art.leg(ci, o + Vector2(-0.3 * r, -0.4 * r), ph * 6.0, 0.35 * r, Color("e8c04a"), 0.2 * r)
	Art.leg(ci, o + Vector2(0.3 * r, -0.4 * r), ph * 6.0 + 1.0, 0.35 * r, Color("e8c04a"), 0.2 * r)
	Art.outlined_ellipse(ci, o + Vector2(0, -0.85 * r), 1.1 * r, 0.62 * r, body)
	var head := o + Vector2(f * 1.15 * r, -1.35 * r)
	Art.outlined_circle(ci, head, 0.5 * r, Color.WHITE if white else Color("f1e7cb"))
	Art.outlined_poly(ci, [head + Vector2(f * 0.35 * r, -0.12 * r), head + Vector2(f * 1.0 * r, 0.12 * r), head + Vector2(f * 0.35 * r, 0.32 * r)], Color("f2c84a"), 1.2)
	ci.draw_circle(head + Vector2(f * 0.05 * r, -0.12 * r), 0.11 * r, Color("c81818"))
	var pts := _orc(ci, o + Vector2(0, -0.95 * r), r * 0.7, f, ph, skin, Color("7a5230"), white, false)
	var hand: Vector2 = pts["hand"]
	Art.outlined_line(ci, hand, hand + Vector2(f * 0.9 * r, -0.7 * r), WOOD, 0.12 * r)


static func _chief(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool) -> void:
	# меховой плащ за спиной
	var fur := Color.WHITE if white else Color("6b4a32")
	var sway := sin(ph * 6.0) * 0.1 * r
	Art.outlined_poly(ci, [o + Vector2(-f * 0.4 * r, -1.9 * r), o + Vector2(-f * 1.5 * r + sway, -0.2 * r), o + Vector2(-f * 0.3 * r, 0.05 * r), o + Vector2(f * 0.3 * r, -1.0 * r)], fur)
	var pts := _orc(ci, o, r, f, ph, skin, Color("3a3f48"), white, true, 1.1)
	var head: Vector2 = pts["head"]
	# железные наплечники
	for side in [-1.0, 1.0]:
		Art.outlined_circle(ci, o + Vector2(side * 0.75 * r, -1.45 * r), 0.36 * r, STEEL_DARK, 1.4)
	# рогатый шлем
	Art.half_disc(ci, head + Vector2(0, -0.04 * r), 0.68 * r, STEEL_DARK)
	ci.draw_arc(head + Vector2(0, -0.04 * r), 0.68 * r, PI, TAU, 14, Art.OUTLINE, 1.6, true)
	for side in [-1.0, 1.0]:
		Art.outlined_poly(ci, [head + Vector2(side * 0.5 * r, -0.3 * r), head + Vector2(side * 1.25 * r, -1.2 * r), head + Vector2(side * 0.75 * r, -0.15 * r)], Color("f0ead0"), 1.3)
	_axe(ci, pts["hand"], f, r, 1.5)


static func _archer(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool) -> void:
	# колчан за спиной
	var q := o + Vector2(-f * 0.55 * r, -1.55 * r)
	Art.outlined_line(ci, q, q + Vector2(-f * 0.3 * r, 0.9 * r), Color("6b4a2a"), 0.3 * r)
	for i in 3:
		Art.tri(ci, q + Vector2(-f * 0.05 * r + i * 0.12 * r, 0), q + Vector2(i * 0.12 * r, -0.4 * r), q + Vector2(0.1 * r + i * 0.12 * r, 0), Color("e0d6b0"))
	var pts := _orc(ci, o, r, f, ph, skin, Color("4a6b3a"), white)
	var head: Vector2 = pts["head"]
	Art.half_disc(ci, head + Vector2(0, -0.02 * r), 0.68 * r, Color("3a5a30"))
	ci.draw_arc(head + Vector2(0, -0.02 * r), 0.68 * r, PI, TAU, 14, Art.OUTLINE, 1.4, true)
	var hand: Vector2 = pts["hand"]
	var turn := 0.0 if f > 0.0 else PI
	ci.draw_arc(hand + Vector2(f * 0.1 * r, 0), 1.0 * r, -1.25 + turn, 1.25 + turn, 12, Art.OUTLINE, maxf(3.0, 0.3 * r), true)
	ci.draw_arc(hand + Vector2(f * 0.1 * r, 0), 1.0 * r, -1.25 + turn, 1.25 + turn, 12, Color("8a5a32"), maxf(1.8, 0.16 * r), true)
	var top := hand + Vector2(f * 0.1 * r + f * cos(1.25) * r, -sin(1.25) * r)
	var bottom := hand + Vector2(f * 0.1 * r + f * cos(1.25) * r, sin(1.25) * r)
	ci.draw_line(top, bottom, Color("e0d6b0"), 1.0)


static func _brute(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool) -> void:
	var pts := _orc(ci, o, r, f, ph, skin, Color("3f6a30"), white, true, 1.3)
	var head: Vector2 = pts["head"]
	# шрамы и медная клёпка на ремне
	ci.draw_line(head + Vector2(-0.3 * r, -0.3 * r), head + Vector2(0.0, 0.1 * r), Color("20300f"), 1.2)
	for side in [-1.0, 1.0]:
		Art.outlined_circle(ci, o + Vector2(side * 0.95 * r, -1.4 * r), 0.3 * r, skin.darkened(0.12), 1.2)
	ci.draw_circle(o + Vector2(0, -0.62 * r), 0.15 * r, Color("c9a23a"))
	# огромная дубина с шипами
	var hand: Vector2 = pts["hand"]
	var tip := hand + Vector2(f * 0.6 * r, -1.5 * r)
	Art.outlined_line(ci, hand + Vector2(-f * 0.1 * r, 0.3 * r), tip, WOOD, 0.3 * r)
	Art.outlined_circle(ci, tip + Vector2(f * 0.1 * r, -0.2 * r), 0.6 * r, Color("7a5a38"), 1.6)
	for i in 4:
		var a := i * 1.6 + 0.4
		Art.tri(ci, tip + Vector2(f * 0.1 * r, -0.2 * r) + Vector2(cos(a), sin(a)) * 0.5 * r, tip + Vector2(f * 0.1 * r, -0.2 * r) + Vector2(cos(a), sin(a)) * 0.95 * r, tip + Vector2(f * 0.1 * r, -0.2 * r) + Vector2(cos(a + 0.4), sin(a + 0.4)) * 0.5 * r, STEEL)


static func _banner(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool) -> void:
	var pts := _orc(ci, o, r, f, ph, skin, Color("8a2a24"), white)
	var hand: Vector2 = pts["hand"]
	var top := hand + Vector2(0, -3.0 * r)
	Art.outlined_line(ci, hand + Vector2(0, 0.4 * r), top, WOOD, 0.2 * r)
	Art.outlined_circle(ci, top + Vector2(0, -0.1 * r), 0.2 * r, Color("e6b84e"), 1.0)
	var wave := sin(ph * 5.0) * 0.25 * r
	var cloth := Color.WHITE if white else Color("b8342a")
	Art.outlined_poly(ci, [top + Vector2(0, 0.1 * r), top + Vector2(-f * 1.5 * r, 0.25 * r + wave), top + Vector2(-f * 1.3 * r, 1.0 * r - wave), top + Vector2(-f * 1.5 * r, 1.7 * r + wave), top + Vector2(0, 1.6 * r)], cloth, 1.3)
	ci.draw_circle(top + Vector2(-f * 0.75 * r, 0.85 * r + wave * 0.5), 0.3 * r, Color("f2ecd2"))
	ci.draw_circle(top + Vector2(-f * 0.85 * r, 0.8 * r + wave * 0.5), 0.07 * r, Art.OUTLINE)
	ci.draw_circle(top + Vector2(-f * 0.65 * r, 0.8 * r + wave * 0.5), 0.07 * r, Art.OUTLINE)


static func _troll(ci: CanvasItem, o: Vector2, r: float, f: float, ph: float, skin: Color, white: bool, healing: bool) -> void:
	var pts := _orc(ci, o, r, f, ph, skin, skin.darkened(0.1), white, true, 1.25)
	var head: Vector2 = pts["head"]
	# мох на плечах и спине
	for p in [Vector2(-0.7, -1.6), Vector2(0.65, -1.55), Vector2(0.0, -1.85), Vector2(-0.2, -0.6)]:
		Art.ellipse(ci, o + p * r, 0.36 * r, 0.2 * r, Color("4f8a3a"))
	ci.draw_circle(head + Vector2(0.1 * r, -0.55 * r), 0.2 * r, Color("4f8a3a"))
	# каменная дубина
	var hand: Vector2 = pts["hand"]
	var tip := hand + Vector2(f * 0.5 * r, -1.2 * r)
	Art.outlined_line(ci, hand + Vector2(-f * 0.1 * r, 0.3 * r), tip, WOOD, 0.26 * r)
	Art.outlined_poly(ci, [tip + Vector2(-0.35 * r, 0.3 * r), tip + Vector2(-0.45 * r, -0.4 * r), tip + Vector2(0.1 * r, -0.75 * r), tip + Vector2(0.55 * r, -0.2 * r), tip + Vector2(0.35 * r, 0.4 * r)], Color("8d9399"), 1.4)
	if healing:
		for i in 3:
			var t := fposmod(ph * 0.9 + i / 3.0, 1.0)
			var p := o + Vector2((i - 1) * 0.6 * r, -1.2 * r - t * 1.3 * r)
			var c := Color(0.4, 1.0, 0.5, 1.0 - t)
			ci.draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), c, 2.0)
			ci.draw_line(p + Vector2(0, -3), p + Vector2(0, 3), c, 2.0)
