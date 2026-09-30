class_name HeroSprite
extends Node2D
## Картинка героя без поведения: для портретов на кнопках и карточках. Рисует то же, что и герой на поле.

var hid := "edrik"
var _time := 0.0


## Кладёт портрет героя в центр кнопки или карточки.
static func attach(parent: Control, hero_id: String, center: Vector2, diameter: float) -> HeroSprite:
	var sprite := HeroSprite.new()
	sprite.hid = hero_id
	var def: Dictionary = Defs.HEROES[hero_id]
	var s := diameter / 44.0
	sprite.scale = Vector2(s, s)
	# драконов рисуем выше земли, поэтому опускаем их, чтобы они оказались в центре
	sprite.position = center + Vector2(0, (24.0 if def["kind"] == "dragon" else 8.0) * s)
	sprite.show_behind_parent = false
	parent.add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# настоящий портрет (assets/art/heroes/<id>/portrait.png) вместо рисунка кодом
	var portrait := ArtPack.texture("heroes/%s/portrait.png" % hid)
	if portrait != null:
		var cy := -24.0 if Defs.HEROES[hid]["kind"] == "dragon" else -8.0   # центр тела героя (см. attach)
		draw_texture_rect(portrait, Rect2(-22, cy - 22, 44, 44), false)
		return
	HeroArt.draw(self, hid, Defs.HEROES[hid], 1.0, false, 0.0, false, _time, false)
