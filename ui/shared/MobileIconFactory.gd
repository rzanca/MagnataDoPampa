extends RefCounted

static var _icon_cache: Dictionary[String, ImageTexture] = {}

const SIZE_HI: int = 96
const SIZE_OUT: int = 44

static func get_icon(icon_id: String, tint: Color = Color("#FFF6D6")) -> ImageTexture:
	var key: String = "%s|%s" % [icon_id, tint.to_html(true)]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var tex: ImageTexture = _build_icon(icon_id, tint)
	_icon_cache[key] = tex
	return tex

static func clear_cache() -> void:
	_icon_cache.clear()

static func _build_icon(icon_id: String, fg: Color) -> ImageTexture:
	var img: Image = Image.create(SIZE_HI, SIZE_HI, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	match icon_id:
		"dice":
			_draw_rounded_rect(img, Rect2(14.0, 14.0, 68.0, 68.0), 14.0, Color(fg.r, fg.g, fg.b, 0.16), fg, 5.0)
			_draw_disc(img, Vector2(32.0, 32.0), 6.5, fg)
			_draw_disc(img, Vector2(64.0, 32.0), 6.5, fg)
			_draw_disc(img, Vector2(48.0, 48.0), 6.5, fg)
			_draw_disc(img, Vector2(32.0, 64.0), 6.5, fg)
			_draw_disc(img, Vector2(64.0, 64.0), 6.5, fg)
		"buy":
			_draw_rounded_rect(img, Rect2(16.0, 22.0, 44.0, 56.0), 8.0, Color(fg.r, fg.g, fg.b, 0.14), fg, 4.5)
			_draw_segment(img, Vector2(26.0, 38.0), Vector2(50.0, 38.0), 4.0, fg)
			_draw_segment(img, Vector2(26.0, 50.0), Vector2(46.0, 50.0), 4.0, fg)
			_draw_disc(img, Vector2(66.0, 62.0), 17.0, Color(fg.r, fg.g, fg.b, 0.28))
			_draw_ring(img, Vector2(66.0, 62.0), 17.0, 4.5, fg)
			_draw_segment(img, Vector2(58.0, 62.0), Vector2(64.0, 69.0), 4.5, fg)
			_draw_segment(img, Vector2(64.0, 69.0), Vector2(76.0, 54.0), 4.5, fg)
		"decline":
			_draw_ring(img, Vector2(48.0, 48.0), 34.0, 5.0, fg)
			_draw_segment(img, Vector2(32.0, 32.0), Vector2(64.0, 64.0), 6.0, fg)
			_draw_segment(img, Vector2(64.0, 32.0), Vector2(32.0, 64.0), 6.0, fg)
		"end_turn":
			_draw_segment(img, Vector2(22.0, 48.0), Vector2(68.0, 48.0), 6.5, fg)
			_draw_segment(img, Vector2(48.0, 26.0), Vector2(70.0, 48.0), 6.5, fg)
			_draw_segment(img, Vector2(48.0, 70.0), Vector2(70.0, 48.0), 6.5, fg)
			_draw_segment(img, Vector2(76.0, 24.0), Vector2(76.0, 72.0), 5.0, fg)
		"trade":
			_draw_segment(img, Vector2(20.0, 34.0), Vector2(74.0, 34.0), 5.5, fg)
			_draw_segment(img, Vector2(58.0, 20.0), Vector2(76.0, 34.0), 5.5, fg)
			_draw_segment(img, Vector2(58.0, 48.0), Vector2(76.0, 34.0), 5.5, fg)
			_draw_segment(img, Vector2(22.0, 64.0), Vector2(76.0, 64.0), 5.5, fg)
			_draw_segment(img, Vector2(38.0, 50.0), Vector2(20.0, 64.0), 5.5, fg)
			_draw_segment(img, Vector2(38.0, 78.0), Vector2(20.0, 64.0), 5.5, fg)
		"deeds":
			_draw_rounded_rect(img, Rect2(26.0, 14.0, 50.0, 60.0), 8.0, Color(fg.r, fg.g, fg.b, 0.12), fg, 4.0)
			_draw_rounded_rect(img, Rect2(16.0, 24.0, 50.0, 60.0), 8.0, Color(fg.r, fg.g, fg.b, 0.24), fg, 5.0)
			_draw_segment(img, Vector2(26.0, 40.0), Vector2(56.0, 40.0), 5.5, fg)
			_draw_segment(img, Vector2(26.0, 54.0), Vector2(50.0, 54.0), 4.0, fg)
			_draw_segment(img, Vector2(26.0, 66.0), Vector2(44.0, 66.0), 4.0, fg)
		"jail_bail":
			_draw_ring(img, Vector2(32.0, 48.0), 16.0, 5.5, fg)
			_draw_segment(img, Vector2(47.0, 48.0), Vector2(80.0, 48.0), 5.5, fg)
			_draw_segment(img, Vector2(66.0, 48.0), Vector2(66.0, 64.0), 5.5, fg)
			_draw_segment(img, Vector2(78.0, 48.0), Vector2(78.0, 62.0), 5.5, fg)
		"jail_card":
			_draw_rounded_rect(img, Rect2(14.0, 22.0, 68.0, 52.0), 10.0, Color(fg.r, fg.g, fg.b, 0.18), fg, 4.5)
			_draw_disc(img, Vector2(48.0, 48.0), 11.0, fg)
			_draw_segment(img, Vector2(48.0, 28.0), Vector2(48.0, 68.0), 4.0, fg)
			_draw_segment(img, Vector2(28.0, 48.0), Vector2(68.0, 48.0), 4.0, fg)
		"cam_3d":
			_draw_segment(img, Vector2(48.0, 14.0), Vector2(80.0, 32.0), 4.5, fg)
			_draw_segment(img, Vector2(48.0, 14.0), Vector2(16.0, 32.0), 4.5, fg)
			_draw_segment(img, Vector2(16.0, 32.0), Vector2(48.0, 50.0), 4.5, fg)
			_draw_segment(img, Vector2(80.0, 32.0), Vector2(48.0, 50.0), 4.5, fg)
			_draw_segment(img, Vector2(16.0, 32.0), Vector2(16.0, 66.0), 4.5, fg)
			_draw_segment(img, Vector2(80.0, 32.0), Vector2(80.0, 66.0), 4.5, fg)
			_draw_segment(img, Vector2(48.0, 50.0), Vector2(48.0, 82.0), 4.5, fg)
			_draw_segment(img, Vector2(16.0, 66.0), Vector2(48.0, 82.0), 4.5, fg)
			_draw_segment(img, Vector2(80.0, 66.0), Vector2(48.0, 82.0), 4.5, fg)
		"cam_2d":
			_draw_rounded_rect(img, Rect2(16.0, 16.0, 64.0, 64.0), 10.0, Color(fg.r, fg.g, fg.b, 0.14), fg, 5.0)
			_draw_segment(img, Vector2(48.0, 18.0), Vector2(48.0, 78.0), 3.5, fg)
			_draw_segment(img, Vector2(18.0, 48.0), Vector2(78.0, 48.0), 3.5, fg)
		"cam_follow":
			_draw_ring(img, Vector2(48.0, 48.0), 26.0, 5.0, fg)
			_draw_disc(img, Vector2(48.0, 48.0), 7.5, fg)
			_draw_segment(img, Vector2(48.0, 12.0), Vector2(48.0, 28.0), 4.5, fg)
			_draw_segment(img, Vector2(48.0, 68.0), Vector2(48.0, 84.0), 4.5, fg)
			_draw_segment(img, Vector2(12.0, 48.0), Vector2(28.0, 48.0), 4.5, fg)
			_draw_segment(img, Vector2(68.0, 48.0), Vector2(84.0, 48.0), 4.5, fg)
		"cam_center":
			_draw_segment(img, Vector2(16.0, 34.0), Vector2(16.0, 16.0), 5.0, fg)
			_draw_segment(img, Vector2(16.0, 16.0), Vector2(34.0, 16.0), 5.0, fg)
			_draw_segment(img, Vector2(62.0, 16.0), Vector2(80.0, 16.0), 5.0, fg)
			_draw_segment(img, Vector2(80.0, 16.0), Vector2(80.0, 34.0), 5.0, fg)
			_draw_segment(img, Vector2(16.0, 62.0), Vector2(16.0, 80.0), 5.0, fg)
			_draw_segment(img, Vector2(16.0, 80.0), Vector2(34.0, 80.0), 5.0, fg)
			_draw_segment(img, Vector2(62.0, 80.0), Vector2(80.0, 80.0), 5.0, fg)
			_draw_segment(img, Vector2(80.0, 80.0), Vector2(80.0, 62.0), 5.0, fg)
			_draw_disc(img, Vector2(48.0, 48.0), 8.5, fg)
		"zoom_in":
			_draw_ring(img, Vector2(42.0, 42.0), 22.0, 5.0, fg)
			_draw_segment(img, Vector2(58.0, 58.0), Vector2(78.0, 78.0), 6.5, fg)
			_draw_segment(img, Vector2(32.0, 42.0), Vector2(52.0, 42.0), 4.5, fg)
			_draw_segment(img, Vector2(42.0, 32.0), Vector2(42.0, 52.0), 4.5, fg)
		"zoom_out":
			_draw_ring(img, Vector2(42.0, 42.0), 22.0, 5.0, fg)
			_draw_segment(img, Vector2(58.0, 58.0), Vector2(78.0, 78.0), 6.5, fg)
			_draw_segment(img, Vector2(32.0, 42.0), Vector2(52.0, 42.0), 4.5, fg)
		"help":
			_draw_ring(img, Vector2(48.0, 48.0), 34.0, 5.0, fg)
			_draw_segment(img, Vector2(38.0, 35.0), Vector2(48.0, 27.0), 5.5, fg)
			_draw_segment(img, Vector2(48.0, 27.0), Vector2(59.0, 34.0), 5.5, fg)
			_draw_segment(img, Vector2(59.0, 34.0), Vector2(48.0, 49.0), 5.5, fg)
			_draw_segment(img, Vector2(48.0, 49.0), Vector2(48.0, 56.0), 5.5, fg)
			_draw_disc(img, Vector2(48.0, 68.0), 4.5, fg)
		"settings":
			_draw_ring(img, Vector2(48.0, 48.0), 22.0, 7.0, fg)
			for i: int in range(8):
				var ang: float = float(i) * TAU / 8.0
				var p0: Vector2 = Vector2(48.0, 48.0) + Vector2(cos(ang), sin(ang)) * 24.0
				var p1: Vector2 = Vector2(48.0, 48.0) + Vector2(cos(ang), sin(ang)) * 34.0
				_draw_segment(img, p0, p1, 7.0, fg)
			_draw_disc(img, Vector2(48.0, 48.0), 8.0, fg)
		"sound_on":
			_draw_rounded_rect(img, Rect2(18.0, 34.0, 16.0, 28.0), 4.0, fg, fg, 1.0)
			_draw_segment(img, Vector2(34.0, 34.0), Vector2(54.0, 20.0), 5.0, fg)
			_draw_segment(img, Vector2(34.0, 62.0), Vector2(54.0, 76.0), 5.0, fg)
			_draw_segment(img, Vector2(54.0, 20.0), Vector2(54.0, 76.0), 5.0, fg)
			_draw_segment(img, Vector2(66.0, 36.0), Vector2(72.0, 48.0), 4.5, fg)
			_draw_segment(img, Vector2(72.0, 48.0), Vector2(66.0, 60.0), 4.5, fg)
			_draw_segment(img, Vector2(76.0, 28.0), Vector2(83.0, 48.0), 4.5, fg)
			_draw_segment(img, Vector2(83.0, 48.0), Vector2(76.0, 68.0), 4.5, fg)
		"sound_off":
			_draw_rounded_rect(img, Rect2(16.0, 34.0, 16.0, 28.0), 4.0, fg, fg, 1.0)
			_draw_segment(img, Vector2(32.0, 34.0), Vector2(52.0, 20.0), 5.0, fg)
			_draw_segment(img, Vector2(32.0, 62.0), Vector2(52.0, 76.0), 5.0, fg)
			_draw_segment(img, Vector2(52.0, 20.0), Vector2(52.0, 76.0), 5.0, fg)
			_draw_segment(img, Vector2(62.0, 36.0), Vector2(82.0, 60.0), 5.5, fg)
			_draw_segment(img, Vector2(82.0, 36.0), Vector2(62.0, 60.0), 5.5, fg)
		"menu":
			_draw_segment(img, Vector2(20.0, 28.0), Vector2(76.0, 28.0), 7.0, fg)
			_draw_segment(img, Vector2(20.0, 48.0), Vector2(76.0, 48.0), 7.0, fg)
			_draw_segment(img, Vector2(20.0, 68.0), Vector2(76.0, 68.0), 7.0, fg)
		"trophies":
			_draw_rounded_rect(img, Rect2(26.0, 18.0, 44.0, 34.0), 10.0, Color(fg.r, fg.g, fg.b, 0.22), fg, 5.0)
			_draw_segment(img, Vector2(48.0, 52.0), Vector2(48.0, 74.0), 6.0, fg)
			_draw_segment(img, Vector2(30.0, 76.0), Vector2(66.0, 76.0), 6.0, fg)
			_draw_segment(img, Vector2(18.0, 24.0), Vector2(26.0, 24.0), 4.5, fg)
			_draw_segment(img, Vector2(70.0, 24.0), Vector2(78.0, 24.0), 4.5, fg)
		_:
			_draw_disc(img, Vector2(48.0, 48.0), 20.0, fg)

	img.resize(SIZE_OUT, SIZE_OUT, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

static func _blend_pixel(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE_HI or y >= SIZE_HI or col.a <= 0.001:
		return
	var dst: Color = img.get_pixel(x, y)
	var inv_a: float = 1.0 - col.a
	var out_a: float = col.a + dst.a * inv_a
	if out_a <= 0.001:
		return
	var r: float = (col.r * col.a + dst.r * dst.a * inv_a) / out_a
	var g: float = (col.g * col.a + dst.g * dst.a * inv_a) / out_a
	var b: float = (col.b * col.a + dst.b * dst.a * inv_a) / out_a
	img.set_pixel(x, y, Color(r, g, b, clampf(out_a, 0.0, 1.0)))

static func _draw_disc(img: Image, center: Vector2, radius: float, col: Color) -> void:
	var x0: int = maxi(0, floori(center.x - radius - 2.0))
	var x1: int = mini(SIZE_HI - 1, ceili(center.x + radius + 2.0))
	var y0: int = maxi(0, floori(center.y - radius - 2.0))
	var y1: int = mini(SIZE_HI - 1, ceili(center.y + radius + 2.0))
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var d: float = Vector2(float(x), float(y)).distance_to(center)
			var a: float = clampf(radius + 0.8 - d, 0.0, 1.0)
			if a > 0.0:
				_blend_pixel(img, x, y, Color(col.r, col.g, col.b, col.a * a))

static func _draw_ring(img: Image, center: Vector2, radius: float, thickness: float, col: Color) -> void:
	var half_t: float = thickness * 0.5
	var x0: int = maxi(0, floori(center.x - radius - half_t - 2.0))
	var x1: int = mini(SIZE_HI - 1, ceili(center.x + radius + half_t + 2.0))
	var y0: int = maxi(0, floori(center.y - radius - half_t - 2.0))
	var y1: int = mini(SIZE_HI - 1, ceili(center.y + radius + half_t + 2.0))
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var d: float = absf(Vector2(float(x), float(y)).distance_to(center) - radius)
			var a: float = clampf(half_t + 0.8 - d, 0.0, 1.0)
			if a > 0.0:
				_blend_pixel(img, x, y, Color(col.r, col.g, col.b, col.a * a))

static func _draw_segment(img: Image, p0: Vector2, p1: Vector2, thickness: float, col: Color) -> void:
	var half_t: float = thickness * 0.5
	var x0: int = maxi(0, floori(minf(p0.x, p1.x) - half_t - 2.0))
	var x1: int = mini(SIZE_HI - 1, ceili(maxf(p0.x, p1.x) + half_t + 2.0))
	var y0: int = maxi(0, floori(minf(p0.y, p1.y) - half_t - 2.0))
	var y1: int = mini(SIZE_HI - 1, ceili(maxf(p0.y, p1.y) + half_t + 2.0))
	var seg: Vector2 = p1 - p0
	var seg_len_sq: float = maxf(0.001, seg.length_squared())
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var pt: Vector2 = Vector2(float(x), float(y))
			var t: float = clampf((pt - p0).dot(seg) / seg_len_sq, 0.0, 1.0)
			var closest: Vector2 = p0 + seg * t
			var d: float = pt.distance_to(closest)
			var a: float = clampf(half_t + 0.8 - d, 0.0, 1.0)
			if a > 0.0:
				_blend_pixel(img, x, y, Color(col.r, col.g, col.b, col.a * a))

static func _draw_rounded_rect(img: Image, rect: Rect2, radius: float, fill_col: Color, stroke_col: Color, stroke_w: float) -> void:
	var center: Vector2 = rect.position + rect.size * 0.5
	var half_size: Vector2 = rect.size * 0.5 - Vector2(radius, radius)
	var x0: int = maxi(0, floori(rect.position.x - stroke_w - 2.0))
	var x1: int = mini(SIZE_HI - 1, ceili(rect.end.x + stroke_w + 2.0))
	var y0: int = maxi(0, floori(rect.position.y - stroke_w - 2.0))
	var y1: int = mini(SIZE_HI - 1, ceili(rect.end.y + stroke_w + 2.0))
	var half_s: float = stroke_w * 0.5
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var q: Vector2 = (Vector2(float(x), float(y)) - center).abs() - half_size
			var sdf: float = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			if fill_col.a > 0.0:
				var fill_a: float = clampf(0.8 - sdf, 0.0, 1.0)
				if fill_a > 0.0:
					_blend_pixel(img, x, y, Color(fill_col.r, fill_col.g, fill_col.b, fill_col.a * fill_a))
			if stroke_col.a > 0.0 and stroke_w > 0.0:
				var st_a: float = clampf(half_s + 0.8 - absf(sdf), 0.0, 1.0)
				if st_a > 0.0:
					_blend_pixel(img, x, y, Color(stroke_col.r, stroke_col.g, stroke_col.b, stroke_col.a * st_a))
