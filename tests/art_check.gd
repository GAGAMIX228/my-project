extends Node
## Проверщик картинок: что из ожидаемого лежит в assets/art, а чего ещё нет.
## Запуск: godot --headless --path . res://tests/art_check.tscn
## Печатает списки «найдено» и «не хватает» и сохраняет «контактный лист» найденных картинок:
## user://art_contact_sheet.png (путь будет напечатан). Код выхода всегда 0, это справка, а не тест.

const THUMB := 88


func _ready() -> void:
	var rep := ArtPack.report()
	var found: Array = rep["found"]
	var missing: Array = rep["missing"]
	print("Папка с картинками: ", ArtPack.root)
	print("Найдено: %d, не хватает: %d" % [found.size(), missing.size()])
	if not found.is_empty():
		print("\n-- найдено --")
		for f in found:
			print("  ", f)
	if not missing.is_empty():
		print("\n-- не хватает (в игре на их месте рисунок кодом) --")
		var group := ""
		for m: String in missing:
			var g := m.get_slice("/", 0)
			if g != group:
				group = g
				print("  [%s]" % g)
			print("    ", m)
	_contact_sheet(found)
	get_tree().quit()


## Все найденные картинки (первый кадр анимаций) в одну сетку.
func _contact_sheet(found: Array) -> void:
	var textures: Array = []
	for label: String in found:
		var tex: Texture2D = null
		if label.ends_with("_*.png"):
			var dir := label.get_base_dir()
			var anim := label.get_file().trim_suffix("_*.png")
			var sf := ArtPack.frames(dir)
			if sf != null and sf.has_animation(anim):
				tex = sf.get_frame_texture(anim, 0)
		else:
			tex = ArtPack.texture(label)
		if tex != null:
			textures.append(tex)
	if textures.is_empty():
		print("\nКонтактный лист не создан: картинок пока нет.")
		return
	var cols := 12
	var rows := ceili(textures.size() / float(cols))
	var sheet := Image.create(cols * (THUMB + 6) + 6, rows * (THUMB + 6) + 6, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("3a3a42"))
	for i in textures.size():
		var img := (textures[i] as Texture2D).get_image()
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var k := minf(1.0, float(THUMB) / float(maxi(img.get_width(), img.get_height())))
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)))
		var x := 6 + (i % cols) * (THUMB + 6) + (THUMB - img.get_width()) / 2
		var y := 6 + (i / cols) * (THUMB + 6) + (THUMB - img.get_height()) / 2
		sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(x, y))
	var path := "user://art_contact_sheet.png"
	sheet.save_png(path)
	print("\nКонтактный лист: ", ProjectSettings.globalize_path(path))
