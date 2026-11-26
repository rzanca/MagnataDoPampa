extends CanvasLayer

signal start_match_requested(player_configs: Array[Dictionary])
signal help_requested
signal settings_requested
signal host_room_requested(port: int, player_name: String)
signal join_room_requested(address: String, port: int, player_name: String)
signal host_web_room_requested(signaling_url: String, player_name: String, turn_cfg: Dictionary)
signal join_web_room_requested(signaling_url: String, room_code: String, player_name: String, turn_cfg: Dictionary)
signal disconnect_network_requested
signal lobby_config_changed
signal lobby_slot_pref_requested(pawn_idx: int, color_idx: int, player_name: String)

const UIStyleTokens = preload("res://ui/shared/UIStyleTokens.gd")
const PlatformProfileAdapter = preload("res://ui/shared/PlatformProfileAdapter.gd")
const BuildInfoClass = preload("res://core/BuildInfo.gd")

const MAX_PLAYERS: int = 6
const MIN_PLAYERS: int = 2
const MODE_TAB_LOCAL: int = 0
const MODE_TAB_ENET: int = 1
const MODE_TAB_WEBRTC: int = 2

const GENERIC_BOT_NAMES: Array[String] = [
	"Pedro",
	"Mariana",
	"Lucas",
	"Carla",
	"Rafael",
	"Fernanda"
]

const PAWN_OPTIONS: Array[Dictionary] = [
	{ "id": "cuia", "name": "Cuia de Chimarrão", "code": "CU" },
	{ "id": "quero_quero", "name": "Quero-Quero", "code": "QQ" },
	{ "id": "espeto", "name": "Espeto de Churrasco", "code": "ES" },
	{ "id": "cavalo", "name": "Cavalo Crioulo", "code": "CV" },
	{ "id": "chapeu", "name": "Chapéu Gaúcho", "code": "CH" },
	{ "id": "facao", "name": "Facão", "code": "FA" }
]

const COLOR_OPTIONS: Array[Dictionary] = [
	{ "name": "Vermelho", "hex": "#FF3B4E" },
	{ "name": "Verde Pampa", "hex": "#22C55E" },
	{ "name": "Ouro Pampa", "hex": "#FFCA3A" },
	{ "name": "Azul Guaíba", "hex": "#2563EB" },
	{ "name": "Roxo Vinhedo", "hex": "#A45CFF" },
	{ "name": "Terracota", "hex": "#FF7A38" }
]

var _profile_adapter: RefCounted = null
var _is_touch_mode: bool = false
var _bold_font: SystemFont = null
var _pawn_textures: Dictionary[String, Texture2D] = {}

var _player_count: int = 2
var _main_card: PanelContainer
var _cards_grid: GridContainer
var _count_buttons: Array[Button] = []
var _error_label: Label

var _slot_rows: Array[PanelContainer] = []
var _slot_accent_styles: Array[StyleBoxFlat] = []
var _slot_medal_styles: Array[StyleBoxFlat] = []
var _slot_medal_textures: Array[TextureRect] = []
var _slot_is_bot: Array[bool] = []
var _slot_type_buttons: Array[Button] = []
var _slot_name_edits: Array[LineEdit] = []
var _slot_pawn_selects: Array[OptionButton] = []
var _slot_color_buttons: Array[Array] = []
var _slot_pawn_indices: Array[int] = []
var _slot_color_indices: Array[int] = []
var _slot_peer_ids: Array[int] = []
var _slot_peer_statuses: Array[String] = []
var _updating_slots: bool = false

# Controles de Modo Local vs P2P LAN (ENet) vs Multiplayer Web (WebRTC)
var _active_mode_tab: int = MODE_TAB_LOCAL
var _net_mode: int = 0 # 0=LOCAL, 1=HOST, 2=CLIENT
var _net_transport: int = 0 # 0=NONE, 1=ENET, 2=WEBRTC
var _local_peer_id: int = 1
var _web_room_code: String = ""
var _connected_peers: Array[Dictionary] = []
var _btn_mode_local: Button
var _btn_mode_p2p: Button
var _btn_mode_web: Button

var _p2p_panel: PanelContainer
var _p2p_name_edit: LineEdit
var _p2p_ip_edit: LineEdit
var _p2p_port_edit: LineEdit
var _btn_host: Button
var _btn_join: Button
var _btn_disconnect: Button
var _p2p_status_label: Label

var _web_panel: PanelContainer
var _web_name_edit: LineEdit
var _web_code_edit: LineEdit
var _web_sig_url_edit: LineEdit
var _btn_web_host: Button
var _btn_web_join: Button
var _btn_web_copy: Button
var _btn_web_disconnect: Button
var _btn_turn_toggle: Button
var _web_turn_row: HBoxContainer
var _web_turn_url_edit: LineEdit
var _web_turn_user_edit: LineEdit
var _web_turn_pass_edit: LineEdit
var _web_status_label: Label

var _btn_start: Button
var _quick_buttons: Array[Button] = []
var _version_info: Dictionary = {}
var _version_badge_label: Label
var _update_pill_btn: Button
var _update_target_url: String = ""
var _update_http: HTTPRequest = null

func _resolve_platform_profile() -> RefCounted:
	return PlatformProfileAdapter.create_for_mobile_flag(PlatformProfileAdapter.resolve_is_mobile(get_tree()))

func get_ui_profile_id() -> String:
	if _profile_adapter != null:
		return str(_profile_adapter.get("profile_name"))
	return "android" if _is_touch_mode else "desktop"

func _ready() -> void:
	layer = 10
	_profile_adapter = _resolve_platform_profile()
	_is_touch_mode = bool(_profile_adapter.get("is_mobile")) if _profile_adapter != null else false
	_bold_font = UIStyleTokens.create_bold_font()
	_preload_pawn_textures()
	_build_ui()
	_refresh_count_buttons()
	_refresh_visible_slots()
	call_deferred("_check_for_updates_async")
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func open_screen() -> void:
	visible = true
	if _error_label != null:
		_error_label.text = ""
	_updating_slots = false
	_refresh_visible_slots()
	_refresh_exclusive_choices()
	_on_viewport_size_changed()

func close_screen() -> void:
	visible = false

func _preload_pawn_textures() -> void:
	_pawn_textures.clear()
	for opt: Dictionary in PAWN_OPTIONS:
		var pid: String = str(opt["id"])
		var path: String = "res://assets/pawns/%s.png" % pid
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			var loaded: Resource = ResourceLoader.load(path)
			if loaded is Texture2D:
				tex = loaded as Texture2D
		if tex == null:
			var abs_path: String = ProjectSettings.globalize_path(path)
			if FileAccess.file_exists(abs_path):
				var img: Image = Image.load_from_file(abs_path)
				if img != null and not img.is_empty():
					tex = ImageTexture.create_from_image(img)
		if tex != null:
			_pawn_textures[pid] = tex

func _make_box(bg_hex: String, border_hex: String, radius: int = 12, border_w: int = 2, shadow: int = 0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(bg_hex)
	sb.border_color = Color(border_hex)
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	return sb

func _style_button(
	btn: Button,
	normal_hex: String,
	hover_hex: String,
	pressed_hex: String,
	border_hex: String,
	text_col: Color,
	font_sz: int,
	min_size: Vector2,
	radius: int = 10,
	border_w: int = 1
) -> void:
	btn.custom_minimum_size = min_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _bold_font != null:
		btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_stylebox_override("normal", _make_box(normal_hex, border_hex, radius, border_w))
	btn.add_theme_stylebox_override("hover", _make_box(hover_hex, "#FFE9A8", radius, border_w))
	btn.add_theme_stylebox_override("pressed", _make_box(pressed_hex, "#FFF3C4", radius, border_w))
	btn.add_theme_stylebox_override("focus", _make_box(hover_hex, "#F3C969", radius, maxi(2, border_w)))

func _build_ui() -> void:
	var f_scale: float = 1.18 if _is_touch_mode else 1.0
	var ctrl_h: float = 46.0 if _is_touch_mode else 38.0

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.06, 0.04, 0.92)
	add_child(backdrop)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad_outer: int = 20 if _is_touch_mode else 28
	outer_margin.add_theme_constant_override("margin_left", pad_outer)
	outer_margin.add_theme_constant_override("margin_right", pad_outer)
	outer_margin.add_theme_constant_override("margin_top", pad_outer)
	outer_margin.add_theme_constant_override("margin_bottom", pad_outer)
	add_child(outer_margin)

	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(center)

	_main_card = PanelContainer.new()
	_main_card.custom_minimum_size = Vector2(1320.0, 760.0)
	_main_card.add_theme_stylebox_override("panel", _make_box("#101A14", "#D4AF37", 18, 2, 26))
	center.add_child(_main_card)

	var card_margin: MarginContainer = MarginContainer.new()
	var card_pad_h: int = 26 if _is_touch_mode else 32
	var card_pad_v: int = 20 if _is_touch_mode else 24
	card_margin.add_theme_constant_override("margin_left", card_pad_h)
	card_margin.add_theme_constant_override("margin_right", card_pad_h)
	card_margin.add_theme_constant_override("margin_top", card_pad_v)
	card_margin.add_theme_constant_override("margin_bottom", card_pad_v)
	_main_card.add_child(card_margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	card_margin.add_child(root_vbox)

	# --- Cabeçalho Hero ---
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(header_row)

	var btn_settings: Button = Button.new()
	btn_settings.text = "Ajustes"
	_style_button(
		btn_settings,
		"#1A2D23",
		"#254032",
		"#132119",
		"#C9A227",
		Color("#F8E5A8"),
		roundi(14.0 * f_scale),
		Vector2(130.0, ctrl_h),
		10,
		1
	)
	btn_settings.pressed.connect(func() -> void: settings_requested.emit())
	header_row.add_child(btn_settings)

	var title_vbox: VBoxContainer = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 4)
	header_row.add_child(title_vbox)

	var crest_row: HBoxContainer = HBoxContainer.new()
	crest_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crest_row.add_theme_constant_override("separation", 14)
	title_vbox.add_child(crest_row)

	var crest_dim: float = 48.0 if _is_touch_mode else 40.0
	if _pawn_textures.has("cuia"):
		var left_crest: TextureRect = TextureRect.new()
		left_crest.texture = _pawn_textures["cuia"]
		left_crest.custom_minimum_size = Vector2(crest_dim, crest_dim)
		left_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		left_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest_row.add_child(left_crest)

	var title_lbl: Label = Label.new()
	title_lbl.text = "MAGNATA DO PAMPA"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", roundi(36.0 * f_scale))
	title_lbl.add_theme_color_override("font_color", Color("#F5D06F"))
	crest_row.add_child(title_lbl)

	if _pawn_textures.has("cavalo"):
		var right_crest: TextureRect = TextureRect.new()
		right_crest.texture = _pawn_textures["cavalo"]
		right_crest.custom_minimum_size = Vector2(crest_dim, crest_dim)
		right_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		right_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest_row.add_child(right_crest)

	var subtitle_lbl: Label = Label.new()
	subtitle_lbl.text = "MODO CLÁSSICO  •  RIO GRANDE DO SUL  •  R$ 2.558 INICIAIS"
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", roundi(13.0 * f_scale))
	subtitle_lbl.add_theme_color_override("font_color", Color("#A7C2B2"))
	title_vbox.add_child(subtitle_lbl)

	_version_info = BuildInfoClass.load_version_info()
	var version_row: HBoxContainer = HBoxContainer.new()
	version_row.alignment = BoxContainer.ALIGNMENT_CENTER
	version_row.add_theme_constant_override("separation", 10)
	title_vbox.add_child(version_row)

	_version_badge_label = Label.new()
	_version_badge_label.text = "Build %s" % BuildInfoClass.get_display_version(_version_info)
	_version_badge_label.add_theme_font_size_override("font_size", roundi(11.5 * f_scale))
	_version_badge_label.add_theme_color_override("font_color", Color("#8FA899"))
	version_row.add_child(_version_badge_label)

	_update_pill_btn = Button.new()
	_update_pill_btn.visible = false
	_update_pill_btn.text = "Atualização disponível"
	_style_button(_update_pill_btn, "#1F4731", "#2B6143", "#163323", "#52B788", Color("#E8FFF2"), roundi(11.5 * f_scale), Vector2(180.0, 26.0 if not _is_touch_mode else 32.0), 8, 1)
	_update_pill_btn.pressed.connect(_on_update_pill_pressed)
	version_row.add_child(_update_pill_btn)

	var btn_help: Button = Button.new()
	btn_help.text = "Regras"
	_style_button(
		btn_help,
		"#1A2D23",
		"#254032",
		"#132119",
		"#4E7863",
		Color("#E9F5EE"),
		roundi(14.0 * f_scale),
		Vector2(130.0, ctrl_h),
		10,
		1
	)
	btn_help.pressed.connect(func() -> void: help_requested.emit())
	header_row.add_child(btn_help)

	# --- Barra de Modo (Local | P2P LAN ENet | Multiplayer Web WebRTC) ---
	var mode_row: HBoxContainer = HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(mode_row)

	_btn_mode_local = Button.new()
	_btn_mode_local.text = "Modo Local (Solo / Mesa)"
	_btn_mode_local.pressed.connect(func() -> void: _set_mode_tab(MODE_TAB_LOCAL))
	mode_row.add_child(_btn_mode_local)

	_btn_mode_p2p = Button.new()
	_btn_mode_p2p.text = "P2P LAN (ENet Desktop)"
	_btn_mode_p2p.disabled = OS.has_feature("web")
	if OS.has_feature("web"):
		_btn_mode_p2p.tooltip_text = "ENet (UDP) disponível apenas no executável Desktop; no navegador use Multiplayer Web (WebRTC)."
	_btn_mode_p2p.pressed.connect(func() -> void: _set_mode_tab(MODE_TAB_ENET))
	mode_row.add_child(_btn_mode_p2p)

	_btn_mode_web = Button.new()
	_btn_mode_web.text = "Multiplayer Web (WebRTC)"
	_btn_mode_web.pressed.connect(func() -> void: _set_mode_tab(MODE_TAB_WEBRTC))
	mode_row.add_child(_btn_mode_web)

	# --- Painel de Conexão P2P LAN (ENet: Hospedar / Entrar por IP e Porta) ---
	_p2p_panel = PanelContainer.new()
	_p2p_panel.visible = false
	var p2p_style: StyleBoxFlat = _make_box("#13241E", "#3B7A62", 12, 1)
	p2p_style.content_margin_left = 14.0
	p2p_style.content_margin_right = 14.0
	p2p_style.content_margin_top = 10.0
	p2p_style.content_margin_bottom = 10.0
	_p2p_panel.add_theme_stylebox_override("panel", p2p_style)
	root_vbox.add_child(_p2p_panel)

	var p2p_vb: VBoxContainer = VBoxContainer.new()
	p2p_vb.add_theme_constant_override("separation", 8)
	_p2p_panel.add_child(p2p_vb)

	var p2p_row: HBoxContainer = HBoxContainer.new()
	p2p_row.add_theme_constant_override("separation", 8)
	p2p_row.alignment = BoxContainer.ALIGNMENT_CENTER
	p2p_vb.add_child(p2p_row)

	var p2p_h: float = 42.0 if _is_touch_mode else 36.0
	var p2p_fs: int = roundi(13.0 * f_scale)

	var n_lbl: Label = Label.new()
	n_lbl.text = "Seu nome:"
	n_lbl.add_theme_font_size_override("font_size", p2p_fs)
	n_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	p2p_row.add_child(n_lbl)

	_p2p_name_edit = LineEdit.new()
	_p2p_name_edit.text = "Jogador 1"
	_p2p_name_edit.max_length = 20
	_p2p_name_edit.custom_minimum_size = Vector2(150.0, p2p_h)
	_p2p_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p2p_name_edit.add_theme_font_size_override("font_size", p2p_fs)
	p2p_row.add_child(_p2p_name_edit)

	var ip_lbl: Label = Label.new()
	ip_lbl.text = "IP:"
	ip_lbl.add_theme_font_size_override("font_size", p2p_fs)
	ip_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	p2p_row.add_child(ip_lbl)

	_p2p_ip_edit = LineEdit.new()
	_p2p_ip_edit.text = "127.0.0.1"
	_p2p_ip_edit.placeholder_text = "127.0.0.1 ou IP da LAN"
	_p2p_ip_edit.custom_minimum_size = Vector2(165.0, p2p_h)
	_p2p_ip_edit.add_theme_font_size_override("font_size", p2p_fs)
	p2p_row.add_child(_p2p_ip_edit)

	var port_lbl: Label = Label.new()
	port_lbl.text = "Porta:"
	port_lbl.add_theme_font_size_override("font_size", p2p_fs)
	port_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	p2p_row.add_child(port_lbl)

	_p2p_port_edit = LineEdit.new()
	_p2p_port_edit.text = "7777"
	_p2p_port_edit.max_length = 5
	_p2p_port_edit.custom_minimum_size = Vector2(76.0, p2p_h)
	_p2p_port_edit.add_theme_font_size_override("font_size", p2p_fs)
	p2p_row.add_child(_p2p_port_edit)

	_btn_host = Button.new()
	_btn_host.text = "Hospedar Sala"
	_style_button(_btn_host, "#226B50", "#2C8765", "#184F3B", "#7BF1A8", Color.WHITE, p2p_fs, Vector2(138.0, p2p_h), 9, 1)
	_btn_host.pressed.connect(_on_host_pressed)
	p2p_row.add_child(_btn_host)

	_btn_join = Button.new()
	_btn_join.text = "Entrar na Sala"
	_style_button(_btn_join, "#1B425C", "#24577A", "#143145", "#4EA8DE", Color("#E4F5FF"), p2p_fs, Vector2(138.0, p2p_h), 9, 1)
	_btn_join.pressed.connect(_on_join_pressed)
	p2p_row.add_child(_btn_join)

	_btn_disconnect = Button.new()
	_btn_disconnect.text = "Desconectar"
	_btn_disconnect.visible = false
	_style_button(_btn_disconnect, "#592528", "#753135", "#401A1C", "#FF758F", Color("#FFE8E8"), p2p_fs, Vector2(124.0, p2p_h), 9, 1)
	_btn_disconnect.pressed.connect(_on_disconnect_pressed)
	p2p_row.add_child(_btn_disconnect)

	_p2p_status_label = Label.new()
	_p2p_status_label.text = "Desconectado • Hospede uma sala ou informe IP e porta do Host para entrar."
	_p2p_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_p2p_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_p2p_status_label.add_theme_font_size_override("font_size", roundi(12.5 * f_scale))
	_p2p_status_label.add_theme_color_override("font_color", Color("#9FD9BE"))
	p2p_vb.add_child(_p2p_status_label)

	# --- Painel de Conexão Multiplayer Web (WebRTC Estrela: Código da Sala + STUN/TURN) ---
	_web_panel = PanelContainer.new()
	_web_panel.visible = false
	var web_style: StyleBoxFlat = _make_box("#13202A", "#4EA8DE", 12, 1)
	web_style.content_margin_left = 14.0
	web_style.content_margin_right = 14.0
	web_style.content_margin_top = 10.0
	web_style.content_margin_bottom = 10.0
	_web_panel.add_theme_stylebox_override("panel", web_style)
	root_vbox.add_child(_web_panel)

	var web_vb: VBoxContainer = VBoxContainer.new()
	web_vb.add_theme_constant_override("separation", 8)
	_web_panel.add_child(web_vb)

	var web_row_a: HBoxContainer = HBoxContainer.new()
	web_row_a.add_theme_constant_override("separation", 8)
	web_row_a.alignment = BoxContainer.ALIGNMENT_CENTER
	web_vb.add_child(web_row_a)

	var wn_lbl: Label = Label.new()
	wn_lbl.text = "Seu nome:"
	wn_lbl.add_theme_font_size_override("font_size", p2p_fs)
	wn_lbl.add_theme_color_override("font_color", Color("#CFE4F2"))
	web_row_a.add_child(wn_lbl)

	_web_name_edit = LineEdit.new()
	_web_name_edit.text = "Jogador 1"
	_web_name_edit.max_length = 20
	_web_name_edit.custom_minimum_size = Vector2(145.0, p2p_h)
	_web_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_web_name_edit.add_theme_font_size_override("font_size", p2p_fs)
	web_row_a.add_child(_web_name_edit)

	var wc_lbl: Label = Label.new()
	wc_lbl.text = "Código:"
	wc_lbl.add_theme_font_size_override("font_size", p2p_fs)
	wc_lbl.add_theme_color_override("font_color", Color("#CFE4F2"))
	web_row_a.add_child(wc_lbl)

	_web_code_edit = LineEdit.new()
	_web_code_edit.placeholder_text = "Ex.: P7K4M2"
	_web_code_edit.max_length = 12
	_web_code_edit.custom_minimum_size = Vector2(126.0, p2p_h)
	_web_code_edit.add_theme_font_size_override("font_size", p2p_fs)
	web_row_a.add_child(_web_code_edit)

	_btn_web_host = Button.new()
	_btn_web_host.text = "Criar Sala Web"
	_style_button(_btn_web_host, "#226B50", "#2C8765", "#184F3B", "#7BF1A8", Color.WHITE, p2p_fs, Vector2(138.0, p2p_h), 9, 1)
	_btn_web_host.pressed.connect(_on_web_host_pressed)
	web_row_a.add_child(_btn_web_host)

	_btn_web_join = Button.new()
	_btn_web_join.text = "Entrar com Código"
	_style_button(_btn_web_join, "#1B425C", "#24577A", "#143145", "#4EA8DE", Color("#E4F5FF"), p2p_fs, Vector2(154.0, p2p_h), 9, 1)
	_btn_web_join.pressed.connect(_on_web_join_pressed)
	web_row_a.add_child(_btn_web_join)

	_btn_web_copy = Button.new()
	_btn_web_copy.text = "Copiar Código"
	_btn_web_copy.visible = false
	_style_button(_btn_web_copy, "#3E351A", "#574A24", "#2B2411", "#F5D06F", Color("#FFF3C4"), p2p_fs, Vector2(134.0, p2p_h), 9, 1)
	_btn_web_copy.pressed.connect(_on_web_copy_code_pressed)
	web_row_a.add_child(_btn_web_copy)

	_btn_web_disconnect = Button.new()
	_btn_web_disconnect.text = "Desconectar"
	_btn_web_disconnect.visible = false
	_style_button(_btn_web_disconnect, "#592528", "#753135", "#401A1C", "#FF758F", Color("#FFE8E8"), p2p_fs, Vector2(124.0, p2p_h), 9, 1)
	_btn_web_disconnect.pressed.connect(_on_disconnect_pressed)
	web_row_a.add_child(_btn_web_disconnect)

	var web_row_b: HBoxContainer = HBoxContainer.new()
	web_row_b.add_theme_constant_override("separation", 8)
	web_row_b.alignment = BoxContainer.ALIGNMENT_CENTER
	web_vb.add_child(web_row_b)

	var sig_lbl: Label = Label.new()
	sig_lbl.text = "Sinalização WS:"
	sig_lbl.add_theme_font_size_override("font_size", roundi(12.0 * f_scale))
	sig_lbl.add_theme_color_override("font_color", Color("#9EC2D6"))
	web_row_b.add_child(sig_lbl)

	_web_sig_url_edit = LineEdit.new()
	_web_sig_url_edit.text = "ws://127.0.0.1:9080"
	_web_sig_url_edit.placeholder_text = "ws://127.0.0.1:9080 ou wss://seu-signaling"
	_web_sig_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_web_sig_url_edit.custom_minimum_size = Vector2(240.0, p2p_h - 4.0)
	_web_sig_url_edit.add_theme_font_size_override("font_size", roundi(12.0 * f_scale))
	web_row_b.add_child(_web_sig_url_edit)

	_btn_turn_toggle = Button.new()
	_btn_turn_toggle.text = "STUN / TURN ▾"
	_btn_turn_toggle.tooltip_text = "STUN público já está ativo por padrão; expanda para configurar servidor TURN opcional (CGNAT/NAT restrito)."
	_style_button(_btn_turn_toggle, "#1A2C38", "#243E4F", "#121F28", "#4B7A96", Color("#D3ECF9"), roundi(12.0 * f_scale), Vector2(132.0, p2p_h - 4.0), 8, 1)
	_btn_turn_toggle.pressed.connect(_on_turn_toggle_pressed)
	web_row_b.add_child(_btn_turn_toggle)

	_web_turn_row = HBoxContainer.new()
	_web_turn_row.visible = false
	_web_turn_row.add_theme_constant_override("separation", 8)
	_web_turn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	web_vb.add_child(_web_turn_row)

	_web_turn_url_edit = LineEdit.new()
	_web_turn_url_edit.placeholder_text = "TURN opcional: turn:host:3478 ou turns:host:5349"
	_web_turn_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_web_turn_url_edit.custom_minimum_size = Vector2(210.0, p2p_h - 4.0)
	_web_turn_url_edit.add_theme_font_size_override("font_size", roundi(12.0 * f_scale))
	_web_turn_row.add_child(_web_turn_url_edit)

	_web_turn_user_edit = LineEdit.new()
	_web_turn_user_edit.placeholder_text = "Usuário TURN"
	_web_turn_user_edit.custom_minimum_size = Vector2(130.0, p2p_h - 4.0)
	_web_turn_user_edit.add_theme_font_size_override("font_size", roundi(12.0 * f_scale))
	_web_turn_row.add_child(_web_turn_user_edit)

	_web_turn_pass_edit = LineEdit.new()
	_web_turn_pass_edit.placeholder_text = "Credencial TURN"
	_web_turn_pass_edit.secret = true
	_web_turn_pass_edit.custom_minimum_size = Vector2(130.0, p2p_h - 4.0)
	_web_turn_pass_edit.add_theme_font_size_override("font_size", roundi(12.0 * f_scale))
	_web_turn_row.add_child(_web_turn_pass_edit)

	_web_status_label = Label.new()
	_web_status_label.text = "WebRTC Estrela (Host + até 5 convidados = 6 estanceiros) • STUN público ativo por padrão."
	_web_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_web_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_web_status_label.add_theme_font_size_override("font_size", roundi(12.5 * f_scale))
	_web_status_label.add_theme_color_override("font_color", Color("#9ED8F5"))
	web_vb.add_child(_web_status_label)

	# --- Barra de Quantidade de Jogadores + Atalhos Rápidos (estilo Monopoly/Rento) ---
	var toolbar_panel: PanelContainer = PanelContainer.new()
	var tb_style: StyleBoxFlat = _make_box("#15221B", "#283D32", 12, 1)
	tb_style.content_margin_left = 16.0
	tb_style.content_margin_right = 16.0
	tb_style.content_margin_top = 10.0
	tb_style.content_margin_bottom = 10.0
	toolbar_panel.add_theme_stylebox_override("panel", tb_style)
	root_vbox.add_child(toolbar_panel)

	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar_panel.add_child(toolbar)

	var count_lbl: Label = Label.new()
	count_lbl.text = "Jogadores:"
	if _bold_font != null:
		count_lbl.add_theme_font_override("font", _bold_font)
	count_lbl.add_theme_font_size_override("font_size", roundi(15.0 * f_scale))
	count_lbl.add_theme_color_override("font_color", Color("#EDF5F0"))
	toolbar.add_child(count_lbl)

	_count_buttons.clear()
	for n: int in range(MIN_PLAYERS, MAX_PLAYERS + 1):
		var c_btn: Button = Button.new()
		c_btn.text = "%d" % n
		var target_n: int = n
		c_btn.pressed.connect(func() -> void: _set_player_count(target_n))
		toolbar.add_child(c_btn)
		_count_buttons.append(c_btn)

	var spacer_tb: Control = Control.new()
	spacer_tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer_tb)

	var quick_lbl: Label = Label.new()
	quick_lbl.text = "Início rápido:"
	quick_lbl.add_theme_font_size_override("font_size", roundi(13.0 * f_scale))
	quick_lbl.add_theme_color_override("font_color", Color("#9EB7A8"))
	toolbar.add_child(quick_lbl)

	var quick_presets: Array[Array] = [
		["Duelo 1v1", 2],
		["Mesa 4", 4],
		["Mesa 6", 6]
	]
	var q_h: float = 42.0 if _is_touch_mode else 34.0
	_quick_buttons.clear()
	for qp: Array in quick_presets:
		var q_btn: Button = Button.new()
		q_btn.text = str(qp[0])
		var q_count: int = int(qp[1])
		_style_button(q_btn, "#1B3429", "#25493A", "#14261E", "#4A7D65", Color("#E4F5EC"), roundi(12.5 * f_scale), Vector2(104.0, q_h), 9, 1)
		q_btn.pressed.connect(func() -> void: _apply_quick_solo_preset(q_count))
		toolbar.add_child(q_btn)
		_quick_buttons.append(q_btn)

	# --- Grade Visual de Cartões de Jogadores (2 colunas com rolagem de segurança) ---
	var slots_scroll: ScrollContainer = ScrollContainer.new()
	slots_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(slots_scroll)

	_cards_grid = GridContainer.new()
	_cards_grid.columns = 2
	_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_grid.add_theme_constant_override("h_separation", 14)
	_cards_grid.add_theme_constant_override("v_separation", 12)
	slots_scroll.add_child(_cards_grid)

	for i: int in range(MAX_PLAYERS):
		_slot_pawn_indices.append(i)
		_slot_color_indices.append(i)
		_slot_is_bot.append(i > 0)
		_slot_peer_ids.append(1 if i == 0 else 0)
		_slot_peer_statuses.append("connected")
		var card_panel: PanelContainer = _build_slot_card(i, f_scale, ctrl_h)
		_cards_grid.add_child(card_panel)
		_slot_rows.append(card_panel)

	_error_label = Label.new()
	_error_label.text = ""
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_font_size_override("font_size", roundi(14.0 * f_scale))
	_error_label.add_theme_color_override("font_color", Color("#FF758F"))
	root_vbox.add_child(_error_label)

	# --- Rodapé CTA ---
	var footer_row: HBoxContainer = HBoxContainer.new()
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(footer_row)

	_btn_start = Button.new()
	_btn_start.text = "Iniciar Partida"
	_style_button(
		_btn_start,
		"#E5BE52",
		"#F6D472",
		"#CCA53A",
		"#FFF2C6",
		Color("#101713"),
		roundi(19.0 * f_scale),
		Vector2(380.0 if _is_touch_mode else 340.0, 62.0 if _is_touch_mode else 52.0),
		12,
		2
	)
	_btn_start.pressed.connect(_on_start_pressed)
	footer_row.add_child(_btn_start)
	_refresh_mode_tabs()

func _build_slot_card(slot_idx: int, f_scale: float, ctrl_h: float) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style: StyleBoxFlat = _make_box("#16231C", "#2B4034", 12, 1)
	card_style.content_margin_left = 10.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_top = 10.0
	card_style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", card_style)

	var shell: HBoxContainer = HBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	card.add_child(shell)

	var init_color: Color = Color(str(COLOR_OPTIONS[slot_idx]["hex"]))

	# Barra de cor vertical
	var accent: Panel = Panel.new()
	accent.custom_minimum_size = Vector2(6.0, 0.0)
	accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var accent_style: StyleBoxFlat = StyleBoxFlat.new()
	accent_style.bg_color = init_color
	accent_style.set_corner_radius_all(3)
	accent.add_theme_stylebox_override("panel", accent_style)
	shell.add_child(accent)
	_slot_accent_styles.append(accent_style)

	# Medalhão clicável do peão gaúcho (mostra arte 256x256 real)
	var medal_size: float = 78.0 if _is_touch_mode else 68.0
	var medal_btn: Button = Button.new()
	medal_btn.custom_minimum_size = Vector2(medal_size, medal_size)
	medal_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	medal_btn.tooltip_text = "Toque ou clique para alternar o peão gaúcho"
	var medal_style: StyleBoxFlat = _make_box("#0E1712", str(COLOR_OPTIONS[slot_idx]["hex"]), 14, 3)
	medal_btn.add_theme_stylebox_override("normal", medal_style)
	medal_btn.add_theme_stylebox_override("hover", medal_style)
	medal_btn.add_theme_stylebox_override("pressed", medal_style)
	medal_btn.add_theme_stylebox_override("focus", medal_style)
	medal_btn.pressed.connect(func() -> void: _cycle_slot_pawn(slot_idx))
	shell.add_child(medal_btn)
	_slot_medal_styles.append(medal_style)

	var medal_margin: MarginContainer = MarginContainer.new()
	medal_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	medal_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal_margin.add_theme_constant_override("margin_left", 5)
	medal_margin.add_theme_constant_override("margin_right", 5)
	medal_margin.add_theme_constant_override("margin_top", 5)
	medal_margin.add_theme_constant_override("margin_bottom", 5)
	medal_btn.add_child(medal_margin)

	var medal_tex: TextureRect = TextureRect.new()
	medal_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	medal_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var init_pawn_id: String = str(PAWN_OPTIONS[slot_idx]["id"])
	if _pawn_textures.has(init_pawn_id):
		medal_tex.texture = _pawn_textures[init_pawn_id]
	medal_margin.add_child(medal_tex)
	_slot_medal_textures.append(medal_tex)

	# Conteúdo à direita do medalhão
	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	shell.add_child(content_vbox)

	# Linha A: Vaga + Nome + Botão Humano/Bot
	var row_a: HBoxContainer = HBoxContainer.new()
	row_a.add_theme_constant_override("separation", 8)
	row_a.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(row_a)

	var idx_lbl: Label = Label.new()
	idx_lbl.text = "#%d" % (slot_idx + 1)
	if _bold_font != null:
		idx_lbl.add_theme_font_override("font", _bold_font)
	idx_lbl.add_theme_font_size_override("font_size", roundi(15.0 * f_scale))
	idx_lbl.add_theme_color_override("font_color", Color("#F3C969"))
	row_a.add_child(idx_lbl)

	var name_edit: LineEdit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(140.0, ctrl_h)
	name_edit.add_theme_font_size_override("font_size", roundi(14.0 * f_scale))
	name_edit.placeholder_text = "Nome do estanceiro..."
	var name_style: StyleBoxFlat = _make_box("#0D1611", "#2E4639", 8, 1)
	name_style.content_margin_left = 10.0
	name_style.content_margin_right = 10.0
	name_edit.add_theme_stylebox_override("normal", name_style)
	name_edit.add_theme_stylebox_override("focus", _make_box("#101D16", "#D4AF37", 8, 2))
	if slot_idx > 0:
		name_edit.text = GENERIC_BOT_NAMES[slot_idx % GENERIC_BOT_NAMES.size()]
	else:
		name_edit.text = "Jogador 1"
	name_edit.max_length = 20
	name_edit.text_submitted.connect(func(_new_txt: String) -> void:
		_on_slot_name_committed(slot_idx)
		name_edit.release_focus()
	)
	name_edit.focus_exited.connect(func() -> void: _on_slot_name_committed(slot_idx))
	row_a.add_child(name_edit)
	_slot_name_edits.append(name_edit)

	var type_btn: Button = Button.new()
	type_btn.pressed.connect(func() -> void: _toggle_slot_type(slot_idx))
	row_a.add_child(type_btn)
	_slot_type_buttons.append(type_btn)
	_refresh_slot_type_button(slot_idx)

	# Linha B: Seletor de Peão + Paleta Tátil de Cores
	var row_b: HBoxContainer = HBoxContainer.new()
	row_b.add_theme_constant_override("separation", 8)
	row_b.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(row_b)

	var pawn_sel: OptionButton = OptionButton.new()
	pawn_sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pawn_sel.custom_minimum_size = Vector2(150.0, ctrl_h - 4.0)
	pawn_sel.clip_text = true
	pawn_sel.add_theme_font_size_override("font_size", roundi(13.0 * f_scale))
	for p_i: int in range(PAWN_OPTIONS.size()):
		var p_data: Dictionary = PAWN_OPTIONS[p_i]
		pawn_sel.add_item(str(p_data["name"]), p_i)
	pawn_sel.select(slot_idx)
	pawn_sel.item_selected.connect(func(item_idx: int) -> void: _on_slot_pawn_changed(slot_idx, item_idx))
	row_b.add_child(pawn_sel)
	_slot_pawn_selects.append(pawn_sel)

	var swatches_row: HBoxContainer = HBoxContainer.new()
	swatches_row.add_theme_constant_override("separation", 5)
	row_b.add_child(swatches_row)

	var slot_swatches: Array = []
	var sw_dim: float = 34.0 if _is_touch_mode else 28.0
	for c_i: int in range(COLOR_OPTIONS.size()):
		var sw_btn: Button = Button.new()
		sw_btn.custom_minimum_size = Vector2(sw_dim, sw_dim)
		sw_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		sw_btn.tooltip_text = str(COLOR_OPTIONS[c_i]["name"])
		var color_idx_ref: int = c_i
		sw_btn.pressed.connect(func() -> void: _on_slot_color_changed(slot_idx, color_idx_ref))
		swatches_row.add_child(sw_btn)
		slot_swatches.append(sw_btn)
	_slot_color_buttons.append(slot_swatches)
	_refresh_slot_color_visuals(slot_idx)

	return card

func _on_viewport_size_changed() -> void:
	if _main_card == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	var target_w: float = clampf(vp_size.x - 56.0, 960.0, 1540.0)
	var target_h: float = clampf(vp_size.y - 56.0, 620.0, 940.0)
	_main_card.custom_minimum_size = Vector2(target_w, target_h)
	if _cards_grid != null:
		if _profile_adapter != null:
			_cards_grid.columns = int(_profile_adapter.call("compute_setup_columns", vp_size.x))
		else:
			_cards_grid.columns = 1 if vp_size.x < 1080.0 else 2

func _set_player_count(new_count: int) -> void:
	if _net_mode == 2:
		return
	var min_allowed: int = maxi(MIN_PLAYERS, _connected_peers.size() if _net_mode == 1 else MIN_PLAYERS)
	_player_count = clampi(new_count, min_allowed, MAX_PLAYERS)
	_refresh_count_buttons()
	_refresh_visible_slots()
	_deduplicate_active_slot_choices()
	_refresh_exclusive_choices()
	if _net_mode == 1:
		lobby_config_changed.emit()

func _apply_quick_solo_preset(target_count: int) -> void:
	if _net_mode != 0:
		return
	_set_player_count(target_count)
	for i: int in range(MAX_PLAYERS):
		var want_bot: bool = (i > 0)
		if _slot_is_bot[i] != want_bot:
			_slot_is_bot[i] = want_bot
			_slot_peer_ids[i] = 0 if want_bot else 1
			_refresh_slot_type_button(i)
			var cur_name: String = _slot_name_edits[i].text.strip_edges()
			if want_bot and _is_default_human_name(cur_name):
				_slot_name_edits[i].text = _pick_unused_generic_bot_name(i)
			elif not want_bot and (cur_name == "" or _is_generic_bot_name(cur_name)):
				_slot_name_edits[i].text = "Jogador 1"

func _refresh_count_buttons() -> void:
	var f_scale: float = 1.18 if _is_touch_mode else 1.0
	var btn_sz: Vector2 = Vector2(58.0, 44.0) if _is_touch_mode else Vector2(48.0, 36.0)
	for i: int in range(_count_buttons.size()):
		var n: int = MIN_PLAYERS + i
		var active: bool = (n == _player_count)
		if active:
			_style_button(_count_buttons[i], "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), roundi(15.0 * f_scale), btn_sz, 9, 2)
		else:
			_style_button(_count_buttons[i], "#1D2E25", "#294034", "#15221B", "#375244", Color("#DCE8E0"), roundi(15.0 * f_scale), btn_sz, 9, 1)

func _refresh_visible_slots() -> void:
	for i: int in range(_slot_rows.size()):
		_slot_rows[i].visible = (i < _player_count)

func _refresh_slot_type_button(slot_idx: int) -> void:
	var f_scale: float = 1.18 if _is_touch_mode else 1.0
	var ctrl_h: float = 46.0 if _is_touch_mode else 38.0
	var btn: Button = _slot_type_buttons[slot_idx]
	var is_bot: bool = _slot_is_bot[slot_idx]
	var peer_id: int = _slot_peer_ids[slot_idx] if slot_idx < _slot_peer_ids.size() else 0
	var peer_status: String = _slot_peer_statuses[slot_idx] if slot_idx < _slot_peer_statuses.size() else "connected"
	if _net_mode != 0:
		if is_bot:
			btn.text = "[BOT]"
			_style_button(btn, "#1B3647", "#244960", "#132733", "#4EA8DE", Color("#D8F3FF"), roundi(12.5 * f_scale), Vector2(114.0, ctrl_h), 8, 1)
		elif peer_status == "connecting":
			btn.text = "Conectando..."
			_style_button(btn, "#423318", "#594520", "#2E2311", "#F3C969", Color("#FFF0B8"), roundi(11.5 * f_scale), Vector2(114.0, ctrl_h), 8, 1)
		elif peer_id == _local_peer_id:
			btn.text = "[VOCÊ • HOST]" if peer_id == 1 else "[VOCÊ]"
			_style_button(btn, "#205941", "#2B7556", "#163F2E", "#FFD166", Color("#FFF8D6"), roundi(11.5 * f_scale), Vector2(114.0, ctrl_h), 8, 2)
		elif peer_id == 1:
			btn.text = "[HOST]"
			_style_button(btn, "#1D4A38", "#27634B", "#143528", "#E9C46A", Color("#FFF3C4"), roundi(12.0 * f_scale), Vector2(114.0, ctrl_h), 8, 1)
		else:
			btn.text = "[ONLINE]"
			_style_button(btn, "#1D4A38", "#27634B", "#143528", "#52B788", Color("#E8FFF2"), roundi(12.0 * f_scale), Vector2(114.0, ctrl_h), 8, 1)
		btn.disabled = true
	else:
		btn.disabled = false
		if is_bot:
			btn.text = "Bot"
			_style_button(btn, "#1B3647", "#244960", "#132733", "#4EA8DE", Color("#D8F3FF"), roundi(13.0 * f_scale), Vector2(96.0, ctrl_h), 8, 1)
		else:
			btn.text = "Humano"
			_style_button(btn, "#1D4A38", "#27634B", "#143528", "#52B788", Color("#E8FFF2"), roundi(13.0 * f_scale), Vector2(96.0, ctrl_h), 8, 1)

func _refresh_slot_color_visuals(slot_idx: int) -> void:
	var sel_c: int = _slot_color_indices[slot_idx]
	var hex_str: String = str(COLOR_OPTIONS[sel_c]["hex"])
	var col: Color = Color(hex_str)
	_slot_accent_styles[slot_idx].bg_color = col
	_slot_medal_styles[slot_idx].border_color = col

	var swatches: Array = _slot_color_buttons[slot_idx]
	for c_i: int in range(swatches.size()):
		var sw_btn: Button = swatches[c_i] as Button
		var c_hex: String = str(COLOR_OPTIONS[c_i]["hex"])
		var is_selected: bool = (c_i == sel_c)
		var border_hex: String = "#FFFFFF" if is_selected else "#101914"
		var bw: int = 3 if is_selected else 1
		var sb: StyleBoxFlat = _make_box(c_hex, border_hex, 8, bw)
		sw_btn.add_theme_stylebox_override("normal", sb)
		sw_btn.add_theme_stylebox_override("hover", _make_box(c_hex, "#FFF2C6", 8, 2))
		sw_btn.add_theme_stylebox_override("pressed", sb)
		sw_btn.add_theme_stylebox_override("focus", sb)

func _refresh_slot_pawn_visual(slot_idx: int) -> void:
	var p_idx: int = clampi(_slot_pawn_indices[slot_idx], 0, PAWN_OPTIONS.size() - 1)
	var pid: String = str(PAWN_OPTIONS[p_idx]["id"])
	if _pawn_textures.has(pid):
		_slot_medal_textures[slot_idx].texture = _pawn_textures[pid]

func _is_default_human_name(name_text: String) -> bool:
	var trimmed: String = name_text.strip_edges()
	if trimmed == "":
		return true
	for i: int in range(1, MAX_PLAYERS + 1):
		if trimmed == "Jogador %d" % i or trimmed == "Gaudério %d" % i:
			return true
	return false

func _is_generic_bot_name(name_text: String) -> bool:
	var trimmed: String = name_text.strip_edges()
	return trimmed in GENERIC_BOT_NAMES

func _pick_unused_generic_bot_name(exclude_slot: int) -> String:
	var used_names: Array[String] = []
	for i: int in range(MAX_PLAYERS):
		if i == exclude_slot:
			continue
		used_names.append(_slot_name_edits[i].text.strip_edges())
	for candidate: String in GENERIC_BOT_NAMES:
		if not (candidate in used_names):
			return candidate
	return GENERIC_BOT_NAMES[exclude_slot % GENERIC_BOT_NAMES.size()]

func _toggle_slot_type(slot_idx: int) -> void:
	if _net_mode != 0:
		return
	var new_is_bot: bool = not _slot_is_bot[slot_idx]
	_slot_is_bot[slot_idx] = new_is_bot
	_slot_peer_ids[slot_idx] = 0 if new_is_bot else 1
	_refresh_slot_type_button(slot_idx)
	var current_name: String = _slot_name_edits[slot_idx].text.strip_edges()
	if new_is_bot:
		if _is_default_human_name(current_name):
			_slot_name_edits[slot_idx].text = _pick_unused_generic_bot_name(slot_idx)
	else:
		if current_name == "" or _is_generic_bot_name(current_name):
			_slot_name_edits[slot_idx].text = "Jogador %d" % (slot_idx + 1)

func _is_pawn_taken_by_other_active(slot_idx: int, pawn_idx: int) -> bool:
	for j: int in range(_player_count):
		if j != slot_idx and j < _slot_pawn_indices.size() and _slot_pawn_indices[j] == pawn_idx:
			return true
	return false

func _is_color_taken_by_other_active(slot_idx: int, color_idx: int) -> bool:
	for j: int in range(_player_count):
		if j != slot_idx and j < _slot_color_indices.size() and _slot_color_indices[j] == color_idx:
			return true
	return false

func _can_edit_slot_choices(slot_idx: int) -> bool:
	if _net_mode != 2:
		return true
	return slot_idx < _player_count and (not _slot_is_bot[slot_idx]) and (_slot_peer_ids[slot_idx] == _local_peer_id)

func _deduplicate_active_slot_choices() -> void:
	var used_pawns: Array[int] = []
	var used_colors: Array[int] = []
	for i: int in range(_player_count):
		if i < _slot_pawn_indices.size():
			var p_idx: int = _slot_pawn_indices[i]
			if p_idx in used_pawns:
				for alt_p: int in range(PAWN_OPTIONS.size()):
					if not (alt_p in used_pawns):
						_assign_unique_slot_value(_slot_pawn_indices, i, alt_p)
						p_idx = alt_p
						break
			used_pawns.append(p_idx)
		if i < _slot_color_indices.size():
			var c_idx: int = _slot_color_indices[i]
			if c_idx in used_colors:
				for alt_c: int in range(COLOR_OPTIONS.size()):
					if not (alt_c in used_colors):
						_assign_unique_slot_value(_slot_color_indices, i, alt_c)
						c_idx = alt_c
						break
			used_colors.append(c_idx)
	for i: int in range(MAX_PLAYERS):
		if i < _slot_pawn_selects.size():
			_slot_pawn_selects[i].select(_slot_pawn_indices[i])
		_refresh_slot_pawn_visual(i)
		_refresh_slot_color_visuals(i)

func _assign_unique_slot_value(arr: Array[int], slot_idx: int, new_val: int) -> void:
	var old_val: int = arr[slot_idx]
	if old_val == new_val:
		return
	for other_idx: int in range(arr.size()):
		if other_idx != slot_idx and arr[other_idx] == new_val:
			arr[other_idx] = old_val
			break
	arr[slot_idx] = new_val

func _refresh_exclusive_choices() -> void:
	var online: bool = (_net_mode != 0)
	for i: int in range(MAX_PLAYERS):
		var can_edit: bool = _can_edit_slot_choices(i)
		var pawn_sel: OptionButton = _slot_pawn_selects[i]
		pawn_sel.disabled = not can_edit
		for p_i: int in range(PAWN_OPTIONS.size()):
			var base_name: String = str(PAWN_OPTIONS[p_i]["name"])
			var taken: bool = online and _is_pawn_taken_by_other_active(i, p_i)
			pawn_sel.set_item_disabled(p_i, taken)
			pawn_sel.set_item_text(p_i, ("%s (em uso)" % base_name) if taken else base_name)

		var swatches: Array = _slot_color_buttons[i]
		for c_i: int in range(swatches.size()):
			var sw_btn: Button = swatches[c_i] as Button
			var c_name: String = str(COLOR_OPTIONS[c_i]["name"])
			var taken_c: bool = online and _is_color_taken_by_other_active(i, c_i)
			sw_btn.disabled = (not can_edit) or taken_c
			sw_btn.modulate = Color(0.45, 0.45, 0.45, 0.48) if taken_c else Color.WHITE
			sw_btn.tooltip_text = ("%s (em uso)" % c_name) if taken_c else c_name

func _cycle_slot_pawn(slot_idx: int) -> void:
	if _net_mode == 2 and not _can_edit_slot_choices(slot_idx):
		return
	for step: int in range(1, PAWN_OPTIONS.size() + 1):
		var candidate: int = (_slot_pawn_indices[slot_idx] + step) % PAWN_OPTIONS.size()
		if _net_mode != 0 and _is_pawn_taken_by_other_active(slot_idx, candidate):
			continue
		_slot_pawn_selects[slot_idx].select(candidate)
		_on_slot_pawn_changed(slot_idx, candidate)
		return

func _sanitize_lobby_name(raw_name: String, fallback: String) -> String:
	var clean: String = raw_name.strip_edges()
	if clean == "":
		return fallback
	if clean.length() > 20:
		clean = clean.substr(0, 20)
	return clean

func _on_slot_name_committed(slot_idx: int) -> void:
	if _updating_slots or slot_idx < 0 or slot_idx >= _slot_name_edits.size():
		return
	var fallback: String = _pick_unused_generic_bot_name(slot_idx) if _slot_is_bot[slot_idx] else ("Jogador %d" % (slot_idx + 1))
	var clean: String = _sanitize_lobby_name(_slot_name_edits[slot_idx].text, fallback)
	_slot_name_edits[slot_idx].text = clean
	if _net_mode == 2:
		if not _can_edit_slot_choices(slot_idx):
			return
		lobby_slot_pref_requested.emit(_slot_pawn_indices[slot_idx], _slot_color_indices[slot_idx], clean)
	elif _net_mode == 1:
		if slot_idx == 0 and _p2p_name_edit != null:
			_p2p_name_edit.text = clean
		if slot_idx == 0 and _web_name_edit != null:
			_web_name_edit.text = clean
		lobby_config_changed.emit()

func _on_slot_pawn_changed(slot_idx: int, new_pawn_idx: int) -> void:
	if _updating_slots:
		return
	var clamped_p: int = clampi(new_pawn_idx, 0, PAWN_OPTIONS.size() - 1)
	if _net_mode == 2:
		if not _can_edit_slot_choices(slot_idx) or _is_pawn_taken_by_other_active(slot_idx, clamped_p):
			_updating_slots = true
			_slot_pawn_selects[slot_idx].select(_slot_pawn_indices[slot_idx])
			_updating_slots = false
			return
		_updating_slots = true
		_slot_pawn_indices[slot_idx] = clamped_p
		_refresh_slot_pawn_visual(slot_idx)
		_refresh_exclusive_choices()
		_updating_slots = false
		var cur_n: String = _slot_name_edits[slot_idx].text.strip_edges() if slot_idx < _slot_name_edits.size() else ""
		lobby_slot_pref_requested.emit(clamped_p, _slot_color_indices[slot_idx], cur_n)
		return

	if _net_mode == 1 and _is_pawn_taken_by_other_active(slot_idx, clamped_p):
		_updating_slots = true
		_slot_pawn_selects[slot_idx].select(_slot_pawn_indices[slot_idx])
		_updating_slots = false
		return

	var old_pawn_idx: int = _slot_pawn_indices[slot_idx]
	if old_pawn_idx == clamped_p:
		return

	_updating_slots = true
	for other_idx: int in range(MAX_PLAYERS):
		if other_idx != slot_idx and _slot_pawn_indices[other_idx] == clamped_p:
			_slot_pawn_indices[other_idx] = old_pawn_idx
			_slot_pawn_selects[other_idx].select(old_pawn_idx)
			_refresh_slot_pawn_visual(other_idx)
			break
	_slot_pawn_indices[slot_idx] = clamped_p
	_refresh_slot_pawn_visual(slot_idx)
	_refresh_exclusive_choices()
	_updating_slots = false
	if _net_mode == 1:
		lobby_config_changed.emit()

func _on_slot_color_changed(slot_idx: int, new_color_idx: int) -> void:
	if _updating_slots:
		return
	var clamped_c: int = clampi(new_color_idx, 0, COLOR_OPTIONS.size() - 1)
	if _net_mode == 2:
		if not _can_edit_slot_choices(slot_idx) or _is_color_taken_by_other_active(slot_idx, clamped_c):
			return
		_updating_slots = true
		_slot_color_indices[slot_idx] = clamped_c
		_refresh_slot_color_visuals(slot_idx)
		_refresh_exclusive_choices()
		_updating_slots = false
		var cur_nc: String = _slot_name_edits[slot_idx].text.strip_edges() if slot_idx < _slot_name_edits.size() else ""
		lobby_slot_pref_requested.emit(_slot_pawn_indices[slot_idx], clamped_c, cur_nc)
		return

	if _net_mode == 1 and _is_color_taken_by_other_active(slot_idx, clamped_c):
		return

	var old_color_idx: int = _slot_color_indices[slot_idx]
	if old_color_idx == clamped_c:
		return

	_updating_slots = true
	for other_idx: int in range(MAX_PLAYERS):
		if other_idx != slot_idx and _slot_color_indices[other_idx] == clamped_c:
			_slot_color_indices[other_idx] = old_color_idx
			_refresh_slot_color_visuals(other_idx)
			break
	_slot_color_indices[slot_idx] = clamped_c
	_refresh_slot_color_visuals(slot_idx)
	_refresh_exclusive_choices()
	_updating_slots = false
	if _net_mode == 1:
		lobby_config_changed.emit()

func apply_remote_peer_selection(sender_peer_id: int, pawn_idx: int, color_idx: int, player_name: String = "") -> bool:
	if _net_mode != 1:
		return false
	var target_slot: int = -1
	for i: int in range(_player_count):
		if not _slot_is_bot[i] and _slot_peer_ids[i] == sender_peer_id:
			target_slot = i
			break
	if target_slot < 0:
		return false

	var changed: bool = false
	var safe_p: int = clampi(pawn_idx, 0, PAWN_OPTIONS.size() - 1)
	var safe_c: int = clampi(color_idx, 0, COLOR_OPTIONS.size() - 1)
	_updating_slots = true
	if safe_p != _slot_pawn_indices[target_slot] and not _is_pawn_taken_by_other_active(target_slot, safe_p):
		_assign_unique_slot_value(_slot_pawn_indices, target_slot, safe_p)
		_slot_pawn_selects[target_slot].select(safe_p)
		_refresh_slot_pawn_visual(target_slot)
		changed = true
	if safe_c != _slot_color_indices[target_slot] and not _is_color_taken_by_other_active(target_slot, safe_c):
		_assign_unique_slot_value(_slot_color_indices, target_slot, safe_c)
		_refresh_slot_color_visuals(target_slot)
		changed = true
	var clean_name: String = player_name.strip_edges()
	if clean_name != "":
		if clean_name.length() > 20:
			clean_name = clean_name.substr(0, 20)
		if target_slot < _slot_name_edits.size() and _slot_name_edits[target_slot].text != clean_name:
			_slot_name_edits[target_slot].text = clean_name
			changed = true
	_refresh_exclusive_choices()
	_updating_slots = false
	return changed

func _on_start_pressed() -> void:
	if _net_mode == 2:
		return
	var configs: Array[Dictionary] = []
	var used_pawns: Array[String] = []

	for i: int in range(_player_count):
		var is_bot: bool = _slot_is_bot[i]
		var peer_id: int = 0 if is_bot else (_slot_peer_ids[i] if i < _slot_peer_ids.size() else 1)
		var player_name: String = _slot_name_edits[i].text.strip_edges()
		if player_name == "":
			player_name = _pick_unused_generic_bot_name(i) if is_bot else ("Jogador %d" % (i + 1))
			_slot_name_edits[i].text = player_name

		var pawn_idx: int = clampi(_slot_pawn_indices[i], 0, PAWN_OPTIONS.size() - 1)
		var pawn_data: Dictionary = PAWN_OPTIONS[pawn_idx]
		var pawn_id: String = str(pawn_data["id"])
		if pawn_id in used_pawns:
			_error_label.text = "Cada jogador ativo deve escolher um peão gaúcho exclusivo."
			return
		used_pawns.append(pawn_id)

		var color_idx: int = clampi(_slot_color_indices[i], 0, COLOR_OPTIONS.size() - 1)
		var color_hex: String = str(COLOR_OPTIONS[color_idx]["hex"])

		configs.append({
			"name": player_name,
			"is_bot": is_bot,
			"peer_id": peer_id,
			"pawn_id": pawn_id,
			"pawn_name": str(pawn_data["name"]),
			"pawn_code": str(pawn_data["code"]),
			"color_hex": color_hex
		})

	if _net_mode == 1:
		for i: int in range(_player_count):
			if not _slot_is_bot[i] and i < _slot_peer_statuses.size() and _slot_peer_statuses[i] == "connecting":
				_error_label.text = "Aguarde os convidados concluírem a conexão WebRTC antes de iniciar."
				return

	_error_label.text = ""
	close_screen()
	start_match_requested.emit(configs)

# --- Controle de UI P2P (Local | P2P LAN ENet | Multiplayer Web WebRTC) ---

func _set_mode_tab(target_tab: int) -> void:
	if target_tab == MODE_TAB_ENET and OS.has_feature("web"):
		return
	if target_tab != _active_mode_tab and _net_mode != 0:
		disconnect_network_requested.emit()
	_active_mode_tab = target_tab
	_refresh_mode_tabs()

func _refresh_mode_tabs() -> void:
	var f_scale: float = 1.18 if _is_touch_mode else 1.0
	var tab_h: float = 42.0 if _is_touch_mode else 36.0
	var tab_fs: int = roundi(13.0 * f_scale)
	if _btn_mode_local != null:
		if _active_mode_tab == MODE_TAB_LOCAL:
			_style_button(_btn_mode_local, "#234938", "#2C5C47", "#1A372A", "#E9C46A", Color("#FFF6D6"), tab_fs, Vector2(210.0, tab_h), 9, 2)
		else:
			_style_button(_btn_mode_local, "#15211B", "#1E2E26", "#101914", "#2B4035", Color("#A7BDB0"), tab_fs, Vector2(210.0, tab_h), 9, 1)
	if _btn_mode_p2p != null:
		if _active_mode_tab == MODE_TAB_ENET:
			_style_button(_btn_mode_p2p, "#1B4236", "#255949", "#132E26", "#52B788", Color("#E8FFF2"), tab_fs, Vector2(215.0, tab_h), 9, 2)
		else:
			_style_button(_btn_mode_p2p, "#15211B", "#1E2E26", "#101914", "#2B4035", Color("#A7BDB0"), tab_fs, Vector2(215.0, tab_h), 9, 1)
	if _btn_mode_web != null:
		if _active_mode_tab == MODE_TAB_WEBRTC:
			_style_button(_btn_mode_web, "#1A3E4C", "#235366", "#132D38", "#4EA8DE", Color("#E4F6FF"), tab_fs, Vector2(230.0, tab_h), 9, 2)
		else:
			_style_button(_btn_mode_web, "#15211B", "#1E2E26", "#101914", "#2B4035", Color("#A7BDB0"), tab_fs, Vector2(230.0, tab_h), 9, 1)
	if _p2p_panel != null:
		_p2p_panel.visible = (_active_mode_tab == MODE_TAB_ENET)
	if _web_panel != null:
		_web_panel.visible = (_active_mode_tab == MODE_TAB_WEBRTC)

func _parse_p2p_port() -> int:
	var raw: String = _p2p_port_edit.text.strip_edges() if _p2p_port_edit != null else "7777"
	if not raw.is_valid_int():
		return 7777
	return clampi(int(raw), 1024, 65535)

func _collect_turn_config() -> Dictionary:
	return {
		"url": _web_turn_url_edit.text.strip_edges() if _web_turn_url_edit != null else "",
		"username": _web_turn_user_edit.text.strip_edges() if _web_turn_user_edit != null else "",
		"credential": _web_turn_pass_edit.text.strip_edges() if _web_turn_pass_edit != null else ""
	}

func _on_host_pressed() -> void:
	_error_label.text = ""
	var pname: String = _p2p_name_edit.text.strip_edges() if _p2p_name_edit != null else "Anfitrião"
	if pname == "":
		pname = "Anfitrião"
		if _p2p_name_edit != null:
			_p2p_name_edit.text = pname
	var port: int = _parse_p2p_port()
	if _p2p_port_edit != null:
		_p2p_port_edit.text = str(port)
	host_room_requested.emit(port, pname)

func _on_join_pressed() -> void:
	_error_label.text = ""
	var pname: String = _p2p_name_edit.text.strip_edges() if _p2p_name_edit != null else "Estanceiro"
	if pname == "":
		pname = "Estanceiro"
		if _p2p_name_edit != null:
			_p2p_name_edit.text = pname
	var ip_str: String = _p2p_ip_edit.text.strip_edges() if _p2p_ip_edit != null else "127.0.0.1"
	if ip_str == "":
		ip_str = "127.0.0.1"
		if _p2p_ip_edit != null:
			_p2p_ip_edit.text = ip_str
	var port: int = _parse_p2p_port()
	if _p2p_port_edit != null:
		_p2p_port_edit.text = str(port)
	join_room_requested.emit(ip_str, port, pname)

func _on_web_host_pressed() -> void:
	_error_label.text = ""
	var pname: String = _web_name_edit.text.strip_edges() if _web_name_edit != null else "Anfitrião"
	if pname == "":
		pname = "Anfitrião"
		if _web_name_edit != null:
			_web_name_edit.text = pname
	var sig_url: String = _web_sig_url_edit.text.strip_edges() if _web_sig_url_edit != null else "ws://127.0.0.1:9080"
	if sig_url == "":
		sig_url = "ws://127.0.0.1:9080"
		if _web_sig_url_edit != null:
			_web_sig_url_edit.text = sig_url
	host_web_room_requested.emit(sig_url, pname, _collect_turn_config())

func _on_web_join_pressed() -> void:
	_error_label.text = ""
	var pname: String = _web_name_edit.text.strip_edges() if _web_name_edit != null else "Estanceiro"
	if pname == "":
		pname = "Estanceiro"
		if _web_name_edit != null:
			_web_name_edit.text = pname
	var code: String = _web_code_edit.text.strip_edges().to_upper() if _web_code_edit != null else ""
	if _web_code_edit != null:
		_web_code_edit.text = code
	if code.length() < 4:
		show_network_error("Digite o Código da Sala compartilhado pelo Host (ex.: P7K4M2).")
		return
	var sig_url: String = _web_sig_url_edit.text.strip_edges() if _web_sig_url_edit != null else "ws://127.0.0.1:9080"
	if sig_url == "":
		sig_url = "ws://127.0.0.1:9080"
		if _web_sig_url_edit != null:
			_web_sig_url_edit.text = sig_url
	join_web_room_requested.emit(sig_url, code, pname, _collect_turn_config())

func _on_web_copy_code_pressed() -> void:
	if _web_room_code == "":
		return
	DisplayServer.clipboard_set(_web_room_code)
	if _btn_web_copy != null:
		_btn_web_copy.text = "Copiado!"
	if _web_status_label != null:
		_web_status_label.text = "Código %s copiado! Envie para até 5 convidados entrarem na mesa." % _web_room_code
		_web_status_label.add_theme_color_override("font_color", Color("#F5D06F"))

func _on_turn_toggle_pressed() -> void:
	if _web_turn_row == null:
		return
	_web_turn_row.visible = not _web_turn_row.visible
	if _btn_turn_toggle != null:
		_btn_turn_toggle.text = "STUN / TURN ▴" if _web_turn_row.visible else "STUN / TURN ▾"

func _on_disconnect_pressed() -> void:
	_error_label.text = ""
	disconnect_network_requested.emit()

func set_web_room_code(room_code: String) -> void:
	_web_room_code = room_code.strip_edges().to_upper()
	if _web_code_edit != null and _web_room_code != "":
		_web_code_edit.text = _web_room_code
	if _btn_web_copy != null:
		_btn_web_copy.visible = (_web_room_code != "")
		_btn_web_copy.text = "Copiar Código"

func show_network_error(message: String) -> void:
	if _error_label != null:
		_error_label.text = message
	if _p2p_status_label != null and message != "" and _active_mode_tab == MODE_TAB_ENET:
		_p2p_status_label.text = message
		_p2p_status_label.add_theme_color_override("font_color", Color("#FF9999"))
	if _web_status_label != null and message != "" and _active_mode_tab == MODE_TAB_WEBRTC:
		_web_status_label.text = message
		_web_status_label.add_theme_color_override("font_color", Color("#FF9999"))

func set_network_status(mode: int, status_text: String, connected_peers: Array[Dictionary], local_peer_id: int, transport_mode: int = 0) -> void:
	_net_mode = mode
	_net_transport = transport_mode
	_local_peer_id = local_peer_id
	_connected_peers = connected_peers.duplicate(true)
	if mode != 0:
		if transport_mode == 2:
			_active_mode_tab = MODE_TAB_WEBRTC
		elif transport_mode == 1:
			_active_mode_tab = MODE_TAB_ENET
	_refresh_mode_tabs()

	var st_col: Color = Color("#9FD9BE")
	if mode == 1:
		st_col = Color("#7BF1A8")
	elif mode == 2:
		st_col = Color("#8CE0FF")

	if _p2p_status_label != null and (_active_mode_tab == MODE_TAB_ENET or mode == 0):
		_p2p_status_label.text = status_text
		_p2p_status_label.add_theme_color_override("font_color", st_col)
	if _web_status_label != null and (_active_mode_tab == MODE_TAB_WEBRTC or mode == 0):
		_web_status_label.text = status_text
		_web_status_label.add_theme_color_override("font_color", st_col)

	var is_online: bool = (mode != 0)
	if _btn_host != null:
		_btn_host.visible = not is_online
	if _btn_join != null:
		_btn_join.visible = not is_online
	if _btn_disconnect != null:
		_btn_disconnect.visible = is_online
	if _p2p_name_edit != null:
		_p2p_name_edit.editable = not is_online
	if _p2p_ip_edit != null:
		_p2p_ip_edit.editable = not is_online
	if _p2p_port_edit != null:
		_p2p_port_edit.editable = not is_online

	if _btn_web_host != null:
		_btn_web_host.visible = not is_online
	if _btn_web_join != null:
		_btn_web_join.visible = not is_online
	if _btn_web_disconnect != null:
		_btn_web_disconnect.visible = is_online
	if _btn_web_copy != null:
		_btn_web_copy.visible = is_online and _web_room_code != ""
	if _web_name_edit != null:
		_web_name_edit.editable = not is_online
	if _web_code_edit != null:
		_web_code_edit.editable = not is_online
	if _web_sig_url_edit != null:
		_web_sig_url_edit.editable = not is_online
	if _web_turn_url_edit != null:
		_web_turn_url_edit.editable = not is_online
	if _web_turn_user_edit != null:
		_web_turn_user_edit.editable = not is_online
	if _web_turn_pass_edit != null:
		_web_turn_pass_edit.editable = not is_online

	for qb: Button in _quick_buttons:
		qb.disabled = is_online

	if mode == 1:
		_sync_host_slots_with_peers()
	elif mode == 0:
		_web_room_code = ""
		if _btn_web_copy != null:
			_btn_web_copy.visible = false
		for i: int in range(MAX_PLAYERS):
			_slot_peer_ids[i] = 0 if _slot_is_bot[i] else 1
			if i < _slot_peer_statuses.size():
				_slot_peer_statuses[i] = "connected"
			_slot_name_edits[i].editable = true
			_slot_pawn_selects[i].disabled = false
			for sw_var: Variant in _slot_color_buttons[i]:
				(sw_var as Button).disabled = false
			_refresh_slot_type_button(i)
		for cb: Button in _count_buttons:
			cb.disabled = false
		_refresh_exclusive_choices()

	_refresh_start_cta_for_network()

func _sync_host_slots_with_peers() -> void:
	var peer_count: int = mini(MAX_PLAYERS, _connected_peers.size())
	if peer_count > _player_count:
		_player_count = clampi(peer_count, MIN_PLAYERS, MAX_PLAYERS)
	_refresh_count_buttons()
	_refresh_visible_slots()

	for i: int in range(MAX_PLAYERS):
		if i < peer_count:
			var pd: Dictionary = _connected_peers[i]
			_slot_is_bot[i] = false
			_slot_peer_ids[i] = int(pd.get("peer_id", 1))
			if i < _slot_peer_statuses.size():
				_slot_peer_statuses[i] = str(pd.get("status", "connected"))
			if not _slot_name_edits[i].has_focus():
				_slot_name_edits[i].text = str(pd.get("name", "Jogador %d" % (i + 1)))
			_slot_name_edits[i].editable = (i == 0)
		else:
			_slot_is_bot[i] = true
			_slot_peer_ids[i] = 0
			if i < _slot_peer_statuses.size():
				_slot_peer_statuses[i] = "connected"
			var cur_n: String = _slot_name_edits[i].text.strip_edges()
			if cur_n == "" or _is_default_human_name(cur_n):
				_slot_name_edits[i].text = _pick_unused_generic_bot_name(i)
			_slot_name_edits[i].editable = true
		_refresh_slot_type_button(i)

	_deduplicate_active_slot_choices()
	_refresh_exclusive_choices()

	for idx: int in range(_count_buttons.size()):
		var n: int = MIN_PLAYERS + idx
		_count_buttons[idx].disabled = (n < peer_count)

func _refresh_start_cta_for_network() -> void:
	if _btn_start == null:
		return
	if _net_mode == 2:
		_btn_start.text = "Aguardando Host iniciar..."
		_btn_start.disabled = true
	elif _net_mode == 1:
		_btn_start.text = "Iniciar Partida Web" if _net_transport == 2 else "Iniciar Partida Online"
		_btn_start.disabled = false
	else:
		_btn_start.text = "Iniciar Partida"
		_btn_start.disabled = false

func get_lobby_snapshot_for_network() -> Dictionary:
	var slots: Array[Dictionary] = []
	for i: int in range(_player_count):
		slots.append({
			"name": _slot_name_edits[i].text.strip_edges(),
			"is_bot": _slot_is_bot[i],
			"peer_id": _slot_peer_ids[i],
			"status": _slot_peer_statuses[i] if i < _slot_peer_statuses.size() else "connected",
			"pawn_idx": _slot_pawn_indices[i],
			"color_idx": _slot_color_indices[i]
		})
	return {
		"player_count": _player_count,
		"room_code": _web_room_code,
		"slots": slots
	}

func apply_remote_lobby_snapshot(lobby_data: Dictionary, local_peer_id: int) -> void:
	_local_peer_id = local_peer_id
	_updating_slots = true
	var synced_code: String = str(lobby_data.get("room_code", "")).strip_edges().to_upper()
	if synced_code != "":
		set_web_room_code(synced_code)
	_player_count = clampi(int(lobby_data.get("player_count", 2)), MIN_PLAYERS, MAX_PLAYERS)
	_refresh_count_buttons()
	_refresh_visible_slots()
	for cb: Button in _count_buttons:
		cb.disabled = true

	var raw_slots: Variant = lobby_data.get("slots", [])
	if raw_slots is Array:
		var s_arr: Array = raw_slots
		for i: int in range(mini(MAX_PLAYERS, s_arr.size())):
			if not (s_arr[i] is Dictionary):
				continue
			var sd: Dictionary = s_arr[i]
			_slot_is_bot[i] = bool(sd.get("is_bot", true))
			_slot_peer_ids[i] = int(sd.get("peer_id", 0))
			if i < _slot_peer_statuses.size():
				_slot_peer_statuses[i] = str(sd.get("status", "connected"))
			var is_my_client_slot: bool = (not _slot_is_bot[i]) and (_slot_peer_ids[i] == _local_peer_id)
			if not _slot_name_edits[i].has_focus():
				_slot_name_edits[i].text = str(sd.get("name", "Estanceiro"))
			_slot_name_edits[i].editable = is_my_client_slot
			var p_idx: int = clampi(int(sd.get("pawn_idx", i)), 0, PAWN_OPTIONS.size() - 1)
			var c_idx: int = clampi(int(sd.get("color_idx", i)), 0, COLOR_OPTIONS.size() - 1)
			_slot_pawn_indices[i] = p_idx
			_slot_color_indices[i] = c_idx
			_slot_pawn_selects[i].select(p_idx)
			_refresh_slot_pawn_visual(i)
			_refresh_slot_color_visuals(i)
			_refresh_slot_type_button(i)
	_refresh_exclusive_choices()
	_updating_slots = false
	_refresh_start_cta_for_network()

func get_version_badge_text() -> String:
	if _version_badge_label != null:
		return _version_badge_label.text
	return "Build %s" % BuildInfoClass.get_display_version(_version_info)

func _check_for_updates_async() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var repo: String = str(_version_info.get("github_repo", "")).strip_edges()
	if repo == "" or not repo.contains("/"):
		return
	if _update_http == null:
		_update_http = HTTPRequest.new()
		_update_http.timeout = 6.0
		_update_http.request_completed.connect(_on_update_http_completed)
		add_child(_update_http)
	var api_url: String = "https://api.github.com/repos/%s/releases/latest" % repo
	var headers: PackedStringArray = PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: MagnataDoPampaGame"
	])
	_update_http.request(api_url, headers)

func _on_update_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var cur_ver: String = str(_version_info.get("version", "0.8.0"))
	var cur_build: int = int(_version_info.get("build_number", 0))
	var rel: Dictionary = BuildInfoClass.parse_github_release_payload(parsed as Dictionary, cur_ver, cur_build)
	if not bool(rel.get("has_update", false)):
		return
	var rem_ver: String = str(rel.get("version", ""))
	var target_url: String = str(rel.get("html_url", ""))
	if OS.get_name() == "Android":
		var apk_d: Variant = rel.get("android_apk_asset", {})
		if apk_d is Dictionary and str((apk_d as Dictionary).get("download_url", "")) != "":
			target_url = str((apk_d as Dictionary).get("download_url", ""))
	if target_url == "":
		return
	_update_target_url = target_url
	if _update_pill_btn != null:
		_update_pill_btn.text = "Nova v%s disponível ↗" % rem_ver
		_update_pill_btn.visible = true

func _on_update_pill_pressed() -> void:
	if _update_target_url != "":
		OS.shell_open(_update_target_url)
