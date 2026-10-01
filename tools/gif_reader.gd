extends RefCounted
## Читает анимированный GIF в список кадров (Image). Godot сам GIF не открывает, а некоторые наборы
## присылают анимации только в GIF. Нужен только инструменту импорта (tools/import_art.gd), в игру не попадает.
## Использование: GifReader.frames("res://raw_art/.../file.gif") -> Array[Image] (каждый кадр в полный размер).


static func frames(path: String) -> Array[Image]:
	var result: Array[Image] = []
	var d := FileAccess.get_file_as_bytes(path)
	if d.size() < 13 or d.slice(0, 3).get_string_from_ascii() != "GIF":
		push_error("это не GIF: %s" % path)
		return result
	var w := d.decode_u16(6)
	var h := d.decode_u16(8)
	var flags := d[10]
	var pos := 13
	var global_pal := PackedByteArray()
	if flags & 0x80:
		var n := 3 * (1 << ((flags & 7) + 1))
		global_pal = d.slice(pos, pos + n)
		pos += n
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var transparent := -1
	var disposal := 0
	while pos < d.size():
		var block := d[pos]
		pos += 1
		if block == 0x3B:   # конец файла
			break
		if block == 0x21:   # расширение
			var label := d[pos]
			pos += 1
			if label == 0xF9:   # управление кадром: прозрачный цвет и как очищать
				var packed := d[pos + 1]
				disposal = (packed >> 2) & 7
				transparent = d[pos + 4] if packed & 1 else -1
			pos = _skip_blocks(d, pos)
			continue
		if block != 0x2C:
			push_error("непонятный блок GIF %d в %s" % [block, path])
			break
		# кадр
		var fx := d.decode_u16(pos)
		var fy := d.decode_u16(pos + 2)
		var fw := d.decode_u16(pos + 4)
		var fh := d.decode_u16(pos + 6)
		var fflags := d[pos + 8]
		pos += 9
		var pal := global_pal
		if fflags & 0x80:
			var n := 3 * (1 << ((fflags & 7) + 1))
			pal = d.slice(pos, pos + n)
			pos += n
		var min_size := d[pos]
		pos += 1
		var data := PackedByteArray()
		while d[pos] != 0:
			var n := d[pos]
			data.append_array(d.slice(pos + 1, pos + 1 + n))
			pos += 1 + n
		pos += 1
		var pixels := _lzw(data, min_size, fw * fh)
		var rows := _row_order(fh, fflags & 0x40 != 0)
		var before := canvas.duplicate() as Image
		for i in pixels.size():
			var idx := pixels[i]
			if idx == transparent or idx * 3 + 2 >= pal.size():
				continue
			var x := fx + i % fw
			var y := fy + rows[i / fw]
			if x < w and y < h:
				canvas.set_pixel(x, y, Color8(pal[idx * 3], pal[idx * 3 + 1], pal[idx * 3 + 2]))
		result.append(canvas.duplicate() as Image)
		# что делать с кадром перед следующим
		if disposal == 2:
			canvas.fill_rect(Rect2i(fx, fy, fw, fh), Color(0, 0, 0, 0))
		elif disposal == 3:
			canvas = before
		transparent = -1
		disposal = 0
	return result


static func _skip_blocks(d: PackedByteArray, pos: int) -> int:
	while pos < d.size() and d[pos] != 0:
		pos += 1 + d[pos]
	return pos + 1


## В каком порядке идут строки кадра (в «черезстрочном» GIF сначала каждая 8-я и так далее).
static func _row_order(h: int, interlaced: bool) -> PackedInt32Array:
	var rows := PackedInt32Array()
	if not interlaced:
		for y in h:
			rows.append(y)
		return rows
	for pass_spec in [[0, 8], [4, 8], [2, 4], [1, 2]]:
		var y: int = pass_spec[0]
		while y < h:
			rows.append(y)
			y += pass_spec[1]
	return rows


## Распаковка LZW: из сжатых данных получаем номера цветов для каждой точки.
static func _lzw(data: PackedByteArray, min_size: int, total: int) -> PackedByteArray:
	var out := PackedByteArray()
	var clear := 1 << min_size
	var eoi := clear + 1
	var table: Array[PackedByteArray] = []
	var size := min_size + 1
	var prev := -1
	var bit := 0
	var bits_total := data.size() * 8
	while bit + size <= bits_total and out.size() < total:
		var code := 0
		for i in size:
			code |= ((data[(bit + i) >> 3] >> ((bit + i) & 7)) & 1) << i
		bit += size
		if code == clear or table.is_empty():
			table.clear()
			for i in clear + 2:
				table.append(PackedByteArray([i & 0xFF]))
			size = min_size + 1
			prev = -1
			if code == clear:
				continue
		if code == eoi:
			break
		var entry: PackedByteArray
		if prev == -1:
			entry = table[code]
		else:
			if code < table.size():
				entry = table[code]
			else:
				entry = table[prev].duplicate()
				entry.append(table[prev][0])
			var added := table[prev].duplicate()
			added.append(entry[0])
			if table.size() < 4096:
				table.append(added)
			if table.size() == (1 << size) and size < 12:
				size += 1
		out.append_array(entry)
		prev = code
	return out
