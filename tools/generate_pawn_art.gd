@tool
extends EditorScript

const IMG_SIZE: int = 256
const OUTPUT_DIR: String = "res://assets/pawns"
const PAWN_IDS: Array[String] = [
	"cuia",
	"quero_quero",
	"espeto",
	"cavalo",
	"chapeu",
	"facao"
]

func _run() -> void:
	var count: int = generate_all_pawns()
	print("[PawnArtGenerator] %d ilustrações modernas de peões geradas em %s." % [count, OUTPUT_DIR])
	if Engine.is_editor_hint():
		var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
		if fs != null:
			fs.scan()

func generate_all_pawns() -> int:
	var abs_out_dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var mk_err: Error = DirAccess.make_dir_recursive_absolute(abs_out_dir)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		push_error("[PawnArtGenerator] Falha ao criar pasta %s (erro %d)" % [abs_out_dir, int(mk_err)])
		return 0

	var count: int = 0
	for pawn_id: String in PAWN_IDS:
		var img: Image = _render_pawn_emblem(pawn_id)
		var out_path: String = "%s/%s.png" % [abs_out_dir, pawn_id]
		var save_err: Error = img.save_png(out_path)
		if save_err == OK:
			count += 1
		else:
			push_error("[PawnArtGenerator] Erro ao salvar %s (%d)" % [out_path, int(save_err)])
	return count

func _render_pawn_emblem(pawn_id: String) -> Image:
	var img: Image = Image.create(IMG_SIZE, IMG_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	# Disco circular de alto contraste com gradiente radial nobre e aro dourado limpo
	var bg_inner: Color = _emblem_bg_inner(pawn_id)
	var bg_outer: Color = _emblem_bg_outer(pawn_id)
	_fill_radial_disc(img, 128.0, 128.0, 120.0, bg_inner, bg_outer)

	# Brilho suave superior para dar profundidade moderna (estilo vetor polido)
	_draw_ellipse_aa(img, 128.0, 74.0, 82.0, 44.0, 0.0, Color(1.0, 0.98, 0.90, 0.09))

	match pawn_id:
		"cuia":
			_draw_cuia(img)
		"quero_quero":
			_draw_quero_quero(img)
		"espeto":
			_draw_espeto(img)
		"cavalo":
			_draw_cavalo(img)
		"chapeu":
			_draw_chapeu(img)
		_:
			_draw_facao(img)

	# Moldura circular dupla dourada nítida (recorta perfeitamente no medalhão 3D)
	_draw_ring_aa(img, 128.0, 128.0, 112.0, 118.0, Color("#F5CA5C"))
	_draw_ring_aa(img, 128.0, 128.0, 118.0, 121.5, Color("#0C1410"))
	_draw_ring_aa(img, 128.0, 128.0, 108.5, 111.5, Color(0.08, 0.13, 0.10, 0.65))

	# Recorte alfa circular suave fora do raio 122
	_mask_outside_circle(img, 128.0, 128.0, 121.5)
	return img

func _emblem_bg_inner(pawn_id: String) -> Color:
	match pawn_id:
		"cuia":
			return Color("#1C3A2B")
		"quero_quero":
			return Color("#183242")
		"espeto":
			return Color("#3B2118")
		"cavalo":
			return Color("#223228")
		"chapeu":
			return Color("#262D3B")
		_:
			return Color("#1E2C36")

func _emblem_bg_outer(pawn_id: String) -> Color:
	match pawn_id:
		"cuia":
			return Color("#0B1912")
		"quero_quero":
			return Color("#0A161F")
		"espeto":
			return Color("#170C08")
		"cavalo":
			return Color("#0D1711")
		"chapeu":
			return Color("#10141C")
		_:
			return Color("#0C1319")

# --- 1. Cuia de Chimarrão ---

func _draw_cuia(img: Image) -> void:
	var ink: Color = Color("#130C08")

	# Sombra projetada suave sob o pé da cuia
	_draw_ellipse_aa(img, 122.0, 212.0, 46.0, 11.0, 0.0, Color(0.0, 0.0, 0.0, 0.42))

	# Vapor estilizado contínuo (sem marcas de sobreposição) saindo da erva quente
	_draw_quad_bezier_smooth(img, Vector2(96.0, 86.0), Vector2(84.0, 64.0), Vector2(101.0, 48.0), 4.2, Color(1.0, 1.0, 1.0, 0.36))
	_draw_quad_bezier_smooth(img, Vector2(120.0, 80.0), Vector2(111.0, 56.0), Vector2(127.0, 40.0), 3.8, Color(1.0, 1.0, 1.0, 0.30))

	# Bomba metálica cromada em diagonal com folga limpa dentro do aro dourado
	_draw_capsule_aa(img, Vector2(138.0, 108.0), Vector2(178.0, 56.0), 11.0, ink)
	_draw_capsule_aa(img, Vector2(138.0, 108.0), Vector2(178.0, 56.0), 7.6, Color("#B8CBD8"))
	_draw_capsule_aa(img, Vector2(136.0, 106.0), Vector2(176.0, 54.0), 3.4, Color("#F4FAFF"))
	# Biqueira curvada dourada
	_draw_capsule_aa(img, Vector2(175.0, 58.0), Vector2(191.0, 52.0), 7.2, ink)
	_draw_capsule_aa(img, Vector2(175.0, 58.0), Vector2(191.0, 52.0), 4.4, Color("#FFD166"))
	# Anel resfriador dourado da bomba
	_draw_ellipse_aa(img, 161.0, 78.0, 13.5, 6.8, 36.0, ink)
	_draw_ellipse_aa(img, 161.0, 78.0, 10.5, 4.6, 36.0, Color("#FFD166"))

	# Morro de erva-mate verde vibrante
	_draw_ellipse_aa(img, 116.0, 103.0, 52.0, 26.0, -4.0, ink)
	_draw_ellipse_aa(img, 116.0, 104.0, 47.0, 22.0, -4.0, Color("#2FA839"))
	_draw_ellipse_aa(img, 104.0, 99.0, 30.0, 13.0, -8.0, Color("#5BE358"))
	# Cevadura (lado da água)
	_draw_ellipse_aa(img, 136.0, 107.0, 16.0, 8.0, 4.0, Color("#1D5E26"))

	# Pé da cuia
	var foot_poly: PackedVector2Array = PackedVector2Array([
		Vector2(96.0, 186.0),
		Vector2(148.0, 186.0),
		Vector2(160.0, 210.0),
		Vector2(84.0, 210.0)
	])
	_draw_polygon_aa(img, _expand_poly(foot_poly, 3.8), ink)
	_draw_polygon_aa(img, foot_poly, Color("#7A3918"))
	_draw_capsule_aa(img, Vector2(92.0, 206.0), Vector2(152.0, 206.0), 3.2, Color("#D4AF37"))

	# Corpo/bojo arredondado da cuia + pescoço acinturado
	_draw_ellipse_aa(img, 122.0, 164.0, 56.0, 42.0, 0.0, ink)
	var neck_poly: PackedVector2Array = PackedVector2Array([
		Vector2(70.0, 108.0),
		Vector2(174.0, 108.0),
		Vector2(156.0, 146.0),
		Vector2(88.0, 146.0)
	])
	_draw_polygon_aa(img, _expand_poly(neck_poly, 4.0), ink)

	_draw_ellipse_aa(img, 122.0, 164.0, 51.0, 37.5, 0.0, Color("#C46329"))
	_draw_polygon_aa(img, neck_poly, Color("#C46329"))

	# Modelagem de luz e sombra do porongo
	_draw_ellipse_aa(img, 102.0, 158.0, 24.0, 26.0, -14.0, Color("#E8924C"))
	_draw_ellipse_aa(img, 96.0, 154.0, 11.0, 18.0, -16.0, Color("#FFC285"))
	_draw_ellipse_aa(img, 146.0, 168.0, 22.0, 26.0, 10.0, Color(0.32, 0.12, 0.04, 0.45))

	# Bocal largo de prata/ouro polido na boca da cuia
	_draw_capsule_aa(img, Vector2(70.0, 109.0), Vector2(174.0, 109.0), 11.0, ink)
	_draw_capsule_aa(img, Vector2(70.0, 109.0), Vector2(174.0, 109.0), 7.5, Color("#F6C958"))
	_draw_capsule_aa(img, Vector2(76.0, 107.0), Vector2(166.0, 107.0), 2.8, Color("#FFF3C4"))

# --- 2. Quero-Quero ---

func _draw_quero_quero(img: Image) -> void:
	var ink: Color = Color("#0F151A")

	# Pernas longas avermelhadas elegantes
	_draw_capsule_aa(img, Vector2(118.0, 172.0), Vector2(108.0, 214.0), 6.2, ink)
	_draw_capsule_aa(img, Vector2(118.0, 172.0), Vector2(108.0, 214.0), 3.6, Color("#FF465C"))
	_draw_capsule_aa(img, Vector2(138.0, 172.0), Vector2(146.0, 214.0), 6.2, ink)
	_draw_capsule_aa(img, Vector2(138.0, 172.0), Vector2(146.0, 214.0), 3.6, Color("#FF465C"))
	# Pés
	_draw_capsule_aa(img, Vector2(98.0, 214.0), Vector2(120.0, 214.0), 3.5, Color("#FF465C"))
	_draw_capsule_aa(img, Vector2(136.0, 214.0), Vector2(158.0, 214.0), 3.5, Color("#FF465C"))

	# Cauda escura em leque apontando para baixo-esquerda
	var tail_poly: PackedVector2Array = PackedVector2Array([
		Vector2(88.0, 148.0),
		Vector2(44.0, 178.0),
		Vector2(58.0, 194.0),
		Vector2(104.0, 166.0)
	])
	_draw_polygon_aa(img, _expand_poly(tail_poly, 3.8), ink)
	_draw_polygon_aa(img, tail_poly, Color("#1C252C"))
	_draw_capsule_aa(img, Vector2(54.0, 177.0), Vector2(68.0, 188.0), 3.2, Color("#F4F8FA"))

	# Corpo branco-marfim (peito e barriga)
	_draw_ellipse_aa(img, 126.0, 146.0, 52.0, 38.0, -18.0, ink)
	_draw_ellipse_aa(img, 126.0, 146.0, 47.0, 33.5, -18.0, Color("#F7FAF8"))

	# Pescoço e cabeça erguidos
	_draw_capsule_aa(img, Vector2(146.0, 124.0), Vector2(160.0, 82.0), 23.0, ink)
	_draw_capsule_aa(img, Vector2(146.0, 124.0), Vector2(160.0, 82.0), 19.0, Color("#CBD7E0"))

	# Asa cinza-prata elegante com pontas pretas e esporão vermelho icônico
	var wing_poly: PackedVector2Array = PackedVector2Array([
		Vector2(150.0, 120.0),
		Vector2(104.0, 114.0),
		Vector2(56.0, 152.0),
		Vector2(98.0, 166.0),
		Vector2(146.0, 148.0)
	])
	_draw_polygon_aa(img, _expand_poly(wing_poly, 4.0), ink)
	_draw_polygon_aa(img, wing_poly, Color("#8EA3B2"))
	var wing_tip: PackedVector2Array = PackedVector2Array([
		Vector2(92.0, 134.0),
		Vector2(56.0, 152.0),
		Vector2(88.0, 164.0),
		Vector2(112.0, 150.0)
	])
	_draw_polygon_aa(img, wing_tip, Color("#1E2830"))
	# Brilho na asa + esporão vermelho-coral
	_draw_capsule_aa(img, Vector2(106.0, 126.0), Vector2(138.0, 128.0), 4.0, Color("#D6E4ED"))
	var spur_poly: PackedVector2Array = PackedVector2Array([
		Vector2(132.0, 126.0),
		Vector2(150.0, 112.0),
		Vector2(142.0, 134.0)
	])
	_draw_polygon_aa(img, spur_poly, Color("#FF3B4E"))

	# Colar/peitoral negro curvado característico do quero-quero
	_draw_ellipse_aa(img, 155.0, 134.0, 18.0, 21.0, 18.0, Color("#182026"))
	_draw_ellipse_aa(img, 159.0, 130.0, 12.0, 15.0, 18.0, Color("#24303A"))

	# Penacho / crista negra comprida esvoaçando para trás
	_draw_quad_bezier_smooth(img, Vector2(150.0, 74.0), Vector2(114.0, 52.0), Vector2(78.0, 62.0), 6.2, ink)
	_draw_quad_bezier_smooth(img, Vector2(150.0, 74.0), Vector2(114.0, 52.0), Vector2(78.0, 62.0), 3.4, Color("#24303A"))
	_draw_quad_bezier_smooth(img, Vector2(148.0, 79.0), Vector2(116.0, 65.0), Vector2(88.0, 77.0), 4.0, Color("#161E24"))

	# Cabeça redonda, máscara frontal preta, olho vermelho vivo e bico coral com ponta preta
	_draw_circle_aa(img, 162.0, 82.0, 26.0, ink)
	_draw_circle_aa(img, 162.0, 82.0, 22.0, Color("#F5F9FC"))
	_draw_ellipse_aa(img, 174.0, 86.0, 12.0, 15.0, 8.0, Color("#182026"))
	_draw_circle_aa(img, 166.0, 79.0, 7.2, Color("#FF3B4E"))
	_draw_circle_aa(img, 166.0, 79.0, 3.8, Color("#11161A"))
	_draw_circle_aa(img, 168.0, 77.0, 1.8, Color.WHITE)

	# Bico afilado vermelho-coral
	var beak_poly: PackedVector2Array = PackedVector2Array([
		Vector2(180.0, 75.0),
		Vector2(220.0, 86.0),
		Vector2(180.0, 94.0)
	])
	_draw_polygon_aa(img, _expand_poly(beak_poly, 3.5), ink)
	_draw_polygon_aa(img, beak_poly, Color("#FF465C"))
	var beak_tip: PackedVector2Array = PackedVector2Array([
		Vector2(204.0, 81.5),
		Vector2(220.0, 86.0),
		Vector2(204.0, 89.5)
	])
	_draw_polygon_aa(img, beak_tip, Color("#151C22"))

# --- 3. Espeto de Churrasco ---

func _draw_espeto(img: Image) -> void:
	var ink: Color = Color("#1A0D08")

	# Chamas/brasas sutis atrás do espeto dando vivacidade ao churrasco
	_draw_circle_aa(img, 146.0, 148.0, 56.0, Color(1.0, 0.42, 0.14, 0.16))
	_draw_circle_aa(img, 108.0, 114.0, 44.0, Color(1.0, 0.72, 0.22, 0.14))

	# Haste metálica do espeto centralizada com folga limpa dentro do aro dourado
	_draw_capsule_aa(img, Vector2(78.0, 178.0), Vector2(194.0, 62.0), 7.8, ink)
	_draw_capsule_aa(img, Vector2(78.0, 178.0), Vector2(194.0, 62.0), 4.6, Color("#DCE7F0"))
	_draw_capsule_aa(img, Vector2(80.0, 176.0), Vector2(192.0, 60.0), 1.8, Color.WHITE)

	# Ponta afiada metálica no topo direito
	var tip_poly: PackedVector2Array = PackedVector2Array([
		Vector2(184.0, 62.0),
		Vector2(204.0, 52.0),
		Vector2(194.0, 72.0)
	])
	_draw_polygon_aa(img, _expand_poly(tip_poly, 3.0), ink)
	_draw_polygon_aa(img, tip_poly, Color("#F2F8FC"))

	# Cabo de madeira torneado na base esquerda + virola dourada
	_draw_capsule_aa(img, Vector2(58.0, 198.0), Vector2(90.0, 166.0), 13.5, ink)
	_draw_capsule_aa(img, Vector2(58.0, 198.0), Vector2(90.0, 166.0), 10.0, Color("#9E5324"))
	_draw_capsule_aa(img, Vector2(60.0, 192.0), Vector2(84.0, 168.0), 3.6, Color("#D4854B"))
	_draw_ellipse_aa(img, 93.0, 163.0, 12.8, 6.5, 45.0, ink)
	_draw_ellipse_aa(img, 93.0, 163.0, 9.8, 4.5, 45.0, Color("#FFD166"))

	# 3 cortes suculentos de picanha/costela com capa dourada e marcas de grelha
	var centers: Array[Vector2] = [
		Vector2(111.0, 145.0),
		Vector2(138.0, 118.0),
		Vector2(164.0, 92.0)
	]
	var radii_x: Array[float] = [26.0, 25.0, 22.0]
	var radii_y: Array[float] = [19.5, 19.0, 16.5]

	for i: int in range(3):
		var c: Vector2 = centers[i]
		var rx: float = radii_x[i]
		var ry: float = radii_y[i]

		# Guarnição colorida entre os cortes (pimentão/tomate para vivacidade)
		if i > 0:
			var mid: Vector2 = (centers[i - 1] + c) * 0.5
			var garnish_col: Color = Color("#46C952") if i == 1 else Color("#FF4A4A")
			_draw_ellipse_aa(img, mid.x, mid.y, 17.0, 8.5, 45.0, ink)
			_draw_ellipse_aa(img, mid.x, mid.y, 13.5, 5.8, 45.0, garnish_col)

		# Corte principal selado
		_draw_ellipse_aa(img, c.x, c.y, rx + 3.8, ry + 3.8, 45.0, ink)
		_draw_ellipse_aa(img, c.x, c.y, rx, ry, 45.0, Color("#B53D22"))
		# Capa de gordura dourada crocante no topo-esquerda do corte
		_draw_ellipse_aa(img, c.x - 7.0, c.y - 7.0, rx * 0.72, ry * 0.36, 45.0, Color("#F6C46A"))
		_draw_ellipse_aa(img, c.x - 8.5, c.y - 8.5, rx * 0.48, ry * 0.18, 45.0, Color("#FFE4AA"))
		# Marcas escuras da grelha
		_draw_capsule_aa(img, c + Vector2(-8.0, 6.0), c + Vector2(8.0, -4.0), 2.4, Color("#4D180E"))
		_draw_capsule_aa(img, c + Vector2(-2.0, 12.0), c + Vector2(14.0, 2.0), 2.2, Color("#4D180E"))

# --- 4. Cavalo Crioulo ---

func _draw_cavalo(img: Image) -> void:
	var ink: Color = Color("#120D0A")

	# Crina escura esvoaçante atrás do pescoço arqueado
	var mane_poly: PackedVector2Array = PackedVector2Array([
		Vector2(124.0, 54.0),
		Vector2(82.0, 74.0),
		Vector2(58.0, 122.0),
		Vector2(54.0, 182.0),
		Vector2(88.0, 198.0),
		Vector2(114.0, 122.0)
	])
	_draw_polygon_aa(img, _expand_poly(mane_poly, 4.0), ink)
	_draw_polygon_aa(img, mane_poly, Color("#1B2128"))
	_draw_quad_bezier(img, Vector2(106.0, 72.0), Vector2(78.0, 112.0), Vector2(72.0, 174.0), 4.0, Color("#3B4854"))
	_draw_quad_bezier(img, Vector2(92.0, 94.0), Vector2(70.0, 132.0), Vector2(64.0, 178.0), 3.0, Color("#3B4854"))

	# Orelha traseira
	var ear_back: PackedVector2Array = PackedVector2Array([
		Vector2(116.0, 68.0),
		Vector2(112.0, 38.0),
		Vector2(134.0, 58.0)
	])
	_draw_polygon_aa(img, _expand_poly(ear_back, 3.5), ink)
	_draw_polygon_aa(img, ear_back, Color("#8F3B1A"))

	# Silhueta nobre de cabeça e pescoço do Cavalo Crioulo
	var horse_poly: PackedVector2Array = PackedVector2Array([
		Vector2(82.0, 204.0),
		Vector2(86.0, 124.0),
		Vector2(116.0, 66.0),
		Vector2(154.0, 64.0),
		Vector2(204.0, 118.0),
		Vector2(202.0, 138.0),
		Vector2(182.0, 146.0),
		Vector2(158.0, 132.0),
		Vector2(150.0, 152.0),
		Vector2(166.0, 204.0)
	])
	_draw_polygon_aa(img, _expand_poly(horse_poly, 4.2), ink)
	_draw_polygon_aa(img, horse_poly, Color("#BD5628"))

	# Volume muscular: brilho dourado-castanho no focinho, testa e pescoço
	var shine_poly: PackedVector2Array = PackedVector2Array([
		Vector2(126.0, 72.0),
		Vector2(152.0, 70.0),
		Vector2(194.0, 118.0),
		Vector2(184.0, 126.0),
		Vector2(142.0, 92.0)
	])
	_draw_polygon_aa(img, shine_poly, Color("#E88C4C"))
	_draw_ellipse_aa(img, 124.0, 158.0, 22.0, 34.0, -14.0, Color("#D97438"))
	_draw_ellipse_aa(img, 142.0, 114.0, 18.0, 14.0, 12.0, Color("#963F1B"))

	# Orelha dianteira atenta
	var ear_front: PackedVector2Array = PackedVector2Array([
		Vector2(128.0, 68.0),
		Vector2(134.0, 38.0),
		Vector2(150.0, 66.0)
	])
	_draw_polygon_aa(img, _expand_poly(ear_front, 3.5), ink)
	_draw_polygon_aa(img, ear_front, Color("#D16934"))

	# Focinho escuro aveludado e narina
	_draw_ellipse_aa(img, 194.0, 128.0, 14.0, 13.0, 22.0, Color("#4D2315"))
	_draw_circle_aa(img, 196.0, 124.0, 4.2, ink)

	# Olho expressivo
	_draw_circle_aa(img, 156.0, 92.0, 7.5, ink)
	_draw_circle_aa(img, 158.0, 90.0, 2.6, Color.WHITE)

	# Cabresto gaúcho (couro vermelho + argolas douradas)
	_draw_capsule_aa(img, Vector2(142.0, 66.0), Vector2(144.0, 124.0), 4.0, Color("#D62828"))
	_draw_capsule_aa(img, Vector2(144.0, 124.0), Vector2(186.0, 134.0), 4.0, Color("#D62828"))
	_draw_capsule_aa(img, Vector2(174.0, 108.0), Vector2(184.0, 136.0), 4.0, Color("#D62828"))
	_draw_ring_aa(img, 144.0, 124.0, 5.5, 9.8, Color("#FFD166"))
	_draw_ring_aa(img, 184.0, 134.0, 4.5, 8.2, Color("#FFD166"))

# --- 5. Chapéu Gaúcho ---

func _draw_chapeu(img: Image) -> void:
	var ink: Color = Color("#120E0B")

	# Barbicacho (cordão dourado do queixo pendente sob a aba)
	_draw_quad_bezier(img, Vector2(96.0, 158.0), Vector2(128.0, 208.0), Vector2(160.0, 158.0), 6.2, ink)
	_draw_quad_bezier(img, Vector2(96.0, 158.0), Vector2(128.0, 208.0), Vector2(160.0, 158.0), 3.6, Color("#FFD166"))
	_draw_circle_aa(img, 128.0, 192.0, 9.5, ink)
	_draw_circle_aa(img, 128.0, 192.0, 6.5, Color("#E63946"))
	_draw_circle_aa(img, 128.0, 192.0, 3.0, Color("#FFD166"))

	# Sombra inferior da aba larga
	_draw_ellipse_aa(img, 128.0, 152.0, 88.0, 26.0, -5.0, ink)
	_draw_ellipse_aa(img, 128.0, 152.0, 83.0, 21.5, -5.0, Color("#734820"))

	# Face superior da aba larga gaúcha com filete dourado
	_draw_ellipse_aa(img, 128.0, 144.0, 86.0, 24.0, -5.0, ink)
	_draw_ellipse_aa(img, 128.0, 144.0, 81.5, 20.0, -5.0, Color("#D69B56"))
	_draw_ellipse_aa(img, 114.0, 141.0, 56.0, 12.0, -5.0, Color("#EBB978"))

	# Copa alta estruturada do chapéu gaúcho
	var crown_poly: PackedVector2Array = PackedVector2Array([
		Vector2(80.0, 140.0),
		Vector2(90.0, 74.0),
		Vector2(114.0, 66.0),
		Vector2(128.0, 73.0),
		Vector2(142.0, 65.0),
		Vector2(166.0, 74.0),
		Vector2(176.0, 134.0)
	])
	_draw_polygon_aa(img, _expand_poly(crown_poly, 4.2), ink)
	_draw_polygon_aa(img, crown_poly, Color("#C98C47"))

	# Luz lateral esquerda e sombra direita na copa
	var crown_light: PackedVector2Array = PackedVector2Array([
		Vector2(86.0, 134.0),
		Vector2(94.0, 78.0),
		Vector2(118.0, 72.0),
		Vector2(116.0, 132.0)
	])
	_draw_polygon_aa(img, crown_light, Color("#EBB978"))
	var crown_shade: PackedVector2Array = PackedVector2Array([
		Vector2(142.0, 72.0),
		Vector2(162.0, 78.0),
		Vector2(170.0, 130.0),
		Vector2(144.0, 132.0)
	])
	_draw_polygon_aa(img, crown_shade, Color("#96602A"))
	# Vinco superior
	_draw_capsule_aa(img, Vector2(114.0, 74.0), Vector2(142.0, 73.0), 4.0, Color("#7A4B1E"))

	# Faixa negra contrastante + detalhe vermelho e fivela dourada
	var band_poly: PackedVector2Array = PackedVector2Array([
		Vector2(80.0, 122.0),
		Vector2(174.0, 114.0),
		Vector2(176.0, 136.0),
		Vector2(78.0, 144.0)
	])
	_draw_polygon_aa(img, _expand_poly(band_poly, 2.5), ink)
	_draw_polygon_aa(img, band_poly, Color("#1A2026"))
	_draw_capsule_aa(img, Vector2(84.0, 132.0), Vector2(170.0, 124.0), 3.5, Color("#E63946"))
	# Fivela dourada central
	_draw_rounded_rect_aa(img, 114.0, 116.0, 26.0, 22.0, 5.0, ink)
	_draw_rounded_rect_aa(img, 117.0, 119.0, 20.0, 16.0, 4.0, Color("#FFD166"))
	_draw_rounded_rect_aa(img, 122.0, 123.0, 10.0, 8.0, 2.0, Color("#1A2026"))

# --- 6. Facão Gaúcho ---

func _draw_facao(img: Image) -> void:
	var ink: Color = Color("#0F1418")

	# Brilho sutil atrás da lâmina
	_draw_ellipse_aa(img, 146.0, 110.0, 62.0, 26.0, -45.0, Color(0.75, 0.90, 1.0, 0.14))

	# Lâmina larga e alongada em aço polido com folga limpa dentro do aro dourado
	var blade_poly: PackedVector2Array = PackedVector2Array([
		Vector2(98.0, 138.0),
		Vector2(172.0, 62.0),
		Vector2(200.0, 54.0),
		Vector2(193.0, 82.0),
		Vector2(120.0, 158.0)
	])
	_draw_polygon_aa(img, _expand_poly(blade_poly, 4.0), ink)
	_draw_polygon_aa(img, blade_poly, Color("#A9BDCB"))

	# Face superior espelhada (meio-fio luminoso)
	var blade_hi: PackedVector2Array = PackedVector2Array([
		Vector2(100.0, 138.0),
		Vector2(172.0, 62.0),
		Vector2(198.0, 56.0),
		Vector2(110.0, 148.0)
	])
	_draw_polygon_aa(img, blade_hi, Color("#F3F9FD"))

	# Gume afiado luminoso e sulco (fuller)
	_draw_capsule_aa(img, Vector2(118.0, 154.0), Vector2(191.0, 80.0), 2.3, Color("#FFFFFF"))
	_draw_capsule_aa(img, Vector2(116.0, 134.0), Vector2(168.0, 82.0), 2.6, Color("#5F7586"))
	# Reflexo diagonal dramático no aço
	var glint_poly: PackedVector2Array = PackedVector2Array([
		Vector2(146.0, 92.0),
		Vector2(162.0, 76.0),
		Vector2(176.0, 90.0),
		Vector2(160.0, 106.0)
	])
	_draw_polygon_aa(img, glint_poly, Color(1.0, 1.0, 1.0, 0.45))

	# Cabo firme em madeira nobre e osso com anéis dourados
	_draw_capsule_aa(img, Vector2(64.0, 192.0), Vector2(102.0, 154.0), 14.0, ink)
	_draw_capsule_aa(img, Vector2(64.0, 192.0), Vector2(102.0, 154.0), 10.4, Color("#6E3619"))
	_draw_capsule_aa(img, Vector2(66.0, 186.0), Vector2(96.0, 156.0), 3.8, Color("#B56333"))
	# Faixa de osso marfim e anéis dourados no cabo
	_draw_ellipse_aa(img, 83.0, 173.0, 12.2, 6.0, 45.0, Color("#F6EAD4"))
	_draw_ellipse_aa(img, 74.0, 182.0, 12.8, 3.8, 45.0, Color("#FFD166"))
	_draw_ellipse_aa(img, 92.0, 164.0, 12.8, 3.8, 45.0, Color("#FFD166"))
	# Pomo dourado
	_draw_circle_aa(img, 60.0, 196.0, 12.2, ink)
	_draw_circle_aa(img, 60.0, 196.0, 8.8, Color("#FFD166"))
	_draw_circle_aa(img, 58.0, 193.0, 3.6, Color("#FFF4C2"))

	# Guarda transversal curva dourada
	_draw_capsule_aa(img, Vector2(88.0, 128.0), Vector2(130.0, 170.0), 9.6, ink)
	_draw_capsule_aa(img, Vector2(88.0, 128.0), Vector2(130.0, 170.0), 6.5, Color("#F5C754"))
	_draw_capsule_aa(img, Vector2(92.0, 132.0), Vector2(126.0, 166.0), 2.4, Color("#FFF3BD"))

# --- Primitivas de Desenho Vetorial com Anti-Aliasing ---

func _blend_px(img: Image, x: int, y: int, col: Color, cov: float = 1.0) -> void:
	if x < 0 or x >= IMG_SIZE or y < 0 or y >= IMG_SIZE:
		return
	var a: float = clampf(col.a * cov, 0.0, 1.0)
	if a <= 0.001:
		return
	var dst: Color = img.get_pixel(x, y)
	var out_a: float = a + dst.a * (1.0 - a)
	if out_a <= 0.0001:
		return
	var r: float = (col.r * a + dst.r * dst.a * (1.0 - a)) / out_a
	var g: float = (col.g * a + dst.g * dst.a * (1.0 - a)) / out_a
	var b: float = (col.b * a + dst.b * dst.a * (1.0 - a)) / out_a
	img.set_pixel(x, y, Color(r, g, b, out_a))

func _fill_radial_disc(img: Image, cx: float, cy: float, radius: float, inner_col: Color, outer_col: Color) -> void:
	var min_x: int = maxi(0, floori(cx - radius - 2.0))
	var max_x: int = mini(IMG_SIZE - 1, ceili(cx + radius + 2.0))
	var min_y: int = maxi(0, floori(cy - radius - 2.0))
	var max_y: int = mini(IMG_SIZE - 1, ceili(cy + radius + 2.0))
	for y: int in range(min_y, max_y + 1):
		var dy: float = float(y) + 0.5 - cy
		for x: int in range(min_x, max_x + 1):
			var dx: float = float(x) + 0.5 - cx
			var dist: float = sqrt(dx * dx + dy * dy)
			var cov: float = clampf(radius + 0.75 - dist, 0.0, 1.0)
			if cov > 0.0:
				var t: float = clampf(dist / maxf(1.0, radius), 0.0, 1.0)
				var col: Color = inner_col.lerp(outer_col, t * t)
				_blend_px(img, x, y, col, cov)

func _mask_outside_circle(img: Image, cx: float, cy: float, radius: float) -> void:
	for y: int in range(IMG_SIZE):
		var dy: float = float(y) + 0.5 - cy
		for x: int in range(IMG_SIZE):
			var dx: float = float(x) + 0.5 - cx
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > radius + 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			elif dist > radius - 1.0:
				var factor: float = clampf((radius + 1.0 - dist) * 0.5, 0.0, 1.0)
				var px: Color = img.get_pixel(x, y)
				px.a *= factor
				img.set_pixel(x, y, px)

func _draw_circle_aa(img: Image, cx: float, cy: float, radius: float, col: Color) -> void:
	var min_x: int = maxi(0, floori(cx - radius - 2.0))
	var max_x: int = mini(IMG_SIZE - 1, ceili(cx + radius + 2.0))
	var min_y: int = maxi(0, floori(cy - radius - 2.0))
	var max_y: int = mini(IMG_SIZE - 1, ceili(cy + radius + 2.0))
	for y: int in range(min_y, max_y + 1):
		var dy: float = float(y) + 0.5 - cy
		for x: int in range(min_x, max_x + 1):
			var dx: float = float(x) + 0.5 - cx
			var dist: float = sqrt(dx * dx + dy * dy)
			var cov: float = clampf(radius + 0.65 - dist, 0.0, 1.0)
			if cov > 0.0:
				_blend_px(img, x, y, col, cov)

func _draw_ring_aa(img: Image, cx: float, cy: float, inner_r: float, outer_r: float, col: Color) -> void:
	var min_x: int = maxi(0, floori(cx - outer_r - 2.0))
	var max_x: int = mini(IMG_SIZE - 1, ceili(cx + outer_r + 2.0))
	var min_y: int = maxi(0, floori(cy - outer_r - 2.0))
	var max_y: int = mini(IMG_SIZE - 1, ceili(cy + outer_r + 2.0))
	for y: int in range(min_y, max_y + 1):
		var dy: float = float(y) + 0.5 - cy
		for x: int in range(min_x, max_x + 1):
			var dx: float = float(x) + 0.5 - cx
			var dist: float = sqrt(dx * dx + dy * dy)
			var cov_out: float = clampf(outer_r + 0.6 - dist, 0.0, 1.0)
			var cov_in: float = clampf(dist - (inner_r - 0.6), 0.0, 1.0)
			var cov: float = minf(cov_out, cov_in)
			if cov > 0.0:
				_blend_px(img, x, y, col, cov)

func _draw_ellipse_aa(img: Image, cx: float, cy: float, rx: float, ry: float, angle_deg: float, col: Color) -> void:
	var rad: float = deg_to_rad(-angle_deg)
	var ca: float = cos(rad)
	var sa: float = sin(rad)
	var bound: float = maxf(rx, ry) + 3.0
	var min_x: int = maxi(0, floori(cx - bound))
	var max_x: int = mini(IMG_SIZE - 1, ceili(cx + bound))
	var min_y: int = maxi(0, floori(cy - bound))
	var max_y: int = mini(IMG_SIZE - 1, ceili(cy + bound))
	var avg_r: float = maxf(1.0, (rx + ry) * 0.5)
	for y: int in range(min_y, max_y + 1):
		var dy: float = float(y) + 0.5 - cy
		for x: int in range(min_x, max_x + 1):
			var dx: float = float(x) + 0.5 - cx
			var lx: float = dx * ca - dy * sa
			var ly: float = dx * sa + dy * ca
			var nx: float = lx / maxf(0.5, rx)
			var ny: float = ly / maxf(0.5, ry)
			var norm_dist: float = sqrt(nx * nx + ny * ny)
			var signed_px: float = (norm_dist - 1.0) * avg_r
			var cov: float = clampf(0.65 - signed_px, 0.0, 1.0)
			if cov > 0.0:
				_blend_px(img, x, y, col, cov)

func _draw_capsule_aa(img: Image, a: Vector2, b: Vector2, radius: float, col: Color) -> void:
	var min_x: int = maxi(0, floori(minf(a.x, b.x) - radius - 2.0))
	var max_x: int = mini(IMG_SIZE - 1, ceili(maxf(a.x, b.x) + radius + 2.0))
	var min_y: int = maxi(0, floori(minf(a.y, b.y) - radius - 2.0))
	var max_y: int = mini(IMG_SIZE - 1, ceili(maxf(a.y, b.y) + radius + 2.0))
	var ab: Vector2 = b - a
	var ab_len_sq: float = maxf(0.0001, ab.length_squared())
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var t: float = clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
			var closest: Vector2 = a + ab * t
			var dist: float = p.distance_to(closest)
			var cov: float = clampf(radius + 0.65 - dist, 0.0, 1.0)
			if cov > 0.0:
				_blend_px(img, x, y, col, cov)

func _draw_quad_bezier(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, radius: float, col: Color) -> void:
	_draw_quad_bezier_smooth(img, p0, p1, p2, radius, col)

func _draw_quad_bezier_smooth(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, radius: float, col: Color) -> void:
	var steps: int = 16
	var pts: PackedVector2Array = PackedVector2Array()
	for s: int in range(steps + 1):
		var t: float = float(s) / float(steps)
		var omt: float = 1.0 - t
		pts.append(p0 * (omt * omt) + p1 * (2.0 * omt * t) + p2 * (t * t))

	var min_xf: float = minf(p0.x, minf(p1.x, p2.x))
	var max_xf: float = maxf(p0.x, maxf(p1.x, p2.x))
	var min_yf: float = minf(p0.y, minf(p1.y, p2.y))
	var max_yf: float = maxf(p0.y, maxf(p1.y, p2.y))
	var min_x: int = maxi(0, floori(min_xf - radius - 2.0))
	var max_x: int = mini(IMG_SIZE - 1, ceili(max_xf + radius + 2.0))
	var min_y: int = maxi(0, floori(min_yf - radius - 2.0))
	var max_y: int = mini(IMG_SIZE - 1, ceili(max_yf + radius + 2.0))

	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var px: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var min_d: float = 9999.0
			for i: int in range(steps):
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var ab: Vector2 = b - a
				var denom: float = maxf(0.0001, ab.length_squared())
				var seg_t: float = clampf((px - a).dot(ab) / denom, 0.0, 1.0)
				var d: float = px.distance_to(a + ab * seg_t)
				if d < min_d:
					min_d = d
			var cov: float = clampf(radius + 0.65 - min_d, 0.0, 1.0)
			if cov > 0.0:
				_blend_px(img, x, y, col, cov)

func _draw_rounded_rect_aa(img: Image, rx: float, ry: float, rw: float, rh: float, corner_r: float, col: Color) -> void:
	var cx: float = rx + rw * 0.5
	var cy: float = ry + rh * 0.5
	var hx: float = maxf(0.5, rw * 0.5 - corner_r)
	var hy: float = maxf(0.5, rh * 0.5 - corner_r)
	var min_x: int = maxi(0, floori(rx - 2.0))
	var max_x: int = mini(IMG_SIZE - 1, ceili(rx + rw + 2.0))
	var min_y: int = maxi(0, floori(ry - 2.0))
	var max_y: int = mini(IMG_SIZE - 1, ceili(ry + rh + 2.0))
	for y: int in range(min_y, max_y + 1):
		var qy: float = absf(float(y) + 0.5 - cy) - hy
		for x: int in range(min_x, max_x + 1):
			var qx: float = absf(float(x) + 0.5 - cx) - hx
			var out_d: float = Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length()
			var in_d: float = minf(maxf(qx, qy), 0.0)
			var sdf: float = out_d + in_d - corner_r
			var cov: float = clampf(0.65 - sdf, 0.0, 1.0)
			if cov > 0.0:
				_blend_px(img, x, y, col, cov)

func _expand_poly(pts: PackedVector2Array, amount: float) -> PackedVector2Array:
	var n: int = pts.size()
	var center: Vector2 = Vector2.ZERO
	for p: Vector2 in pts:
		center += p
	center /= maxf(1.0, float(n))
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		var dir: Vector2 = p - center
		var dlen: float = dir.length()
		if dlen > 0.001:
			out.append(p + (dir / dlen) * amount)
		else:
			out.append(p)
	return out

func _draw_polygon_aa(img: Image, pts: PackedVector2Array, col: Color) -> void:
	var n: int = pts.size()
	if n < 3:
		return
	var min_xf: float = pts[0].x
	var max_xf: float = pts[0].x
	var min_yf: float = pts[0].y
	var max_yf: float = pts[0].y
	for p: Vector2 in pts:
		min_xf = minf(min_xf, p.x)
		max_xf = maxf(max_xf, p.x)
		min_yf = minf(min_yf, p.y)
		max_yf = maxf(max_yf, p.y)

	var min_x: int = maxi(0, floori(min_xf - 2.0))
	var max_x: int = mini(IMG_SIZE - 1, ceili(max_xf + 2.0))
	var min_y: int = maxi(0, floori(min_yf - 2.0))
	var max_y: int = mini(IMG_SIZE - 1, ceili(max_yf + 2.0))

	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var px: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var inside: bool = Geometry2D.is_point_in_polygon(px, pts)
			var min_edge_d: float = 9999.0
			for i: int in range(n):
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % n]
				var ab: Vector2 = b - a
				var denom: float = maxf(0.0001, ab.length_squared())
				var t: float = clampf((px - a).dot(ab) / denom, 0.0, 1.0)
				var d: float = px.distance_to(a + ab * t)
				if d < min_edge_d:
					min_edge_d = d
			var sdf: float = -min_edge_d if inside else min_edge_d
			var cov: float = clampf(0.65 - sdf, 0.0, 1.0)
			if cov > 0.0:
				_blend_px(img, x, y, col, cov)
