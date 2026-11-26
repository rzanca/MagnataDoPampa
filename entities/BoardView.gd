extends Node2D

signal tile_clicked(tile_index: int)

@export var board_size: float = 680.0
@export var top_left: Vector2 = Vector2(24.0, 20.0)

var tile_centers: Array[Vector2] = []
var token_nodes: Array[Node2D] = []
var _tile_containers: Array[ColorRect] = []
var _tile_borders: Array[ReferenceRect] = []
var _building_overlays: Dictionary[int, Node2D] = {}
var _owner_overlays: Dictionary[int, Node2D] = {}
var _tile_value_labels: Dictionary[int, Label] = {}
var _tiles_cache: Array[Dictionary] = []
var _owners_cache: Dictionary[int, int] = {}
var _buildings_cache: Dictionary[int, int] = {}
var _player_colors: Dictionary[int, Color] = {}
var _mortgaged_cache: Dictionary[int, bool] = {}

const TILE_DEFAULT_BG: Color = Color("#F5F2EA")
const TILE_HOVER_BG: Color = Color("#E7EEDF")
const TILE_MORTGAGED_BG: Color = Color("#D6D0C5")
const BORDER_DEFAULT: Color = Color("#2B3630")
const BORDER_HOVER: Color = Color("#D4AF37")

const TOKEN_COLORS: Array[Color] = [
	Color("#FF3B4E"), # Vermelho
	Color("#22C55E"), # Verde Pampa
	Color("#FFCA3A"), # Ouro Pampa
	Color("#2563EB"), # Azul Guaíba
	Color("#A45CFF"), # Roxo Vinhedo
	Color("#FF7A38")  # Terracota
]

func build_board(tiles: Array[Dictionary]) -> void:
	for child: Node in get_children():
		child.queue_free()
	tile_centers.clear()
	_tile_containers.clear()
	_tile_borders.clear()
	_building_overlays.clear()
	_owner_overlays.clear()
	_tile_value_labels.clear()
	_tiles_cache = tiles.duplicate(true)
	_owners_cache.clear()
	_buildings_cache.clear()
	_mortgaged_cache.clear()

	var center_bg: ColorRect = ColorRect.new()
	var corner_size: float = board_size * 0.14
	center_bg.position = top_left + Vector2(corner_size, corner_size)
	center_bg.size = Vector2(board_size - corner_size * 2.0, board_size - corner_size * 2.0)
	center_bg.color = Color("#132219")
	center_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_bg)

	var center_border: ReferenceRect = ReferenceRect.new()
	center_border.position = center_bg.position + Vector2(12.0, 12.0)
	center_border.size = center_bg.size - Vector2(24.0, 24.0)
	center_border.border_color = Color("#C9A227")
	center_border.border_width = 1.5
	center_border.editor_only = false
	center_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_border)

	var title_label: Label = Label.new()
	title_label.text = "MAGNATA DO PAMPA\nMODO CLÁSSICO • RS\n\nClique em qualquer casa para inspecionar"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.position = center_bg.position
	title_label.size = center_bg.size
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("#F3C969"))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

	for i: int in range(tiles.size()):
		var rect: Rect2 = _get_tile_rect(i, board_size, corner_size)
		var tile_data: Dictionary = tiles[i]
		var container: ColorRect = _create_tile_visual(i, rect.position + top_left, rect.size, tile_data)
		_tile_containers.append(container)
		tile_centers.append(rect.position + top_left + rect.size * 0.5)

		var owner_overlay: Node2D = Node2D.new()
		container.add_child(owner_overlay)
		_owner_overlays[i] = owner_overlay

		var building_overlay: Node2D = Node2D.new()
		container.add_child(building_overlay)
		_building_overlays[i] = building_overlay

func _get_tile_rect(index: int, total_size: float, corner: float) -> Rect2:
	var side_len: float = total_size - corner * 2.0
	var step: float = side_len / 9.0

	if index == 0:
		return Rect2(total_size - corner, total_size - corner, corner, corner)
	elif index < 10:
		var k: float = float(index)
		var x: float = total_size - corner - k * step
		return Rect2(x, total_size - corner, step, corner)
	elif index == 10:
		return Rect2(0.0, total_size - corner, corner, corner)
	elif index < 20:
		var k: float = float(index - 10)
		var y: float = total_size - corner - k * step
		return Rect2(0.0, y, corner, step)
	elif index == 20:
		return Rect2(0.0, 0.0, corner, corner)
	elif index < 30:
		var k: float = float(index - 20)
		var x: float = corner + (k - 1.0) * step
		return Rect2(x, 0.0, step, corner)
	elif index == 30:
		return Rect2(total_size - corner, 0.0, corner, corner)
	else:
		var k: float = float(index - 30)
		var y: float = corner + (k - 1.0) * step
		return Rect2(total_size - corner, y, corner, step)

func _create_tile_visual(tile_idx: int, pos: Vector2, size: Vector2, tile_data: Dictionary) -> ColorRect:
	var container: ColorRect = ColorRect.new()
	container.position = pos
	container.size = size
	container.color = TILE_DEFAULT_BG
	container.clip_contents = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.gui_input.connect(func(event: InputEvent) -> void: _on_tile_gui_input(tile_idx, event))
	container.mouse_entered.connect(func() -> void: _on_tile_hover(tile_idx, true))
	container.mouse_exited.connect(func() -> void: _on_tile_hover(tile_idx, false))
	add_child(container)

	var border: ReferenceRect = ReferenceRect.new()
	border.size = size
	border.border_color = BORDER_DEFAULT
	border.border_width = 1.5
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border)
	_tile_borders.append(border)

	var group_color_hex: String = str(tile_data.get("color", ""))
	var text_offset: Vector2 = Vector2(3.0, 3.0)
	var text_size: Vector2 = size - Vector2(6.0, 14.0)

	if group_color_hex != "":
		var stripe: ColorRect = ColorRect.new()
		stripe.color = Color(group_color_hex)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if size.y > size.x:
			stripe.size = Vector2(10.0, size.y)
			text_offset = Vector2(13.0, 3.0)
			text_size = size - Vector2(16.0, 14.0)
		else:
			stripe.size = Vector2(size.x, 10.0)
			text_offset = Vector2(3.0, 13.0)
			text_size = size - Vector2(6.0, 24.0)
		container.add_child(stripe)

	var lbl: Label = Label.new()
	lbl.text = str(tile_data.get("name", ""))
	lbl.position = text_offset
	lbl.size = Vector2(maxf(8.0, text_size.x), maxf(8.0, text_size.y))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.clip_text = true
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color("#1D2320"))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)

	var t_type: String = str(tile_data.get("type", ""))
	if t_type == "PROPERTY" or t_type == "COMPANY" or t_type == "TAX":
		var val_lbl: Label = Label.new()
		val_lbl.position = Vector2(2.0, size.y - 19.0)
		val_lbl.size = Vector2(maxf(8.0, size.x - 4.0), 11.0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 7)
		if t_type == "TAX":
			val_lbl.text = "-P$%d" % int(tile_data.get("amount", 0))
			val_lbl.add_theme_color_override("font_color", Color("#9B1B1B"))
		else:
			val_lbl.text = "P$%d" % int(tile_data.get("price", 0))
			val_lbl.add_theme_color_override("font_color", Color("#7C5800"))
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(val_lbl)
		_tile_value_labels[tile_idx] = val_lbl

	return container

func _on_tile_gui_input(tile_idx: int, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			tile_clicked.emit(tile_idx)

func _on_tile_hover(tile_idx: int, hovered: bool) -> void:
	if tile_idx < 0 or tile_idx >= _tile_containers.size():
		return
	var is_mortgaged: bool = _mortgaged_cache.get(tile_idx, false)
	if hovered:
		_tile_containers[tile_idx].color = TILE_HOVER_BG
		if tile_idx < _tile_borders.size():
			_tile_borders[tile_idx].border_color = BORDER_HOVER
			_tile_borders[tile_idx].border_width = 2.0
	else:
		_tile_containers[tile_idx].color = TILE_MORTGAGED_BG if is_mortgaged else TILE_DEFAULT_BG
		if tile_idx < _tile_borders.size():
			_tile_borders[tile_idx].border_color = BORDER_DEFAULT
			_tile_borders[tile_idx].border_width = 1.5

func get_player_color(player_id: int) -> Color:
	if _player_colors.has(player_id):
		return _player_colors[player_id]
	var safe_idx: int = absi(player_id) % TOKEN_COLORS.size()
	return TOKEN_COLORS[safe_idx]

func _refresh_tile_value_labels() -> void:
	for tile_idx: int in _tile_value_labels.keys():
		if tile_idx < 0 or tile_idx >= _tiles_cache.size():
			continue
		var lbl: Label = _tile_value_labels[tile_idx]
		if lbl == null or not is_instance_valid(lbl):
			continue
		var t: Dictionary = _tiles_cache[tile_idx]
		var t_type: String = str(t.get("type", ""))
		if t_type == "TAX":
			continue
		if not _owners_cache.has(tile_idx):
			lbl.text = "P$%d" % int(t.get("price", 0))
			lbl.add_theme_color_override("font_color", Color("#7C5800"))
		elif _mortgaged_cache.get(tile_idx, false):
			lbl.text = "HIPOT"
			lbl.add_theme_color_override("font_color", Color("#9B1B1B"))
		elif t_type == "COMPANY":
			lbl.text = "%dx dados" % int(t.get("multiplier", 40))
			lbl.add_theme_color_override("font_color", Color("#0C4A6E"))
		elif t_type == "PROPERTY":
			var owner_id: int = int(_owners_cache[tile_idx])
			var rents: Array = t.get("rent", [])
			var lvl: int = clampi(int(_buildings_cache.get(tile_idx, 0)), 0, maxi(0, rents.size() - 1))
			var rent_val: int = int(rents[lvl]) if not rents.is_empty() else 0
			if lvl == 0 and _has_monopoly_in_cache(owner_id, str(t.get("group", ""))):
				rent_val *= 2
			lbl.text = "Al.P$%d" % rent_val
			lbl.add_theme_color_override("font_color", Color("#14532D"))

func _has_monopoly_in_cache(owner_id: int, group_name: String) -> bool:
	if group_name == "":
		return false
	var count: int = 0
	for i: int in range(_tiles_cache.size()):
		var t: Dictionary = _tiles_cache[i]
		if str(t.get("type", "")) == "PROPERTY" and str(t.get("group", "")) == group_name:
			count += 1
			if int(_owners_cache.get(i, -1)) != owner_id:
				return false
	return count > 0

func update_ownership(owners_map: Dictionary[int, int], mortgaged_map: Dictionary[int, bool]) -> void:
	_owners_cache = owners_map.duplicate()
	_mortgaged_cache.clear()
	for tile_idx: int in _owner_overlays.keys():
		var overlay: Node2D = _owner_overlays[tile_idx]
		for child: Node in overlay.get_children():
			child.queue_free()

		if tile_idx < 0 or tile_idx >= _tile_containers.size():
			continue

		var container: ColorRect = _tile_containers[tile_idx]
		if not owners_map.has(tile_idx):
			container.color = TILE_DEFAULT_BG
			continue

		var owner_id: int = owners_map[tile_idx]
		var is_mortgaged: bool = mortgaged_map.get(tile_idx, false)
		_mortgaged_cache[tile_idx] = is_mortgaged
		container.color = TILE_MORTGAGED_BG if is_mortgaged else TILE_DEFAULT_BG

		var owner_color: Color = get_player_color(owner_id)
		if is_mortgaged:
			owner_color.a = 0.45

		var bar_height: float = 7.0
		var bar: ColorRect = ColorRect.new()
		bar.position = Vector2(2.0, container.size.y - bar_height - 2.0)
		bar.size = Vector2(maxf(4.0, container.size.x - 4.0), bar_height)
		bar.color = owner_color
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(bar)

		var bar_outline: ReferenceRect = ReferenceRect.new()
		bar_outline.position = bar.position
		bar_outline.size = bar.size
		bar_outline.border_color = Color("#1D2320")
		bar_outline.border_width = 1.0
		bar_outline.editor_only = false
		bar_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(bar_outline)
	_refresh_tile_value_labels()

func update_buildings(buildings_map: Dictionary[int, int]) -> void:
	_buildings_cache = buildings_map.duplicate()
	for tile_idx: int in _building_overlays.keys():
		var overlay: Node2D = _building_overlays[tile_idx]
		for child: Node in overlay.get_children():
			child.queue_free()

		var level: int = buildings_map.get(tile_idx, 0)
		if level <= 0:
			continue

		if level >= 5:
			var hotel: ColorRect = ColorRect.new()
			hotel.size = Vector2(14.0, 9.0)
			hotel.position = Vector2(2.0, 2.0)
			hotel.color = Color("#C1121F")
			hotel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.add_child(hotel)
		else:
			for h: int in range(level):
				var house: ColorRect = ColorRect.new()
				house.size = Vector2(6.0, 6.0)
				house.position = Vector2(2.0 + float(h) * 8.0, 2.0)
				house.color = Color("#2D6A4F")
				house.mouse_filter = Control.MOUSE_FILTER_IGNORE
				overlay.add_child(house)
	_refresh_tile_value_labels()

func setup_tokens(players: Array[Dictionary]) -> void:
	for token: Node2D in token_nodes:
		token.queue_free()
	token_nodes.clear()
	_player_colors.clear()

	for i: int in range(players.size()):
		var player: Dictionary = players[i]
		var pid: int = int(player.get("id", i))
		var custom_hex: String = str(player.get("color_hex", ""))
		var token_color: Color = Color(custom_hex) if custom_hex != "" else TOKEN_COLORS[i % TOKEN_COLORS.size()]
		_player_colors[pid] = token_color

		var pawn_code: String = str(player.get("pawn_code", "P%d" % (i + 1)))

		var holder: Node2D = Node2D.new()
		var badge: PanelContainer = PanelContainer.new()
		badge.size = Vector2(22.0, 22.0)
		badge.position = Vector2(-11.0, -11.0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = token_color
		sb.border_color = Color.WHITE
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		badge.add_theme_stylebox_override("panel", sb)

		var code_lbl: Label = Label.new()
		code_lbl.text = pawn_code
		code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		code_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		code_lbl.add_theme_font_size_override("font_size", 8)
		var text_color: Color = Color("#121714") if token_color.get_luminance() > 0.62 else Color.WHITE
		code_lbl.add_theme_color_override("font_color", text_color)
		code_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(code_lbl)

		holder.add_child(badge)
		add_child(holder)
		token_nodes.append(holder)

	update_token_positions(players)

func update_token_positions(players: Array[Dictionary]) -> void:
	if tile_centers.is_empty():
		return

	var total_players: int = players.size()
	for i: int in range(total_players):
		if i >= token_nodes.size():
			break
		var player: Dictionary = players[i]
		if bool(player.get("bankrupt", false)):
			token_nodes[i].visible = false
			continue
		token_nodes[i].visible = true
		var pos_index: int = int(player.get("position", 0)) % tile_centers.size()
		var base_pos: Vector2 = tile_centers[pos_index]

		var col: int = i % 3
		var row: int = floori(float(i) / 3.0)
		var cols_in_row: int = mini(3, total_players - row * 3)
		var rows_total: int = 2 if total_players > 3 else 1
		var offset_x: float = (float(col) - float(cols_in_row - 1) * 0.5) * 14.0
		var offset_y: float = (float(row) - float(rows_total - 1) * 0.5) * 14.0
		token_nodes[i].position = base_pos + Vector2(offset_x, offset_y)

func animate_token_move(player_id: int, from_pos: int, steps: int, players: Array[Dictionary]) -> bool:
	if player_id < 0 or player_id >= token_nodes.size() or tile_centers.is_empty():
		update_token_positions(players)
		return true
	var token: Node2D = token_nodes[player_id]
	var board_len: int = tile_centers.size()
	var step_dir: int = 1 if steps >= 0 else -1
	var total_hops: int = absi(steps)
	var cur: int = from_pos
	for _hop: int in range(total_hops):
		if not is_inside_tree():
			return false
		cur = posmod(cur + step_dir, board_len)
		var target: Vector2 = tile_centers[cur]
		var tw: Tween = create_tween()
		tw.tween_property(token, "position", target, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	update_token_positions(players)
	return true
