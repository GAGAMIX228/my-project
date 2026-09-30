class_name ArtPack
extends RefCounted
## Загрузчик настоящих картинок. Всё лежит в папке assets/art (подробности в assets/README.md).
## Правило: если нужного файла нет, возвращается null, и игра рисует этот элемент кодом, как раньше.
## Картинки рисуются в двойном размере (масштаб 0.5 по умолчанию), тогда они чёткие при растяжении окна.

## Где искать картинки. Автотесты подменяют на другую папку (см. reset).
static var root := "res://assets/art/"

static var _textures := {}    # путь -> Texture2D или null
static var _frames := {}      # папка -> SpriteFrames или null
static var _meta := {}        # папка -> словарь настроек

const LOOPING := ["idle", "walk"]   # эти анимации повторяются, остальные (attack, die, shoot) играют один раз


## Меняет папку с картинками и забывает всё, что было загружено.
static func reset(new_root := "res://assets/art/") -> void:
	root = new_root if new_root.ends_with("/") else new_root + "/"
	_textures.clear()
	_frames.clear()
	_meta.clear()


## Картинка по пути внутри assets/art, например "icons/heart.png". Нет файла: null.
static func texture(rel: String) -> Texture2D:
	var path := root + rel
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_textures[path] = tex
	return tex


## Настройки папки из необязательного meta.json: fps (число или словарь по анимациям), scale, offset [x, y].
static func meta(dir: String) -> Dictionary:
	if _meta.has(dir):
		return _meta[dir]
	var result := {"fps": 10.0, "scale": 0.5, "offset": Vector2.ZERO}
	var path := root + dir + "/meta.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			if parsed.has("fps"):
				result["fps"] = parsed["fps"]
			if parsed.has("scale"):
				result["scale"] = float(parsed["scale"])
			if parsed.has("offset") and parsed["offset"] is Array and parsed["offset"].size() >= 2:
				result["offset"] = Vector2(float(parsed["offset"][0]), float(parsed["offset"][1]))
	_meta[dir] = result
	return result


## Файлы в папке. В собранной игре рядом с картинками лежат .import и .remap, их убираем.
static func _list(dir: String) -> PackedStringArray:
	var names := PackedStringArray()
	var access := DirAccess.open(root + dir)
	if access == null:
		return names
	for file in access.get_files():
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if name.ends_with(".png") and not names.has(name):
			names.append(name)
	names.sort()
	return names


## Анимации из папки: файлы вида walk_00.png, walk_01.png, attack_00.png ... Нет кадров: null.
static func frames(dir: String) -> SpriteFrames:
	if _frames.has(dir):
		return _frames[dir]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var by_anim := {}
	var pattern := RegEx.new()
	pattern.compile("^([a-z]+)_(\\d+)\\.png$")
	for file in _list(dir):
		var m := pattern.search(file)
		if m == null:
			continue
		var anim := m.get_string(1)
		if not by_anim.has(anim):
			by_anim[anim] = []
		by_anim[anim].append(file)
	var fps_setting: Variant = meta(dir)["fps"]
	for anim: String in by_anim:
		var tex_list: Array = []
		for file: String in by_anim[anim]:
			var tex := texture(dir + "/" + file)
			if tex != null:
				tex_list.append(tex)
		if tex_list.is_empty():
			continue
		sf.add_animation(anim)
		sf.set_animation_loop(anim, anim in LOOPING)
		var fps := float(fps_setting[anim]) if fps_setting is Dictionary and fps_setting.has(anim) else (float(fps_setting) if not (fps_setting is Dictionary) else 10.0)
		sf.set_animation_speed(anim, fps)
		for tex in tex_list:
			sf.add_frame(anim, tex)
	var result: SpriteFrames = sf if not sf.get_animation_names().is_empty() else null
	_frames[dir] = result
	return result


static func has_frames(dir: String) -> bool:
	return frames(dir) != null


## Готовый спрайт с анимациями. feet: куда поставить «ноги» (низ по центру картинки). Высота кадра в единицах игры лежит в метаданных спрайта (set_meta "height").
static func make_sprite(dir: String, feet: Vector2) -> AnimatedSprite2D:
	var sf := frames(dir)
	if sf == null:
		return null
	var m := meta(dir)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	var scale_value: float = m["scale"]
	sprite.scale = Vector2(scale_value, scale_value)
	var first_anim := "walk" if sf.has_animation("walk") else (sf.get_animation_names()[0] as String)
	var height := float(sf.get_frame_texture(first_anim, 0).get_height())
	sprite.offset = Vector2(0, -height * 0.5)           # низ картинки в точке (0, 0)
	sprite.position = feet + (m["offset"] as Vector2)
	sprite.set_meta("height", height * scale_value)     # высота в единицах игры, для полосок здоровья
	sprite.animation = first_anim
	sprite.play(first_anim)
	return sprite


## Играет анимацию, если она есть и сейчас не играет. Если нет: walk вместо idle и наоборот.
static func play(sprite: AnimatedSprite2D, anim: String) -> void:
	var sf := sprite.sprite_frames
	var name := anim
	if not sf.has_animation(name):
		name = "walk" if sf.has_animation("walk") else ("idle" if sf.has_animation("idle") else "")
	if name == "":
		return
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)


# ---------- что ожидается (для проверщика) ----------

## Папки с анимациями: [путь, какие анимации ждём].
static func expected_frame_dirs() -> Array:
	var list: Array = []
	for type: String in Defs.ENEMIES:
		list.append(["enemies/" + type, ["walk", "attack"]])
	for id: String in Defs.HERO_ORDER:
		list.append(["heroes/" + id, ["idle", "walk", "attack"]])
	list.append(["soldiers/knight", ["idle", "walk", "attack"]])
	return list


## Отдельные файлы.
static func expected_files() -> Array:
	var list: Array = []
	for kind: String in Defs.TOWER_ORDER:
		for level in range(1, 4):
			list.append("towers/%s_%d.png" % [kind, level])
	for id: String in Defs.HERO_ORDER:
		list.append("heroes/%s/portrait.png" % id)
	for id in ["levels/orcs/background.png", "campaign/map.png", "title/background.png", "title/logo.png"]:
		list.append(id)
	for kind in ["arrow", "arrow_big", "orb", "shell", "meteor"]:
		list.append("projectiles/%s.png" % kind)
	for id in ["heart", "coin", "flag", "star_full", "star_empty", "pause", "play", "speed", "back", "up", "lock", "gear", "close", "trash"]:
		list.append("icons/%s.png" % id)
	for kind: String in Defs.TOWER_ORDER:
		list.append("icons/tower_%s.png" % kind)
	for id: String in Defs.HERO_ORDER:
		list.append("icons/ab_%s.png" % id)
	for id: String in Defs.SPELL_ORDER:
		list.append("icons/sp_%s.png" % id)
	return list


## Что найдено и чего нет: {"found": [...], "missing": [...]}. Для папок с анимациями считается найденным, если есть нужные анимации.
static func report() -> Dictionary:
	var found: Array = []
	var missing: Array = []
	for spec: Array in expected_frame_dirs():
		var sf := frames(spec[0])
		for anim: String in spec[1]:
			var label: String = "%s/%s_*.png" % [spec[0], anim]
			if sf != null and sf.has_animation(anim):
				found.append(label)
			else:
				missing.append(label)
	for rel: String in expected_files():
		if texture(rel) != null:
			found.append(rel)
		else:
			missing.append(rel)
	return {"found": found, "missing": missing}
