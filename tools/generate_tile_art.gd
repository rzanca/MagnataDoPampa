extends RefCounted

const IMG_SIZE: int = 256
const OUTPUT_DIR: String = "res://assets/tiles"
const BOARD_DATA_PATH: String = "res://data/board_data.json"

func generate_all_tiles() -> int:
	var file: FileAccess = FileAccess.open(BOARD_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("[TileArtGenerator] Não foi possível abrir %s" % BOARD_DATA_PATH)
		return 0

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("[TileArtGenerator] JSON inválido em %s" % BOARD_DATA_PATH)
		return 0

	var parsed_dict: Dictionary = parsed
	var raw_tiles: Variant = parsed_dict.get("tiles", [])
	if not (raw_tiles is Array):
		push_error("[TileArtGenerator] Campo 'tiles' inválido em %s" % BOARD_DATA_PATH)
		return 0

	var abs_out_dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var mk_err: Error = DirAccess.make_dir_recursive_absolute(abs_out_dir)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		push_error("[TileArtGenerator] Falha ao criar pasta %s (erro %d)" % [abs_out_dir, int(mk_err)])
		return 0

	var generated: Dictionary[String, bool] = {}
	var count: int = 0
	for entry: Variant in raw_tiles:
		if not (entry is Dictionary):
			continue
		var tile: Dictionary = entry
		var art_id: String = str(tile.get("art_id", "")).strip_edges()
		if art_id == "" or generated.has(art_id):
			continue
		var img: Image = _render_tile_art(tile, art_id)
		var out_path: String = "%s/%s.png" % [abs_out_dir, art_id]
		var save_err: Error = img.save_png(out_path)
		if save_err == OK:
			generated[art_id] = true
			count += 1
		else:
			push_error("[TileArtGenerator] Erro ao salvar %s (%d)" % [out_path, int(save_err)])

	return count

func _render_tile_art(tile: Dictionary, art_id: String) -> Image:
	var img: Image = Image.create(IMG_SIZE, IMG_SIZE, false, Image.FORMAT_RGBA8)
	var tile_type: String = str(tile.get("type", ""))
	var group_hex: String = str(tile.get("color", ""))
	var accent: Color = Color(group_hex) if group_hex != "" else _default_accent_for(art_id, tile_type)

	# Céu atmosférico full-bleed em gradiente rico (sem borda branca nem aparência de ícone solto)
	var sky_top: Color = _scene_sky_top(art_id, tile_type, accent)
	var sky_mid: Color = _scene_sky_mid(art_id, tile_type, accent)
	var sky_bot: Color = _scene_sky_bot(art_id, tile_type, accent)
	_fill_three_stop_gradient(img, sky_top, sky_mid, sky_bot)

	# Atmosfera luminosa de horizonte e nuvens/raios estilizados
	_draw_circle_aa(img, 186.0, 62.0, 56.0, Color(1.0, 0.90, 0.65, 0.22))
	_draw_circle_aa(img, 186.0, 62.0, 32.0, Color(1.0, 0.95, 0.78, 0.34))
	_draw_circle_aa(img, 62.0, 54.0, 46.0, Color(1.0, 1.0, 1.0, 0.08))

	# Composição cenográfica completa de ponta a ponta
	_draw_motif(img, art_id, accent)

	# Vinheta inferior e superior sutil para harmonizar com a moldura do tabuleiro 3D
	_draw_bottom_scrim(img, Color("#0C1611"), 62)

	# Identidade visual moderna do Pampa: moldura esmeralda escura + filete dourado unificado
	_draw_rounded_border(img, 3.0, 3.0, 250.0, 250.0, 14.0, 3.5, Color(0.06, 0.11, 0.08, 0.82))
	var is_corner_tile: bool = (art_id == "tile_galpao_central" or art_id == "tile_xadrez" or art_id == "tile_feriadao_20_setembro" or art_id == "tile_va_para_xadrez")
	var gold_alpha: float = 0.88 if (is_corner_tile or tile_type == "COMPANY" or tile_type == "CHANCE") else 0.54
	_draw_rounded_border(img, 7.0, 7.0, 242.0, 242.0, 12.0, 2.2 if not is_corner_tile else 3.0, Color(0.88, 0.73, 0.30, gold_alpha))
	if is_corner_tile or tile_type == "CHANCE":
		var gem_col: Color = Color(0.95, 0.80, 0.38, 0.85)
		_draw_diamond_aa(img, 20.0, 20.0, 5.0, 5.0, gem_col)
		_draw_diamond_aa(img, 236.0, 20.0, 5.0, 5.0, gem_col)

	return img

func _scene_sky_top(art_id: String, tile_type: String, accent: Color) -> Color:
	match art_id:
		"tile_galpao_central":
			return Color("#0B2E23")
		"tile_sorte_ou_azar":
			return Color("#0A261E")
		"tile_imposto_erva_mate":
			return Color("#153526")
		"tile_xadrez":
			return Color("#141B22")
		"tile_feriadao_20_setembro":
			return Color("#0E291F")
		"tile_va_para_xadrez":
			return Color("#4E0B16")
		"tile_taxa_churrasco":
			return Color("#42170D")
		"prop_orla_do_guaiba":
			return Color("#4D1827")
		"prop_lago_negro":
			return Color("#0E2233")
		"prop_praia_do_cassino", "prop_guarita_de_torres":
			return Color("#10415C")
		"prop_estancia_real_do_pampa":
			return Color("#0C1B33")
		_:
			if tile_type == "COMPANY":
				return Color("#0E2434")
			return accent.lerp(Color("#0E1512"), 0.56)

func _scene_sky_mid(art_id: String, tile_type: String, accent: Color) -> Color:
	match art_id:
		"tile_galpao_central":
			return Color("#1B5A42")
		"tile_sorte_ou_azar":
			return Color("#194D3B")
		"tile_xadrez":
			return Color("#27323D")
		"tile_va_para_xadrez":
			return Color("#8C1928")
		"tile_taxa_churrasco":
			return Color("#8C3419")
		"prop_orla_do_guaiba":
			return Color("#B84423")
		"prop_praia_do_cassino", "prop_guarita_de_torres":
			return Color("#2A7B9B")
		_:
			if tile_type == "COMPANY":
				return Color("#1E4B63")
			return accent.lerp(Color("#2B2620"), 0.28)

func _scene_sky_bot(art_id: String, tile_type: String, accent: Color) -> Color:
	match art_id:
		"prop_orla_do_guaiba":
			return Color("#F29F3D")
		"tile_galpao_central":
			return Color("#2F7E5B")
		"tile_xadrez":
			return Color("#3B4856")
		"tile_va_para_xadrez":
			return Color("#5A0E18")
		_:
			if tile_type == "COMPANY":
				return Color("#2F6D85")
			return accent.lerp(Color("#E6C792"), 0.25)

func _default_accent_for(art_id: String, tile_type: String) -> Color:
	match art_id:
		"tile_galpao_central":
			return Color("#2A9D8F")
		"tile_sorte_ou_azar":
			return Color("#E5BE5C")
		"tile_imposto_erva_mate":
			return Color("#52B788")
		"tile_xadrez":
			return Color("#6C757D")
		"tile_feriadao_20_setembro":
			return Color("#2A9D8F")
		"tile_va_para_xadrez":
			return Color("#D62828")
		"tile_taxa_churrasco":
			return Color("#E76F51")
		_:
			if tile_type == "COMPANY":
				return Color("#3A86A8")
			return Color("#386641")

func _draw_motif(img: Image, art_id: String, accent: Color) -> void:
	var ink: Color = Color("#0F1713")
	var wood: Color = Color("#8C5229")
	var wood_dark: Color = Color("#573116")
	var gold: Color = Color("#F5CB5C")
	var gold_deep: Color = Color("#C99224")
	var emerald: Color = Color("#2EC4B6")
	var pine: Color = Color("#1F5A42")
	var pine_bright: Color = Color("#46A87C")
	var crimson: Color = Color("#E63946")
	var water: Color = Color("#247BA0")
	var cyan: Color = Color("#8CE0F0")
	var terracotta: Color = Color("#E06643")
	var ivory: Color = Color("#FFF9EE")
	var steel: Color = Color("#D8E2E8")

	match art_id:
		"tile_galpao_central":
			_draw_hills(img, 146.0, Color("#174A36"), pine_bright)
			_draw_hills(img, 184.0, pine, Color("#133B2B"))
			_draw_rect_aa(img, 48.0, 96.0, 160.0, 84.0, ivory)
			_draw_rect_aa(img, 54.0, 102.0, 148.0, 78.0, wood)
			_draw_triangle_aa(img, Vector2(30.0, 104.0), Vector2(128.0, 32.0), Vector2(226.0, 104.0), ivory)
			_draw_triangle_aa(img, Vector2(40.0, 102.0), Vector2(128.0, 42.0), Vector2(216.0, 102.0), crimson)
			_draw_rounded_rect_aa(img, 100.0, 124.0, 56.0, 56.0, 22.0, ink)
			_draw_capsule_aa(img, Vector2(54.0, 198.0), Vector2(174.0, 198.0), 10.0, gold)
			_draw_triangle_aa(img, Vector2(166.0, 178.0), Vector2(214.0, 198.0), Vector2(166.0, 218.0), gold)

		"tile_sorte_ou_azar":
			_draw_circle_aa(img, 128.0, 122.0, 108.0, Color(0.96, 0.80, 0.36, 0.14))
			_draw_rounded_rect_aa(img, 42.0, 28.0, 172.0, 192.0, 20.0, gold)
			_draw_rounded_rect_aa(img, 50.0, 36.0, 156.0, 176.0, 15.0, Color("#134230"))
			_draw_diamond_aa(img, 128.0, 124.0, 62.0, 74.0, gold)
			_draw_diamond_aa(img, 128.0, 124.0, 48.0, 58.0, ivory)
			_draw_circle_aa(img, 128.0, 106.0, 19.0, Color("#134230"))
			_draw_circle_aa(img, 128.0, 106.0, 9.0, gold)
			_draw_circle_aa(img, 128.0, 152.0, 10.0, Color("#134230"))

		"tile_imposto_erva_mate":
			_draw_hills(img, 170.0, pine, Color("#123828"))
			_draw_circle_aa(img, 128.0, 118.0, 82.0, ink)
			_draw_circle_aa(img, 128.0, 118.0, 76.0, gold)
			_draw_circle_aa(img, 128.0, 118.0, 62.0, gold_deep)
			_draw_diamond_aa(img, 128.0, 116.0, 40.0, 56.0, Color("#154734"))
			_draw_capsule_aa(img, Vector2(128.0, 78.0), Vector2(128.0, 168.0), 4.5, ivory)

		"tile_xadrez":
			_draw_rect_aa(img, 0.0, 0.0, 256.0, 256.0, Color("#19212A"))
			_draw_rect_aa(img, 0.0, 168.0, 256.0, 88.0, Color("#11171D"))
			for b: int in range(5):
				var bx: float = 40.0 + float(b) * 44.0
				_draw_capsule_aa(img, Vector2(bx, 22.0), Vector2(bx, 212.0), 7.5, steel)
			_draw_rect_aa(img, 18.0, 56.0, 220.0, 14.0, Color("#566370"))
			_draw_rounded_rect_aa(img, 86.0, 108.0, 84.0, 66.0, 14.0, ink)
			_draw_rounded_rect_aa(img, 92.0, 114.0, 72.0, 54.0, 10.0, gold)
			_draw_circle_aa(img, 128.0, 138.0, 10.0, ink)

		"tile_feriadao_20_setembro":
			_draw_triangle_aa(img, Vector2(0.0, 0.0), Vector2(236.0, 0.0), Vector2(0.0, 236.0), Color("#198765"))
			_draw_triangle_aa(img, Vector2(256.0, 256.0), Vector2(20.0, 256.0), Vector2(256.0, 20.0), gold)
			_draw_capsule_aa(img, Vector2(18.0, 238.0), Vector2(238.0, 18.0), 38.0, crimson)
			_draw_circle_aa(img, 128.0, 118.0, 48.0, ink)
			_draw_circle_aa(img, 128.0, 118.0, 43.0, ivory)
			_draw_diamond_aa(img, 128.0, 118.0, 26.0, 26.0, gold_deep)

		"tile_va_para_xadrez":
			_draw_circle_aa(img, 128.0, 114.0, 90.0, ivory)
			_draw_circle_aa(img, 128.0, 114.0, 82.0, crimson)
			_draw_circle_aa(img, 128.0, 114.0, 64.0, Color("#3E0A11"))
			for b: int in range(3):
				var bx: float = 92.0 + float(b) * 36.0
				_draw_capsule_aa(img, Vector2(bx, 66.0), Vector2(bx, 162.0), 6.5, steel)
			_draw_capsule_aa(img, Vector2(68.0, 174.0), Vector2(188.0, 54.0), 9.0, gold)

		"tile_taxa_churrasco":
			_draw_rect_aa(img, 0.0, 164.0, 256.0, 92.0, Color("#241510"))
			_draw_circle_aa(img, 128.0, 166.0, 70.0, ink)
			_draw_triangle_aa(img, Vector2(72.0, 166.0), Vector2(128.0, 38.0), Vector2(184.0, 166.0), terracotta)
			_draw_triangle_aa(img, Vector2(96.0, 166.0), Vector2(128.0, 76.0), Vector2(160.0, 166.0), gold)
			_draw_capsule_aa(img, Vector2(36.0, 146.0), Vector2(220.0, 88.0), 7.0, ivory)

		"comp_expresso_minuano":
			_draw_hills(img, 146.0, Color("#1A4352"), Color("#122D38"))
			_draw_rect_aa(img, 0.0, 182.0, 256.0, 74.0, Color("#1C242B"))
			_draw_capsule_aa(img, Vector2(16.0, 198.0), Vector2(240.0, 198.0), 5.0, gold)
			_draw_rounded_rect_aa(img, 32.0, 78.0, 192.0, 96.0, 18.0, ivory)
			_draw_rounded_rect_aa(img, 38.0, 84.0, 180.0, 84.0, 14.0, Color("#1B4965"))
			_draw_rounded_rect_aa(img, 50.0, 96.0, 156.0, 34.0, 8.0, cyan)
			_draw_circle_aa(img, 80.0, 176.0, 22.0, ink)
			_draw_circle_aa(img, 80.0, 176.0, 10.0, gold)
			_draw_circle_aa(img, 176.0, 176.0, 22.0, ink)
			_draw_circle_aa(img, 176.0, 176.0, 10.0, gold)

		"comp_usina_jacui":
			_draw_hills(img, 128.0, Color("#183C4A"), Color("#122D38"))
			_draw_rect_aa(img, 0.0, 162.0, 256.0, 94.0, water)
			_draw_rounded_rect_aa(img, 30.0, 84.0, 196.0, 88.0, 10.0, steel)
			for s: int in range(3):
				_draw_rect_aa(img, 58.0 + float(s) * 56.0, 106.0, 28.0, 66.0, cyan)
			_draw_triangle_aa(img, Vector2(142.0, 28.0), Vector2(96.0, 114.0), Vector2(138.0, 114.0), gold)
			_draw_triangle_aa(img, Vector2(118.0, 102.0), Vector2(162.0, 102.0), Vector2(114.0, 182.0), gold)

		"comp_viacao_fandangueira":
			_draw_hills(img, 132.0, pine, Color("#183E30"))
			_draw_triangle_aa(img, Vector2(14.0, 256.0), Vector2(128.0, 76.0), Vector2(242.0, 256.0), Color("#1E2429"))
			_draw_capsule_aa(img, Vector2(128.0, 108.0), Vector2(128.0, 146.0), 5.5, gold)
			_draw_capsule_aa(img, Vector2(128.0, 174.0), Vector2(128.0, 224.0), 7.0, gold)
			_draw_rounded_rect_aa(img, 74.0, 42.0, 108.0, 62.0, 14.0, ivory)
			_draw_rounded_rect_aa(img, 80.0, 48.0, 96.0, 50.0, 10.0, terracotta)
			_draw_rounded_rect_aa(img, 92.0, 58.0, 72.0, 24.0, 6.0, cyan)

		"comp_estaleiro_rio_grande":
			_draw_rect_aa(img, 0.0, 164.0, 256.0, 92.0, water)
			_draw_capsule_aa(img, Vector2(20.0, 198.0), Vector2(120.0, 198.0), 4.0, cyan)
			_draw_capsule_aa(img, Vector2(132.0, 218.0), Vector2(236.0, 218.0), 4.0, cyan)
			_draw_triangle_aa(img, Vector2(28.0, 124.0), Vector2(228.0, 124.0), Vector2(198.0, 182.0), ivory)
			_draw_triangle_aa(img, Vector2(28.0, 124.0), Vector2(58.0, 182.0), Vector2(198.0, 182.0), ivory)
			_draw_triangle_aa(img, Vector2(38.0, 130.0), Vector2(218.0, 130.0), Vector2(192.0, 176.0), Color("#1D3557"))
			_draw_triangle_aa(img, Vector2(38.0, 130.0), Vector2(64.0, 176.0), Vector2(192.0, 176.0), Color("#1D3557"))
			_draw_rect_aa(img, 66.0, 86.0, 54.0, 40.0, terracotta)
			_draw_rect_aa(img, 126.0, 74.0, 48.0, 52.0, gold)
			_draw_rect_aa(img, 142.0, 48.0, 16.0, 28.0, ivory)

		"comp_cooperativa_agricola":
			_draw_hills(img, 152.0, pine_bright, pine)
			_draw_hills(img, 192.0, Color("#8C5E22"), Color("#593A12"))
			_draw_rounded_rect_aa(img, 58.0, 74.0, 66.0, 118.0, 30.0, steel)
			_draw_rounded_rect_aa(img, 130.0, 92.0, 66.0, 100.0, 30.0, ivory)
			_draw_circle_aa(img, 128.0, 56.0, 28.0, gold)
			_draw_capsule_aa(img, Vector2(36.0, 206.0), Vector2(220.0, 206.0), 8.0, gold)

		"comp_aeroporto_salgado_filho":
			_draw_hills(img, 182.0, Color("#153A4E"), Color("#0F2636"))
			_draw_circle_aa(img, 128.0, 118.0, 86.0, gold)
			_draw_circle_aa(img, 128.0, 118.0, 79.0, Color("#17567D"))
			_draw_capsule_aa(img, Vector2(54.0, 170.0), Vector2(202.0, 66.0), 12.0, ivory)
			_draw_triangle_aa(img, Vector2(100.0, 116.0), Vector2(186.0, 138.0), Vector2(142.0, 98.0), ivory)
			_draw_triangle_aa(img, Vector2(114.0, 126.0), Vector2(82.0, 60.0), Vector2(136.0, 108.0), ivory)
			_draw_triangle_aa(img, Vector2(74.0, 146.0), Vector2(58.0, 122.0), Vector2(92.0, 138.0), gold)

		"prop_beco_do_chimarrao":
			_draw_hills(img, 166.0, wood_dark, Color("#2E190C"))
			_draw_circle_aa(img, 128.0, 144.0, 68.0, ivory)
			_draw_circle_aa(img, 128.0, 144.0, 61.0, wood)
			_draw_rounded_rect_aa(img, 88.0, 70.0, 80.0, 30.0, 12.0, pine_bright)
			_draw_capsule_aa(img, Vector2(146.0, 82.0), Vector2(190.0, 26.0), 7.0, steel)
			_draw_rounded_rect_aa(img, 86.0, 194.0, 84.0, 20.0, 8.0, gold)

		"prop_vila_da_bombacha":
			_draw_hills(img, 168.0, pine_bright, pine)
			_draw_rect_aa(img, 36.0, 110.0, 78.0, 82.0, ivory)
			_draw_triangle_aa(img, Vector2(26.0, 112.0), Vector2(75.0, 62.0), Vector2(124.0, 112.0), gold)
			_draw_rect_aa(img, 122.0, 94.0, 92.0, 98.0, Color("#F6ECDA"))
			_draw_triangle_aa(img, Vector2(112.0, 96.0), Vector2(168.0, 44.0), Vector2(224.0, 96.0), terracotta)
			_draw_rect_aa(img, 156.0, 142.0, 26.0, 50.0, ink)

		"prop_passo_do_quero_quero":
			_draw_hills(img, 156.0, pine_bright, water)
			_draw_rect_aa(img, 0.0, 188.0, 256.0, 68.0, Color("#154C6B"))
			_draw_circle_aa(img, 128.0, 116.0, 32.0, ivory)
			_draw_triangle_aa(img, Vector2(30.0, 78.0), Vector2(126.0, 114.0), Vector2(84.0, 144.0), ink)
			_draw_triangle_aa(img, Vector2(226.0, 78.0), Vector2(130.0, 114.0), Vector2(172.0, 144.0), ink)
			_draw_circle_aa(img, 128.0, 78.0, 20.0, ivory)
			_draw_triangle_aa(img, Vector2(122.0, 62.0), Vector2(108.0, 32.0), Vector2(134.0, 60.0), gold)

		"prop_rincao_da_coxilha":
			_draw_circle_aa(img, 128.0, 86.0, 52.0, gold)
			_draw_hills(img, 134.0, pine_bright, pine)
			_draw_hills(img, 182.0, pine, Color("#0E2D20"))

		"prop_estancia_do_guapo":
			_draw_hills(img, 166.0, pine_bright, pine)
			_draw_rect_aa(img, 42.0, 102.0, 172.0, 88.0, ivory)
			_draw_triangle_aa(img, Vector2(28.0, 104.0), Vector2(128.0, 42.0), Vector2(228.0, 104.0), gold)
			for w: int in range(3):
				_draw_rect_aa(img, 64.0 + float(w) * 50.0, 128.0, 28.0, 36.0, ink)

		"prop_serra_do_umbu":
			_draw_hills(img, 162.0, Color("#6D4C82"), Color("#3C274C"))
			_draw_rect_aa(img, 112.0, 118.0, 32.0, 74.0, wood)
			_draw_circle_aa(img, 128.0, 92.0, 54.0, pine_bright)
			_draw_circle_aa(img, 80.0, 108.0, 40.0, emerald)
			_draw_circle_aa(img, 176.0, 108.0, 40.0, emerald)

		"prop_vale_dos_vinhedos":
			_draw_hills(img, 152.0, pine_bright, pine)
			_draw_hills(img, 192.0, Color("#173F2D"), Color("#0F2A1E"))
			for r: int in range(3):
				var row_y: float = 82.0 + float(r) * 26.0
				var cols: int = 3 - r
				for c: int in range(cols):
					var cx: float = 128.0 + (float(c) - float(cols - 1) * 0.5) * 30.0
					_draw_circle_aa(img, cx, row_y, 17.0, ivory)
					_draw_circle_aa(img, cx, row_y, 13.5, Color("#A41E72"))
			_draw_capsule_aa(img, Vector2(128.0, 38.0), Vector2(128.0, 68.0), 6.0, gold)

		"prop_canion_itaimbezinho":
			_draw_rect_aa(img, 0.0, 176.0, 256.0, 80.0, water)
			_draw_triangle_aa(img, Vector2(0.0, 224.0), Vector2(0.0, 38.0), Vector2(118.0, 224.0), Color("#7A5F50"))
			_draw_triangle_aa(img, Vector2(256.0, 224.0), Vector2(256.0, 38.0), Vector2(138.0, 224.0), Color("#4E3C32"))
			_draw_rect_aa(img, 114.0, 72.0, 28.0, 138.0, cyan)

		"prop_missoes_jesuiticas":
			_draw_hills(img, 176.0, pine, Color("#143627"))
			_draw_rect_aa(img, 40.0, 82.0, 176.0, 116.0, terracotta)
			_draw_triangle_aa(img, Vector2(36.0, 84.0), Vector2(128.0, 28.0), Vector2(220.0, 84.0), gold)
			for a: int in range(3):
				_draw_rounded_rect_aa(img, 62.0 + float(a) * 50.0, 122.0, 32.0, 76.0, 16.0, ink)

		"prop_fronteira_da_paz":
			_draw_hills(img, 164.0, emerald, water)
			_draw_rect_aa(img, 108.0, 48.0, 40.0, 146.0, ivory)
			_draw_triangle_aa(img, Vector2(102.0, 50.0), Vector2(128.0, 18.0), Vector2(154.0, 50.0), gold)
			_draw_circle_aa(img, 64.0, 126.0, 28.0, gold)
			_draw_circle_aa(img, 192.0, 126.0, 28.0, cyan)

		"prop_capital_da_soja":
			_draw_circle_aa(img, 128.0, 70.0, 48.0, gold)
			_draw_hills(img, 140.0, Color("#DDA15E"), Color("#9C521B"))
			for st: int in range(5):
				var sx: float = 48.0 + float(st) * 40.0
				_draw_capsule_aa(img, Vector2(sx, 212.0), Vector2(sx, 114.0), 5.0, gold)
				_draw_circle_aa(img, sx, 110.0, 11.0, ivory)

		"prop_avenida_borges":
			_draw_rect_aa(img, 24.0, 68.0, 54.0, 154.0, steel)
			_draw_rect_aa(img, 94.0, 34.0, 68.0, 188.0, ivory)
			_draw_rect_aa(img, 178.0, 80.0, 54.0, 142.0, steel)
			_draw_rounded_rect_aa(img, 12.0, 158.0, 232.0, 36.0, 12.0, crimson)
			_draw_rect_aa(img, 110.0, 58.0, 14.0, 24.0, ink)
			_draw_rect_aa(img, 134.0, 58.0, 14.0, 24.0, ink)

		"prop_parque_da_redencao":
			_draw_hills(img, 170.0, pine_bright, pine)
			_draw_rounded_rect_aa(img, 70.0, 58.0, 116.0, 136.0, 16.0, ivory)
			_draw_rounded_rect_aa(img, 98.0, 108.0, 60.0, 86.0, 28.0, pine)
			_draw_circle_aa(img, 42.0, 138.0, 36.0, emerald)
			_draw_circle_aa(img, 214.0, 138.0, 36.0, emerald)

		"prop_orla_do_guaiba":
			_draw_circle_aa(img, 128.0, 108.0, 58.0, Color("#FF9F1C"))
			_draw_rect_aa(img, 0.0, 132.0, 256.0, 124.0, Color("#112A48"))
			_draw_capsule_aa(img, Vector2(58.0, 154.0), Vector2(198.0, 154.0), 7.0, gold)
			_draw_capsule_aa(img, Vector2(84.0, 178.0), Vector2(172.0, 178.0), 5.5, Color("#FF9F1C"))
			_draw_rect_aa(img, 0.0, 200.0, 256.0, 56.0, wood)

		"prop_lago_negro":
			_draw_rect_aa(img, 0.0, 156.0, 256.0, 100.0, Color("#0C2032"))
			_draw_triangle_aa(img, Vector2(22.0, 164.0), Vector2(66.0, 42.0), Vector2(110.0, 164.0), pine_bright)
			_draw_triangle_aa(img, Vector2(84.0, 164.0), Vector2(130.0, 26.0), Vector2(176.0, 164.0), emerald)
			_draw_triangle_aa(img, Vector2(146.0, 164.0), Vector2(192.0, 56.0), Vector2(238.0, 164.0), pine_bright)

		"prop_rua_coberta":
			_draw_rounded_rect_aa(img, 30.0, 44.0, 196.0, 164.0, 92.0, ivory)
			_draw_rounded_rect_aa(img, 46.0, 60.0, 164.0, 148.0, 78.0, water)
			_draw_rect_aa(img, 0.0, 176.0, 256.0, 80.0, ink)
			for l: int in range(4):
				_draw_circle_aa(img, 70.0 + float(l) * 38.0, 102.0, 11.0, gold)

		"prop_cascata_do_caracol":
			_draw_rect_aa(img, 0.0, 176.0, 256.0, 80.0, water)
			_draw_rounded_rect_aa(img, 32.0, 38.0, 192.0, 150.0, 20.0, Color("#3A3F47"))
			_draw_rect_aa(img, 100.0, 44.0, 56.0, 148.0, cyan)
			_draw_circle_aa(img, 128.0, 188.0, 44.0, ivory)
			_draw_triangle_aa(img, Vector2(12.0, 166.0), Vector2(46.0, 78.0), Vector2(80.0, 166.0), pine_bright)

		"prop_praia_do_cassino":
			_draw_rect_aa(img, 0.0, 122.0, 256.0, 60.0, water)
			_draw_rect_aa(img, 0.0, 170.0, 256.0, 86.0, gold)
			_draw_rect_aa(img, 146.0, 54.0, 38.0, 126.0, ivory)
			_draw_rect_aa(img, 146.0, 84.0, 38.0, 24.0, crimson)
			_draw_triangle_aa(img, Vector2(138.0, 56.0), Vector2(165.0, 26.0), Vector2(192.0, 56.0), crimson)

		"prop_guarita_de_torres":
			_draw_rect_aa(img, 0.0, 160.0, 256.0, 96.0, water)
			_draw_triangle_aa(img, Vector2(24.0, 174.0), Vector2(126.0, 34.0), Vector2(222.0, 174.0), Color("#7F6A58"))
			_draw_triangle_aa(img, Vector2(68.0, 108.0), Vector2(126.0, 34.0), Vector2(174.0, 108.0), pine_bright)

		"prop_cais_embarcadero":
			_draw_rect_aa(img, 0.0, 172.0, 256.0, 84.0, water)
			_draw_rect_aa(img, 24.0, 100.0, 92.0, 74.0, terracotta)
			_draw_triangle_aa(img, Vector2(18.0, 102.0), Vector2(70.0, 58.0), Vector2(122.0, 102.0), gold)
			_draw_rect_aa(img, 134.0, 100.0, 92.0, 74.0, terracotta)
			_draw_triangle_aa(img, Vector2(128.0, 102.0), Vector2(180.0, 58.0), Vector2(232.0, 102.0), gold)
			_draw_rect_aa(img, 0.0, 164.0, 256.0, 18.0, ivory)

		"prop_moinhos_de_vento":
			_draw_hills(img, 170.0, pine_bright, pine)
			_draw_triangle_aa(img, Vector2(82.0, 198.0), Vector2(128.0, 62.0), Vector2(174.0, 198.0), ivory)
			_draw_capsule_aa(img, Vector2(54.0, 38.0), Vector2(202.0, 186.0), 9.0, gold)
			_draw_capsule_aa(img, Vector2(202.0, 38.0), Vector2(54.0, 186.0), 9.0, gold)
			_draw_circle_aa(img, 128.0, 112.0, 18.0, ink)

		"prop_estancia_real_do_pampa":
			_draw_hills(img, 172.0, pine_bright, pine)
			_draw_rect_aa(img, 38.0, 102.0, 180.0, 92.0, ivory)
			_draw_triangle_aa(img, Vector2(24.0, 104.0), Vector2(128.0, 52.0), Vector2(232.0, 104.0), gold)
			_draw_triangle_aa(img, Vector2(84.0, 52.0), Vector2(96.0, 22.0), Vector2(114.0, 52.0), gold)
			_draw_triangle_aa(img, Vector2(108.0, 52.0), Vector2(128.0, 14.0), Vector2(148.0, 52.0), gold)
			_draw_triangle_aa(img, Vector2(142.0, 52.0), Vector2(160.0, 22.0), Vector2(172.0, 52.0), gold)
			_draw_rounded_rect_aa(img, 104.0, 136.0, 48.0, 58.0, 18.0, Color("#1D3557"))

		_:
			_draw_hills(img, 166.0, pine_bright, accent)
			_draw_diamond_aa(img, 128.0, 112.0, 54.0, 54.0, gold)

# --- Primitivas Anti-Aliased Rápidas (Clipped BBox SDF) ---

func _fill_three_stop_gradient(img: Image, top_col: Color, mid_col: Color, bot_col: Color) -> void:
	var bands: int = 64
	var band_h: int = 4
	for b: int in range(bands):
		var t: float = float(b) / float(bands - 1)
		var col: Color = top_col.lerp(mid_col, t * 2.0) if t < 0.5 else mid_col.lerp(bot_col, (t - 0.5) * 2.0)
		img.fill_rect(Rect2i(0, b * band_h, IMG_SIZE, band_h), col)

func _draw_bottom_scrim(img: Image, dark_col: Color, height_px: int) -> void:
	var y_start: int = maxi(0, IMG_SIZE - height_px)
	for y: int in range(y_start, IMG_SIZE):
		var t: float = float(y - y_start) / float(maxi(1, height_px - 1))
		var alpha: float = t * t * 0.55
		for x: int in range(IMG_SIZE):
			var dst: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, dst.lerp(dark_col, alpha))

func _blend_pixel(img: Image, x: int, y: int, src: Color, coverage: float) -> void:
	var alpha: float = clampf(src.a * coverage, 0.0, 1.0)
	if alpha <= 0.002:
		return
	if alpha >= 0.998:
		img.set_pixel(x, y, Color(src.r, src.g, src.b, 1.0))
		return
	var dst: Color = img.get_pixel(x, y)
	var out: Color = dst.lerp(Color(src.r, src.g, src.b, 1.0), alpha)
	img.set_pixel(x, y, out)

func _draw_circle_aa(img: Image, cx: float, cy: float, radius: float, col: Color) -> void:
	var x0: int = maxi(0, floori(cx - radius - 2.0))
	var x1: int = mini(IMG_SIZE - 1, ceili(cx + radius + 2.0))
	var y0: int = maxi(0, floori(cy - radius - 2.0))
	var y1: int = mini(IMG_SIZE - 1, ceili(cy + radius + 2.0))
	for y: int in range(y0, y1 + 1):
		var dy: float = float(y) + 0.5 - cy
		for x: int in range(x0, x1 + 1):
			var dx: float = float(x) + 0.5 - cx
			var dist: float = sqrt(dx * dx + dy * dy) - radius
			if dist < 1.0:
				_blend_pixel(img, x, y, col, clampf(0.5 - dist, 0.0, 1.0))

func _draw_rect_aa(img: Image, rx: float, ry: float, rw: float, rh: float, col: Color) -> void:
	_draw_rounded_rect_aa(img, rx, ry, rw, rh, 2.0, col)

func _draw_rounded_rect_aa(img: Image, rx: float, ry: float, rw: float, rh: float, radius: float, col: Color) -> void:
	var half_w: float = rw * 0.5
	var half_h: float = rh * 0.5
	var cx: float = rx + half_w
	var cy: float = ry + half_h
	var r: float = minf(radius, minf(half_w, half_h))
	var x0: int = maxi(0, floori(rx - 2.0))
	var x1: int = mini(IMG_SIZE - 1, ceili(rx + rw + 2.0))
	var y0: int = maxi(0, floori(ry - 2.0))
	var y1: int = mini(IMG_SIZE - 1, ceili(ry + rh + 2.0))
	for y: int in range(y0, y1 + 1):
		var py: float = absf(float(y) + 0.5 - cy) - (half_h - r)
		for x: int in range(x0, x1 + 1):
			var px: float = absf(float(x) + 0.5 - cx) - (half_w - r)
			var qx: float = maxf(px, 0.0)
			var qy: float = maxf(py, 0.0)
			var dist: float = sqrt(qx * qx + qy * qy) + minf(maxf(px, py), 0.0) - r
			if dist < 1.0:
				_blend_pixel(img, x, y, col, clampf(0.5 - dist, 0.0, 1.0))

func _draw_rounded_border(img: Image, rx: float, ry: float, rw: float, rh: float, radius: float, thickness: float, col: Color) -> void:
	var half_w: float = rw * 0.5
	var half_h: float = rh * 0.5
	var cx: float = rx + half_w
	var cy: float = ry + half_h
	var r: float = minf(radius, minf(half_w, half_h))
	var half_t: float = thickness * 0.5
	var x0: int = maxi(0, floori(rx - thickness - 2.0))
	var x1: int = mini(IMG_SIZE - 1, ceili(rx + rw + thickness + 2.0))
	var y0: int = maxi(0, floori(ry - thickness - 2.0))
	var y1: int = mini(IMG_SIZE - 1, ceili(ry + rh + thickness + 2.0))
	for y: int in range(y0, y1 + 1):
		var py: float = absf(float(y) + 0.5 - cy) - (half_h - r)
		for x: int in range(x0, x1 + 1):
			var px: float = absf(float(x) + 0.5 - cx) - (half_w - r)
			var qx: float = maxf(px, 0.0)
			var qy: float = maxf(py, 0.0)
			var sd: float = sqrt(qx * qx + qy * qy) + minf(maxf(px, py), 0.0) - r
			var ring_dist: float = absf(sd) - half_t
			if ring_dist < 1.0:
				_blend_pixel(img, x, y, col, clampf(0.5 - ring_dist, 0.0, 1.0))

func _draw_capsule_aa(img: Image, a: Vector2, b: Vector2, radius: float, col: Color) -> void:
	var x0: int = maxi(0, floori(minf(a.x, b.x) - radius - 2.0))
	var x1: int = mini(IMG_SIZE - 1, ceili(maxf(a.x, b.x) + radius + 2.0))
	var y0: int = maxi(0, floori(minf(a.y, b.y) - radius - 2.0))
	var y1: int = mini(IMG_SIZE - 1, ceili(maxf(a.y, b.y) + radius + 2.0))
	var ba: Vector2 = b - a
	var ba_dot: float = maxf(0.0001, ba.dot(ba))
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var pa: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - a
			var h: float = clampf(pa.dot(ba) / ba_dot, 0.0, 1.0)
			var dist: float = (pa - ba * h).length() - radius
			if dist < 1.0:
				_blend_pixel(img, x, y, col, clampf(0.5 - dist, 0.0, 1.0))

func _draw_triangle_aa(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, col: Color) -> void:
	var x0: int = maxi(0, floori(minf(p0.x, minf(p1.x, p2.x)) - 2.0))
	var x1: int = mini(IMG_SIZE - 1, ceili(maxf(p0.x, maxf(p1.x, p2.x)) + 2.0))
	var y0: int = maxi(0, floori(minf(p0.y, minf(p1.y, p2.y)) - 2.0))
	var y1: int = mini(IMG_SIZE - 1, ceili(maxf(p0.y, maxf(p1.y, p2.y)) + 2.0))

	var e0: Vector2 = p1 - p0
	var e1: Vector2 = p2 - p1
	var e2: Vector2 = p0 - p2
	var area_sign: float = 1.0 if (e0.x * (p2.y - p0.y) - e0.y * (p2.x - p0.x)) >= 0.0 else -1.0
	var len0: float = maxf(0.0001, e0.length())
	var len1: float = maxf(0.0001, e1.length())
	var len2: float = maxf(0.0001, e2.length())

	for y: int in range(y0, y1 + 1):
		var py: float = float(y) + 0.5
		for x: int in range(x0, x1 + 1):
			var px: float = float(x) + 0.5
			var d0: float = ((e0.x * (py - p0.y) - e0.y * (px - p0.x)) * area_sign) / len0
			var d1: float = ((e1.x * (py - p1.y) - e1.y * (px - p1.x)) * area_sign) / len1
			var d2: float = ((e2.x * (py - p2.y) - e2.y * (px - p2.x)) * area_sign) / len2
			var inside_d: float = minf(d0, minf(d1, d2))
			if inside_d > -1.0:
				_blend_pixel(img, x, y, col, clampf(inside_d + 0.5, 0.0, 1.0))

func _draw_diamond_aa(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	_draw_triangle_aa(img, Vector2(cx, cy - ry), Vector2(cx + rx, cy), Vector2(cx, cy + ry), col)
	_draw_triangle_aa(img, Vector2(cx, cy - ry), Vector2(cx, cy + ry), Vector2(cx - rx, cy), col)

func _draw_hills(img: Image, base_y: float, back_col: Color, front_col: Color) -> void:
	_draw_circle_aa(img, 76.0, base_y + 52.0, 110.0, back_col)
	_draw_circle_aa(img, 188.0, base_y + 58.0, 118.0, front_col)
	var fill_y: int = clampi(floori(base_y + 24.0), 0, IMG_SIZE - 1)
	img.fill_rect(Rect2i(0, fill_y, IMG_SIZE, IMG_SIZE - fill_y), front_col)
