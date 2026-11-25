extends CanvasLayer

signal roll_pressed
signal buy_pressed
signal decline_buy_pressed
signal bail_pressed
signal use_jail_card_pressed
signal property_selected(tile_index: int)
signal build_pressed(tile_index: int)
signal sell_building_pressed(tile_index: int)
signal mortgage_pressed(tile_index: int)
signal end_turn_pressed
signal trade_executed(target_id: int, offer_tile: int, request_tile: int, cash_delta: int)
signal menu_requested
signal restart_match_requested
signal camera_toggle_requested
signal camera_follow_toggle_requested
signal camera_reset_requested
signal inspect_tile_requested(tile_index: int)
signal player_inspected(player_id: int)
signal board_layout_updated(board_rect: Rect2)
signal settings_updated(settings_data: Dictionary)
signal chance_card_dismissed

const STATUS_BG_DEFAULT: Color = Color("#15251D")
const STATUS_BORDER_DEFAULT: Color = Color("#D4AF37")

const TAB_PLAYERS: int = 0
const TAB_DEEDS: int = 1
const TAB_LOG: int = 2

var _is_touch_mode: bool = false
var _bold_font: SystemFont = null
var _pawn_textures: Dictionary[String, Texture2D] = {}
var _feedback_tween: Tween = null

# Raiz de HUD da partida + Camada de Modais (acima do SetupScreen)
var _hud_root: Control
var _modal_layer: CanvasLayer

# Barra flutuante sobre o tabuleiro + Toast não-bloqueante de eventos
var _board_quick_bar: PanelContainer
var _btn_camera: Button
var _btn_cam_follow: Button
var _btn_cam_reset: Button
var _btn_help: Button
var _btn_settings: Button
var _btn_pause: Button
var _toast_panel: PanelContainer
var _toast_style: StyleBoxFlat
var _toast_title_label: Label
var _toast_detail_label: Label
var _toast_tween: Tween = null
var _cached_cam_follow: bool = true

# Painel Lateral Direito Responsivo
var _side_panel: PanelContainer
var _status_card: PanelContainer
var _status_card_style: StyleBoxFlat
var _hero_accent_style: StyleBoxFlat
var _hero_avatar_frame_style: StyleBoxFlat
var _hero_avatar_tex: TextureRect
var _hero_name_label: Label
var _hero_money_label: Label
var _hero_phase_badge_style: StyleBoxFlat
var _hero_phase_label: Label
var _hero_pawn_name_label: Label
var _round_badge: PanelContainer
var _round_badge_style: StyleBoxFlat
var _round_label: Label
var _bank_label: Label
var _tile_info_label: Label

# Abas centrais (Estanceiros | Escrituras | Diário)
var _active_tab: int = TAB_PLAYERS
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[Control] = []
var _players_box: VBoxContainer
var _ticker_panel: PanelContainer
var _ticker_scroll: ScrollContainer
var _ticker_hdr_label: Label
var _ticker_label: Label
var _deeds_list_box: VBoxContainer
var _deeds_empty_label: Label
var _deeds_action_box: VBoxContainer
var _btn_build: Button
var _btn_sell_building: Button
var _btn_mortgage: Button
var _btn_inspect_selected: Button
var _log_label: Label
var _log_scroll: ScrollContainer

# Dock Contextual Inferior
var _dock_card: PanelContainer
var _bot_banner: PanelContainer
var _bot_banner_label: Label
var _human_dock_vbox: VBoxContainer
var _jail_row: HBoxContainer
var _btn_bail: Button
var _btn_jail_card: Button
var _primary_action_row: HBoxContainer
var _btn_roll: Button
var _btn_buy: Button
var _btn_decline: Button
var _btn_end_turn: Button
var _secondary_action_row: HBoxContainer
var _btn_trade_open: Button
var _btn_deeds_jump: Button

# Modais dedicados (layer 20)
var _deed_overlay: Control
var _deed_banner: PanelContainer
var _deed_title_label: Label
var _deed_group_label: Label
var _deed_body_box: VBoxContainer

var _trade_overlay: Control
var _trade_target_select: OptionButton
var _trade_offer_select: OptionButton
var _trade_request_select: OptionButton
var _trade_cash_label: Label
var _trade_summary_label: Label
var _trade_cash_value: int = 0

var _pause_overlay: Control
var _pause_restart_btn: Button
var _pause_menu_btn: Button
var _help_overlay: Control

var _victory_overlay: Control
var _victory_banner: PanelContainer
var _victory_title_label: Label
var _victory_subtitle_label: Label
var _victory_pawn_frame: PanelContainer
var _victory_pawn_tex: TextureRect
var _victory_pawn_name_label: Label
var _victory_stats_box: VBoxContainer
var _victory_replay_btn: Button

# Estado de identidade Multiplayer P2P (ENet LAN / WebRTC Web)
var _net_is_online: bool = false
var _net_is_host: bool = false
var _net_local_peer_id: int = 0
var _net_local_player_id: int = -1
var _net_wait_text: String = ""
var _net_transport_label: String = "ONLINE"
var _net_room_code: String = ""
var _net_identity_bar: PanelContainer
var _net_identity_style: StyleBoxFlat
var _net_identity_label: Label

var _chance_overlay: Control
var _chance_card: PanelContainer
var _chance_player_label: Label
var _chance_effect_badge: PanelContainer
var _chance_effect_badge_style: StyleBoxFlat
var _chance_effect_label: Label
var _chance_text_label: Label
var _chance_hint_label: Label
var _chance_close_btn: Button
var _chance_anim_tween: Tween = null
var _chance_timer_token: int = 0
var _chance_is_active: bool = false

var _portfolio_overlay: Control
var _portfolio_card: PanelContainer
var _portfolio_scroll: ScrollContainer
var _portfolio_banner: PanelContainer
var _portfolio_avatar_frame: PanelContainer
var _portfolio_avatar_tex: TextureRect
var _portfolio_name_label: Label
var _portfolio_meta_label: Label
var _portfolio_money_label: Label
var _portfolio_monopoly_wrap: VBoxContainer
var _portfolio_monopoly_box: HFlowContainer
var _portfolio_list_box: VBoxContainer
var _portfolio_empty_label: Label

var _settings_overlay: Control
var _settings_target_row: HBoxContainer
var _settings_target_select: OptionButton
var _settings_mode_btns: Dictionary[String, Button] = {}
var _settings_dur_btns: Dictionary[String, Button] = {}
var _settings_dur_row_box: VBoxContainer
var _settings_bot_speed_btns: Dictionary[String, Button] = {}
var _settings_cam_follow_btns: Dictionary[String, Button] = {}
var _settings_scale_btns: Dictionary[String, Button] = {}
var _settings_toast_btns: Dictionary[String, Button] = {}
var _settings_note_label: Label
var _settings_card: PanelContainer
var _settings_scroll: ScrollContainer
var _settings_target_key: String = "global"
var _comfort_text_scale: float = 1.0
var _show_event_toasts: bool = true
var _prefs_cache: Dictionary = {
	"chance_close_mode": "auto",
	"chance_auto_duration": "default",
	"bot_speed": "normal",
	"camera_follow": true,
	"ui_comfort_scale": "normal",
	"show_event_toasts": true,
	"player_chance_overrides": {}
}

# Cache de estado da UI
var _cached_players: Array[Dictionary] = []
var _cached_current_idx: int = 0
var _cached_tiles: Array[Dictionary] = []
var _cached_player_colors: Dictionary[int, Color] = {}
var _cached_owned_options: Array[Dictionary] = []
var _cached_selected_tile: int = -1
var _cached_is_2d_cam: bool = false
var _last_board_rect: Rect2 = Rect2(18.0, 18.0, 1418.0, 1044.0)
var _last_layout_vp_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 2
	_is_touch_mode = OS.has_feature("mobile") or OS.has_feature("android") or DisplayServer.is_touchscreen_available()
	_bold_font = SystemFont.new()
	_bold_font.font_names = PackedStringArray(["Segoe UI", "Roboto", "Arial", "Liberation Sans", "sans-serif"])
	_bold_font.font_weight = 700
	_preload_pawn_textures()
	_build_ui()
	_build_modals()
	_switch_tab(TAB_PLAYERS)
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.size_changed.connect(_update_responsive_layout)
	if _hud_root != null:
		_hud_root.resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")

func _fs(base_px: float) -> int:
	var mult: float = 1.22 if _is_touch_mode else 1.0
	return roundi(base_px * mult)

func _bh(base_h: float) -> float:
	var mult: float = 1.28 if _is_touch_mode else 1.0
	return base_h * mult

func _preload_pawn_textures() -> void:
	_pawn_textures.clear()
	var ids: Array[String] = ["cuia", "quero_quero", "espeto", "cavalo", "chapeu", "facao"]
	for pid: String in ids:
		var tex: Texture2D = _try_load_pawn_art(pid)
		if tex != null:
			_pawn_textures[pid] = tex

func _normalize_pawn_id(pawn_id: String) -> String:
	var key: String = pawn_id.strip_edges().to_upper()
	match key:
		"CUIA", "CHIMARRAO":
			return "cuia"
		"QUERO_QUERO":
			return "quero_quero"
		"ESPETO", "CHURRASCO":
			return "espeto"
		"CAVALO":
			return "cavalo"
		"CHAPEU":
			return "chapeu"
		"FACAO":
			return "facao"
		_:
			return "cuia"

func _try_load_pawn_art(pawn_id: String) -> Texture2D:
	var canonical: String = _normalize_pawn_id(pawn_id)
	if _pawn_textures.has(canonical):
		return _pawn_textures[canonical]
	var path: String = "res://assets/pawns/%s.png" % canonical
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var abs_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img: Image = Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

func _try_load_deed_art(art_id: String) -> Texture2D:
	if art_id == "":
		return null
	var path: String = "res://assets/tiles/%s.png" % art_id
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var abs_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img: Image = Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

func _format_brl(amount: int) -> String:
	var sign_str: String = "-" if amount < 0 else ""
	var digits: String = str(absi(amount))
	var out: String = ""
	var count: int = 0
	for idx: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "." + out
		out = digits.substr(idx, 1) + out
		count += 1
	return "%sR$ %s" % [sign_str, out]

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return
		if _chance_overlay != null and _chance_overlay.visible:
			if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
				hide_chance_card_modal(true)
				get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_ESCAPE:
			if _deed_overlay != null and _deed_overlay.visible:
				hide_deed_modal()
				get_viewport().set_input_as_handled()
			elif _portfolio_overlay != null and _portfolio_overlay.visible:
				hide_player_portfolio_modal()
				get_viewport().set_input_as_handled()
			elif _settings_overlay != null and _settings_overlay.visible:
				hide_settings_modal()
				get_viewport().set_input_as_handled()
			elif _help_overlay != null and _help_overlay.visible:
				hide_help_modal()
				get_viewport().set_input_as_handled()
			elif _trade_overlay != null and _trade_overlay.visible:
				hide_trade_modal()
				get_viewport().set_input_as_handled()
			elif _pause_overlay != null and _pause_overlay.visible:
				hide_pause_modal()
				get_viewport().set_input_as_handled()

func has_blocking_modal_open() -> bool:
	if _chance_overlay != null and _chance_overlay.visible:
		return true
	if _portfolio_overlay != null and _portfolio_overlay.visible:
		return true
	if _settings_overlay != null and _settings_overlay.visible:
		return true
	if _deed_overlay != null and _deed_overlay.visible:
		return true
	if _trade_overlay != null and _trade_overlay.visible:
		return true
	if _pause_overlay != null and _pause_overlay.visible:
		return true
	if _help_overlay != null and _help_overlay.visible:
		return true
	if _victory_overlay != null and _victory_overlay.visible:
		return true
	return false

func set_match_ui_visible(is_visible: bool) -> void:
	if _hud_root != null:
		_hud_root.visible = is_visible
	if is_visible:
		_update_responsive_layout()
		call_deferred("_update_responsive_layout")

func get_board_viewport_rect() -> Rect2:
	return _last_board_rect

func _get_effective_viewport_size() -> Vector2:
	if _hud_root != null and _hud_root.size.x >= 320.0 and _hud_root.size.y >= 240.0:
		return _hud_root.size
	var vp: Viewport = get_viewport()
	if vp != null:
		return vp.get_visible_rect().size
	return Vector2.ZERO

func _update_responsive_layout() -> void:
	if _side_panel == null:
		return
	var vp_size: Vector2 = _get_effective_viewport_size()
	if vp_size.x < 320.0 or vp_size.y < 240.0:
		return
	_last_layout_vp_size = vp_size

	var pad: float = 14.0 if _is_touch_mode else 18.0
	var gap: float = 14.0 if _is_touch_mode else 16.0
	var panel_w: float = 468.0
	if _is_touch_mode:
		panel_w = clampf(vp_size.x * 0.275, 490.0, 610.0)
	else:
		panel_w = clampf(vp_size.x * 0.245, 430.0, 520.0)
	panel_w = minf(panel_w, maxf(300.0, vp_size.x * 0.42))

	var usable_h: float = maxf(300.0, vp_size.y - pad * 2.0)
	var board_w: float = maxf(360.0, vp_size.x - pad * 2.0 - gap - panel_w)

	_last_board_rect = Rect2(Vector2(pad, pad), Vector2(board_w, usable_h))
	_side_panel.anchor_left = 1.0
	_side_panel.anchor_right = 1.0
	_side_panel.anchor_top = 0.0
	_side_panel.anchor_bottom = 1.0
	_side_panel.offset_left = -(pad + panel_w)
	_side_panel.offset_right = -pad
	_side_panel.offset_top = pad
	_side_panel.offset_bottom = -pad
	_side_panel.custom_minimum_size = Vector2(panel_w, 0.0)

	if _ticker_panel != null:
		var ticker_h: float = clampf(usable_h * 0.215, 132.0, 226.0)
		_ticker_panel.custom_minimum_size = Vector2(0.0, ticker_h)
	if _settings_card != null:
		var set_w: float = clampf(vp_size.x * 0.46, 520.0, 740.0) if not _is_touch_mode else clampf(vp_size.x * 0.72, 560.0, 820.0)
		_settings_card.custom_minimum_size = Vector2(minf(set_w, vp_size.x - 40.0), 0.0)
	if _settings_scroll != null:
		var max_scroll_h: float = clampf(vp_size.y * 0.62, 260.0, 620.0)
		_settings_scroll.custom_minimum_size = Vector2(0.0, max_scroll_h)
	if _portfolio_card != null:
		var port_w: float = clampf(vp_size.x * 0.44, 520.0, 700.0) if not _is_touch_mode else clampf(vp_size.x * 0.72, 540.0, 780.0)
		_portfolio_card.custom_minimum_size = Vector2(minf(port_w, vp_size.x - 40.0), 0.0)
	if _portfolio_scroll != null:
		var port_scroll_h: float = clampf(vp_size.y * 0.48, 220.0, 500.0)
		_portfolio_scroll.custom_minimum_size = Vector2(0.0, port_scroll_h)

	if _board_quick_bar != null:
		_board_quick_bar.position = Vector2(pad + 14.0, pad + 14.0)
	_layout_event_toast()

	board_layout_updated.emit(_last_board_rect)

func _layout_event_toast() -> void:
	if _toast_panel == null:
		return
	var board_w: float = maxf(320.0, _last_board_rect.size.x)
	var toast_w: float = clampf(board_w * 0.36, 290.0, 400.0) if _is_touch_mode else clampf(board_w * 0.27, 280.0, 380.0)
	var inner_w: float = maxf(220.0, toast_w - 28.0)
	if _toast_title_label != null:
		_toast_title_label.custom_minimum_size = Vector2(inner_w, 0.0)
	if _toast_detail_label != null:
		_toast_detail_label.custom_minimum_size = Vector2(inner_w, 0.0)
	_toast_panel.custom_minimum_size = Vector2(toast_w, 0.0)
	_toast_panel.size = Vector2(toast_w, 0.0)
	_toast_panel.reset_size()
	var final_w: float = maxf(toast_w, _toast_panel.size.x)
	_toast_panel.position = Vector2(
		_last_board_rect.position.x + (board_w - final_w) * 0.5,
		_last_board_rect.position.y + 58.0
	)

# --- Estilos Modernos ---

func _make_panel_style(bg_hex: String = "#111A15", border_hex: String = "#C9A227", radius: int = 12, border_w: int = 2) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(bg_hex)
	sb.border_color = Color(border_hex)
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

func _make_btn_style(bg_hex: String, border_hex: String, border_w: int = 1, radius: int = 9, pressed_shift: bool = false, pad_h: float = 10.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(bg_hex)
	sb.border_color = Color(border_hex)
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = 6.0 if pressed_shift else 5.0
	sb.content_margin_bottom = 4.0 if pressed_shift else 5.0
	return sb

func _apply_button_theme(
	btn: Button,
	normal_bg: String,
	hover_bg: String,
	pressed_bg: String,
	border_hex: String,
	text_col: Color = Color.WHITE,
	is_primary: bool = false,
	min_h: float = 38.0,
	font_sz: int = 13,
	pad_h: float = 10.0,
	bold_text: bool = false
) -> void:
	var bw: int = 2 if is_primary else 1
	var hover_border: String = "#FFF2C6" if is_primary else "#E9C46A"
	btn.custom_minimum_size = Vector2(0.0, min_h)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if (is_primary or bold_text) and _bold_font != null:
		btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", Color("#5B6D63"))
	btn.add_theme_stylebox_override("normal", _make_btn_style(normal_bg, border_hex, bw, 9, false, pad_h))
	btn.add_theme_stylebox_override("hover", _make_btn_style(hover_bg, hover_border, bw, 9, false, pad_h))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(pressed_bg, "#F8E3A3", bw, 9, true, pad_h))
	btn.add_theme_stylebox_override("disabled", _make_btn_style("#141C18", "#233029", 1, 9, false, pad_h))
	btn.add_theme_stylebox_override("focus", _make_btn_style(hover_bg, "#F3C969", 2, 9, false, pad_h))

func flash_action_feedback(tone: String = "positive") -> void:
	if _status_card_style == null or not is_inside_tree():
		return
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()

	var flash_border: Color = Color("#52B788")
	var flash_bg: Color = Color("#1F3C2E")
	match tone:
		"warning":
			flash_border = Color("#F5CA5C")
			flash_bg = Color("#342A1B")
		"turn":
			flash_border = Color("#4EA8DE")
			flash_bg = Color("#182E3A")
		_:
			flash_border = Color("#52B788")
			flash_bg = Color("#1F3C2E")

	_status_card_style.border_color = flash_border
	_status_card_style.bg_color = flash_bg

	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.set_trans(Tween.TRANS_CUBIC)
	_feedback_tween.set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_status_card_style, "border_color", STATUS_BORDER_DEFAULT, 0.55)
	_feedback_tween.tween_property(_status_card_style, "bg_color", STATUS_BG_DEFAULT, 0.55)

# --- Construção do HUD Principal ---

func _build_ui() -> void:
	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	# 1. Barra Flutuante Elegante no Topo Esquerdo do Tabuleiro (Câmera + Ajuda + Menu)
	_board_quick_bar = PanelContainer.new()
	var qb_style: StyleBoxFlat = _make_panel_style("#0E1813", "#C9A227", 12, 1)
	qb_style.bg_color = Color(0.055, 0.095, 0.075, 0.90)
	qb_style.content_margin_left = 8.0
	qb_style.content_margin_right = 8.0
	qb_style.content_margin_top = 6.0
	qb_style.content_margin_bottom = 6.0
	qb_style.shadow_size = 10
	qb_style.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
	_board_quick_bar.add_theme_stylebox_override("panel", qb_style)
	_hud_root.add_child(_board_quick_bar)

	var qb_row: HBoxContainer = HBoxContainer.new()
	qb_row.add_theme_constant_override("separation", 8)
	_board_quick_bar.add_child(qb_row)

	var qb_h: float = _bh(34.0)
	var qb_fs: int = _fs(12.0)

	_btn_camera = Button.new()
	_btn_camera.text = "Vista 3D" if _is_touch_mode else "Vista 3D [Tab]"
	_apply_button_theme(_btn_camera, "#183329", "#224A3B", "#12261F", "#2FA378", Color("#ECFFF5"), false, qb_h, qb_fs, 11.0, true)
	_btn_camera.pressed.connect(func() -> void: camera_toggle_requested.emit())
	qb_row.add_child(_btn_camera)

	_btn_cam_follow = Button.new()
	_btn_cam_follow.text = "Foco Auto"
	_btn_cam_follow.tooltip_text = "Acompanhar automaticamente o peão da vez na Vista Isométrica"
	_apply_button_theme(_btn_cam_follow, "#1B362E", "#264C40", "#132620", "#52B788", Color("#D8FFE8"), false, qb_h, qb_fs, 10.0, true)
	_btn_cam_follow.pressed.connect(func() -> void: camera_follow_toggle_requested.emit())
	qb_row.add_child(_btn_cam_follow)

	_btn_cam_reset = Button.new()
	_btn_cam_reset.text = "Centralizar"
	_btn_cam_reset.tooltip_text = "Voltar imediatamente ao enquadramento geral do tabuleiro"
	_apply_button_theme(_btn_cam_reset, "#1A2721", "#253830", "#121C17", "#4D695B", Color("#E6F0EA"), false, qb_h, qb_fs, 10.0, true)
	_btn_cam_reset.pressed.connect(func() -> void: camera_reset_requested.emit())
	qb_row.add_child(_btn_cam_reset)

	_btn_help = Button.new()
	_btn_help.text = "Regras"
	_apply_button_theme(_btn_help, "#1A2721", "#253830", "#121C17", "#4D695B", Color("#E6F0EA"), false, qb_h, qb_fs, 11.0, true)
	_btn_help.pressed.connect(show_help_modal)
	qb_row.add_child(_btn_help)

	_btn_settings = Button.new()
	_btn_settings.text = "Ajustes"
	_btn_settings.tooltip_text = "Configurar carta de Sorte ou Azar, ritmo dos bots, câmera e conforto visual"
	_apply_button_theme(_btn_settings, "#1A2923", "#253B32", "#121E19", "#C9A227", Color("#F8E5A8"), false, qb_h, qb_fs, 11.0, true)
	_btn_settings.pressed.connect(show_settings_modal)
	qb_row.add_child(_btn_settings)

	_btn_pause = Button.new()
	_btn_pause.text = "Menu"
	_apply_button_theme(_btn_pause, "#1E2A24", "#2C3E35", "#151F1A", "#8B7432", Color("#F8E5A8"), false, qb_h, qb_fs, 11.0, true)
	_btn_pause.pressed.connect(show_pause_modal)
	qb_row.add_child(_btn_pause)

	# 1B. Toast Compacto Não-Bloqueante de Micro-Reações (compras, trocas, aluguel, rodadas)
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_style = _make_panel_style("#12231B", "#E9C46A", 11, 1)
	_toast_style.bg_color = Color(0.06, 0.12, 0.09, 0.92)
	_toast_style.content_margin_left = 14.0
	_toast_style.content_margin_right = 14.0
	_toast_style.content_margin_top = 7.0
	_toast_style.content_margin_bottom = 7.0
	_toast_style.shadow_size = 10
	_toast_style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	_toast_panel.add_theme_stylebox_override("panel", _toast_style)
	_hud_root.add_child(_toast_panel)

	var toast_vb: VBoxContainer = VBoxContainer.new()
	toast_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_vb.add_theme_constant_override("separation", 2)
	_toast_panel.add_child(toast_vb)

	_toast_title_label = Label.new()
	_toast_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_title_label.clip_text = true
	_toast_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _bold_font != null:
		_toast_title_label.add_theme_font_override("font", _bold_font)
	_toast_title_label.add_theme_font_size_override("font_size", _fs(13.0))
	_toast_title_label.add_theme_color_override("font_color", Color("#F8D568"))
	toast_vb.add_child(_toast_title_label)

	_toast_detail_label = Label.new()
	_toast_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_detail_label.max_lines_visible = 2
	_toast_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toast_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_detail_label.add_theme_font_size_override("font_size", _fs(11.5))
	_toast_detail_label.add_theme_color_override("font_color", Color("#E8F2EC"))
	toast_vb.add_child(_toast_detail_label)

	# 2. Painel Lateral Direito Executivo (3 Zonas: Hero -> Abas -> Dock Contextual)
	_side_panel = PanelContainer.new()
	_side_panel.anchor_left = 1.0
	_side_panel.anchor_right = 1.0
	_side_panel.anchor_top = 0.0
	_side_panel.anchor_bottom = 1.0
	_side_panel.offset_left = -486.0
	_side_panel.offset_right = -18.0
	_side_panel.offset_top = 18.0
	_side_panel.offset_bottom = -18.0
	var side_style: StyleBoxFlat = _make_panel_style("#0F1813", "#D4AF37", 16, 2)
	side_style.shadow_size = 16
	side_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	_side_panel.add_theme_stylebox_override("panel", side_style)
	_hud_root.add_child(_side_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var m_pad: int = 12 if _is_touch_mode else 12
	margin.add_theme_constant_override("margin_left", m_pad)
	margin.add_theme_constant_override("margin_right", m_pad)
	margin.add_theme_constant_override("margin_top", m_pad)
	margin.add_theme_constant_override("margin_bottom", m_pad)
	_side_panel.add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	_build_hero_zone(root_vbox)
	_build_tabs_zone(root_vbox)
	_build_action_dock_zone(root_vbox)

func _build_hero_zone(parent: VBoxContainer) -> void:
	_status_card = PanelContainer.new()
	_status_card_style = _make_panel_style("#15251D", "#D4AF37", 12, 2)
	_status_card.add_theme_stylebox_override("panel", _status_card_style)
	parent.add_child(_status_card)

	var st_margin: MarginContainer = MarginContainer.new()
	st_margin.add_theme_constant_override("margin_left", 10)
	st_margin.add_theme_constant_override("margin_right", 11)
	st_margin.add_theme_constant_override("margin_top", 10)
	st_margin.add_theme_constant_override("margin_bottom", 10)
	_status_card.add_child(st_margin)

	var hero_shell: HBoxContainer = HBoxContainer.new()
	hero_shell.add_theme_constant_override("separation", 10)
	st_margin.add_child(hero_shell)

	var accent: Panel = Panel.new()
	accent.custom_minimum_size = Vector2(6.0, 0.0)
	accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_accent_style = StyleBoxFlat.new()
	_hero_accent_style.bg_color = Color("#FFCA3A")
	_hero_accent_style.set_corner_radius_all(3)
	accent.add_theme_stylebox_override("panel", _hero_accent_style)
	hero_shell.add_child(accent)

	var hero_vbox: VBoxContainer = VBoxContainer.new()
	hero_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_vbox.add_theme_constant_override("separation", 6)
	hero_shell.add_child(hero_vbox)

	# Faixa compacta de identidade P2P (visível apenas em partidas online ENet)
	_net_identity_bar = PanelContainer.new()
	_net_identity_bar.visible = false
	_net_identity_style = _make_panel_style("#14332C", "#4EA8DE", 7, 1)
	_net_identity_style.content_margin_left = 8.0
	_net_identity_style.content_margin_right = 8.0
	_net_identity_style.content_margin_top = 3.0
	_net_identity_style.content_margin_bottom = 3.0
	_net_identity_bar.add_theme_stylebox_override("panel", _net_identity_style)
	hero_vbox.add_child(_net_identity_bar)

	_net_identity_label = Label.new()
	_net_identity_label.text = "ONLINE • P2P"
	_net_identity_label.clip_text = true
	if _bold_font != null:
		_net_identity_label.add_theme_font_override("font", _bold_font)
	_net_identity_label.add_theme_font_size_override("font_size", _fs(10.5))
	_net_identity_label.add_theme_color_override("font_color", Color("#C9F2FF"))
	_net_identity_bar.add_child(_net_identity_label)

	# Linha Superior: Avatar do Peão + Nome + Saldo
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_vbox.add_child(top_row)

	var av_dim: float = 52.0 if _is_touch_mode else 44.0
	var avatar_frame: PanelContainer = PanelContainer.new()
	avatar_frame.custom_minimum_size = Vector2(av_dim, av_dim)
	_hero_avatar_frame_style = _make_panel_style("#0D1611", "#FFCA3A", 12, 2)
	_hero_avatar_frame_style.content_margin_left = 3.0
	_hero_avatar_frame_style.content_margin_right = 3.0
	_hero_avatar_frame_style.content_margin_top = 3.0
	_hero_avatar_frame_style.content_margin_bottom = 3.0
	avatar_frame.add_theme_stylebox_override("panel", _hero_avatar_frame_style)
	top_row.add_child(avatar_frame)

	_hero_avatar_tex = TextureRect.new()
	_hero_avatar_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_frame.add_child(_hero_avatar_tex)

	var id_vbox: VBoxContainer = VBoxContainer.new()
	id_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_vbox.add_theme_constant_override("separation", 2)
	top_row.add_child(id_vbox)

	var name_cash_row: HBoxContainer = HBoxContainer.new()
	name_cash_row.add_theme_constant_override("separation", 6)
	name_cash_row.alignment = BoxContainer.ALIGNMENT_CENTER
	id_vbox.add_child(name_cash_row)

	_hero_name_label = Label.new()
	_hero_name_label.text = "Aguardando..."
	_hero_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_name_label.clip_text = true
	if _bold_font != null:
		_hero_name_label.add_theme_font_override("font", _bold_font)
	_hero_name_label.add_theme_font_size_override("font_size", _fs(18.0))
	_hero_name_label.add_theme_color_override("font_color", Color("#FFFDF5"))
	name_cash_row.add_child(_hero_name_label)

	_hero_money_label = Label.new()
	_hero_money_label.text = "R$ 2.558"
	_hero_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hero_money_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	if _bold_font != null:
		_hero_money_label.add_theme_font_override("font", _bold_font)
	_hero_money_label.add_theme_font_size_override("font_size", _fs(19.0))
	_hero_money_label.add_theme_color_override("font_color", Color("#7BF1A8"))
	name_cash_row.add_child(_hero_money_label)

	var meta_row: HBoxContainer = HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 6)
	meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	id_vbox.add_child(meta_row)

	var phase_badge: PanelContainer = PanelContainer.new()
	_hero_phase_badge_style = _make_panel_style("#1E4736", "#52B788", 6, 1)
	_hero_phase_badge_style.content_margin_left = 7.0
	_hero_phase_badge_style.content_margin_right = 7.0
	_hero_phase_badge_style.content_margin_top = 2.0
	_hero_phase_badge_style.content_margin_bottom = 2.0
	phase_badge.add_theme_stylebox_override("panel", _hero_phase_badge_style)
	meta_row.add_child(phase_badge)

	_hero_phase_label = Label.new()
	_hero_phase_label.text = "ROLAR"
	if _bold_font != null:
		_hero_phase_label.add_theme_font_override("font", _bold_font)
	_hero_phase_label.add_theme_font_size_override("font_size", _fs(10.0))
	_hero_phase_label.add_theme_color_override("font_color", Color("#E8FFF2"))
	phase_badge.add_child(_hero_phase_label)

	_hero_pawn_name_label = Label.new()
	_hero_pawn_name_label.text = ""
	_hero_pawn_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_pawn_name_label.clip_text = true
	_hero_pawn_name_label.add_theme_font_size_override("font_size", _fs(11.0))
	_hero_pawn_name_label.add_theme_color_override("font_color", Color("#BDD3C6"))
	meta_row.add_child(_hero_pawn_name_label)

	_round_badge = PanelContainer.new()
	_round_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	_round_badge.tooltip_text = "Rodada atual da partida (avança quando todos os ativos completam sua vez)"
	_round_badge_style = _make_panel_style("#182820", "#3B5949", 6, 1)
	_round_badge_style.content_margin_left = 7.0
	_round_badge_style.content_margin_right = 7.0
	_round_badge_style.content_margin_top = 2.0
	_round_badge_style.content_margin_bottom = 2.0
	_round_badge.add_theme_stylebox_override("panel", _round_badge_style)
	meta_row.add_child(_round_badge)

	_round_label = Label.new()
	_round_label.text = "ROD. 1"
	if _bold_font != null:
		_round_label.add_theme_font_override("font", _bold_font)
	_round_label.add_theme_font_size_override("font_size", _fs(10.0))
	_round_label.add_theme_color_override("font_color", Color("#D8ECE0"))
	_round_badge.add_child(_round_label)

	_bank_label = Label.new()
	_bank_label.text = "32C • 12H"
	_bank_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_bank_label.tooltip_text = "Estoque do Banco: Casas e Hotéis disponíveis"
	_bank_label.add_theme_font_size_override("font_size", _fs(11.0))
	_bank_label.add_theme_color_override("font_color", Color("#95D5B2"))
	meta_row.add_child(_bank_label)

	# Faixa rebaixada do resumo da casa atual
	var tile_box: PanelContainer = PanelContainer.new()
	var tile_style: StyleBoxFlat = _make_panel_style("#0B1410", "#263B30", 8, 1)
	tile_style.content_margin_left = 10.0
	tile_style.content_margin_right = 10.0
	tile_style.content_margin_top = 6.0
	tile_style.content_margin_bottom = 6.0
	tile_box.add_theme_stylebox_override("panel", tile_style)
	hero_vbox.add_child(tile_box)

	_tile_info_label = Label.new()
	_tile_info_label.text = "Casa atual: -"
	_tile_info_label.add_theme_font_size_override("font_size", _fs(12.0))
	_tile_info_label.add_theme_color_override("font_color", Color("#EFF6F2"))
	_tile_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_box.add_child(_tile_info_label)

func _build_tabs_zone(parent: VBoxContainer) -> void:
	# Seletor segmentado de 3 abas
	var tabs_bar: HBoxContainer = HBoxContainer.new()
	tabs_bar.add_theme_constant_override("separation", 6)
	parent.add_child(tabs_bar)

	var tab_titles: Array[String] = ["Estanceiros", "Escrituras", "Diário"]
	_tab_buttons.clear()
	for i: int in range(tab_titles.size()):
		var t_btn: Button = Button.new()
		t_btn.text = tab_titles[i]
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tab_idx: int = i
		t_btn.pressed.connect(func() -> void: _switch_tab(tab_idx))
		tabs_bar.add_child(t_btn)
		_tab_buttons.append(t_btn)

	# Container principal das abas (expande verticalmente sem aperto e sem empurrar o dock)
	var tab_frame: PanelContainer = PanelContainer.new()
	tab_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_frame.custom_minimum_size = Vector2(0.0, 96.0)
	tab_frame.clip_contents = true
	var tf_style: StyleBoxFlat = _make_panel_style("#131D18", "#273B30", 12, 1)
	tf_style.content_margin_left = 10.0
	tf_style.content_margin_right = 10.0
	tf_style.content_margin_top = 10.0
	tf_style.content_margin_bottom = 10.0
	tab_frame.add_theme_stylebox_override("panel", tf_style)
	parent.add_child(tab_frame)

	_tab_panels.clear()

	# --- ABA 0: ESTANCEIROS + TICKER RECENTE ---
	var players_tab: VBoxContainer = VBoxContainer.new()
	players_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_tab.add_theme_constant_override("separation", 8)
	tab_frame.add_child(players_tab)
	_tab_panels.append(players_tab)

	var players_scroll: ScrollContainer = ScrollContainer.new()
	players_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_scroll.custom_minimum_size = Vector2(0.0, 64.0)
	players_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	players_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	players_tab.add_child(players_scroll)

	_players_box = VBoxContainer.new()
	_players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_players_box.add_theme_constant_override("separation", 6)
	players_scroll.add_child(_players_box)

	_ticker_panel = PanelContainer.new()
	_ticker_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticker_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_ticker_panel.custom_minimum_size = Vector2(0.0, 214.0 if not _is_touch_mode else 188.0)
	_ticker_panel.clip_contents = true
	var tk_style: StyleBoxFlat = _make_panel_style("#0B130F", "#2A4033", 9, 1)
	tk_style.content_margin_left = 10.0
	tk_style.content_margin_right = 10.0
	tk_style.content_margin_top = 8.0
	tk_style.content_margin_bottom = 8.0
	_ticker_panel.add_theme_stylebox_override("panel", tk_style)
	players_tab.add_child(_ticker_panel)

	var tk_vbox: VBoxContainer = VBoxContainer.new()
	tk_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tk_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tk_vbox.add_theme_constant_override("separation", 5)
	_ticker_panel.add_child(tk_vbox)

	_ticker_hdr_label = Label.new()
	_ticker_hdr_label.text = "ÚLTIMAS ATUALIZAÇÕES"
	if _bold_font != null:
		_ticker_hdr_label.add_theme_font_override("font", _bold_font)
	_ticker_hdr_label.add_theme_font_size_override("font_size", _fs(10.5))
	_ticker_hdr_label.add_theme_color_override("font_color", Color("#E9C46A"))
	tk_vbox.add_child(_ticker_hdr_label)

	_ticker_scroll = ScrollContainer.new()
	_ticker_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ticker_scroll.custom_minimum_size = Vector2(0.0, 96.0)
	_ticker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ticker_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tk_vbox.add_child(_ticker_scroll)

	_ticker_label = Label.new()
	_ticker_label.text = "Partida pronta para começar."
	_ticker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ticker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticker_label.add_theme_font_size_override("font_size", _fs(12.0))
	_ticker_label.add_theme_color_override("font_color", Color("#D8E6DD"))
	_ticker_scroll.add_child(_ticker_label)

	# --- ABA 1: ESCRITURAS (GESTÃO VISUAL DE PROPRIEDADES) ---
	var deeds_tab: VBoxContainer = VBoxContainer.new()
	deeds_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deeds_tab.add_theme_constant_override("separation", 8)
	deeds_tab.visible = false
	tab_frame.add_child(deeds_tab)
	_tab_panels.append(deeds_tab)

	var deeds_scroll: ScrollContainer = ScrollContainer.new()
	deeds_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deeds_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deeds_scroll.custom_minimum_size = Vector2(0.0, 64.0)
	deeds_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deeds_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	deeds_tab.add_child(deeds_scroll)

	var deeds_inner: VBoxContainer = VBoxContainer.new()
	deeds_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deeds_inner.add_theme_constant_override("separation", 6)
	deeds_scroll.add_child(deeds_inner)

	_deeds_empty_label = Label.new()
	_deeds_empty_label.text = "Nenhuma escritura própria ainda.\nCompre terrenos ou companhias ao parar em casas livres."
	_deeds_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deeds_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deeds_empty_label.add_theme_font_size_override("font_size", _fs(13.0))
	_deeds_empty_label.add_theme_color_override("font_color", Color("#8FA899"))
	deeds_inner.add_child(_deeds_empty_label)

	_deeds_list_box = VBoxContainer.new()
	_deeds_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deeds_list_box.add_theme_constant_override("separation", 6)
	deeds_inner.add_child(_deeds_list_box)

	_deeds_action_box = VBoxContainer.new()
	_deeds_action_box.add_theme_constant_override("separation", 6)
	deeds_tab.add_child(_deeds_action_box)

	var d_row1: HBoxContainer = HBoxContainer.new()
	d_row1.add_theme_constant_override("separation", 6)
	_deeds_action_box.add_child(d_row1)

	var act_h: float = _bh(38.0)
	var act_fs: int = _fs(12.0)

	_btn_build = Button.new()
	_btn_build.text = "+Casa"
	_btn_build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_build, "#1D4A38", "#27644C", "#143528", "#40916C", Color.WHITE, false, act_h, act_fs, 8.0, true)
	_btn_build.pressed.connect(_on_build_pressed)
	d_row1.add_child(_btn_build)

	_btn_sell_building = Button.new()
	_btn_sell_building.text = "-Casa"
	_btn_sell_building.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_sell_building, "#3D2724", "#553631", "#2B1B19", "#C46E5F", Color.WHITE, false, act_h, act_fs, 8.0, true)
	_btn_sell_building.pressed.connect(_on_sell_building_pressed)
	d_row1.add_child(_btn_sell_building)

	var d_row2: HBoxContainer = HBoxContainer.new()
	d_row2.add_theme_constant_override("separation", 6)
	_deeds_action_box.add_child(d_row2)

	_btn_mortgage = Button.new()
	_btn_mortgage.text = "Hipotecar"
	_btn_mortgage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_mortgage, "#2B323C", "#3B4553", "#1F242B", "#7B8C9E", Color.WHITE, false, act_h, act_fs, 8.0, true)
	_btn_mortgage.pressed.connect(_on_mortgage_pressed)
	d_row2.add_child(_btn_mortgage)

	_btn_inspect_selected = Button.new()
	_btn_inspect_selected.text = "Ver Escritura"
	_btn_inspect_selected.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_inspect_selected, "#1E3028", "#294338", "#15231D", "#C9A227", Color("#F8E5A8"), false, act_h, act_fs, 8.0, true)
	_btn_inspect_selected.pressed.connect(_on_inspect_selected_pressed)
	d_row2.add_child(_btn_inspect_selected)

	# --- ABA 2: DIÁRIO COMPLETO DA RODADA ---
	var log_tab: VBoxContainer = VBoxContainer.new()
	log_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_tab.visible = false
	tab_frame.add_child(log_tab)
	_tab_panels.append(log_tab)

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.custom_minimum_size = Vector2(0.0, 64.0)
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	log_tab.add_child(_log_scroll)

	_log_label = Label.new()
	_log_label.text = ""
	_log_label.add_theme_font_size_override("font_size", _fs(13.0))
	_log_label.add_theme_color_override("font_color", Color("#DDE8E1"))
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_label)

func _build_action_dock_zone(parent: VBoxContainer) -> void:
	_dock_card = PanelContainer.new()
	_dock_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock_card.size_flags_vertical = Control.SIZE_SHRINK_END
	_dock_card.custom_minimum_size = Vector2(0.0, _bh(108.0))
	var dk_style: StyleBoxFlat = _make_panel_style("#14211A", "#324A3D", 12, 1)
	dk_style.content_margin_left = 10.0
	dk_style.content_margin_right = 10.0
	dk_style.content_margin_top = 10.0
	dk_style.content_margin_bottom = 10.0
	_dock_card.add_theme_stylebox_override("panel", dk_style)
	parent.add_child(_dock_card)

	var dock_vbox: VBoxContainer = VBoxContainer.new()
	dock_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_vbox.add_theme_constant_override("separation", 8)
	_dock_card.add_child(dock_vbox)

	# Banner calmo quando for turno de Bot
	_bot_banner = PanelContainer.new()
	_bot_banner.visible = false
	var bb_style: StyleBoxFlat = _make_panel_style("#132833", "#4EA8DE", 10, 1)
	bb_style.content_margin_left = 12.0
	bb_style.content_margin_right = 12.0
	bb_style.content_margin_top = 14.0
	bb_style.content_margin_bottom = 14.0
	_bot_banner.add_theme_stylebox_override("panel", bb_style)
	dock_vbox.add_child(_bot_banner)

	_bot_banner_label = Label.new()
	_bot_banner_label.text = "Turno do Bot..."
	_bot_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_bot_banner_label.add_theme_font_override("font", _bold_font)
	_bot_banner_label.add_theme_font_size_override("font_size", _fs(14.0))
	_bot_banner_label.add_theme_color_override("font_color", Color("#9BE0FF"))
	_bot_banner.add_child(_bot_banner_label)

	# Controles Humanos Contextuais
	_human_dock_vbox = VBoxContainer.new()
	_human_dock_vbox.add_theme_constant_override("separation", 8)
	dock_vbox.add_child(_human_dock_vbox)

	# Faixa Contextual do Xadrez (visível apenas quando preso)
	_jail_row = HBoxContainer.new()
	_jail_row.add_theme_constant_override("separation", 6)
	_jail_row.visible = false
	_human_dock_vbox.add_child(_jail_row)

	var jail_h: float = _bh(38.0)
	var jail_fs: int = _fs(12.0)

	_btn_bail = Button.new()
	_btn_bail.text = "Fiança R$50"
	_btn_bail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_bail, "#4D371F", "#6B4D2B", "#382716", "#E9C46A", Color("#FFF3D1"), false, jail_h, jail_fs, 8.0, true)
	_btn_bail.pressed.connect(func() -> void: bail_pressed.emit())
	_jail_row.add_child(_btn_bail)

	_btn_jail_card = Button.new()
	_btn_jail_card.text = "Carta Livre"
	_btn_jail_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_jail_card, "#1D4540", "#275E57", "#14312D", "#4EA8DE", Color.WHITE, false, jail_h, jail_fs, 8.0, true)
	_btn_jail_card.pressed.connect(func() -> void: use_jail_card_pressed.emit())
	_jail_row.add_child(_btn_jail_card)

	# Linha Principal (Hero Action: Rolar Dados OU Comprar/Recusar OU Passar a Vez)
	_primary_action_row = HBoxContainer.new()
	_primary_action_row.add_theme_constant_override("separation", 8)
	_human_dock_vbox.add_child(_primary_action_row)

	var prim_h: float = _bh(48.0)
	var prim_fs: int = _fs(15.0)

	_btn_roll = Button.new()
	_btn_roll.text = "Rolar Dados"
	_btn_roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_roll, "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), true, prim_h, prim_fs, 12.0, true)
	_btn_roll.pressed.connect(func() -> void: roll_pressed.emit())
	_primary_action_row.add_child(_btn_roll)

	_btn_buy = Button.new()
	_btn_buy.text = "Comprar"
	_btn_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_buy.size_flags_stretch_ratio = 1.35
	_apply_button_theme(_btn_buy, "#248762", "#2FA87B", "#1A6649", "#A8FF78", Color.WHITE, true, prim_h, prim_fs, 10.0, true)
	_btn_buy.pressed.connect(func() -> void: buy_pressed.emit())
	_primary_action_row.add_child(_btn_buy)

	_btn_decline = Button.new()
	_btn_decline.text = "Recusar"
	_btn_decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_decline.size_flags_stretch_ratio = 0.75
	_apply_button_theme(_btn_decline, "#3A4840", "#4C5E54", "#2B3630", "#E9C46A", Color("#F5F9F6"), false, prim_h, _fs(14.0), 10.0, true)
	_btn_decline.pressed.connect(func() -> void: decline_buy_pressed.emit())
	_primary_action_row.add_child(_btn_decline)

	_btn_end_turn = Button.new()
	_btn_end_turn.text = "Passar a Vez"
	_btn_end_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_end_turn, "#227557", "#2C946E", "#185740", "#A8FF78", Color.WHITE, true, prim_h, prim_fs, 12.0, true)
	_btn_end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	_primary_action_row.add_child(_btn_end_turn)

	# Linha Secundária (Negociar + Atalho Escrituras)
	_secondary_action_row = HBoxContainer.new()
	_secondary_action_row.add_theme_constant_override("separation", 8)
	_human_dock_vbox.add_child(_secondary_action_row)

	var sec_h: float = _bh(38.0)
	var sec_fs: int = _fs(13.0)

	_btn_trade_open = Button.new()
	_btn_trade_open.text = "Negociar"
	_btn_trade_open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_trade_open, "#1B3345", "#264861", "#142633", "#4EA8DE", Color("#E4F5FF"), false, sec_h, sec_fs, 10.0, true)
	_btn_trade_open.pressed.connect(show_trade_modal)
	_secondary_action_row.add_child(_btn_trade_open)

	_btn_deeds_jump = Button.new()
	_btn_deeds_jump.text = "Escrituras (0)"
	_btn_deeds_jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_deeds_jump, "#1B2E25", "#254033", "#13211A", "#52B788", Color("#E9F5EE"), false, sec_h, sec_fs, 10.0, true)
	_btn_deeds_jump.pressed.connect(func() -> void: _switch_tab(TAB_DEEDS))
	_secondary_action_row.add_child(_btn_deeds_jump)

func _switch_tab(tab_idx: int) -> void:
	_active_tab = clampi(tab_idx, 0, _tab_panels.size() - 1)
	var tab_h: float = _bh(36.0)
	var tab_fs: int = _fs(12.5)
	for i: int in range(_tab_panels.size()):
		_tab_panels[i].visible = (i == _active_tab)
	for i: int in range(_tab_buttons.size()):
		if i == _active_tab:
			_apply_button_theme(_tab_buttons[i], "#234938", "#2C5C47", "#1A372A", "#E9C46A", Color("#FFF6D6"), true, tab_h, tab_fs, 8.0, true)
		else:
			_apply_button_theme(_tab_buttons[i], "#15211B", "#1E2E26", "#101914", "#2B4035", Color("#A7BDB0"), false, tab_h, tab_fs, 8.0, false)

# --- Camada de Modais Dedicados (Layer 20) ---

func _build_modals() -> void:
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 20
	add_child(_modal_layer)

	_build_deed_modal()
	_build_trade_modal()
	_build_pause_modal()
	_build_help_modal()
	_build_victory_modal()
	_build_chance_card_modal()
	_build_settings_modal()
	_build_portfolio_modal()

func _create_modal_backdrop(on_dismiss: Callable) -> Control:
	var overlay: Control = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	_modal_layer.add_child(overlay)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.03, 0.80)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if on_dismiss.is_valid():
		dim.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton:
				var mb: InputEventMouseButton = ev
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
					on_dismiss.call()
		)
	overlay.add_child(dim)
	return overlay

# 1. Modal de Inspeção de Escritura
func _build_deed_modal() -> void:
	_deed_overlay = _create_modal_backdrop(hide_deed_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deed_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(560.0 if _is_touch_mode else 500.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#141F19", "#D4AF37", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 0)
	card.add_child(card_vbox)

	_deed_banner = PanelContainer.new()
	var banner_style: StyleBoxFlat = StyleBoxFlat.new()
	banner_style.bg_color = Color("#2A9D8F")
	banner_style.corner_radius_top_left = 16
	banner_style.corner_radius_top_right = 16
	_deed_banner.add_theme_stylebox_override("panel", banner_style)
	card_vbox.add_child(_deed_banner)

	var b_margin: MarginContainer = MarginContainer.new()
	b_margin.add_theme_constant_override("margin_left", 24)
	b_margin.add_theme_constant_override("margin_right", 24)
	b_margin.add_theme_constant_override("margin_top", 16)
	b_margin.add_theme_constant_override("margin_bottom", 14)
	_deed_banner.add_child(b_margin)

	var b_vbox: VBoxContainer = VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 3)
	b_margin.add_child(b_vbox)

	_deed_group_label = Label.new()
	_deed_group_label.text = "ESCRITURA"
	_deed_group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_deed_group_label.add_theme_font_override("font", _bold_font)
	_deed_group_label.add_theme_font_size_override("font_size", _fs(12.0))
	b_vbox.add_child(_deed_group_label)

	_deed_title_label = Label.new()
	_deed_title_label.text = "Propriedade"
	_deed_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deed_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _bold_font != null:
		_deed_title_label.add_theme_font_override("font", _bold_font)
	_deed_title_label.add_theme_font_size_override("font_size", _fs(23.0))
	b_vbox.add_child(_deed_title_label)

	var body_margin: MarginContainer = MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 24)
	body_margin.add_theme_constant_override("margin_right", 24)
	body_margin.add_theme_constant_override("margin_top", 16)
	body_margin.add_theme_constant_override("margin_bottom", 18)
	card_vbox.add_child(body_margin)

	var body_outer: VBoxContainer = VBoxContainer.new()
	body_outer.add_theme_constant_override("separation", 14)
	body_margin.add_child(body_outer)

	_deed_body_box = VBoxContainer.new()
	_deeds_spacing_init(_deed_body_box, 7)
	body_outer.add_child(_deed_body_box)

	var btn_close: Button = Button.new()
	btn_close.text = "Fechar" if _is_touch_mode else "Fechar [ESC]"
	_apply_button_theme(btn_close, "#213329", "#2E473A", "#17241D", "#D4AF37", Color.WHITE, false, _bh(42.0), _fs(14.0), 12.0, true)
	btn_close.pressed.connect(hide_deed_modal)
	body_outer.add_child(btn_close)

func _deeds_spacing_init(vb: VBoxContainer, sep: int) -> void:
	vb.add_theme_constant_override("separation", sep)

func hide_deed_modal() -> void:
	if _deed_overlay != null:
		_deed_overlay.visible = false

func _add_deed_kv_row(label_text: String, value_text: String, highlight: bool = false, value_color: Color = Color("#F2F7F4")) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var k_lbl: Label = Label.new()
	k_lbl.text = label_text
	k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k_lbl.add_theme_font_size_override("font_size", _fs(14.0))
	k_lbl.add_theme_color_override("font_color", Color("#F3C969") if highlight else Color("#B8C9BF"))
	row.add_child(k_lbl)

	var v_lbl: Label = Label.new()
	v_lbl.text = value_text
	v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if highlight and _bold_font != null:
		v_lbl.add_theme_font_override("font", _bold_font)
	v_lbl.add_theme_font_size_override("font_size", _fs(14.0))
	v_lbl.add_theme_color_override("font_color", Color("#A8FF78") if highlight else value_color)
	row.add_child(v_lbl)
	_deed_body_box.add_child(row)

func show_deed_modal(info: Dictionary) -> void:
	if _deed_overlay == null:
		return
	_deed_overlay.move_to_front()
	for child: Node in _deed_body_box.get_children():
		child.queue_free()

	var tile: Dictionary = info.get("tile", {})
	var tile_type: String = str(tile.get("type", ""))
	var tile_name: String = str(tile.get("name", "Casa"))
	var group_name: String = str(tile.get("group", ""))
	var banner_hex: String = str(tile.get("color", ""))
	if banner_hex == "":
		banner_hex = "#2D5248" if tile_type == "COMPANY" else "#23362C"

	var banner_color: Color = Color(banner_hex)
	var banner_style: StyleBoxFlat = StyleBoxFlat.new()
	banner_style.bg_color = banner_color
	banner_style.corner_radius_top_left = 16
	banner_style.corner_radius_top_right = 16
	_deed_banner.add_theme_stylebox_override("panel", banner_style)

	var header_text_col: Color = Color("#101713") if banner_color.get_luminance() > 0.56 else Color.WHITE
	_deed_title_label.text = tile_name
	_deed_title_label.add_theme_color_override("font_color", header_text_col)
	_deed_group_label.add_theme_color_override("font_color", header_text_col)

	var art_tex: Texture2D = _try_load_deed_art(str(tile.get("art_id", "")))
	if art_tex != null:
		var art_center: CenterContainer = CenterContainer.new()
		var art_frame: PanelContainer = PanelContainer.new()
		art_frame.add_theme_stylebox_override("panel", _make_panel_style("#101814", "#D4AF37", 12, 2))
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.texture = art_tex
		tex_rect.custom_minimum_size = Vector2(118.0, 118.0)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_frame.add_child(tex_rect)
		art_center.add_child(art_frame)
		_deed_body_box.add_child(art_center)

	if tile_type == "PROPERTY":
		_deed_group_label.text = "ESCRITURA DE TERRENO • GRUPO %s" % group_name.replace("_", " ")
		var price: int = int(tile.get("price", 0))
		var mortgage_val: int = int(info.get("mortgage_value", 0))
		var redeem_cost: int = int(info.get("redeem_cost", 0))
		var house_cost: int = int(tile.get("house_cost", 50))
		var rent_list: Array = tile.get("rent", [])
		var base_rent: int = int(rent_list[0]) if rent_list.size() > 0 else 0
		var building_lvl: int = int(info.get("building_level", 0))
		var has_monopoly: bool = bool(info.get("has_monopoly", false))
		var is_owned: bool = bool(info.get("is_owned", false))
		var is_mortgaged: bool = bool(info.get("is_mortgaged", false))

		_add_deed_kv_row("Preço de Compra", _format_brl(price))
		_deed_body_box.add_child(HSeparator.new())

		var active_base: bool = is_owned and not is_mortgaged and building_lvl == 0 and not has_monopoly
		var active_mono: bool = is_owned and not is_mortgaged and building_lvl == 0 and has_monopoly
		_add_deed_kv_row("Aluguel Base (0 casas)", _format_brl(base_rent), active_base)
		_add_deed_kv_row("Aluguel Monopólio (sem casas)", _format_brl(base_rent * 2), active_mono)

		for lvl: int in range(1, mini(5, rent_list.size())):
			var lbl_str: String = "Com %d casa" % lvl if lvl == 1 else "Com %d casas" % lvl
			_add_deed_kv_row(lbl_str, _format_brl(int(rent_list[lvl])), is_owned and not is_mortgaged and building_lvl == lvl)
		if rent_list.size() > 5:
			_add_deed_kv_row("Com Hotel", _format_brl(int(rent_list[5])), is_owned and not is_mortgaged and building_lvl >= 5)

		_deed_body_box.add_child(HSeparator.new())
		_add_deed_kv_row("Custo de Construção (Casa/Hotel)", _format_brl(house_cost))
		_add_deed_kv_row("Hipoteca / Desipoteca (+10%)", "%s  /  %s" % [_format_brl(mortgage_val), _format_brl(redeem_cost)])
		_deed_body_box.add_child(HSeparator.new())
		_add_deed_ownership_rows(info)
	elif tile_type == "COMPANY":
		_deed_group_label.text = "ESCRITURA DE COMPANHIA"
		var price: int = int(tile.get("price", 0))
		var mult: int = int(tile.get("multiplier", 40))
		var mortgage_val: int = int(info.get("mortgage_value", 0))
		var redeem_cost: int = int(info.get("redeem_cost", 0))

		_add_deed_kv_row("Preço de Compra", _format_brl(price))
		_add_deed_kv_row("Regra de Aluguel", "%dx soma dos dados" % mult)
		_add_deed_kv_row("Hipoteca / Desipoteca (+10%)", "%s  /  %s" % [_format_brl(mortgage_val), _format_brl(redeem_cost)])
		_deed_body_box.add_child(HSeparator.new())
		_add_deed_ownership_rows(info)
	else:
		_deed_group_label.text = "CASA ESPECIAL DO TABULEIRO"
		var desc_lbl: Label = Label.new()
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", _fs(14.0))
		desc_lbl.add_theme_color_override("font_color", Color("#DCE8E0"))
		match tile_type:
			"START":
				desc_lbl.text = "Ponto de Partida. Ao passar ou parar no Galpão Central, o estanceiro recebe o bônus da rodada."
			"CHANCE":
				desc_lbl.text = "Sorte ou Azar, Tchê! Ao parar nesta casa, saque uma carta do baralho central e aplique o efeito."
			"TAX":
				desc_lbl.text = "Imposto obrigatório: ao parar aqui, pague %s diretamente ao Banco." % _format_brl(int(tile.get("amount", 0)))
			"JAIL":
				desc_lbl.text = "Xadrez. Quem cai aqui normalmente está só de visita; quem foi preso precisa tirar dupla, usar Carta Livre ou pagar fiança."
			"GO_TO_JAIL":
				desc_lbl.text = "Vá direto para o Xadrez sem passar pelo Galpão Central e sem receber o bônus da partida."
			"FREE_PARKING":
				desc_lbl.text = "Feriadão de 20 de Setembro: descanso livre de cobranças nesta rodada."
			_:
				desc_lbl.text = "Casa #%d do tabuleiro." % int(tile.get("index", 0))
		_deed_body_box.add_child(desc_lbl)

	_deed_overlay.visible = true

func _add_deed_ownership_rows(info: Dictionary) -> void:
	var is_owned: bool = bool(info.get("is_owned", false))
	var is_mortgaged: bool = bool(info.get("is_mortgaged", false))
	var building_lvl: int = int(info.get("building_level", 0))

	if is_owned:
		var owner_name: String = str(info.get("owner_name", "-"))
		var owner_pawn: String = str(info.get("owner_pawn", ""))
		var owner_text: String = "%s (%s)" % [owner_name, owner_pawn] if owner_pawn != "" else owner_name
		var owner_color: Color = info.get("owner_color", Color.WHITE)
		_add_deed_kv_row("Dono Atual", owner_text, false, owner_color)
		if is_mortgaged:
			_add_deed_kv_row("Estado da Escritura", "HIPOTECADA (sem aluguel)", false, Color("#FF758F"))
		else:
			var build_str: String = "Ativa • Hotel" if building_lvl >= 5 else ("Ativa • %d casa(s)" % building_lvl if building_lvl > 0 else "Ativa • Sem construções")
			_add_deed_kv_row("Estado da Escritura", build_str, false, Color("#A8FF78"))
	else:
		_add_deed_kv_row("Dono Atual", "Disponível (Banco)", false, Color("#E9C46A"))
		_add_deed_kv_row("Estado da Escritura", "Livre para compra", false, Color("#B7C7BD"))

# 2. Modal Dedicado de Negociação / Troca (com botões de incremento táteis para mobile e desktop)
func _build_trade_modal() -> void:
	_trade_overlay = _create_modal_backdrop(hide_trade_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(620.0 if _is_touch_mode else 560.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#131E18", "#4EA8DE", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "NEGOCIAÇÃO ENTRE ESTANCEIROS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", _fs(19.0))
	title.add_theme_color_override("font_color", Color("#90E0EF"))
	vbox.add_child(title)

	var opt_h: float = _bh(40.0)

	# Parceiro
	var p_lbl: Label = Label.new()
	p_lbl.text = "Negociar com:"
	p_lbl.add_theme_font_size_override("font_size", _fs(13.0))
	p_lbl.add_theme_color_override("font_color", Color("#C2D4C9"))
	vbox.add_child(p_lbl)

	_trade_target_select = OptionButton.new()
	_trade_target_select.custom_minimum_size = Vector2(0.0, opt_h)
	_trade_target_select.add_theme_font_size_override("font_size", _fs(14.0))
	_trade_target_select.item_selected.connect(func(_i: int) -> void: _refresh_trade_dropdowns())
	vbox.add_child(_trade_target_select)

	# Duas colunas: Você oferece vs Você pede
	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	vbox.add_child(cols)

	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 6)
	cols.add_child(left_col)

	var l_lbl: Label = Label.new()
	l_lbl.text = "Escritura que você oferece:"
	l_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	l_lbl.add_theme_color_override("font_color", Color("#F3C969"))
	left_col.add_child(l_lbl)

	_trade_offer_select = OptionButton.new()
	_trade_offer_select.custom_minimum_size = Vector2(0.0, opt_h)
	_trade_offer_select.clip_text = true
	_trade_offer_select.add_theme_font_size_override("font_size", _fs(13.0))
	_trade_offer_select.item_selected.connect(func(_i: int) -> void: _refresh_trade_summary())
	left_col.add_child(_trade_offer_select)

	var right_col: VBoxContainer = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	cols.add_child(right_col)

	var r_lbl: Label = Label.new()
	r_lbl.text = "Escritura que você pede:"
	r_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	r_lbl.add_theme_color_override("font_color", Color("#7BF1A8"))
	right_col.add_child(r_lbl)

	_trade_request_select = OptionButton.new()
	_trade_request_select.custom_minimum_size = Vector2(0.0, opt_h)
	_trade_request_select.clip_text = true
	_trade_request_select.add_theme_font_size_override("font_size", _fs(13.0))
	_trade_request_select.item_selected.connect(func(_i: int) -> void: _refresh_trade_summary())
	right_col.add_child(_trade_request_select)

	# Ajuste de dinheiro tátil (-100, -50, -10, Zerar, +10, +50, +100)
	var cash_box: PanelContainer = PanelContainer.new()
	var cb_style: StyleBoxFlat = _make_panel_style("#0B1410", "#273C31", 10, 1)
	cb_style.content_margin_left = 12.0
	cb_style.content_margin_right = 12.0
	cb_style.content_margin_top = 10.0
	cb_style.content_margin_bottom = 10.0
	cash_box.add_theme_stylebox_override("panel", cb_style)
	vbox.add_child(cash_box)

	var cash_vbox: VBoxContainer = VBoxContainer.new()
	cash_vbox.add_theme_constant_override("separation", 8)
	cash_box.add_child(cash_vbox)

	_trade_cash_label = Label.new()
	_trade_cash_label.text = "Dinheiro na troca: R$ 0"
	_trade_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_trade_cash_label.add_theme_font_override("font", _bold_font)
	_trade_cash_label.add_theme_font_size_override("font_size", _fs(15.0))
	_trade_cash_label.add_theme_color_override("font_color", Color("#F8D568"))
	cash_vbox.add_child(_trade_cash_label)

	var step_row: HBoxContainer = HBoxContainer.new()
	step_row.add_theme_constant_override("separation", 6)
	cash_vbox.add_child(step_row)

	var steps: Array[int] = [-100, -50, -10, 0, 10, 50, 100]
	var step_h: float = _bh(36.0)
	for st_val: int in steps:
		var s_btn: Button = Button.new()
		s_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var delta_ref: int = st_val
		if st_val == 0:
			s_btn.text = "Zerar"
			_apply_button_theme(s_btn, "#24302A", "#33443C", "#19221E", "#5A7366", Color("#DCE8E0"), false, step_h, _fs(11.5), 4.0, true)
			s_btn.pressed.connect(func() -> void:
				_trade_cash_value = 0
				_refresh_trade_summary()
			)
		elif st_val < 0:
			s_btn.text = "%d" % st_val
			_apply_button_theme(s_btn, "#3A2322", "#52302E", "#281817", "#C46E5F", Color("#FFD5D5"), false, step_h, _fs(12.0), 4.0, true)
			s_btn.pressed.connect(func() -> void: _adjust_trade_cash(delta_ref))
		else:
			s_btn.text = "+%d" % st_val
			_apply_button_theme(s_btn, "#1D4434", "#275C46", "#143025", "#52B788", Color("#D8FFE8"), false, step_h, _fs(12.0), 4.0, true)
			s_btn.pressed.connect(func() -> void: _adjust_trade_cash(delta_ref))
		step_row.add_child(s_btn)

	_trade_summary_label = Label.new()
	_trade_summary_label.text = ""
	_trade_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_summary_label.add_theme_font_size_override("font_size", _fs(13.0))
	_trade_summary_label.add_theme_color_override("font_color", Color("#D8E8DE"))
	vbox.add_child(_trade_summary_label)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var btn_cancel: Button = Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.size_flags_stretch_ratio = 0.75
	_apply_button_theme(btn_cancel, "#24302A", "#32433B", "#1A221E", "#5A7366", Color.WHITE, false, _bh(44.0), _fs(14.0), 10.0, true)
	btn_cancel.pressed.connect(hide_trade_modal)
	btn_row.add_child(btn_cancel)

	var btn_confirm: Button = Button.new()
	btn_confirm.text = "Fechar Negócio"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.size_flags_stretch_ratio = 1.25
	_apply_button_theme(btn_confirm, "#227557", "#2C946E", "#185740", "#A8FF78", Color.WHITE, true, _bh(44.0), _fs(14.0), 10.0, true)
	btn_confirm.pressed.connect(_emit_trade)
	btn_row.add_child(btn_confirm)

func show_trade_modal() -> void:
	if _trade_overlay == null:
		return
	_trade_cash_value = 0
	_refresh_trade_targets()
	_trade_overlay.visible = true

func hide_trade_modal() -> void:
	if _trade_overlay != null:
		_trade_overlay.visible = false

func _adjust_trade_cash(delta: int) -> void:
	_trade_cash_value = clampi(_trade_cash_value + delta, -5000, 5000)
	_refresh_trade_summary()

func _refresh_trade_targets() -> void:
	var prev_target_meta: Variant = _trade_target_select.get_selected_metadata()
	_trade_target_select.clear()
	var selected_idx: int = 0

	for i: int in range(_cached_players.size()):
		if i == _cached_current_idx:
			continue
		var p: Dictionary = _cached_players[i]
		if bool(p.get("bankrupt", false)):
			continue
		var pid: int = int(p["id"])
		var bot_tag: String = " [BOT]" if bool(p.get("is_bot", false)) else ""
		_trade_target_select.add_item("%s%s (%s)" % [str(p["name"]), bot_tag, _format_brl(int(p["money"]))])
		var item_idx: int = _trade_target_select.item_count - 1
		_trade_target_select.set_item_metadata(item_idx, pid)
		if prev_target_meta != null and int(prev_target_meta) == pid:
			selected_idx = item_idx

	if _trade_target_select.item_count > 0:
		_trade_target_select.select(selected_idx)
	_refresh_trade_dropdowns()

func _refresh_trade_dropdowns() -> void:
	_trade_offer_select.clear()
	_trade_offer_select.add_item("Nenhuma escritura")
	_trade_offer_select.set_item_metadata(0, -1)

	if _cached_current_idx >= 0 and _cached_current_idx < _cached_players.size():
		var current_props: Array = _cached_players[_cached_current_idx].get("properties", [])
		for t_idx: Variant in current_props:
			var idx_int: int = int(t_idx)
			if idx_int >= 0 and idx_int < _cached_tiles.size():
				_trade_offer_select.add_item(str(_cached_tiles[idx_int]["name"]))
				_trade_offer_select.set_item_metadata(_trade_offer_select.item_count - 1, idx_int)

	_trade_request_select.clear()
	_trade_request_select.add_item("Nenhuma escritura")
	_trade_request_select.set_item_metadata(0, -1)

	var target_id: Variant = _trade_target_select.get_selected_metadata()
	if target_id != null:
		var target_id_int: int = int(target_id)
		for p: Dictionary in _cached_players:
			if int(p["id"]) == target_id_int:
				var target_props: Array = p.get("properties", [])
				for t_idx: Variant in target_props:
					var idx_int: int = int(t_idx)
					if idx_int >= 0 and idx_int < _cached_tiles.size():
						_trade_request_select.add_item(str(_cached_tiles[idx_int]["name"]))
						_trade_request_select.set_item_metadata(_trade_request_select.item_count - 1, idx_int)
				break

	_refresh_trade_summary()

func _refresh_trade_summary() -> void:
	if _trade_cash_label == null or _trade_summary_label == null:
		return
	if _trade_cash_value > 0:
		_trade_cash_label.text = "Você oferece +%s em dinheiro" % _format_brl(_trade_cash_value)
		_trade_cash_label.add_theme_color_override("font_color", Color("#F8D568"))
	elif _trade_cash_value < 0:
		_trade_cash_label.text = "Você pede %s em dinheiro" % _format_brl(absi(_trade_cash_value))
		_trade_cash_label.add_theme_color_override("font_color", Color("#7BF1A8"))
	else:
		_trade_cash_label.text = "Sem dinheiro envolvido (R$ 0)"
		_trade_cash_label.add_theme_color_override("font_color", Color("#B8C9BF"))

	var offer_idx: int = int(_trade_offer_select.get_selected_metadata()) if _trade_offer_select.selected >= 0 else -1
	var req_idx: int = int(_trade_request_select.get_selected_metadata()) if _trade_request_select.selected >= 0 else -1
	var offer_txt: String = str(_cached_tiles[offer_idx]["name"]) if (offer_idx >= 0 and offer_idx < _cached_tiles.size()) else ""
	var req_txt: String = str(_cached_tiles[req_idx]["name"]) if (req_idx >= 0 and req_idx < _cached_tiles.size()) else ""

	if offer_txt == "" and req_txt == "" and _trade_cash_value == 0:
		_trade_summary_label.text = "Selecione uma escritura ou ajuste o valor para propor o negócio."
		return
	var gives: Array[String] = []
	var receives: Array[String] = []
	if offer_txt != "":
		gives.append(offer_txt)
	if _trade_cash_value > 0:
		gives.append(_format_brl(_trade_cash_value))
	if req_txt != "":
		receives.append(req_txt)
	if _trade_cash_value < 0:
		receives.append(_format_brl(absi(_trade_cash_value)))

	var g_str: String = " + ".join(gives) if not gives.is_empty() else "nada"
	var r_str: String = " + ".join(receives) if not receives.is_empty() else "nada"
	_trade_summary_label.text = "Resumo: você entrega %s  ⇄  recebe %s." % [g_str, r_str]

func _emit_trade() -> void:
	var target_meta: Variant = _trade_target_select.get_selected_metadata()
	if target_meta == null:
		return
	var offer_meta: Variant = _trade_offer_select.get_selected_metadata()
	var req_meta: Variant = _trade_request_select.get_selected_metadata()
	var offer_idx: int = int(offer_meta) if offer_meta != null else -1
	var req_idx: int = int(req_meta) if req_meta != null else -1
	trade_executed.emit(int(target_meta), offer_idx, req_idx, _trade_cash_value)
	_trade_cash_value = 0
	hide_trade_modal()

# 3. Modal de Pausa / Menu da Partida
func _build_pause_modal() -> void:
	_pause_overlay = _create_modal_backdrop(hide_pause_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(440.0 if _is_touch_mode else 400.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#121D17", "#D4AF37", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "MENU DA PARTIDA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", _fs(20.0))
	title.add_theme_color_override("font_color", Color("#F5D06F"))
	vbox.add_child(title)

	var btn_h: float = _bh(44.0)
	var btn_fs: int = _fs(14.0)

	var b_resume: Button = Button.new()
	b_resume.text = "Continuar Partida"
	_apply_button_theme(b_resume, "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), true, btn_h, btn_fs, 12.0, true)
	b_resume.pressed.connect(hide_pause_modal)
	vbox.add_child(b_resume)

	_pause_restart_btn = Button.new()
	_pause_restart_btn.text = "Reiniciar Partida Atual"
	_apply_button_theme(_pause_restart_btn, "#1E4234", "#285846", "#153026", "#52B788", Color.WHITE, false, btn_h, btn_fs, 12.0, true)
	_pause_restart_btn.pressed.connect(func() -> void:
		hide_pause_modal()
		restart_match_requested.emit()
	)
	vbox.add_child(_pause_restart_btn)

	var b_settings: Button = Button.new()
	b_settings.text = "Configurações"
	_apply_button_theme(b_settings, "#1A3229", "#24473A", "#12241D", "#C9A227", Color("#F8E5A8"), false, btn_h, btn_fs, 12.0, true)
	b_settings.pressed.connect(func() -> void:
		hide_pause_modal()
		show_settings_modal()
	)
	vbox.add_child(b_settings)

	var b_rules: Button = Button.new()
	b_rules.text = "Regras Rápidas"
	_apply_button_theme(b_rules, "#1B2E26", "#253F34", "#13211B", "#4D705F", Color("#E8F2EC"), false, btn_h, btn_fs, 12.0, true)
	b_rules.pressed.connect(func() -> void:
		hide_pause_modal()
		show_help_modal()
	)
	vbox.add_child(b_rules)

	_pause_menu_btn = Button.new()
	_pause_menu_btn.text = "Voltar à Tela Inicial"
	_apply_button_theme(_pause_menu_btn, "#3A2322", "#50302E", "#291817", "#C46E5F", Color("#FFE4E4"), false, btn_h, btn_fs, 12.0, true)
	_pause_menu_btn.pressed.connect(func() -> void:
		hide_pause_modal()
		menu_requested.emit()
	)
	vbox.add_child(_pause_menu_btn)

func show_pause_modal() -> void:
	if _pause_overlay != null:
		_pause_overlay.visible = true

func hide_pause_modal() -> void:
	if _pause_overlay != null:
		_pause_overlay.visible = false

# 4. Modal de Ajuda / Regras Rápidas (acessível no Lobby e na Partida)
func _build_help_modal() -> void:
	_help_overlay = _create_modal_backdrop(hide_help_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(680.0 if _is_touch_mode else 620.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#121D17", "#D4AF37", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "GUIA RÁPIDO • MODO CLÁSSICO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", _fs(20.0))
	title.add_theme_color_override("font_color", Color("#F5D06F"))
	vbox.add_child(title)

	var tips_panel: PanelContainer = PanelContainer.new()
	var tp_style: StyleBoxFlat = _make_panel_style("#0B1410", "#273C31", 12, 1)
	tp_style.content_margin_left = 16.0
	tp_style.content_margin_right = 16.0
	tp_style.content_margin_top = 14.0
	tp_style.content_margin_bottom = 14.0
	tips_panel.add_theme_stylebox_override("panel", tp_style)
	vbox.add_child(tips_panel)

	var tips_vbox: VBoxContainer = VBoxContainer.new()
	tips_vbox.add_theme_constant_override("separation", 9)
	tips_panel.add_child(tips_vbox)

	var inspect_hint: String = "Toque em qualquer casa do tabuleiro para abrir a escritura completa." if _is_touch_mode else "Clique em qualquer casa do tabuleiro para inspecionar a escritura (feche com ESC ou clique fora)."
	var cam_hint: String = "Use o botão 'Vista 3D / Vista 2D' no canto superior esquerdo do tabuleiro." if _is_touch_mode else "Alterne entre Vista Isométrica 3D e Conferência 2D pelo botão superior ou tecla [Tab]."

	var rules_items: Array[Array] = [
		["Economia Base", "Cada estanceiro começa com R$ 2.558. O Banco possui 32 casas e 12 hotéis."],
		["Monopólio & Construções", "Possuir todo o grupo de cor dobra o aluguel base e libera construções equilibradas (venda devolve 50%)."],
		["Companhias & Hipoteca", "Companhias cobram (soma dos dados × fator). Desipotecar custa o valor da hipoteca +10%."],
		["Inspecionar Casas", inspect_hint],
		["Câmera Híbrida", cam_hint],
		["Atalhos de Teclado", "[Espaço/Enter] Rolar dados ou Passar a vez • [C] Comprar • [R] Recusar • [E] Encerrar turno • [N] Negociar • [F] Fiança • [L] Carta Livre • [Tab] Câmera."],
		["Falência & Vitória", "Dívida com jogador transfere escrituras ao credor (construções voltam ao Banco). O último ativo vence!"]
	]

	for entry: Array in rules_items:
		var item_vb: VBoxContainer = VBoxContainer.new()
		item_vb.add_theme_constant_override("separation", 2)
		var h_lbl: Label = Label.new()
		h_lbl.text = "• %s" % str(entry[0])
		if _bold_font != null:
			h_lbl.add_theme_font_override("font", _bold_font)
		h_lbl.add_theme_font_size_override("font_size", _fs(13.5))
		h_lbl.add_theme_color_override("font_color", Color("#F3C969"))
		item_vb.add_child(h_lbl)

		var d_lbl: Label = Label.new()
		d_lbl.text = str(entry[1])
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.add_theme_font_size_override("font_size", _fs(12.5))
		d_lbl.add_theme_color_override("font_color", Color("#DAE7DF"))
		item_vb.add_child(d_lbl)
		tips_vbox.add_child(item_vb)

	var btn_ok: Button = Button.new()
	btn_ok.text = "Entendi" if _is_touch_mode else "Entendi [ESC]"
	_apply_button_theme(btn_ok, "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), true, _bh(42.0), _fs(14.0), 14.0, true)
	btn_ok.pressed.connect(hide_help_modal)
	vbox.add_child(btn_ok)

func show_help_modal() -> void:
	if _help_overlay != null:
		_help_overlay.visible = true

func hide_help_modal() -> void:
	if _help_overlay != null:
		_help_overlay.visible = false

# 5. Modal de Vitória / Fim de Jogo
func _build_victory_modal() -> void:
	_victory_overlay = _create_modal_backdrop(Callable())

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(560.0 if _is_touch_mode else 520.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#131D17", "#D4AF37", 18, 2)
	card_style.shadow_size = 26
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 0)
	card.add_child(card_vbox)

	_victory_banner = PanelContainer.new()
	var banner_style: StyleBoxFlat = StyleBoxFlat.new()
	banner_style.bg_color = Color("#1F4E3D")
	banner_style.corner_radius_top_left = 16
	banner_style.corner_radius_top_right = 16
	_victory_banner.add_theme_stylebox_override("panel", banner_style)
	card_vbox.add_child(_victory_banner)

	var banner_margin: MarginContainer = MarginContainer.new()
	banner_margin.add_theme_constant_override("margin_left", 24)
	banner_margin.add_theme_constant_override("margin_right", 24)
	banner_margin.add_theme_constant_override("margin_top", 16)
	banner_margin.add_theme_constant_override("margin_bottom", 14)
	_victory_banner.add_child(banner_margin)

	var banner_vbox: VBoxContainer = VBoxContainer.new()
	banner_vbox.add_theme_constant_override("separation", 4)
	banner_margin.add_child(banner_vbox)

	_victory_subtitle_label = Label.new()
	_victory_subtitle_label.text = "FIM DE JOGO • NOVO MAGNATA DO PAMPA"
	_victory_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_victory_subtitle_label.add_theme_font_override("font", _bold_font)
	_victory_subtitle_label.add_theme_font_size_override("font_size", _fs(12.0))
	banner_vbox.add_child(_victory_subtitle_label)

	_victory_title_label = Label.new()
	_victory_title_label.text = "Vencedor"
	_victory_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _bold_font != null:
		_victory_title_label.add_theme_font_override("font", _bold_font)
	_victory_title_label.add_theme_font_size_override("font_size", _fs(28.0))
	banner_vbox.add_child(_victory_title_label)

	var body_margin: MarginContainer = MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 24)
	body_margin.add_theme_constant_override("margin_right", 24)
	body_margin.add_theme_constant_override("margin_top", 18)
	body_margin.add_theme_constant_override("margin_bottom", 20)
	card_vbox.add_child(body_margin)

	var body_vbox: VBoxContainer = VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 14)
	body_margin.add_child(body_vbox)

	var crest_center: CenterContainer = CenterContainer.new()
	body_vbox.add_child(crest_center)

	var crest_vbox: VBoxContainer = VBoxContainer.new()
	crest_vbox.add_theme_constant_override("separation", 8)
	crest_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	crest_center.add_child(crest_vbox)

	var frame_center: CenterContainer = CenterContainer.new()
	crest_vbox.add_child(frame_center)

	_victory_pawn_frame = PanelContainer.new()
	var frame_style: StyleBoxFlat = _make_panel_style("#18251E", "#D4AF37", 68, 4)
	frame_style.content_margin_left = 8.0
	frame_style.content_margin_right = 8.0
	frame_style.content_margin_top = 8.0
	frame_style.content_margin_bottom = 8.0
	_victory_pawn_frame.add_theme_stylebox_override("panel", frame_style)
	frame_center.add_child(_victory_pawn_frame)

	_victory_pawn_tex = TextureRect.new()
	_victory_pawn_tex.custom_minimum_size = Vector2(118.0, 118.0)
	_victory_pawn_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_victory_pawn_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_victory_pawn_frame.add_child(_victory_pawn_tex)

	_victory_pawn_name_label = Label.new()
	_victory_pawn_name_label.text = "Cuia de Chimarrão"
	_victory_pawn_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_victory_pawn_name_label.add_theme_font_override("font", _bold_font)
	_victory_pawn_name_label.add_theme_font_size_override("font_size", _fs(15.0))
	_victory_pawn_name_label.add_theme_color_override("font_color", Color("#F3C969"))
	crest_vbox.add_child(_victory_pawn_name_label)

	var stats_panel: PanelContainer = PanelContainer.new()
	var stats_style: StyleBoxFlat = _make_panel_style("#0B1410", "#294034", 10, 1)
	stats_style.content_margin_left = 16.0
	stats_style.content_margin_right = 16.0
	stats_style.content_margin_top = 12.0
	stats_style.content_margin_bottom = 12.0
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	body_vbox.add_child(stats_panel)

	_victory_stats_box = VBoxContainer.new()
	_victory_stats_box.add_theme_constant_override("separation", 8)
	stats_panel.add_child(_victory_stats_box)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	body_vbox.add_child(btn_row)

	_victory_replay_btn = Button.new()
	_victory_replay_btn.text = "Jogar Novamente"
	_victory_replay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_victory_replay_btn.size_flags_stretch_ratio = 1.25
	_apply_button_theme(_victory_replay_btn, "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), true, _bh(46.0), _fs(14.5), 10.0, true)
	_victory_replay_btn.pressed.connect(func() -> void:
		hide_victory_modal()
		restart_match_requested.emit()
	)
	btn_row.add_child(_victory_replay_btn)

	var btn_menu: Button = Button.new()
	btn_menu.text = "Menu"
	btn_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_menu.size_flags_stretch_ratio = 0.85
	_apply_button_theme(btn_menu, "#1F3027", "#2B4437", "#16231C", "#52B788", Color.WHITE, false, _bh(46.0), _fs(14.5), 10.0, true)
	btn_menu.pressed.connect(func() -> void:
		hide_victory_modal()
		menu_requested.emit()
	)
	btn_row.add_child(btn_menu)

func _add_victory_stat_row(k_text: String, v_text: String, v_color: Color = Color("#F2F7F4"), big: bool = false) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var k_lbl: Label = Label.new()
	k_lbl.text = k_text
	k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k_lbl.add_theme_font_size_override("font_size", _fs(14.0))
	k_lbl.add_theme_color_override("font_color", Color("#B7C9BE"))
	row.add_child(k_lbl)

	var v_lbl: Label = Label.new()
	v_lbl.text = v_text
	v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _bold_font != null and big:
		v_lbl.add_theme_font_override("font", _bold_font)
	v_lbl.add_theme_font_size_override("font_size", _fs(18.0 if big else 14.0))
	v_lbl.add_theme_color_override("font_color", v_color)
	row.add_child(v_lbl)
	_victory_stats_box.add_child(row)

func show_victory_modal(info: Dictionary) -> void:
	if _victory_overlay == null:
		return
	hide_deed_modal()
	hide_trade_modal()
	hide_pause_modal()
	hide_help_modal()
	for child: Node in _victory_stats_box.get_children():
		child.queue_free()

	var winner_name: String = str(info.get("name", "Campeão"))
	var is_bot: bool = bool(info.get("is_bot", false))
	var display_name: String = "%s [BOT]" % winner_name if is_bot else winner_name
	var winner_color: Color = info.get("color", Color("#E9C46A"))
	var pawn_id: String = str(info.get("pawn_id", "cuia"))
	var pawn_name: String = str(info.get("pawn_name", "Cuia de Chimarrão"))
	var pawn_code: String = str(info.get("pawn_code", ""))
	var final_money: int = int(info.get("money", 0))
	var props_count: int = int(info.get("properties_count", 0))
	var houses_count: int = int(info.get("houses_count", 0))
	var hotels_count: int = int(info.get("hotels_count", 0))
	var total_players: int = int(info.get("total_players", 2))

	var banner_style: StyleBoxFlat = StyleBoxFlat.new()
	banner_style.bg_color = winner_color
	banner_style.corner_radius_top_left = 16
	banner_style.corner_radius_top_right = 16
	_victory_banner.add_theme_stylebox_override("panel", banner_style)

	var header_text_col: Color = Color("#101713") if winner_color.get_luminance() > 0.56 else Color.WHITE
	_victory_title_label.text = display_name
	_victory_title_label.add_theme_color_override("font_color", header_text_col)
	_victory_subtitle_label.add_theme_color_override("font_color", header_text_col)

	var frame_style: StyleBoxFlat = _make_panel_style("#0E1712", "#D4AF37", 68, 4)
	frame_style.border_color = winner_color
	frame_style.content_margin_left = 8.0
	frame_style.content_margin_right = 8.0
	frame_style.content_margin_top = 8.0
	frame_style.content_margin_bottom = 8.0
	_victory_pawn_frame.add_theme_stylebox_override("panel", frame_style)

	var pawn_tex: Texture2D = _try_load_pawn_art(pawn_id)
	_victory_pawn_tex.texture = pawn_tex
	_victory_pawn_tex.visible = (pawn_tex != null)
	_victory_pawn_name_label.text = "%s [%s]" % [pawn_name, pawn_code] if pawn_code != "" else pawn_name

	_add_victory_stat_row("Saldo Final", _format_brl(final_money), Color("#7BF1A8") if final_money >= 0 else Color("#FF758F"), true)
	var props_str: String = "%d escritura" % props_count if props_count == 1 else "%d escrituras" % props_count
	_add_victory_stat_row("Patrimônio Imobiliário", props_str, Color("#F8D568"), false)
	var build_str: String = "Nenhuma"
	if houses_count > 0 or hotels_count > 0:
		build_str = "%d casa(s) • %d hotel(is)" % [houses_count, hotels_count]
	_add_victory_stat_row("Construções Ativas", build_str, Color("#DCE8E0"), false)
	var rounds_played: int = int(info.get("rounds_played", 1))
	_add_victory_stat_row("Rodadas Disputadas", "Rodada %d" % maxi(1, rounds_played), Color("#A7D7C5"), false)
	_add_victory_stat_row("Estanceiros na Partida", "%d jogadores" % total_players, Color("#B7C9BE"), false)

	_victory_overlay.visible = true

func hide_victory_modal() -> void:
	if _victory_overlay != null:
		_victory_overlay.visible = false

# 6. Modal Dedicado de Carta de Sorte ou Azar (Automático ou Manual Configurável)
func _build_chance_card_modal() -> void:
	_chance_overlay = _create_modal_backdrop(Callable())

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chance_overlay.add_child(center)

	_chance_card = PanelContainer.new()
	_chance_card.custom_minimum_size = Vector2(600.0 if _is_touch_mode else 540.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#141F19", "#F5CA5C", 18, 2)
	card_style.shadow_size = 26
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	_chance_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_chance_card)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 0)
	_chance_card.add_child(card_vbox)

	var banner: PanelContainer = PanelContainer.new()
	var banner_style: StyleBoxFlat = StyleBoxFlat.new()
	banner_style.bg_color = Color("#C99A2E")
	banner_style.corner_radius_top_left = 16
	banner_style.corner_radius_top_right = 16
	banner.add_theme_stylebox_override("panel", banner_style)
	card_vbox.add_child(banner)

	var b_margin: MarginContainer = MarginContainer.new()
	b_margin.add_theme_constant_override("margin_left", 24)
	b_margin.add_theme_constant_override("margin_right", 24)
	b_margin.add_theme_constant_override("margin_top", 16)
	b_margin.add_theme_constant_override("margin_bottom", 14)
	banner.add_child(b_margin)

	var b_vbox: VBoxContainer = VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 3)
	b_margin.add_child(b_vbox)

	var hdr_lbl: Label = Label.new()
	hdr_lbl.text = "SORTE OU AZAR, TCHÊ!"
	hdr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		hdr_lbl.add_theme_font_override("font", _bold_font)
	hdr_lbl.add_theme_font_size_override("font_size", _fs(21.0))
	hdr_lbl.add_theme_color_override("font_color", Color("#101713"))
	b_vbox.add_child(hdr_lbl)

	_chance_player_label = Label.new()
	_chance_player_label.text = ""
	_chance_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_chance_player_label.add_theme_font_override("font", _bold_font)
	_chance_player_label.add_theme_font_size_override("font_size", _fs(13.0))
	_chance_player_label.add_theme_color_override("font_color", Color("#223026"))
	b_vbox.add_child(_chance_player_label)

	var body_margin: MarginContainer = MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 26)
	body_margin.add_theme_constant_override("margin_right", 26)
	body_margin.add_theme_constant_override("margin_top", 22)
	body_margin.add_theme_constant_override("margin_bottom", 22)
	card_vbox.add_child(body_margin)

	var body_vbox: VBoxContainer = VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 14)
	body_margin.add_child(body_vbox)

	var effect_center: CenterContainer = CenterContainer.new()
	body_vbox.add_child(effect_center)

	_chance_effect_badge = PanelContainer.new()
	_chance_effect_badge.visible = false
	_chance_effect_badge_style = _make_panel_style("#18382A", "#52B788", 10, 1)
	_chance_effect_badge_style.content_margin_left = 14.0
	_chance_effect_badge_style.content_margin_right = 14.0
	_chance_effect_badge_style.content_margin_top = 5.0
	_chance_effect_badge_style.content_margin_bottom = 5.0
	_chance_effect_badge.add_theme_stylebox_override("panel", _chance_effect_badge_style)
	effect_center.add_child(_chance_effect_badge)

	_chance_effect_label = Label.new()
	_chance_effect_label.text = ""
	_chance_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_chance_effect_label.add_theme_font_override("font", _bold_font)
	_chance_effect_label.add_theme_font_size_override("font_size", _fs(12.5))
	_chance_effect_label.add_theme_color_override("font_color", Color("#E8FFF2"))
	_chance_effect_badge.add_child(_chance_effect_label)

	var text_frame: PanelContainer = PanelContainer.new()
	var tf_style: StyleBoxFlat = _make_panel_style("#0B1410", "#354F40", 12, 1)
	tf_style.content_margin_left = 18.0
	tf_style.content_margin_right = 18.0
	tf_style.content_margin_top = 18.0
	tf_style.content_margin_bottom = 18.0
	text_frame.add_theme_stylebox_override("panel", tf_style)
	body_vbox.add_child(text_frame)

	_chance_text_label = Label.new()
	_chance_text_label.text = ""
	_chance_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chance_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _bold_font != null:
		_chance_text_label.add_theme_font_override("font", _bold_font)
	_chance_text_label.add_theme_font_size_override("font_size", _fs(17.5))
	_chance_text_label.add_theme_color_override("font_color", Color("#FFFDF5"))
	text_frame.add_child(_chance_text_label)

	_chance_hint_label = Label.new()
	_chance_hint_label.text = ""
	_chance_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chance_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chance_hint_label.add_theme_font_size_override("font_size", _fs(12.5))
	_chance_hint_label.add_theme_color_override("font_color", Color("#A7C2B2"))
	body_vbox.add_child(_chance_hint_label)

	_chance_close_btn = Button.new()
	_chance_close_btn.text = "Continuar" if _is_touch_mode else "Continuar [Espaço / Enter]"
	_apply_button_theme(_chance_close_btn, "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), true, _bh(46.0), _fs(15.0), 14.0, true)
	_chance_close_btn.pressed.connect(func() -> void: hide_chance_card_modal(true))
	body_vbox.add_child(_chance_close_btn)

func show_chance_card_modal(info: Dictionary) -> void:
	if _chance_overlay == null:
		chance_card_dismissed.emit()
		return
	_chance_timer_token += 1
	var my_token: int = _chance_timer_token
	_chance_is_active = true

	var p_name: String = str(info.get("player_name", "Estanceiro"))
	var is_bot: bool = bool(info.get("is_bot", false))
	var card_text: String = str(info.get("card_text", ""))
	var is_manual: bool = bool(info.get("manual_close", false)) and not is_bot
	var duration_sec: float = maxf(1.2, float(info.get("duration_sec", 4.5)))

	_chance_player_label.text = "%s [BOT]" % p_name if is_bot else p_name
	_chance_text_label.text = card_text

	var effect_badge: String = str(info.get("effect_badge", ""))
	var effect_tone: String = str(info.get("effect_tone", "chance"))
	if _chance_effect_badge != null and _chance_effect_label != null:
		_chance_effect_badge.visible = (effect_badge != "")
		if effect_badge != "":
			_chance_effect_label.text = effect_badge
			match effect_tone:
				"positive":
					_chance_effect_badge_style.bg_color = Color("#163D2C")
					_chance_effect_badge_style.border_color = Color("#52B788")
					_chance_effect_label.add_theme_color_override("font_color", Color("#B7FFD6"))
				"negative":
					_chance_effect_badge_style.bg_color = Color("#421B1D")
					_chance_effect_badge_style.border_color = Color("#FF6B6B")
					_chance_effect_label.add_theme_color_override("font_color", Color("#FFD0D0"))
				"move":
					_chance_effect_badge_style.bg_color = Color("#153147")
					_chance_effect_badge_style.border_color = Color("#4EA8DE")
					_chance_effect_label.add_theme_color_override("font_color", Color("#D2F0FF"))
				"jail":
					_chance_effect_badge_style.bg_color = Color("#4A2616")
					_chance_effect_badge_style.border_color = Color("#FF9F1C")
					_chance_effect_label.add_theme_color_override("font_color", Color("#FFE5B8"))
				"special":
					_chance_effect_badge_style.bg_color = Color("#2C3216")
					_chance_effect_badge_style.border_color = Color("#F5CA5C")
					_chance_effect_label.add_theme_color_override("font_color", Color("#FFF3C4"))
				_:
					_chance_effect_badge_style.bg_color = Color("#282313")
					_chance_effect_badge_style.border_color = Color("#E9C46A")
					_chance_effect_label.add_theme_color_override("font_color", Color("#FFF3C4"))

	_apply_comfort_text_scale()

	if is_manual:
		_chance_hint_label.text = "Fechamento manual — leia com calma e toque em Continuar."
		_chance_close_btn.text = "Continuar" if _is_touch_mode else "Continuar [Espaço / Enter]"
	else:
		var secs_i: int = maxi(1, ceili(duration_sec))
		if is_bot:
			_chance_hint_label.text = "Turno de Bot — fechamento automático em %ds (toque para pular)." % secs_i
		else:
			_chance_hint_label.text = "Fechamento automático em %ds (toque em Continuar para avançar antes)." % secs_i
		_chance_close_btn.text = "Continuar (%ds)" % secs_i

	_chance_overlay.visible = true
	if _chance_anim_tween != null and _chance_anim_tween.is_valid():
		_chance_anim_tween.kill()
	if _chance_card != null and is_inside_tree():
		_chance_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_chance_card.pivot_offset = _chance_card.size * 0.5
		_chance_card.scale = Vector2(0.92, 0.92)
		_chance_anim_tween = create_tween()
		_chance_anim_tween.set_parallel(true)
		_chance_anim_tween.tween_property(_chance_card, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_chance_anim_tween.tween_property(_chance_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if not is_manual:
		_run_chance_auto_close(my_token, duration_sec, is_bot)

func _run_chance_auto_close(expected_token: int, duration_sec: float, is_bot: bool) -> void:
	var remaining: float = duration_sec
	while remaining > 0.0:
		if not is_inside_tree() or expected_token != _chance_timer_token or not _chance_is_active:
			return
		var secs_i: int = maxi(1, ceili(remaining))
		if _chance_close_btn != null:
			_chance_close_btn.text = "Continuar (%ds)" % secs_i
		if _chance_hint_label != null:
			if is_bot:
				_chance_hint_label.text = "Turno de Bot — fechamento automático em %ds (toque para pular)." % secs_i
			else:
				_chance_hint_label.text = "Fechamento automático em %ds (toque em Continuar para avançar antes)." % secs_i
		var step: float = minf(0.25, remaining)
		await get_tree().create_timer(step).timeout
		remaining -= step
	if expected_token == _chance_timer_token and _chance_is_active:
		hide_chance_card_modal(true)

func hide_chance_card_modal(emit_signal: bool = true) -> void:
	_chance_timer_token += 1
	if _chance_anim_tween != null and _chance_anim_tween.is_valid():
		_chance_anim_tween.kill()
	_chance_anim_tween = null
	var was_active: bool = _chance_is_active
	_chance_is_active = false
	if _chance_overlay != null:
		_chance_overlay.visible = false
	if emit_signal and was_active:
		chance_card_dismissed.emit()

# 7. Modal de Configurações e Conforto (acessível no Lobby e na Partida)
func _build_settings_modal() -> void:
	_settings_overlay = _create_modal_backdrop(hide_settings_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(center)

	_settings_card = PanelContainer.new()
	_settings_card.custom_minimum_size = Vector2(680.0 if _is_touch_mode else 620.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#121D17", "#D4AF37", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	_settings_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_settings_card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_settings_card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "CONFIGURAÇÕES & CONFORTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", _fs(20.0))
	title.add_theme_color_override("font_color", Color("#F5D06F"))
	vbox.add_child(title)

	_settings_scroll = ScrollContainer.new()
	_settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_scroll.custom_minimum_size = Vector2(0.0, 480.0)
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(_settings_scroll)

	var content_vb: VBoxContainer = VBoxContainer.new()
	content_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vb.add_theme_constant_override("separation", 12)
	_settings_scroll.add_child(content_vb)

	# --- Seção 1: Carta de Sorte ou Azar ---
	var sec1: PanelContainer = PanelContainer.new()
	var sec_style: StyleBoxFlat = _make_panel_style("#0B1410", "#273C31", 12, 1)
	sec_style.content_margin_left = 14.0
	sec_style.content_margin_right = 14.0
	sec_style.content_margin_top = 12.0
	sec_style.content_margin_bottom = 12.0
	sec1.add_theme_stylebox_override("panel", sec_style)
	content_vb.add_child(sec1)

	var s1_vb: VBoxContainer = VBoxContainer.new()
	s1_vb.add_theme_constant_override("separation", 9)
	sec1.add_child(s1_vb)

	var s1_hdr: Label = Label.new()
	s1_hdr.text = "CARTA DE SORTE OU AZAR"
	if _bold_font != null:
		s1_hdr.add_theme_font_override("font", _bold_font)
	s1_hdr.add_theme_font_size_override("font_size", _fs(13.0))
	s1_hdr.add_theme_color_override("font_color", Color("#F3C969"))
	s1_vb.add_child(s1_hdr)

	_settings_target_row = HBoxContainer.new()
	_settings_target_row.add_theme_constant_override("separation", 10)
	_settings_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	s1_vb.add_child(_settings_target_row)

	var target_lbl: Label = Label.new()
	target_lbl.text = "Aplicar para:"
	target_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	target_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	_settings_target_row.add_child(target_lbl)

	_settings_target_select = OptionButton.new()
	_settings_target_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_target_select.custom_minimum_size = Vector2(0.0, _bh(38.0))
	_settings_target_select.add_theme_font_size_override("font_size", _fs(12.5))
	_settings_target_select.item_selected.connect(_on_settings_target_selected)
	_settings_target_row.add_child(_settings_target_select)

	var mode_lbl: Label = Label.new()
	mode_lbl.text = "Modo de fechamento do aviso:"
	mode_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	mode_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	s1_vb.add_child(mode_lbl)

	var mode_row: HBoxContainer = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	s1_vb.add_child(mode_row)
	_settings_mode_btns.clear()
	var mode_specs: Array[Array] = [
		["inherit", "Usar Padrão"],
		["auto", "Automático"],
		["manual", "Manual (Botão)"]
	]
	for spec: Array in mode_specs:
		var m_key: String = str(spec[0])
		var m_btn: Button = Button.new()
		m_btn.text = str(spec[1])
		m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_btn.pressed.connect(func() -> void: _set_chance_mode_pref(m_key))
		mode_row.add_child(m_btn)
		_settings_mode_btns[m_key] = m_btn

	_settings_dur_row_box = VBoxContainer.new()
	_settings_dur_row_box.add_theme_constant_override("separation", 6)
	s1_vb.add_child(_settings_dur_row_box)

	var dur_lbl: Label = Label.new()
	dur_lbl.text = "Duração no fechamento automático:"
	dur_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	dur_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	_settings_dur_row_box.add_child(dur_lbl)

	var dur_row: HBoxContainer = HBoxContainer.new()
	dur_row.add_theme_constant_override("separation", 8)
	_settings_dur_row_box.add_child(dur_row)
	_settings_dur_btns.clear()
	var dur_specs: Array[Array] = [
		["short", "Curto (2,5s)"],
		["default", "Padrão (4,5s)"],
		["long", "Longo (7,0s)"]
	]
	for spec: Array in dur_specs:
		var d_key: String = str(spec[0])
		var d_btn: Button = Button.new()
		d_btn.text = str(spec[1])
		d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_btn.pressed.connect(func() -> void: _set_chance_duration_pref(d_key))
		dur_row.add_child(d_btn)
		_settings_dur_btns[d_key] = d_btn

	_settings_note_label = Label.new()
	_settings_note_label.text = "Turnos de bots sempre usam fechamento automático para nunca travar a partida."
	_settings_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_note_label.add_theme_font_size_override("font_size", _fs(11.5))
	_settings_note_label.add_theme_color_override("font_color", Color("#8FA899"))
	s1_vb.add_child(_settings_note_label)

	# --- Seção 2: Conforto e Experiência ---
	var sec2: PanelContainer = PanelContainer.new()
	var sec2_style: StyleBoxFlat = _make_panel_style("#0B1410", "#273C31", 12, 1)
	sec2_style.content_margin_left = 14.0
	sec2_style.content_margin_right = 14.0
	sec2_style.content_margin_top = 12.0
	sec2_style.content_margin_bottom = 12.0
	sec2.add_theme_stylebox_override("panel", sec2_style)
	content_vb.add_child(sec2)

	var s2_vb: VBoxContainer = VBoxContainer.new()
	s2_vb.add_theme_constant_override("separation", 10)
	sec2.add_child(s2_vb)

	var s2_hdr: Label = Label.new()
	s2_hdr.text = "CONFORTO, CÂMERA & RITMO"
	if _bold_font != null:
		s2_hdr.add_theme_font_override("font", _bold_font)
	s2_hdr.add_theme_font_size_override("font_size", _fs(13.0))
	s2_hdr.add_theme_color_override("font_color", Color("#F3C969"))
	s2_vb.add_child(s2_hdr)

	# Ritmo dos Bots
	var bot_lbl: Label = Label.new()
	bot_lbl.text = "Ritmo de jogada dos bots:"
	bot_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	bot_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	s2_vb.add_child(bot_lbl)

	var bot_row: HBoxContainer = HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 8)
	s2_vb.add_child(bot_row)
	_settings_bot_speed_btns.clear()
	var bot_specs: Array[Array] = [
		["calm", "Calmo"],
		["normal", "Normal"],
		["fast", "Rápido"]
	]
	for spec: Array in bot_specs:
		var b_key: String = str(spec[0])
		var b_btn: Button = Button.new()
		b_btn.text = str(spec[1])
		b_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_btn.pressed.connect(func() -> void: _set_global_pref("bot_speed", b_key))
		bot_row.add_child(b_btn)
		_settings_bot_speed_btns[b_key] = b_btn

	# Câmera Isométrica no Peão
	var cam_lbl: Label = Label.new()
	cam_lbl.text = "Câmera isométrica acompanhando o peão:"
	cam_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	cam_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	s2_vb.add_child(cam_lbl)

	var cam_row: HBoxContainer = HBoxContainer.new()
	cam_row.add_theme_constant_override("separation", 8)
	s2_vb.add_child(cam_row)
	_settings_cam_follow_btns.clear()
	var cam_specs: Array[Array] = [
		["on", "Acompanhar Peão"],
		["off", "Enquadramento Fixo"]
	]
	for spec: Array in cam_specs:
		var c_key: String = str(spec[0])
		var c_val: bool = (c_key == "on")
		var c_btn: Button = Button.new()
		c_btn.text = str(spec[1])
		c_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_btn.pressed.connect(func() -> void: _set_global_pref("camera_follow", c_val))
		cam_row.add_child(c_btn)
		_settings_cam_follow_btns[c_key] = c_btn

	# Conforto Visual (Escala de Leitura)
	var scale_lbl: Label = Label.new()
	scale_lbl.text = "Tamanho de leitura dos textos do HUD:"
	scale_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	scale_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	s2_vb.add_child(scale_lbl)

	var scale_row: HBoxContainer = HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 8)
	s2_vb.add_child(scale_row)
	_settings_scale_btns.clear()
	var scale_specs: Array[Array] = [
		["normal", "Padrão (100%)"],
		["large", "Ampliado (114%)"]
	]
	for spec: Array in scale_specs:
		var sc_key: String = str(spec[0])
		var sc_btn: Button = Button.new()
		sc_btn.text = str(spec[1])
		sc_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc_btn.pressed.connect(func() -> void: _set_global_pref("ui_comfort_scale", sc_key))
		scale_row.add_child(sc_btn)
		_settings_scale_btns[sc_key] = sc_btn

	# Avisos Rápidos no Tabuleiro (Toasts)
	var toast_lbl: Label = Label.new()
	toast_lbl.text = "Avisos flutuantes rápidos sobre o tabuleiro:"
	toast_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	toast_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	s2_vb.add_child(toast_lbl)

	var toast_row: HBoxContainer = HBoxContainer.new()
	toast_row.add_theme_constant_override("separation", 8)
	s2_vb.add_child(toast_row)
	_settings_toast_btns.clear()
	var toast_specs: Array[Array] = [
		["on", "Exibir Avisos"],
		["off", "Modo Limpo"]
	]
	for spec: Array in toast_specs:
		var t_key: String = str(spec[0])
		var t_val: bool = (t_key == "on")
		var t_btn: Button = Button.new()
		t_btn.text = str(spec[1])
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_btn.pressed.connect(func() -> void: _set_global_pref("show_event_toasts", t_val))
		toast_row.add_child(t_btn)
		_settings_toast_btns[t_key] = t_btn

	var btn_done: Button = Button.new()
	btn_done.text = "Concluir" if _is_touch_mode else "Concluir [ESC]"
	_apply_button_theme(btn_done, "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), true, _bh(44.0), _fs(14.5), 14.0, true)
	btn_done.pressed.connect(hide_settings_modal)
	vbox.add_child(btn_done)

func apply_preferences(prefs: Dictionary) -> void:
	_prefs_cache = prefs.duplicate(true)
	if not _prefs_cache.has("player_chance_overrides") or not (_prefs_cache["player_chance_overrides"] is Dictionary):
		_prefs_cache["player_chance_overrides"] = {}
	var scale_key: String = str(_prefs_cache.get("ui_comfort_scale", "normal"))
	_comfort_text_scale = 1.14 if scale_key == "large" else 1.0
	_show_event_toasts = bool(_prefs_cache.get("show_event_toasts", true))
	_cached_cam_follow = bool(_prefs_cache.get("camera_follow", true))
	_refresh_cam_follow_button()
	_apply_comfort_text_scale()
	if _settings_overlay != null and _settings_overlay.visible:
		_refresh_settings_ui()

func _apply_comfort_text_scale() -> void:
	var s: float = _comfort_text_scale
	if _hero_name_label != null:
		_hero_name_label.add_theme_font_size_override("font_size", _fs(18.0 * s))
	if _hero_money_label != null:
		_hero_money_label.add_theme_font_size_override("font_size", _fs(19.0 * s))
	if _tile_info_label != null:
		_tile_info_label.add_theme_font_size_override("font_size", _fs(12.0 * s))
	if _ticker_hdr_label != null:
		_ticker_hdr_label.add_theme_font_size_override("font_size", _fs(10.5 * s))
	if _ticker_label != null:
		_ticker_label.add_theme_font_size_override("font_size", _fs(12.0 * s))
	if _log_label != null:
		_log_label.add_theme_font_size_override("font_size", _fs(13.0 * s))
	if _chance_text_label != null:
		_chance_text_label.add_theme_font_size_override("font_size", _fs(17.5 * s))

func show_settings_modal() -> void:
	if _settings_overlay == null:
		return
	_rebuild_settings_target_options()
	_refresh_settings_ui()
	_settings_overlay.visible = true

func hide_settings_modal() -> void:
	if _settings_overlay != null:
		_settings_overlay.visible = false

func _rebuild_settings_target_options() -> void:
	if _settings_target_select == null:
		return
	_settings_target_select.clear()
	_settings_target_select.add_item("Padrão da Partida (Todos os Humanos)")
	_settings_target_select.set_item_metadata(0, "global")

	var human_count: int = 0
	var selected_idx: int = 0
	if _hud_root != null and _hud_root.visible:
		for p: Dictionary in _cached_players:
			if bool(p.get("is_bot", false)):
				continue
			human_count += 1
			var pid_key: String = str(int(p.get("id", 0)))
			_settings_target_select.add_item("Jogador: %s" % str(p.get("name", "Humano")))
			var idx: int = _settings_target_select.item_count - 1
			_settings_target_select.set_item_metadata(idx, pid_key)
			if pid_key == _settings_target_key:
				selected_idx = idx

	if human_count == 0:
		_settings_target_key = "global"
		selected_idx = 0
	_settings_target_row.visible = (human_count > 0)
	_settings_target_select.select(selected_idx)
	var chosen_meta: Variant = _settings_target_select.get_selected_metadata()
	_settings_target_key = str(chosen_meta) if chosen_meta != null else "global"

func _on_settings_target_selected(idx: int) -> void:
	if _settings_target_select == null or idx < 0:
		return
	var meta: Variant = _settings_target_select.get_item_metadata(idx)
	_settings_target_key = str(meta) if meta != null else "global"
	_refresh_settings_ui()

func _style_seg_btn(btn: Button, active: bool) -> void:
	var seg_h: float = _bh(38.0)
	var seg_fs: int = _fs(12.5)
	if active:
		_apply_button_theme(btn, "#234938", "#2C5C47", "#1A372A", "#E9C46A", Color("#FFF6D6"), true, seg_h, seg_fs, 8.0, true)
	else:
		_apply_button_theme(btn, "#15211B", "#1E2E26", "#101914", "#2B4035", Color("#A7BDB0"), false, seg_h, seg_fs, 8.0, false)

func _set_chance_mode_pref(mode_key: String) -> void:
	if _settings_target_key == "global":
		if mode_key == "inherit":
			return
		_prefs_cache["chance_close_mode"] = mode_key
	else:
		var overrides: Dictionary = _prefs_cache.get("player_chance_overrides", {})
		if mode_key == "inherit":
			overrides.erase(_settings_target_key)
		else:
			var existing: Dictionary = {}
			if overrides.has(_settings_target_key) and overrides[_settings_target_key] is Dictionary:
				existing = (overrides[_settings_target_key] as Dictionary).duplicate(true)
			existing["mode"] = mode_key
			if not existing.has("duration"):
				existing["duration"] = str(_prefs_cache.get("chance_auto_duration", "default"))
			overrides[_settings_target_key] = existing
		_prefs_cache["player_chance_overrides"] = overrides
	_refresh_settings_ui()
	settings_updated.emit(_prefs_cache.duplicate(true))

func _set_chance_duration_pref(dur_key: String) -> void:
	if _settings_target_key == "global":
		_prefs_cache["chance_auto_duration"] = dur_key
	else:
		var overrides: Dictionary = _prefs_cache.get("player_chance_overrides", {})
		var existing: Dictionary = {}
		if overrides.has(_settings_target_key) and overrides[_settings_target_key] is Dictionary:
			existing = (overrides[_settings_target_key] as Dictionary).duplicate(true)
		if not existing.has("mode"):
			existing["mode"] = "auto"
		existing["duration"] = dur_key
		overrides[_settings_target_key] = existing
		_prefs_cache["player_chance_overrides"] = overrides
	_refresh_settings_ui()
	settings_updated.emit(_prefs_cache.duplicate(true))

func _set_global_pref(pref_key: String, value: Variant) -> void:
	_prefs_cache[pref_key] = value
	apply_preferences(_prefs_cache)
	settings_updated.emit(_prefs_cache.duplicate(true))

func _refresh_settings_ui() -> void:
	var is_global: bool = (_settings_target_key == "global")
	var active_mode: String = str(_prefs_cache.get("chance_close_mode", "auto"))
	var active_dur: String = str(_prefs_cache.get("chance_auto_duration", "default"))

	if not is_global:
		var overrides: Dictionary = _prefs_cache.get("player_chance_overrides", {})
		if overrides.has(_settings_target_key) and overrides[_settings_target_key] is Dictionary:
			var ov: Dictionary = overrides[_settings_target_key]
			active_mode = str(ov.get("mode", "inherit"))
			active_dur = str(ov.get("duration", active_dur))
		else:
			active_mode = "inherit"

	if _settings_mode_btns.has("inherit"):
		_settings_mode_btns["inherit"].visible = not is_global
	for m_key: String in _settings_mode_btns.keys():
		_style_seg_btn(_settings_mode_btns[m_key], m_key == active_mode)

	var effective_mode: String = active_mode
	if effective_mode == "inherit":
		effective_mode = str(_prefs_cache.get("chance_close_mode", "auto"))
	var dur_enabled: bool = (effective_mode == "auto")
	if _settings_dur_row_box != null:
		_settings_dur_row_box.modulate = Color(1.0, 1.0, 1.0, 1.0) if dur_enabled else Color(0.65, 0.72, 0.68, 0.75)
	for d_key: String in _settings_dur_btns.keys():
		var d_btn: Button = _settings_dur_btns[d_key]
		d_btn.disabled = not dur_enabled
		_style_seg_btn(d_btn, d_key == active_dur)

	var bot_speed: String = str(_prefs_cache.get("bot_speed", "normal"))
	for b_key: String in _settings_bot_speed_btns.keys():
		_style_seg_btn(_settings_bot_speed_btns[b_key], b_key == bot_speed)

	var cam_on: bool = bool(_prefs_cache.get("camera_follow", true))
	for c_key: String in _settings_cam_follow_btns.keys():
		_style_seg_btn(_settings_cam_follow_btns[c_key], (c_key == "on") == cam_on)

	var ui_sc: String = str(_prefs_cache.get("ui_comfort_scale", "normal"))
	for sc_key: String in _settings_scale_btns.keys():
		_style_seg_btn(_settings_scale_btns[sc_key], sc_key == ui_sc)

	var toasts_on: bool = bool(_prefs_cache.get("show_event_toasts", true))
	for t_key: String in _settings_toast_btns.keys():
		_style_seg_btn(_settings_toast_btns[t_key], (t_key == "on") == toasts_on)

# 8. Modal de Carteira / Escrituras do Estanceiro (Adversários ou Próprio Jogador)
func _build_portfolio_modal() -> void:
	_portfolio_overlay = _create_modal_backdrop(hide_player_portfolio_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portfolio_overlay.add_child(center)

	_portfolio_card = PanelContainer.new()
	_portfolio_card.custom_minimum_size = Vector2(640.0 if _is_touch_mode else 580.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#121D17", "#D4AF37", 18, 2)
	card_style.shadow_size = 26
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	_portfolio_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_portfolio_card)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 0)
	_portfolio_card.add_child(card_vbox)

	_portfolio_banner = PanelContainer.new()
	var b_style: StyleBoxFlat = StyleBoxFlat.new()
	b_style.bg_color = Color("#1F4736")
	b_style.corner_radius_top_left = 16
	b_style.corner_radius_top_right = 16
	_portfolio_banner.add_theme_stylebox_override("panel", b_style)
	card_vbox.add_child(_portfolio_banner)

	var bm: MarginContainer = MarginContainer.new()
	bm.add_theme_constant_override("margin_left", 20)
	bm.add_theme_constant_override("margin_right", 20)
	bm.add_theme_constant_override("margin_top", 14)
	bm.add_theme_constant_override("margin_bottom", 14)
	_portfolio_banner.add_child(bm)

	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bm.add_child(header_row)

	var av_sz: float = 52.0 if _is_touch_mode else 46.0
	_portfolio_avatar_frame = PanelContainer.new()
	_portfolio_avatar_frame.custom_minimum_size = Vector2(av_sz, av_sz)
	var af_style: StyleBoxFlat = _make_panel_style("#0D1611", "#FFFDF5", 12, 2)
	af_style.content_margin_left = 3.0
	af_style.content_margin_right = 3.0
	af_style.content_margin_top = 3.0
	af_style.content_margin_bottom = 3.0
	_portfolio_avatar_frame.add_theme_stylebox_override("panel", af_style)
	header_row.add_child(_portfolio_avatar_frame)

	_portfolio_avatar_tex = TextureRect.new()
	_portfolio_avatar_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portfolio_avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portfolio_avatar_frame.add_child(_portfolio_avatar_tex)

	var hdr_info: VBoxContainer = VBoxContainer.new()
	hdr_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_info.add_theme_constant_override("separation", 2)
	header_row.add_child(hdr_info)

	_portfolio_name_label = Label.new()
	_portfolio_name_label.text = "Estanceiro"
	if _bold_font != null:
		_portfolio_name_label.add_theme_font_override("font", _bold_font)
	_portfolio_name_label.add_theme_font_size_override("font_size", _fs(19.0))
	_portfolio_name_label.add_theme_color_override("font_color", Color("#FFFDF5"))
	hdr_info.add_child(_portfolio_name_label)

	_portfolio_meta_label = Label.new()
	_portfolio_meta_label.text = ""
	_portfolio_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_portfolio_meta_label.add_theme_font_size_override("font_size", _fs(12.0))
	_portfolio_meta_label.add_theme_color_override("font_color", Color("#E6F2EC"))
	hdr_info.add_child(_portfolio_meta_label)

	_portfolio_money_label = Label.new()
	_portfolio_money_label.text = "R$ 0"
	_portfolio_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _bold_font != null:
		_portfolio_money_label.add_theme_font_override("font", _bold_font)
	_portfolio_money_label.add_theme_font_size_override("font_size", _fs(19.0))
	_portfolio_money_label.add_theme_color_override("font_color", Color("#FFFDF5"))
	header_row.add_child(_portfolio_money_label)

	var body_m: MarginContainer = MarginContainer.new()
	body_m.add_theme_constant_override("margin_left", 20)
	body_m.add_theme_constant_override("margin_right", 20)
	body_m.add_theme_constant_override("margin_top", 14)
	body_m.add_theme_constant_override("margin_bottom", 18)
	card_vbox.add_child(body_m)

	var body_vb: VBoxContainer = VBoxContainer.new()
	body_vb.add_theme_constant_override("separation", 12)
	body_m.add_child(body_vb)

	_portfolio_monopoly_wrap = VBoxContainer.new()
	_portfolio_monopoly_wrap.add_theme_constant_override("separation", 5)
	_portfolio_monopoly_wrap.visible = false
	body_vb.add_child(_portfolio_monopoly_wrap)

	var mono_hdr: Label = Label.new()
	mono_hdr.text = "GRUPOS COMPLETOS (MONOPÓLIO — ALUGUEL 2×)"
	if _bold_font != null:
		mono_hdr.add_theme_font_override("font", _bold_font)
	mono_hdr.add_theme_font_size_override("font_size", _fs(11.0))
	mono_hdr.add_theme_color_override("font_color", Color("#F5CA5C"))
	_portfolio_monopoly_wrap.add_child(mono_hdr)

	_portfolio_monopoly_box = HFlowContainer.new()
	_portfolio_monopoly_box.add_theme_constant_override("h_separation", 6)
	_portfolio_monopoly_box.add_theme_constant_override("v_separation", 6)
	_portfolio_monopoly_wrap.add_child(_portfolio_monopoly_box)

	var list_hdr: Label = Label.new()
	list_hdr.text = "ESCRITURAS E CONSTRUÇÕES (TOQUE PARA DETALHES)"
	if _bold_font != null:
		list_hdr.add_theme_font_override("font", _bold_font)
	list_hdr.add_theme_font_size_override("font_size", _fs(11.0))
	list_hdr.add_theme_color_override("font_color", Color("#A7C2B2"))
	body_vb.add_child(list_hdr)

	_portfolio_scroll = ScrollContainer.new()
	_portfolio_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portfolio_scroll.custom_minimum_size = Vector2(0.0, 340.0)
	_portfolio_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_portfolio_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_vb.add_child(_portfolio_scroll)

	var scroll_inner: VBoxContainer = VBoxContainer.new()
	scroll_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inner.add_theme_constant_override("separation", 7)
	_portfolio_scroll.add_child(scroll_inner)

	_portfolio_empty_label = Label.new()
	_portfolio_empty_label.text = "Este estanceiro ainda não possui escrituras."
	_portfolio_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portfolio_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_portfolio_empty_label.add_theme_font_size_override("font_size", _fs(13.5))
	_portfolio_empty_label.add_theme_color_override("font_color", Color("#8FA899"))
	scroll_inner.add_child(_portfolio_empty_label)

	_portfolio_list_box = VBoxContainer.new()
	_portfolio_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portfolio_list_box.add_theme_constant_override("separation", 7)
	scroll_inner.add_child(_portfolio_list_box)

	var btn_close: Button = Button.new()
	btn_close.text = "Fechar" if _is_touch_mode else "Fechar [ESC]"
	_apply_button_theme(btn_close, "#213329", "#2E473A", "#17241D", "#D4AF37", Color.WHITE, false, _bh(42.0), _fs(14.0), 14.0, true)
	btn_close.pressed.connect(hide_player_portfolio_modal)
	body_vb.add_child(btn_close)

func show_player_portfolio_modal(info: Dictionary) -> void:
	if _portfolio_overlay == null:
		return
	for ch: Node in _portfolio_monopoly_box.get_children():
		ch.queue_free()
	for ch: Node in _portfolio_list_box.get_children():
		ch.queue_free()

	var p_name: String = str(info.get("name", "Estanceiro"))
	var is_bot: bool = bool(info.get("is_bot", false))
	var is_bankrupt: bool = bool(info.get("is_bankrupt", false))
	var in_jail: bool = bool(info.get("in_jail", false))
	var jail_cards: int = int(info.get("jail_free_cards", 0))
	var money: int = int(info.get("money", 0))
	var pawn_id: String = str(info.get("pawn_id", "cuia"))
	var pawn_name: String = str(info.get("pawn_name", ""))
	var p_color: Color = info.get("color", Color("#2A9D8F"))
	var houses_total: int = int(info.get("houses_total", 0))
	var hotels_total: int = int(info.get("hotels_total", 0))
	var mortgaged_count: int = int(info.get("mortgaged_count", 0))
	var monopolies: Array = info.get("monopolies", [])
	var deeds: Array = info.get("deeds", [])

	var b_style: StyleBoxFlat = StyleBoxFlat.new()
	b_style.bg_color = p_color.darkened(0.22)
	b_style.corner_radius_top_left = 16
	b_style.corner_radius_top_right = 16
	_portfolio_banner.add_theme_stylebox_override("panel", b_style)

	var text_col: Color = Color("#101713") if b_style.bg_color.get_luminance() > 0.52 else Color("#FFFDF5")
	var sub_col: Color = Color("#203028") if b_style.bg_color.get_luminance() > 0.52 else Color("#E4F2EA")
	_portfolio_avatar_tex.texture = _try_load_pawn_art(pawn_id)
	_portfolio_name_label.text = "%s [BOT]" % p_name if is_bot else p_name
	_portfolio_name_label.add_theme_color_override("font_color", text_col)
	_portfolio_money_label.text = "FALIDO" if is_bankrupt else _format_brl(money)
	_portfolio_money_label.add_theme_color_override("font_color", text_col)

	var summary_parts: Array[String] = []
	if pawn_name != "":
		summary_parts.append(pawn_name)
	summary_parts.append("%d escritura(s)" % deeds.size())
	if houses_total > 0 or hotels_total > 0:
		summary_parts.append("%d casa(s) • %d hotel(is)" % [houses_total, hotels_total])
	if mortgaged_count > 0:
		summary_parts.append("%d hipotecada(s)" % mortgaged_count)
	if in_jail:
		summary_parts.append("NO XADREZ")
	if jail_cards > 0:
		summary_parts.append("Carta Livre x%d" % jail_cards)
	_portfolio_meta_label.text = " • ".join(summary_parts)
	_portfolio_meta_label.add_theme_color_override("font_color", sub_col)

	_portfolio_monopoly_wrap.visible = not monopolies.is_empty()
	for m_entry: Variant in monopolies:
		if not (m_entry is Dictionary):
			continue
		var m_dict: Dictionary = m_entry
		var m_group: String = str(m_dict.get("group", ""))
		var m_hex: String = str(m_dict.get("color_hex", "#E9C46A"))
		var badge: PanelContainer = PanelContainer.new()
		var badge_sb: StyleBoxFlat = _make_panel_style("#18281F", "#F5CA5C", 8, 2)
		badge_sb.border_width_left = 7
		badge_sb.border_color = Color(m_hex)
		badge_sb.content_margin_left = 10.0
		badge_sb.content_margin_right = 10.0
		badge_sb.content_margin_top = 4.0
		badge_sb.content_margin_bottom = 4.0
		badge.add_theme_stylebox_override("panel", badge_sb)
		var b_lbl: Label = Label.new()
		b_lbl.text = "★ %s" % m_group
		if _bold_font != null:
			b_lbl.add_theme_font_override("font", _bold_font)
		b_lbl.add_theme_font_size_override("font_size", _fs(11.5))
		b_lbl.add_theme_color_override("font_color", Color("#FFF3C4"))
		badge.add_child(b_lbl)
		_portfolio_monopoly_box.add_child(badge)

	_portfolio_empty_label.visible = deeds.is_empty()
	for d_entry: Variant in deeds:
		if not (d_entry is Dictionary):
			continue
		var d: Dictionary = d_entry
		var tid: int = int(d.get("tile_index", -1))
		var d_name: String = str(d.get("name", "Propriedade"))
		var d_hex: String = str(d.get("color_hex", "#4EA8DE"))
		var d_group: String = str(d.get("group", ""))
		var b_lvl: int = int(d.get("building_level", 0))
		var is_mort: bool = bool(d.get("is_mortgaged", false))
		var has_mono: bool = bool(d.get("has_monopoly", false))
		var rent_txt: String = str(d.get("rent_text", ""))

		var row_card: PanelContainer = PanelContainer.new()
		var rc_sb: StyleBoxFlat = _make_panel_style("#16231C" if not is_mort else "#23191B", "#F5CA5C" if has_mono else "#283D32", 10, 2 if has_mono else 1)
		rc_sb.border_width_left = 9
		rc_sb.border_color = Color(d_hex)
		rc_sb.content_margin_left = 12.0
		rc_sb.content_margin_right = 12.0
		rc_sb.content_margin_top = 8.0
		rc_sb.content_margin_bottom = 8.0
		row_card.add_theme_stylebox_override("panel", rc_sb)
		row_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tile_ref: int = tid
		row_card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton:
				var mb: InputEventMouseButton = ev
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and tile_ref >= 0:
					inspect_tile_requested.emit(tile_ref)
		)
		_portfolio_list_box.add_child(row_card)

		var r_hb: HBoxContainer = HBoxContainer.new()
		r_hb.add_theme_constant_override("separation", 10)
		r_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		r_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_card.add_child(r_hb)

		var left_vb: VBoxContainer = VBoxContainer.new()
		left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_vb.add_theme_constant_override("separation", 2)
		left_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r_hb.add_child(left_vb)

		var title_lbl: Label = Label.new()
		title_lbl.text = d_name
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _bold_font != null:
			title_lbl.add_theme_font_override("font", _bold_font)
		title_lbl.add_theme_font_size_override("font_size", _fs(13.5))
		title_lbl.add_theme_color_override("font_color", Color("#C9A5A8") if is_mort else Color("#FFFDF5"))
		left_vb.add_child(title_lbl)

		var sub_parts: Array[String] = []
		if d_group != "":
			sub_parts.append(d_group)
		if rent_txt != "":
			sub_parts.append(rent_txt)
		var sub_lbl: Label = Label.new()
		sub_lbl.text = " • ".join(sub_parts)
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_lbl.add_theme_font_size_override("font_size", _fs(11.5))
		sub_lbl.add_theme_color_override("font_color", Color("#9CB6A7"))
		left_vb.add_child(sub_lbl)

		var status_hb: HBoxContainer = HBoxContainer.new()
		status_hb.add_theme_constant_override("separation", 6)
		status_hb.alignment = BoxContainer.ALIGNMENT_END
		status_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r_hb.add_child(status_hb)

		if is_mort:
			status_hb.add_child(_make_status_pill("HIPOTECADA", "#4A1E22", "#FF6B6B", Color("#FFD0D0")))
		elif b_lvl >= 5:
			status_hb.add_child(_make_status_pill("HOTEL", "#52161E", "#F5CA5C", Color("#FFE89E")))
		elif b_lvl > 0:
			var c_txt: String = "1 CASA" if b_lvl == 1 else "%d CASAS" % b_lvl
			status_hb.add_child(_make_status_pill(c_txt, "#163D2C", "#52B788", Color("#B7FFD6")))
		elif has_mono:
			status_hb.add_child(_make_status_pill("★ 2×", "#3A2F12", "#F5CA5C", Color("#FFF3C4")))
		else:
			status_hb.add_child(_make_status_pill("TERRENO" if str(d.get("tile_type", "")) == "PROPERTY" else "CIA", "#192620", "#355043", Color("#B5C9BD")))

	_portfolio_overlay.visible = true

func _make_status_pill(txt: String, bg_hex: String, border_hex: String, text_col: Color) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = _make_panel_style(bg_hex, border_hex, 6, 1)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override("panel", sb)
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _bold_font != null:
		lbl.add_theme_font_override("font", _bold_font)
	lbl.add_theme_font_size_override("font_size", _fs(10.5))
	lbl.add_theme_color_override("font_color", text_col)
	pill.add_child(lbl)
	return pill

func hide_player_portfolio_modal() -> void:
	if _portfolio_overlay != null:
		_portfolio_overlay.visible = false

func hide_all_modals() -> void:
	hide_chance_card_modal(true)
	hide_player_portfolio_modal()
	hide_settings_modal()
	hide_deed_modal()
	hide_trade_modal()
	hide_pause_modal()
	hide_help_modal()
	hide_victory_modal()
	hide_event_toast()

func hide_event_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	if _toast_panel != null:
		_toast_panel.visible = false

func show_event_toast(title: String, detail: String, tone: String = "positive") -> void:
	if not _show_event_toasts:
		return
	if _toast_panel == null or not is_inside_tree():
		return
	if _hud_root != null and not _hud_root.visible:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	var border_hex: String = "#52B788"
	var bg_col: Color = Color(0.07, 0.16, 0.11, 0.94)
	var title_hex: String = "#A8FF78"
	match tone:
		"negative":
			border_hex = "#FF6B6B"
			bg_col = Color(0.20, 0.08, 0.09, 0.94)
			title_hex = "#FF9999"
		"chance":
			border_hex = "#F5CA5C"
			bg_col = Color(0.16, 0.14, 0.06, 0.95)
			title_hex = "#FFE28A"
		"build":
			border_hex = "#FFD166"
			bg_col = Color(0.08, 0.18, 0.13, 0.95)
			title_hex = "#FFE28A"
		"turn":
			border_hex = "#4EA8DE"
			bg_col = Color(0.07, 0.13, 0.19, 0.92)
			title_hex = "#9BE0FF"
		_:
			border_hex = "#52B788"
			bg_col = Color(0.07, 0.16, 0.11, 0.94)
			title_hex = "#A8FF78"

	_toast_style.border_color = Color(border_hex)
	_toast_style.bg_color = bg_col
	_toast_title_label.text = title
	_toast_title_label.add_theme_color_override("font_color", Color(title_hex))
	_toast_detail_label.text = detail
	_toast_detail_label.visible = (detail != "")

	_layout_event_toast()
	var base_y: float = _last_board_rect.position.y + 58.0
	_toast_panel.position.y = base_y - 12.0
	_toast_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_toast_panel.visible = true

	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "position:y", base_y, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.14)
	_toast_tween.chain().tween_interval(1.30)
	_toast_tween.chain().tween_property(_toast_panel, "modulate:a", 0.0, 0.22)
	_toast_tween.chain().tween_callback(func() -> void:
		if _toast_panel != null:
			_toast_panel.visible = false
	)

# --- Ações da Aba Escrituras ---

func _on_build_pressed() -> void:
	if _cached_selected_tile >= 0:
		build_pressed.emit(_cached_selected_tile)

func _on_sell_building_pressed() -> void:
	if _cached_selected_tile >= 0:
		sell_building_pressed.emit(_cached_selected_tile)

func _on_mortgage_pressed() -> void:
	if _cached_selected_tile >= 0:
		mortgage_pressed.emit(_cached_selected_tile)

func _on_inspect_selected_pressed() -> void:
	if _cached_selected_tile >= 0:
		inspect_tile_requested.emit(_cached_selected_tile)

func set_round_info(round_num: int, is_market_cycle: bool) -> void:
	if _round_label == null or _round_badge_style == null:
		return
	var safe_round: int = maxi(1, round_num)
	if is_market_cycle:
		_round_label.text = "ROD. %d ★" % safe_round
		_round_badge_style.bg_color = Color("#342A12")
		_round_badge_style.border_color = Color("#F5CA5C")
		_round_label.add_theme_color_override("font_color", Color("#FFF3C4"))
		if _round_badge != null:
			_round_badge.tooltip_text = "Rodada %d • Feira de Negócios: maior estímulo a trocas e construções" % safe_round
	else:
		_round_label.text = "ROD. %d" % safe_round
		_round_badge_style.bg_color = Color("#182820")
		_round_badge_style.border_color = Color("#3B5949")
		_round_label.add_theme_color_override("font_color", Color("#D8ECE0"))
		if _round_badge != null:
			_round_badge.tooltip_text = "Rodada %d (avança quando todos os jogadores ativos completam sua vez)" % safe_round

func set_camera_mode_label(is_2d: bool) -> void:
	_cached_is_2d_cam = is_2d
	if _btn_camera != null:
		if _is_touch_mode:
			_btn_camera.text = "Vista 2D" if is_2d else "Vista 3D"
		else:
			_btn_camera.text = "Vista 2D [Tab]" if is_2d else "Vista 3D [Tab]"
	_refresh_cam_follow_button()

func set_camera_follow_label(enabled: bool) -> void:
	_cached_cam_follow = enabled
	_refresh_cam_follow_button()

func _refresh_cam_follow_button() -> void:
	if _btn_cam_follow == null:
		return
	var qb_h: float = _bh(34.0)
	var qb_fs: int = _fs(12.0)
	if _cached_is_2d_cam:
		_btn_cam_follow.text = "2D Fixa"
		_btn_cam_follow.disabled = true
	else:
		_btn_cam_follow.disabled = false
		if _cached_cam_follow:
			_btn_cam_follow.text = "Foco Auto"
			_apply_button_theme(_btn_cam_follow, "#1B362E", "#264C40", "#132620", "#52B788", Color("#D8FFE8"), false, qb_h, qb_fs, 10.0, true)
		else:
			_btn_cam_follow.text = "Foco Fixo"
			_apply_button_theme(_btn_cam_follow, "#202A25", "#2B3A33", "#161E1A", "#5A6F64", Color("#BFD1C7"), false, qb_h, qb_fs, 10.0, true)

func clear_log() -> void:
	if _log_label != null:
		_log_label.text = ""
	if _ticker_label != null:
		_ticker_label.text = "Partida iniciada! Aguardando a primeira jogada."

func push_log(msg: String) -> void:
	if _log_label == null:
		return
	var current_lines: PackedStringArray = _log_label.text.split("\n", false)
	current_lines.append("• " + msg)
	if current_lines.size() > 48:
		current_lines = current_lines.slice(current_lines.size() - 48, current_lines.size())
	_log_label.text = "\n".join(current_lines)
	if _ticker_label != null:
		var recent_count: int = mini(10, current_lines.size())
		var recent_slice: PackedStringArray = current_lines.slice(current_lines.size() - recent_count, current_lines.size())
		_ticker_label.text = "\n".join(recent_slice)
	call_deferred("_scroll_log_to_bottom")

func _scroll_log_to_bottom() -> void:
	if _log_scroll != null:
		var vbar: VScrollBar = _log_scroll.get_v_scroll_bar()
		if vbar != null:
			_log_scroll.scroll_vertical = roundi(vbar.max_value)
	if _ticker_scroll != null:
		var t_vbar: VScrollBar = _ticker_scroll.get_v_scroll_bar()
		if t_vbar != null:
			_ticker_scroll.scroll_vertical = roundi(t_vbar.max_value)

# --- Atualização Completa do HUD ---

func refresh_hud(
	players: Array[Dictionary],
	current_idx: int,
	tiles: Array[Dictionary],
	player_colors: Dictionary[int, Color],
	state_name: String,
	tile_info: String,
	houses_left: int,
	hotels_left: int,
	is_bot_turn: bool,
	primary_action: String,
	can_roll: bool,
	can_buy: bool,
	buy_label: String,
	can_decline: bool,
	can_bail: bool,
	bail_label: String,
	can_use_jail_card: bool,
	jail_card_label: String,
	owned_options: Array[Dictionary],
	selected_tile_idx: int,
	can_build: bool,
	build_label: String,
	can_sell_building: bool,
	sell_building_label: String,
	can_mortgage: bool,
	mortgage_label: String,
	can_trade: bool,
	can_end: bool
) -> void:
	_cached_players = players
	_cached_current_idx = current_idx
	_cached_tiles = tiles
	_cached_player_colors = player_colors
	_cached_owned_options = owned_options
	_cached_selected_tile = selected_tile_idx

	var live_vp_size: Vector2 = _get_effective_viewport_size()
	if live_vp_size.x >= 320.0 and live_vp_size.y >= 240.0 and not live_vp_size.is_equal_approx(_last_layout_vp_size):
		_update_responsive_layout()

	var has_active: bool = current_idx >= 0 and current_idx < players.size()
	var active_money: int = 0
	var active_name: String = "-"
	var active_in_jail: bool = false
	var active_pid: int = -1
	var active_is_real_bot: bool = false

	if has_active:
		var active_p: Dictionary = players[current_idx]
		active_pid = int(active_p.get("id", current_idx))
		var active_col: Color = player_colors.get(active_pid, Color("#FFCA3A"))
		active_name = str(active_p.get("name", "-"))
		active_is_real_bot = bool(active_p.get("is_bot", false))
		var active_tag: String = _format_player_net_tag(active_p)
		active_money = int(active_p.get("money", 0))
		var active_pawn_id: String = str(active_p.get("pawn_id", "cuia"))
		var active_pawn_name: String = str(active_p.get("pawn_name", ""))
		active_in_jail = bool(active_p.get("in_jail", false)) and not bool(active_p.get("bankrupt", false))

		_hero_accent_style.bg_color = active_col
		_hero_avatar_frame_style.border_color = active_col
		_hero_avatar_tex.texture = _try_load_pawn_art(active_pawn_id)

		_hero_name_label.text = "%s%s" % [active_name, active_tag]
		_hero_name_label.add_theme_color_override("font_color", Color("#90E0EF") if (active_is_real_bot or is_bot_turn) else Color("#FFFDF5"))

		_hero_money_label.text = _format_brl(active_money)
		_hero_money_label.add_theme_color_override("font_color", Color("#FF758F") if active_money < 0 else Color("#7BF1A8"))

		_hero_phase_label.text = state_name.to_upper()
		if active_is_real_bot or is_bot_turn:
			_hero_phase_badge_style.bg_color = Color("#163547")
			_hero_phase_badge_style.border_color = Color("#4EA8DE")
			_hero_phase_label.add_theme_color_override("font_color", Color("#D8F3FF"))
		elif active_in_jail:
			_hero_phase_badge_style.bg_color = Color("#4D2E1B")
			_hero_phase_badge_style.border_color = Color("#F3C969")
			_hero_phase_label.add_theme_color_override("font_color", Color("#FFF3D1"))
		else:
			_hero_phase_badge_style.bg_color = Color("#1F4736")
			_hero_phase_badge_style.border_color = Color("#52B788")
			_hero_phase_label.add_theme_color_override("font_color", Color("#E8FFF2"))

		var pawn_status_suffix: String = " • XADREZ" if active_in_jail else ""
		_hero_pawn_name_label.text = "%s%s" % [active_pawn_name, pawn_status_suffix]
		_hero_pawn_name_label.add_theme_color_override("font_color", Color("#F8D568") if active_in_jail else Color("#BDD3C6"))
	else:
		_hero_name_label.text = "-"
		_hero_money_label.text = "R$ 0"
		_hero_phase_label.text = state_name.to_upper()
		_hero_pawn_name_label.text = ""

	_refresh_net_identity_banner(players, active_pid)

	_bank_label.text = "%dC • %dH" % [houses_left, hotels_left]
	_tile_info_label.text = tile_info

	# Atualizar badges das abas
	if _tab_buttons.size() >= 3:
		_tab_buttons[TAB_PLAYERS].text = "Estanceiros (%d)" % players.size()
		_tab_buttons[TAB_DEEDS].text = "Escrituras (%d)" % owned_options.size()
		_tab_buttons[TAB_LOG].text = "Diário"

	_rebuild_players_list(players, current_idx, player_colors, is_bot_turn)
	_rebuild_deeds_list(owned_options, selected_tile_idx, tiles, is_bot_turn)

	# Atualizar botões da Aba Escrituras
	var lock_controls: bool = is_bot_turn
	_deeds_action_box.visible = not owned_options.is_empty()
	_btn_build.text = build_label
	_btn_build.disabled = lock_controls or not can_build
	_btn_sell_building.text = sell_building_label
	_btn_sell_building.disabled = lock_controls or not can_sell_building
	_btn_mortgage.text = mortgage_label
	_btn_mortgage.disabled = lock_controls or not can_mortgage
	_btn_inspect_selected.disabled = (selected_tile_idx < 0)

	# Dock Contextual Inferior (sempre visível, com altura válida e atalhos claros no desktop)
	if _dock_card != null:
		_dock_card.visible = true
	_bot_banner.visible = is_bot_turn and has_active
	_human_dock_vbox.visible = not is_bot_turn
	_primary_action_row.visible = not is_bot_turn
	_secondary_action_row.visible = not is_bot_turn
	if is_bot_turn and has_active:
		if _net_wait_text != "":
			_bot_banner_label.text = _net_wait_text
		elif active_is_real_bot:
			_bot_banner_label.text = "%s [BOT] está jogando..." % active_name
		else:
			_bot_banner_label.text = "Aguardando %s..." % active_name

	_jail_row.visible = (not is_bot_turn) and active_in_jail
	_btn_bail.text = bail_label if _is_touch_mode else "%s [F]" % bail_label
	_btn_bail.disabled = lock_controls or not can_bail
	_btn_jail_card.text = jail_card_label if _is_touch_mode else "%s [L]" % jail_card_label
	_btn_jail_card.disabled = lock_controls or not can_use_jail_card

	var show_eval_pair: bool = can_decline or can_buy
	var show_roll_main: bool = can_roll and not show_eval_pair

	_btn_roll.visible = show_roll_main
	_btn_roll.text = "Rolar Dados" if _is_touch_mode else "Rolar Dados [Espaço]"
	_btn_roll.disabled = lock_controls or not can_roll

	_btn_buy.visible = show_eval_pair
	_btn_buy.text = buy_label if _is_touch_mode else "%s [C]" % buy_label
	_btn_buy.disabled = lock_controls or not can_buy

	_btn_decline.visible = show_eval_pair
	_btn_decline.text = "Recusar" if _is_touch_mode else "Recusar [R]"
	_btn_decline.disabled = lock_controls or not can_decline

	_btn_end_turn.visible = (not show_roll_main) and (not show_eval_pair)
	_btn_end_turn.disabled = lock_controls or not can_end

	if active_money < 0 and _btn_end_turn.visible:
		_btn_end_turn.text = "Encerrar (Falência)"
	elif _btn_end_turn.visible and not can_end and not is_bot_turn:
		_btn_end_turn.text = "Aguarde..."
	elif primary_action == "END_TURN" and _btn_end_turn.visible:
		_btn_end_turn.text = "Passar a Vez" if _is_touch_mode else "Passar a Vez [E]"
	else:
		_btn_end_turn.text = "Passar a Vez" if _is_touch_mode else "Passar a Vez [E]"

	_btn_trade_open.text = "Negociar" if _is_touch_mode else "Negociar [N]"
	_btn_trade_open.disabled = lock_controls or not can_trade
	if lock_controls or not can_trade:
		hide_trade_modal()

	if active_money < 0 and not owned_options.is_empty():
		_btn_deeds_jump.text = "Quitar Dívida (%d)" % owned_options.size()
		_apply_button_theme(_btn_deeds_jump, "#592822", "#75352D", "#401C18", "#FF758F", Color("#FFE8E8"), true, _bh(38.0), _fs(13.0), 10.0, true)
	else:
		_btn_deeds_jump.text = "Escrituras (%d)" % owned_options.size()
		_apply_button_theme(_btn_deeds_jump, "#1B2E25", "#254033", "#13211A", "#52B788", Color("#E9F5EE"), false, _bh(38.0), _fs(13.0), 10.0, true)

func set_network_identity(is_online: bool, is_host: bool, local_peer_id: int, local_player_id: int, wait_text: String, transport_label: String = "ONLINE", room_code: String = "") -> void:
	_net_is_online = is_online
	_net_is_host = is_host
	_net_local_peer_id = local_peer_id
	_net_local_player_id = local_player_id
	_net_wait_text = wait_text
	_net_transport_label = transport_label if transport_label != "" else "ONLINE"
	_net_room_code = room_code.strip_edges().to_upper()
	if _net_identity_bar != null:
		_net_identity_bar.visible = _net_is_online
	if _pause_restart_btn != null:
		_pause_restart_btn.visible = (not _net_is_online) or _net_is_host
		_pause_restart_btn.disabled = _net_is_online and not _net_is_host
	if _pause_menu_btn != null:
		if _net_is_online:
			_pause_menu_btn.text = "Encerrar Sala Online" if _net_is_host else "Sair da Sala Online"
		else:
			_pause_menu_btn.text = "Voltar à Tela Inicial"
	if _victory_replay_btn != null:
		_victory_replay_btn.visible = (not _net_is_online) or _net_is_host
		_victory_replay_btn.disabled = _net_is_online and not _net_is_host

func _refresh_net_identity_banner(players: Array[Dictionary], active_pid: int) -> void:
	if _net_identity_bar == null or _net_identity_label == null or _net_identity_style == null:
		return
	_net_identity_bar.visible = _net_is_online
	if not _net_is_online:
		return
	var local_name: String = "Jogador"
	for p: Dictionary in players:
		if int(p.get("id", -1)) == _net_local_player_id:
			local_name = str(p.get("name", "Jogador"))
			break
	var role_lbl: String = "HOST" if _net_is_host else "CLIENTE"
	var code_part: String = " • SALA %s" % _net_room_code if _net_room_code != "" else ""
	var is_my_turn: bool = (_net_local_player_id >= 0 and active_pid == _net_local_player_id and _net_wait_text == "")
	if is_my_turn:
		_net_identity_label.text = "%s (%s)%s • SUA VEZ! (%s)" % [_net_transport_label, role_lbl, code_part, local_name]
		_net_identity_style.bg_color = Color("#1B4735")
		_net_identity_style.border_color = Color("#52B788")
		_net_identity_label.add_theme_color_override("font_color", Color("#D8FFE8"))
	else:
		_net_identity_label.text = "%s (%s)%s • Você: %s" % [_net_transport_label, role_lbl, code_part, local_name]
		_net_identity_style.bg_color = Color("#132C3C")
		_net_identity_style.border_color = Color("#4EA8DE")
		_net_identity_label.add_theme_color_override("font_color", Color("#C9F2FF"))

func _format_player_net_tag(p: Dictionary) -> String:
	if bool(p.get("is_bot", false)):
		return " [BOT]"
	if not _net_is_online:
		return ""
	var pid: int = int(p.get("id", -1))
	var p_peer: int = int(p.get("peer_id", 0))
	if pid == _net_local_player_id and _net_local_player_id >= 0:
		return " [VOCÊ • HOST]" if _net_is_host else " [VOCÊ]"
	if p_peer == 1:
		return " [HOST]"
	if p_peer > 1:
		return " [ONLINE]"
	return ""

func _get_player_monopoly_groups(player: Dictionary, tiles: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	var owned_props: Array = player.get("properties", [])
	if owned_props.is_empty() or tiles.is_empty():
		return result
	var group_totals: Dictionary[String, int] = {}
	var group_owned: Dictionary[String, int] = {}
	for i: int in range(tiles.size()):
		var t: Dictionary = tiles[i]
		if str(t.get("type", "")) != "PROPERTY":
			continue
		var g: String = str(t.get("group", ""))
		if g == "":
			continue
		group_totals[g] = group_totals.get(g, 0) + 1
	for p_idx: Variant in owned_props:
		var tid: int = int(p_idx)
		if tid >= 0 and tid < tiles.size():
			var t: Dictionary = tiles[tid]
			if str(t.get("type", "")) == "PROPERTY":
				var g: String = str(t.get("group", ""))
				if g != "":
					group_owned[g] = group_owned.get(g, 0) + 1
	for g: String in group_totals.keys():
		if group_owned.get(g, 0) >= group_totals[g] and group_totals[g] > 0:
			result.append(g)
	return result

func _rebuild_players_list(players: Array[Dictionary], current_idx: int, player_colors: Dictionary[int, Color], is_bot_turn: bool) -> void:
	for child: Node in _players_box.get_children():
		child.queue_free()

	var mini_dim: float = 34.0 if _is_touch_mode else 28.0
	for i: int in range(players.size()):
		var p: Dictionary = players[i]
		var pid: int = int(p["id"])
		var p_col: Color = player_colors.get(pid, Color.WHITE)
		var is_active: bool = (i == current_idx)
		var is_bankrupt: bool = bool(p.get("bankrupt", false))
		var p_money: int = int(p["money"])
		var props: Array = p.get("properties", [])
		var props_count: int = props.size()
		var mono_groups: Array[String] = _get_player_monopoly_groups(p, _cached_tiles)

		var card: PanelContainer = PanelContainer.new()
		var bg_hex: String = "#1B2E24" if is_active else "#111A15"
		var bdr_col: Color = p_col if is_active else Color("#24362C")
		var sb: StyleBoxFlat = _make_panel_style(bg_hex, "#24362C", 10, 2 if is_active else 1)
		sb.border_color = bdr_col
		sb.content_margin_left = 8.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 6.0
		card.add_theme_stylebox_override("panel", sb)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.tooltip_text = "Toque para inspecionar escrituras, construções e monopólios"
		var inspected_pid: int = pid
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton:
				var mb: InputEventMouseButton = ev
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
					player_inspected.emit(inspected_pid)
		)
		_players_box.add_child(card)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)

		var icon_panel: PanelContainer = PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(mini_dim, mini_dim)
		icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_sb: StyleBoxFlat = _make_panel_style("#0B130F", "#D4AF37", 8, 2)
		icon_sb.border_color = p_col
		icon_sb.content_margin_left = 2.0
		icon_sb.content_margin_right = 2.0
		icon_sb.content_margin_top = 2.0
		icon_sb.content_margin_bottom = 2.0
		icon_panel.add_theme_stylebox_override("panel", icon_sb)
		row.add_child(icon_panel)

		var icon_tex: TextureRect = TextureRect.new()
		icon_tex.texture = _try_load_pawn_art(str(p.get("pawn_id", "cuia")))
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(icon_tex)

		var info_vb: VBoxContainer = VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.add_theme_constant_override("separation", 1)
		info_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info_vb)

		var role_tag: String = _format_player_net_tag(p)
		var is_local_me: bool = _net_is_online and (not bool(p.get("is_bot", false))) and (pid == _net_local_player_id)
		var name_lbl: Label = Label.new()
		name_lbl.text = "%s%s" % [str(p["name"]), role_tag]
		name_lbl.clip_text = true
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if (is_active or is_local_me) and _bold_font != null:
			name_lbl.add_theme_font_override("font", _bold_font)
		name_lbl.add_theme_font_size_override("font_size", _fs(13.0))
		if is_bankrupt:
			name_lbl.add_theme_color_override("font_color", Color("#73827A"))
		elif is_active:
			name_lbl.add_theme_color_override("font_color", Color("#90E0EF") if is_bot_turn else Color("#FFFDF5"))
		elif is_local_me:
			name_lbl.add_theme_color_override("font_color", Color("#9CF6B8"))
		else:
			name_lbl.add_theme_color_override("font_color", Color("#E4EFE8"))
		info_vb.add_child(name_lbl)

		var tags: Array[String] = []
		if is_bankrupt:
			tags.append("FALIDO")
		else:
			tags.append("%d esc." % props_count)
			if not mono_groups.is_empty():
				tags.append("★ %d mon." % mono_groups.size())
			if bool(p.get("in_jail", false)):
				tags.append("XADREZ")
			var jc: int = int(p.get("jail_free_cards", 0))
			if jc > 0:
				tags.append("Livre x%d" % jc)

		var sub_lbl: Label = Label.new()
		sub_lbl.text = " • ".join(tags)
		sub_lbl.clip_text = true
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_lbl.add_theme_font_size_override("font_size", _fs(10.5))
		sub_lbl.add_theme_color_override("font_color", Color("#F3C969") if (bool(p.get("in_jail", false)) or not mono_groups.is_empty()) else Color("#95AE9F"))
		info_vb.add_child(sub_lbl)

		# Faixa visual instantânea dos grupos de cor/companhias possuídos (com borda dourada para monopólio completo)
		if not is_bankrupt and props_count > 0:
			var chips_flow: HFlowContainer = HFlowContainer.new()
			chips_flow.add_theme_constant_override("h_separation", 4)
			chips_flow.add_theme_constant_override("v_separation", 3)
			chips_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var max_chips: int = mini(14, props_count)
			for c_idx: int in range(max_chips):
				var tid: int = int(props[c_idx])
				var chip_hex: String = "#4EA8DE"
				var chip_group: String = ""
				if tid >= 0 and tid < _cached_tiles.size():
					var t_data: Dictionary = _cached_tiles[tid]
					chip_group = str(t_data.get("group", ""))
					var col_str: String = str(t_data.get("color", ""))
					if col_str != "":
						chip_hex = col_str
				var is_mono_chip: bool = (chip_group != "") and (chip_group in mono_groups)
				var chip: Panel = Panel.new()
				chip.custom_minimum_size = Vector2(14.0 if _is_touch_mode else 11.0, 9.0 if _is_touch_mode else 7.0)
				chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var chip_sb: StyleBoxFlat = StyleBoxFlat.new()
				chip_sb.bg_color = Color(chip_hex)
				chip_sb.border_color = Color("#FFD166") if is_mono_chip else Color("#0A120E")
				chip_sb.set_border_width_all(2 if is_mono_chip else 1)
				chip_sb.set_corner_radius_all(2)
				chip.add_theme_stylebox_override("panel", chip_sb)
				chips_flow.add_child(chip)
			if props_count > max_chips:
				var more_lbl: Label = Label.new()
				more_lbl.text = "+%d" % (props_count - max_chips)
				more_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				more_lbl.add_theme_font_size_override("font_size", _fs(9.5))
				more_lbl.add_theme_color_override("font_color", Color("#A7C2B2"))
				chips_flow.add_child(more_lbl)
			info_vb.add_child(chips_flow)

		var cash_lbl: Label = Label.new()
		cash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cash_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
		cash_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cash_lbl.text = "Falido" if is_bankrupt else _format_brl(p_money)
		if _bold_font != null:
			cash_lbl.add_theme_font_override("font", _bold_font)
		cash_lbl.add_theme_font_size_override("font_size", _fs(13.5))
		if is_bankrupt:
			cash_lbl.add_theme_color_override("font_color", Color("#73827A"))
		elif p_money < 0:
			cash_lbl.add_theme_color_override("font_color", Color("#FF758F"))
		elif is_active:
			cash_lbl.add_theme_color_override("font_color", Color("#A8FF78"))
		else:
			cash_lbl.add_theme_color_override("font_color", Color("#CBE0D3"))
		row.add_child(cash_lbl)

		var chevron_lbl: Label = Label.new()
		chevron_lbl.text = "›"
		chevron_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chevron_lbl.add_theme_font_size_override("font_size", _fs(15.0))
		chevron_lbl.add_theme_color_override("font_color", Color("#8EA89A"))
		row.add_child(chevron_lbl)

func _rebuild_deeds_list(owned_options: Array[Dictionary], selected_tile_idx: int, tiles: Array[Dictionary], is_bot_turn: bool) -> void:
	for child: Node in _deeds_list_box.get_children():
		child.queue_free()

	_deeds_empty_label.visible = owned_options.is_empty()
	if owned_options.is_empty():
		return

	var item_h: float = _bh(42.0)
	for opt: Dictionary in owned_options:
		var tid: int = int(opt["tile_index"])
		var label_str: String = str(opt["label"])
		var is_sel: bool = (tid == selected_tile_idx)
		var stripe_hex: String = "#365C4E"
		if tid >= 0 and tid < tiles.size():
			var c_hex: String = str(tiles[tid].get("color", ""))
			if c_hex != "":
				stripe_hex = c_hex

		var row_btn: Button = Button.new()
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_btn.custom_minimum_size = Vector2(0.0, item_h)
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.clip_text = true
		row_btn.text = ("▸ %s" if is_sel else "  %s") % label_str
		row_btn.disabled = is_bot_turn
		row_btn.focus_mode = Control.FOCUS_NONE
		row_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if is_sel and _bold_font != null:
			row_btn.add_theme_font_override("font", _bold_font)
		row_btn.add_theme_font_size_override("font_size", _fs(12.5))
		row_btn.add_theme_color_override("font_color", Color("#FFFDF5") if is_sel else Color("#D5E4DB"))

		var sb: StyleBoxFlat = _make_panel_style("#1E3429" if is_sel else "#111A15", "#E9C46A" if is_sel else "#26382E", 9, 2 if is_sel else 1)
		sb.border_width_left = 8
		sb.border_color = Color(stripe_hex)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		row_btn.add_theme_stylebox_override("normal", sb)
		var sb_hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color("#254234")
		row_btn.add_theme_stylebox_override("hover", sb_hover)
		row_btn.add_theme_stylebox_override("pressed", sb_hover)
		row_btn.add_theme_stylebox_override("focus", sb_hover)

		var tile_ref: int = tid
		row_btn.pressed.connect(func() -> void: property_selected.emit(tile_ref))
		_deeds_list_box.add_child(row_btn)
