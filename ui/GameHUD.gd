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
signal build_cart_applied(target_levels: Dictionary)
signal end_turn_pressed
signal trade_executed(target_id: int, offer_tile: int, request_tile: int, cash_delta: int, rent_waiver_rounds: int)
signal trade_offer_responded(offer_id: int, accepted: bool)
signal auction_bid_submitted(bid_amount: int)
signal auction_pass_submitted
signal auction_owned_requested(tile_index: int)
signal leave_to_bot_requested
signal forfeit_match_requested
signal menu_requested
signal restart_match_requested
signal quit_game_requested
signal trophies_requested
signal camera_toggle_requested
signal camera_follow_toggle_requested
signal camera_reset_requested
signal camera_zoom_in_requested
signal camera_zoom_out_requested
signal inspect_tile_requested(tile_index: int)
signal player_inspected(player_id: int)
signal board_layout_updated(board_rect: Rect2)
signal settings_updated(settings_data: Dictionary)
signal chance_card_dismissed

const UIStyleTokens = preload("res://ui/shared/UIStyleTokens.gd")
const PlatformProfileAdapter = preload("res://ui/shared/PlatformProfileAdapter.gd")
const TradeAndAuctionHelper = preload("res://ui/shared/TradeAndAuctionHelper.gd")
const ConstructionCartHelper = preload("res://ui/shared/ConstructionCartHelper.gd")

const STATUS_BG_DEFAULT: Color = Color(UIStyleTokens.BG_STATUS_DEFAULT)
const STATUS_BORDER_DEFAULT: Color = Color(UIStyleTokens.BORDER_GOLD)

const TAB_PLAYERS: int = 0
const TAB_LOG: int = 1

var _profile_adapter: RefCounted = null
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
var _btn_zoom_out: Button
var _btn_zoom_in: Button
var _btn_help: Button
var _btn_settings: Button
var _btn_sound: Button
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
var _mission_bar: PanelContainer
var _mission_bar_style: StyleBoxFlat
var _mission_label: Label

# Abas centrais (Estanceiros | Diário)
var _active_tab: int = TAB_PLAYERS
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[Control] = []
var _players_box: VBoxContainer
var _ticker_panel: PanelContainer
var _ticker_scroll: ScrollContainer
var _ticker_hdr_label: Label
var _ticker_label: Label
var _log_label: Label
var _log_scroll: ScrollContainer
var _cached_active_pid: int = -1

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
var _deed_card: PanelContainer
var _deed_scroll: ScrollContainer
var _deed_banner: PanelContainer
var _deed_title_label: Label
var _deed_group_label: Label
var _deed_body_box: VBoxContainer
var _deed_actions_grid: GridContainer
var _deed_build_btn: Button
var _deed_sell_btn: Button
var _deed_mortgage_btn: Button
var _deed_offer_trade_btn: Button
var _deed_auction_btn: Button
var _deed_trade_btn: Button
var _deed_cart_btn: Button
var _deed_open_tile_idx: int = -1
var _deed_trade_target_id: int = -1
var _deed_trade_tile_idx: int = -1
var _deed_cart_group: String = ""

var _cart_overlay: Control
var _cart_card: PanelContainer
var _cart_scroll: ScrollContainer
var _cart_list_box: VBoxContainer
var _cart_summary_label: Label
var _cart_bank_label: Label
var _cart_confirm_btn: Button
var _cart_draft_levels: Dictionary[int, int] = {}
var _cart_focus_group: String = ""

var _trade_overlay: Control
var _trade_card: PanelContainer
var _trade_target_select: OptionButton
var _trade_offer_select: OptionButton
var _trade_request_select: OptionButton
var _trade_cash_label: Label
var _trade_deliver_preview: Label
var _trade_receive_preview: Label
var _trade_summary_label: Label
var _trade_confirm_btn: Button
var _trade_waiver_btn: Button
var _trade_cash_value: int = 0
var _trade_waiver_enabled: bool = false

var _trade_confirm_overlay: Control
var _trade_confirm_title_label: Label
var _trade_confirm_gives_label: Label
var _trade_confirm_receives_label: Label
var _trade_confirm_pact_label: Label
var _trade_confirm_offer_id: int = -1

var _auction_overlay: Control
var _auction_banner: PanelContainer
var _auction_title_label: Label
var _auction_meta_label: Label
var _auction_bid_label: Label
var _auction_turn_label: Label
var _auction_btn_min: Button
var _auction_btn_20: Button
var _auction_btn_50: Button
var _auction_btn_100: Button
var _auction_btn_pass: Button
var _auction_min_next_val: int = 0

var _pause_overlay: Control
var _pause_restart_btn: Button
var _pause_bot_leave_btn: Button
var _pause_forfeit_btn: Button
var _pause_menu_btn: Button
var _pause_quit_btn: Button
var _help_overlay: Control
var _help_card: PanelContainer
var _trophies_overlay: Control
var _trophies_card: PanelContainer
var _trophies_list_box: VBoxContainer
var _trophies_summary_label: Label

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
var _portfolio_cart_btn: Button
var _portfolio_debt_banner: PanelContainer
var _portfolio_debt_label: Label
var _portfolio_filter_btns: Dictionary[String, Button] = {}
var _portfolio_filter: String = "all"
var _portfolio_open_pid: int = -1
var _portfolio_last_info: Dictionary = {}

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
var _settings_auction_btns: Dictionary[String, Button] = {}
var _settings_audio_btns: Dictionary[String, Button] = {}
var _settings_volume_btns: Dictionary[String, Button] = {}
var _settings_step_sfx_btns: Dictionary[String, Button] = {}
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
	"auction_interval_rounds": 3,
	"audio_enabled": true,
	"audio_volume": 0.75,
	"audio_step_sfx": true,
	"player_chance_overrides": {}
}

# Cache de estado da UI
var _cached_players: Array[Dictionary] = []
var _cached_current_idx: int = 0
var _cached_tiles: Array[Dictionary] = []
var _cached_player_colors: Dictionary[int, Color] = {}
var _cached_owned_options: Array[Dictionary] = []
var _cached_selected_tile: int = -1
var _cached_owners_map: Dictionary[int, int] = {}
var _cached_buildings_map: Dictionary[int, int] = {}
var _cached_mortgaged_map: Dictionary[int, bool] = {}
var _cached_tradable_map: Dictionary[int, bool] = {}
var _cached_houses_left: int = 32
var _cached_hotels_left: int = 12
var _cached_is_bot_turn: bool = false
var _cached_is_2d_cam: bool = false
var _last_board_rect: Rect2 = Rect2(18.0, 18.0, 1418.0, 1044.0)
var _last_layout_vp_size: Vector2 = Vector2.ZERO

func _resolve_platform_profile() -> RefCounted:
	return PlatformProfileAdapter.create_for_mobile_flag(PlatformProfileAdapter.resolve_is_mobile(get_tree()))

func get_ui_profile_id() -> String:
	if _profile_adapter != null:
		return str(_profile_adapter.get("profile_name"))
	return "android" if _is_touch_mode else "desktop"

func bind_core_signals(core_manager: Node) -> void:
	if core_manager == null or not core_manager.has_signal("turn_state_changed"):
		return
	var cb: Callable = Callable(self, "_on_base_core_turn_state_changed")
	if not core_manager.is_connected("turn_state_changed", cb):
		core_manager.connect("turn_state_changed", cb)

func _on_base_core_turn_state_changed(_state: int, _player_id: int, round_number: int) -> void:
	if _round_label != null and round_number >= 1:
		_round_label.text = "Rodada %d" % round_number

func _ready() -> void:
	layer = 2
	_profile_adapter = _resolve_platform_profile()
	_is_touch_mode = bool(_profile_adapter.get("is_mobile")) if _profile_adapter != null else false
	_bold_font = UIStyleTokens.create_bold_font()
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
	var mult: float = float(_profile_adapter.get("font_scale")) if _profile_adapter != null else (1.22 if _is_touch_mode else 1.0)
	return roundi(base_px * mult)

func _bh(base_h: float) -> float:
	var mult: float = float(_profile_adapter.get("button_height_scale")) if _profile_adapter != null else (1.28 if _is_touch_mode else 1.0)
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
	return UIStyleTokens.format_brl(amount)

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
			elif _cart_overlay != null and _cart_overlay.visible:
				hide_construction_cart_modal()
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
	if _auction_overlay != null and _auction_overlay.visible:
		return true
	if _trade_confirm_overlay != null and _trade_confirm_overlay.visible:
		return true
	if _cart_overlay != null and _cart_overlay.visible:
		return true
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

	var pad: float = float(_profile_adapter.get("viewport_padding")) if _profile_adapter != null else (14.0 if _is_touch_mode else 18.0)
	var gap: float = float(_profile_adapter.get("panel_gap")) if _profile_adapter != null else (14.0 if _is_touch_mode else 16.0)
	var panel_w: float = float(_profile_adapter.call("compute_side_panel_width", vp_size.x)) if _profile_adapter != null else clampf(vp_size.x * 0.245, 430.0, 520.0)

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
	if _cart_card != null:
		var cart_w: float = clampf(vp_size.x * 0.50, 560.0, 780.0) if not _is_touch_mode else clampf(vp_size.x * 0.78, 580.0, 860.0)
		_cart_card.custom_minimum_size = Vector2(minf(cart_w, vp_size.x - 40.0), 0.0)
	if _cart_scroll != null:
		var cart_scroll_h: float = clampf(vp_size.y * 0.50, 240.0, 520.0)
		_cart_scroll.custom_minimum_size = Vector2(0.0, cart_scroll_h)
	if _deed_card != null:
		var deed_w: float = clampf(vp_size.x * 0.36, 480.0, 580.0) if not _is_touch_mode else clampf(vp_size.x * 0.72, 520.0, 720.0)
		_deed_card.custom_minimum_size = Vector2(minf(deed_w, vp_size.x - 40.0), 0.0)
	if _deed_scroll != null:
		var deed_scroll_h: float = clampf(vp_size.y * 0.44, 210.0, 440.0)
		_deed_scroll.custom_minimum_size = Vector2(0.0, deed_scroll_h)

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
	return UIStyleTokens.make_panel_style(bg_hex, border_hex, radius, border_w)

func _make_btn_style(bg_hex: String, border_hex: String, border_w: int = 1, radius: int = 9, pressed_shift: bool = false, pad_h: float = 10.0) -> StyleBoxFlat:
	return UIStyleTokens.make_button_style(bg_hex, border_hex, border_w, radius, pressed_shift, pad_h)

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

	_btn_zoom_out = Button.new()
	_btn_zoom_out.text = "-"
	_btn_zoom_out.tooltip_text = "Afastar câmera (ou use a roda do mouse)"
	_btn_zoom_out.custom_minimum_size = Vector2(qb_h, qb_h)
	_apply_button_theme(_btn_zoom_out, "#18251F", "#24372E", "#121B17", "#4D695B", Color("#E6F0EA"), true, qb_h, qb_fs + 2, 8.0, true)
	_btn_zoom_out.pressed.connect(func() -> void: camera_zoom_out_requested.emit())
	qb_row.add_child(_btn_zoom_out)

	_btn_zoom_in = Button.new()
	_btn_zoom_in.text = "+"
	_btn_zoom_in.tooltip_text = "Aproximar câmera (ou use a roda do mouse)"
	_btn_zoom_in.custom_minimum_size = Vector2(qb_h, qb_h)
	_apply_button_theme(_btn_zoom_in, "#18251F", "#24372E", "#121B17", "#4D695B", Color("#E6F0EA"), true, qb_h, qb_fs + 2, 8.0, true)
	_btn_zoom_in.pressed.connect(func() -> void: camera_zoom_in_requested.emit())
	qb_row.add_child(_btn_zoom_in)

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

	_btn_sound = Button.new()
	_btn_sound.tooltip_text = "Ativar ou silenciar efeitos sonoros da partida"
	_btn_sound.pressed.connect(func() -> void: _set_global_pref("audio_enabled", not bool(_prefs_cache.get("audio_enabled", true))))
	qb_row.add_child(_btn_sound)
	_refresh_sound_button()

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
	_hero_money_label.text = "P$ 2.558"
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

	_mission_bar = PanelContainer.new()
	_mission_bar.visible = false
	_mission_bar_style = _make_panel_style("#182112", "#D4AF37", 8, 1)
	_mission_bar_style.content_margin_left = 10.0
	_mission_bar_style.content_margin_right = 10.0
	_mission_bar_style.content_margin_top = 4.0
	_mission_bar_style.content_margin_bottom = 4.0
	_mission_bar.add_theme_stylebox_override("panel", _mission_bar_style)
	hero_vbox.add_child(_mission_bar)

	_mission_label = Label.new()
	_mission_label.text = ""
	_mission_label.add_theme_font_size_override("font_size", _fs(11.0))
	_mission_label.add_theme_color_override("font_color", Color("#F6DF8F"))
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_bar.add_child(_mission_label)

func _build_tabs_zone(parent: VBoxContainer) -> void:
	# Seletor segmentado de 2 abas (Estanceiros | Diário) — gestão de escrituras centralizada na Carta do Lote
	var tabs_bar: HBoxContainer = HBoxContainer.new()
	tabs_bar.add_theme_constant_override("separation", 6)
	parent.add_child(tabs_bar)

	var tab_titles: Array[String] = ["Estanceiros", "Diário"]
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

	# --- ABA 1: DIÁRIO COMPLETO DA RODADA ---
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
	_btn_bail.text = "Fiança P$50"
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
	_btn_deeds_jump.text = "Minhas Escrituras (0)"
	_btn_deeds_jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_btn_deeds_jump, "#1B2E25", "#254033", "#13211A", "#52B788", Color("#E9F5EE"), false, sec_h, sec_fs, 10.0, true)
	_btn_deeds_jump.pressed.connect(func() -> void:
		if _cached_active_pid >= 0:
			player_inspected.emit(_cached_active_pid)
	)
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
	_build_construction_cart_modal()
	_build_trade_modal()
	_build_trade_confirm_modal()
	_build_auction_modal()
	_build_pause_modal()
	_build_help_modal()
	_build_trophies_modal()
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

func _enable_modal_drag(card: PanelContainer, handle: Control, overlay: Control = null) -> void:
	if card == null or handle == null:
		return
	card.set_meta("drag_offset", Vector2.ZERO)
	card.set_meta("drag_active", false)
	card.set_meta("drag_last_mouse", Vector2.ZERO)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	if handle.tooltip_text == "":
		handle.tooltip_text = "Arraste para mover a janela"
	handle.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb: InputEventMouseButton = ev
			if mb.button_index == MOUSE_BUTTON_LEFT:
				card.set_meta("drag_active", mb.pressed)
				card.set_meta("drag_last_mouse", mb.global_position)
		elif ev is InputEventMouseMotion:
			if bool(card.get_meta("drag_active", false)):
				var mm: InputEventMouseMotion = ev
				var prev_pos: Variant = card.get_meta("drag_last_mouse", mm.global_position)
				var delta: Vector2 = mm.global_position - (prev_pos as Vector2 if prev_pos is Vector2 else mm.global_position)
				card.set_meta("drag_last_mouse", mm.global_position)
				drag_modal_by(card, delta)
	)
	var center_parent: Container = card.get_parent() as Container
	if center_parent != null:
		center_parent.sort_children.connect(func() -> void: _apply_modal_drag_offset(card))
	if overlay != null:
		overlay.visibility_changed.connect(func() -> void:
			if not overlay.visible:
				reset_modal_drag(card)
		)

func reset_modal_drag(card: PanelContainer) -> void:
	if card == null:
		return
	card.set_meta("drag_offset", Vector2.ZERO)
	card.set_meta("drag_active", false)
	_apply_modal_drag_offset(card)

func drag_modal_by(card: PanelContainer, delta: Vector2) -> void:
	if card == null:
		return
	var raw_offset: Variant = card.get_meta("drag_offset", Vector2.ZERO)
	var cur_offset: Vector2 = raw_offset as Vector2 if raw_offset is Vector2 else Vector2.ZERO
	card.set_meta("drag_offset", cur_offset + delta)
	_apply_modal_drag_offset(card)

func _apply_modal_drag_offset(card: PanelContainer) -> void:
	if card == null:
		return
	var parent_ctrl: Control = card.get_parent() as Control
	var vp_size: Vector2 = Vector2(1280.0, 720.0)
	if parent_ctrl != null and parent_ctrl.size.x > 0.0 and parent_ctrl.size.y > 0.0:
		vp_size = parent_ctrl.size
	elif get_viewport() != null:
		vp_size = get_viewport().get_visible_rect().size
	var c_size: Vector2 = card.size
	if c_size.x <= 1.0 or c_size.y <= 1.0:
		c_size = card.get_combined_minimum_size()
	var base_pos: Vector2 = (vp_size - c_size) * 0.5
	var raw_offset: Variant = card.get_meta("drag_offset", Vector2.ZERO)
	var offset: Vector2 = raw_offset as Vector2 if raw_offset is Vector2 else Vector2.ZERO
	var desired: Vector2 = base_pos + offset
	var max_x: float = maxf(8.0, vp_size.x - c_size.x - 8.0)
	var max_y: float = maxf(8.0, vp_size.y - c_size.y - 8.0)
	var clamped: Vector2 = Vector2(clampf(desired.x, 8.0, max_x), clampf(desired.y, 8.0, max_y))
	card.set_meta("drag_offset", clamped - base_pos)
	card.position = clamped

# 1. Modal de Inspeção & Gestão Direta da Carta do Lote
func _build_deed_modal() -> void:
	_deed_overlay = _create_modal_backdrop(hide_deed_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deed_overlay.add_child(center)

	_deed_card = PanelContainer.new()
	_deed_card.custom_minimum_size = Vector2(560.0 if _is_touch_mode else 510.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#141F19", "#D4AF37", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	_deed_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_deed_card)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 0)
	_deed_card.add_child(card_vbox)

	_deed_banner = PanelContainer.new()
	var banner_style: StyleBoxFlat = StyleBoxFlat.new()
	banner_style.bg_color = Color("#2A9D8F")
	banner_style.corner_radius_top_left = 16
	banner_style.corner_radius_top_right = 16
	_deed_banner.add_theme_stylebox_override("panel", banner_style)
	card_vbox.add_child(_deed_banner)
	_enable_modal_drag(_deed_card, _deed_banner, _deed_overlay)

	var b_margin: MarginContainer = MarginContainer.new()
	b_margin.add_theme_constant_override("margin_left", 22)
	b_margin.add_theme_constant_override("margin_right", 22)
	b_margin.add_theme_constant_override("margin_top", 14)
	b_margin.add_theme_constant_override("margin_bottom", 12)
	_deed_banner.add_child(b_margin)

	var b_vbox: VBoxContainer = VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 3)
	b_margin.add_child(b_vbox)

	_deed_group_label = Label.new()
	_deed_group_label.text = "ESCRITURA"
	_deed_group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_deed_group_label.add_theme_font_override("font", _bold_font)
	_deed_group_label.add_theme_font_size_override("font_size", _fs(11.5))
	b_vbox.add_child(_deed_group_label)

	_deed_title_label = Label.new()
	_deed_title_label.text = "Propriedade"
	_deed_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deed_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _bold_font != null:
		_deed_title_label.add_theme_font_override("font", _bold_font)
	_deed_title_label.add_theme_font_size_override("font_size", _fs(22.0))
	b_vbox.add_child(_deed_title_label)

	var body_margin: MarginContainer = MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 20)
	body_margin.add_theme_constant_override("margin_right", 20)
	body_margin.add_theme_constant_override("margin_top", 14)
	body_margin.add_theme_constant_override("margin_bottom", 16)
	card_vbox.add_child(body_margin)

	var body_outer: VBoxContainer = VBoxContainer.new()
	body_outer.add_theme_constant_override("separation", 12)
	body_margin.add_child(body_outer)

	_deed_scroll = ScrollContainer.new()
	_deed_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deed_scroll.custom_minimum_size = Vector2(0.0, 310.0)
	_deed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_deed_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_outer.add_child(_deed_scroll)

	_deed_body_box = VBoxContainer.new()
	_deed_body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deeds_spacing_init(_deed_body_box, 6)
	_deed_scroll.add_child(_deed_body_box)

	var deed_act_h: float = _bh(40.0)
	var deed_act_fs: int = _fs(12.5)

	_deed_actions_grid = GridContainer.new()
	_deed_actions_grid.columns = 2
	_deed_actions_grid.add_theme_constant_override("h_separation", 8)
	_deed_actions_grid.add_theme_constant_override("v_separation", 8)
	_deed_actions_grid.visible = false
	body_outer.add_child(_deed_actions_grid)

	_deed_build_btn = Button.new()
	_deed_build_btn.text = "+Casa"
	_deed_build_btn.visible = false
	_deed_build_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_deed_build_btn, "#1D4A38", "#27644C", "#143528", "#52B788", Color("#E8FFF2"), false, deed_act_h, deed_act_fs, 8.0, true)
	_deed_build_btn.pressed.connect(func() -> void:
		if _deed_open_tile_idx >= 0:
			build_pressed.emit(_deed_open_tile_idx)
	)
	_deed_actions_grid.add_child(_deed_build_btn)

	_deed_sell_btn = Button.new()
	_deed_sell_btn.text = "-Casa"
	_deed_sell_btn.visible = false
	_deed_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_deed_sell_btn, "#3D2724", "#553631", "#2B1B19", "#C46E5F", Color.WHITE, false, deed_act_h, deed_act_fs, 8.0, true)
	_deed_sell_btn.pressed.connect(func() -> void:
		if _deed_open_tile_idx >= 0:
			sell_building_pressed.emit(_deed_open_tile_idx)
	)
	_deed_actions_grid.add_child(_deed_sell_btn)

	_deed_mortgage_btn = Button.new()
	_deed_mortgage_btn.text = "Hipotecar"
	_deed_mortgage_btn.visible = false
	_deed_mortgage_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_deed_mortgage_btn, "#2B323C", "#3B4553", "#1F242B", "#8FA3B8", Color.WHITE, false, deed_act_h, deed_act_fs, 8.0, true)
	_deed_mortgage_btn.pressed.connect(func() -> void:
		if _deed_open_tile_idx >= 0:
			mortgage_pressed.emit(_deed_open_tile_idx)
	)
	_deed_actions_grid.add_child(_deed_mortgage_btn)

	_deed_cart_btn = Button.new()
	_deed_cart_btn.text = "Carrinho de Obras"
	_deed_cart_btn.visible = false
	_deed_cart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_deed_cart_btn, "#1B3F31", "#265945", "#132E24", "#7BF1A8", Color("#E4FFF2"), true, deed_act_h, deed_act_fs, 8.0, true)
	_deed_cart_btn.pressed.connect(func() -> void:
		var fg: String = _deed_cart_group
		hide_deed_modal()
		show_construction_cart_modal(fg)
	)
	_deed_actions_grid.add_child(_deed_cart_btn)

	_deed_offer_trade_btn = Button.new()
	_deed_offer_trade_btn.text = "Ofertar em Troca"
	_deed_offer_trade_btn.visible = false
	_deed_offer_trade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_deed_offer_trade_btn, "#1B425C", "#24577A", "#143145", "#4EA8DE", Color("#E4F5FF"), false, deed_act_h, deed_act_fs, 8.0, true)
	_deed_offer_trade_btn.pressed.connect(func() -> void:
		var off_idx: int = _deed_open_tile_idx
		hide_deed_modal()
		if off_idx >= 0:
			show_trade_modal(-1, -1, off_idx)
	)
	_deed_actions_grid.add_child(_deed_offer_trade_btn)

	_deed_auction_btn = Button.new()
	_deed_auction_btn.text = "Leiloar Lote"
	_deed_auction_btn.visible = false
	_deed_auction_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_deed_auction_btn, "#3C2D16", "#543F1F", "#2B2010", "#F5CA5C", Color("#FFF3C4"), false, deed_act_h, deed_act_fs, 8.0, true)
	_deed_auction_btn.pressed.connect(func() -> void:
		var auc_idx: int = _deed_open_tile_idx
		if auc_idx >= 0:
			auction_owned_requested.emit(auc_idx)
	)
	_deed_actions_grid.add_child(_deed_auction_btn)

	_deed_trade_btn = Button.new()
	_deed_trade_btn.text = "Propor Troca por Este Lote"
	_deed_trade_btn.visible = false
	_deed_trade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_deed_trade_btn, "#1B425C", "#24577A", "#143145", "#4EA8DE", Color("#E4F5FF"), true, deed_act_h, deed_act_fs, 10.0, true)
	_deed_trade_btn.pressed.connect(func() -> void:
		var t_id: int = _deed_trade_target_id
		var t_idx: int = _deed_trade_tile_idx
		hide_deed_modal()
		if t_id >= 0 and t_idx >= 0:
			show_trade_modal(t_id, t_idx, -1)
	)
	body_outer.add_child(_deed_trade_btn)

	var btn_close: Button = Button.new()
	btn_close.text = "Fechar" if _is_touch_mode else "Fechar [ESC]"
	btn_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(btn_close, "#213329", "#2E473A", "#17241D", "#D4AF37", Color.WHITE, false, _bh(42.0), _fs(14.0), 12.0, true)
	btn_close.pressed.connect(hide_deed_modal)
	body_outer.add_child(btn_close)

func _deeds_spacing_init(vb: VBoxContainer, sep: int) -> void:
	vb.add_theme_constant_override("separation", sep)

func hide_deed_modal() -> void:
	_deed_open_tile_idx = -1
	if _deed_overlay != null:
		_deed_overlay.visible = false

func get_open_deed_tile_index() -> int:
	if _deed_overlay != null and _deed_overlay.visible:
		return _deed_open_tile_idx
	return -1

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
		var raw_peers: Variant = info.get("group_peers", [])
		if raw_peers is Array and (raw_peers as Array).size() > 1:
			_deed_body_box.add_child(HSeparator.new())
			var gp_hdr: Label = Label.new()
			gp_hdr.text = "Lotes do mesmo grupo (%s) — toque para alternar:" % group_name.replace("_", " ")
			gp_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			gp_hdr.add_theme_font_size_override("font_size", _fs(11.5))
			gp_hdr.add_theme_color_override("font_color", Color("#A7C2B3"))
			_deed_body_box.add_child(gp_hdr)

			var gp_flow: HFlowContainer = HFlowContainer.new()
			gp_flow.add_theme_constant_override("h_separation", 6)
			gp_flow.add_theme_constant_override("v_separation", 6)
			_deed_body_box.add_child(gp_flow)
			for peer_var: Variant in (raw_peers as Array):
				if not (peer_var is Dictionary):
					continue
				var peer: Dictionary = peer_var as Dictionary
				var p_tid: int = int(peer.get("tile_index", -1))
				var p_name: String = str(peer.get("name", "Lote"))
				var p_curr: bool = bool(peer.get("is_current", false))
				var p_owned: bool = bool(peer.get("is_owned", false))
				var p_border: String = str(peer.get("owner_color_hex", "#4A6658")) if p_owned else "#4A6658"
				var chip_btn: Button = Button.new()
				chip_btn.text = "• %s" % p_name if p_curr else p_name
				chip_btn.disabled = p_curr
				var chip_bg: String = "#274738" if p_curr else "#14221B"
				var chip_fg: Color = Color("#F5D06F") if p_curr else Color("#DCEBE2")
				_apply_button_theme(chip_btn, chip_bg, "#1F372C", "#0E1813", p_border, chip_fg, p_curr, _bh(30.0), _fs(11.5), 10.0, true)
				if not p_curr and p_tid >= 0:
					chip_btn.pressed.connect(func() -> void: inspect_tile_requested.emit(p_tid))
				gp_flow.add_child(chip_btn)
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
				desc_lbl.text = "Feriadão de 20 de Setembro: Festa Farroupilha! Convoca imediatamente um Leilão Farroupilha de lote livre ou promove o Rateio de Chimarrão no Galpão (+P$ 20 de cada adversário solvente)."
			_:
				desc_lbl.text = "Casa #%d do tabuleiro." % int(tile.get("index", 0))
		_deed_body_box.add_child(desc_lbl)

	_deed_open_tile_idx = int(info.get("tile_index", -1))
	_deed_trade_target_id = int(info.get("owner_id", -1))
	_deed_trade_tile_idx = _deed_open_tile_idx
	_deed_cart_group = group_name

	var is_owner_active: bool = bool(info.get("is_owner_active", false))
	var show_build: bool = is_owner_active and tile_type == "PROPERTY" and bool(info.get("has_monopoly", false))
	var show_sell: bool = is_owner_active and tile_type == "PROPERTY" and int(info.get("building_level", 0)) > 0
	var show_mortgage: bool = is_owner_active and (tile_type == "PROPERTY" or tile_type == "COMPANY")
	var show_cart: bool = bool(info.get("can_open_build_cart", false))
	var show_offer: bool = bool(info.get("can_offer_in_trade", false))
	var show_auction: bool = bool(info.get("can_auction_owned", false))

	if _deed_build_btn != null:
		_deed_build_btn.visible = show_build
		_deed_build_btn.text = str(info.get("build_label", "+Casa"))
		_deed_build_btn.disabled = not bool(info.get("can_build", false))
	if _deed_sell_btn != null:
		_deed_sell_btn.visible = show_sell
		_deed_sell_btn.text = str(info.get("sell_building_label", "-Casa"))
		_deed_sell_btn.disabled = not bool(info.get("can_sell_building", false))
	if _deed_mortgage_btn != null:
		_deed_mortgage_btn.visible = show_mortgage
		_deed_mortgage_btn.text = str(info.get("mortgage_label", "Hipotecar"))
		_deed_mortgage_btn.disabled = not bool(info.get("can_mortgage", false))
	if _deed_cart_btn != null:
		_deed_cart_btn.visible = show_cart
	if _deed_offer_trade_btn != null:
		_deed_offer_trade_btn.visible = show_offer
	if _deed_auction_btn != null:
		_deed_auction_btn.visible = show_auction
	if _deed_actions_grid != null:
		_deed_actions_grid.visible = show_build or show_sell or show_mortgage or show_cart or show_offer or show_auction

	if _deed_trade_btn != null:
		_deed_trade_btn.visible = bool(info.get("can_propose_trade", false)) and _deed_trade_target_id >= 0 and _deed_trade_tile_idx >= 0

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

	_trade_card = PanelContainer.new()
	_trade_card.custom_minimum_size = Vector2(620.0 if _is_touch_mode else 560.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#131E18", "#4EA8DE", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	_trade_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_trade_card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_trade_card.add_child(margin)

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
	_enable_modal_drag(_trade_card, title, _trade_overlay)

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
	_trade_cash_label.text = "Dinheiro na troca: P$ 0"
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

	_trade_waiver_btn = Button.new()
	_trade_waiver_btn.toggle_mode = true
	_trade_waiver_btn.button_pressed = false
	_trade_waiver_btn.text = "Parceria Campeira (3 rod. sem aluguel): Desligada"
	_apply_button_theme(_trade_waiver_btn, "#16241D", "#20362B", "#0E1712", "#4B7561", Color("#CBE4D6"), false, _bh(34.0), _fs(12.0), 8.0, true)
	_trade_waiver_btn.toggled.connect(func(pressed: bool) -> void:
		_trade_waiver_enabled = pressed
		_sync_trade_waiver_btn_visual()
		_refresh_trade_summary()
	)
	vbox.add_child(_trade_waiver_btn)

	var preview_row: HBoxContainer = HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 10)
	vbox.add_child(preview_row)

	var deliv_card: PanelContainer = PanelContainer.new()
	deliv_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var deliv_sb: StyleBoxFlat = _make_panel_style("#18211C", "#C9A227", 9, 1)
	deliv_sb.content_margin_left = 10.0
	deliv_sb.content_margin_right = 10.0
	deliv_sb.content_margin_top = 8.0
	deliv_sb.content_margin_bottom = 8.0
	deliv_card.add_theme_stylebox_override("panel", deliv_sb)
	preview_row.add_child(deliv_card)

	var deliv_vb: VBoxContainer = VBoxContainer.new()
	deliv_vb.add_theme_constant_override("separation", 2)
	deliv_card.add_child(deliv_vb)
	var deliv_hdr: Label = Label.new()
	deliv_hdr.text = "VOCÊ ENTREGA"
	if _bold_font != null:
		deliv_hdr.add_theme_font_override("font", _bold_font)
	deliv_hdr.add_theme_font_size_override("font_size", _fs(11.0))
	deliv_hdr.add_theme_color_override("font_color", Color("#F3C969"))
	deliv_vb.add_child(deliv_hdr)
	_trade_deliver_preview = Label.new()
	_trade_deliver_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_deliver_preview.add_theme_font_size_override("font_size", _fs(12.5))
	_trade_deliver_preview.add_theme_color_override("font_color", Color("#FFFDF5"))
	deliv_vb.add_child(_trade_deliver_preview)

	var rec_card: PanelContainer = PanelContainer.new()
	rec_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rec_sb: StyleBoxFlat = _make_panel_style("#13231D", "#52B788", 9, 1)
	rec_sb.content_margin_left = 10.0
	rec_sb.content_margin_right = 10.0
	rec_sb.content_margin_top = 8.0
	rec_sb.content_margin_bottom = 8.0
	rec_card.add_theme_stylebox_override("panel", rec_sb)
	preview_row.add_child(rec_card)

	var rec_vb: VBoxContainer = VBoxContainer.new()
	rec_vb.add_theme_constant_override("separation", 2)
	rec_card.add_child(rec_vb)
	var rec_hdr: Label = Label.new()
	rec_hdr.text = "VOCÊ RECEBE"
	if _bold_font != null:
		rec_hdr.add_theme_font_override("font", _bold_font)
	rec_hdr.add_theme_font_size_override("font_size", _fs(11.0))
	rec_hdr.add_theme_color_override("font_color", Color("#7BF1A8"))
	rec_vb.add_child(rec_hdr)
	_trade_receive_preview = Label.new()
	_trade_receive_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_receive_preview.add_theme_font_size_override("font_size", _fs(12.5))
	_trade_receive_preview.add_theme_color_override("font_color", Color("#E8FFF2"))
	rec_vb.add_child(_trade_receive_preview)

	_trade_summary_label = Label.new()
	_trade_summary_label.text = ""
	_trade_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_summary_label.add_theme_font_size_override("font_size", _fs(12.5))
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

	_trade_confirm_btn = Button.new()
	_trade_confirm_btn.text = "Enviar Proposta"
	_trade_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_confirm_btn.size_flags_stretch_ratio = 1.25
	_apply_button_theme(_trade_confirm_btn, "#227557", "#2C946E", "#185740", "#A8FF78", Color.WHITE, true, _bh(44.0), _fs(14.0), 10.0, true)
	_trade_confirm_btn.pressed.connect(_emit_trade)
	btn_row.add_child(_trade_confirm_btn)

func show_trade_modal(pre_target_id: int = -1, pre_request_tile: int = -1, pre_offer_tile: int = -1) -> void:
	if _trade_overlay == null:
		return
	_trade_cash_value = 0
	_trade_waiver_enabled = false
	if _trade_waiver_btn != null:
		_trade_waiver_btn.set_pressed_no_signal(false)
		_sync_trade_waiver_btn_visual()
	_refresh_trade_targets(pre_target_id, pre_request_tile, pre_offer_tile)
	_trade_overlay.visible = true

func _sync_trade_waiver_btn_visual() -> void:
	if _trade_waiver_btn == null:
		return
	if _trade_waiver_enabled:
		_trade_waiver_btn.text = "Parceria Campeira Ativa: 3 rodadas sem aluguel mútuo"
		_apply_button_theme(_trade_waiver_btn, "#1F4B38", "#286148", "#163628", "#7BF1A8", Color("#E8FFF2"), true, _bh(34.0), _fs(12.0), 8.0, true)
	else:
		_trade_waiver_btn.text = "Parceria Campeira (3 rod. sem aluguel): Desligada"
		_apply_button_theme(_trade_waiver_btn, "#16241D", "#20362B", "#0E1712", "#4B7561", Color("#CBE4D6"), false, _bh(34.0), _fs(12.0), 8.0, true)

func hide_trade_modal() -> void:
	if _trade_overlay != null:
		_trade_overlay.visible = false

func _adjust_trade_cash(delta: int) -> void:
	_trade_cash_value = clampi(_trade_cash_value + delta, -5000, 5000)
	_refresh_trade_summary()

func _refresh_trade_targets(pre_target_id: int = -1, pre_request_tile: int = -1, pre_offer_tile: int = -1) -> void:
	var prev_target_meta: Variant = _trade_target_select.get_selected_metadata()
	var wanted_target_id: int = pre_target_id if pre_target_id >= 0 else (int(prev_target_meta) if prev_target_meta != null else -1)
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
		if wanted_target_id >= 0 and wanted_target_id == pid:
			selected_idx = item_idx

	if _trade_target_select.item_count > 0:
		_trade_target_select.select(selected_idx)
	_refresh_trade_dropdowns(pre_request_tile, pre_offer_tile)

func set_board_snapshot_meta(
	owners_map: Dictionary[int, int],
	buildings_map: Dictionary[int, int],
	mortgaged_map: Dictionary[int, bool],
	tradable_map: Dictionary[int, bool]
) -> void:
	_cached_owners_map = owners_map.duplicate()
	_cached_buildings_map = buildings_map.duplicate()
	_cached_mortgaged_map = mortgaged_map.duplicate()
	_cached_tradable_map = tradable_map.duplicate()

func _is_tile_tradable_in_cache(tile_idx: int) -> bool:
	if _cached_tradable_map.has(tile_idx):
		return bool(_cached_tradable_map[tile_idx])
	if _cached_buildings_map.get(tile_idx, 0) > 0:
		return false
	if tile_idx >= 0 and tile_idx < _cached_tiles.size():
		var g_name: String = str(_cached_tiles[tile_idx].get("group", ""))
		if g_name != "":
			for i: int in range(_cached_tiles.size()):
				var t: Dictionary = _cached_tiles[i]
				if str(t.get("type", "")) == "PROPERTY" and str(t.get("group", "")) == g_name:
					if _cached_buildings_map.get(i, 0) > 0:
						return false
	return true

func _refresh_trade_dropdowns(pre_request_tile: int = -1, pre_offer_tile: int = -1) -> void:
	_trade_offer_select.clear()
	_trade_offer_select.add_item("Nenhuma escritura")
	_trade_offer_select.set_item_metadata(0, -1)

	var offer_pre_idx: int = 0
	if _cached_current_idx >= 0 and _cached_current_idx < _cached_players.size():
		var current_props: Array = _cached_players[_cached_current_idx].get("properties", [])
		for t_idx: Variant in current_props:
			var idx_int: int = int(t_idx)
			if idx_int >= 0 and idx_int < _cached_tiles.size() and _is_tile_tradable_in_cache(idx_int):
				_trade_offer_select.add_item(str(_cached_tiles[idx_int]["name"]))
				var added_off_idx: int = _trade_offer_select.item_count - 1
				_trade_offer_select.set_item_metadata(added_off_idx, idx_int)
				if pre_offer_tile >= 0 and idx_int == pre_offer_tile:
					offer_pre_idx = added_off_idx
	if offer_pre_idx > 0:
		_trade_offer_select.select(offer_pre_idx)

	_trade_request_select.clear()
	_trade_request_select.add_item("Nenhuma escritura")
	_trade_request_select.set_item_metadata(0, -1)

	var req_pre_idx: int = 0
	var target_id: Variant = _trade_target_select.get_selected_metadata()
	if target_id != null:
		var target_id_int: int = int(target_id)
		for p: Dictionary in _cached_players:
			if int(p["id"]) == target_id_int:
				var target_props: Array = p.get("properties", [])
				for t_idx: Variant in target_props:
					var idx_int: int = int(t_idx)
					if idx_int >= 0 and idx_int < _cached_tiles.size() and _is_tile_tradable_in_cache(idx_int):
						_trade_request_select.add_item(str(_cached_tiles[idx_int]["name"]))
						var added_idx: int = _trade_request_select.item_count - 1
						_trade_request_select.set_item_metadata(added_idx, idx_int)
						if pre_request_tile >= 0 and idx_int == pre_request_tile:
							req_pre_idx = added_idx
				break
	if req_pre_idx > 0:
		_trade_request_select.select(req_pre_idx)

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
		_trade_cash_label.text = "Sem dinheiro envolvido (P$ 0)"
		_trade_cash_label.add_theme_color_override("font_color", Color("#B8C9BF"))

	var offer_idx: int = int(_trade_offer_select.get_selected_metadata()) if _trade_offer_select.selected >= 0 else -1
	var req_idx: int = int(_trade_request_select.get_selected_metadata()) if _trade_request_select.selected >= 0 else -1
	var offer_txt: String = str(_cached_tiles[offer_idx]["name"]) if (offer_idx >= 0 and offer_idx < _cached_tiles.size()) else ""
	var req_txt: String = str(_cached_tiles[req_idx]["name"]) if (req_idx >= 0 and req_idx < _cached_tiles.size()) else ""

	var sides: Dictionary = TradeAndAuctionHelper.format_trade_sides(offer_txt, req_txt, _trade_cash_value)
	if _trade_deliver_preview != null:
		_trade_deliver_preview.text = str(sides["sender_text"])
	if _trade_receive_preview != null:
		_trade_receive_preview.text = str(sides["target_text"])

	var check: Dictionary = TradeAndAuctionHelper.evaluate_trade_counterpart(offer_idx, req_idx, _trade_cash_value)
	var is_valid: bool = bool(check.get("valid", false))
	if _trade_confirm_btn != null:
		_trade_confirm_btn.disabled = not is_valid
	if not is_valid:
		_trade_summary_label.text = str(check.get("reason", "Proposta incompleta."))
		_trade_summary_label.add_theme_color_override("font_color", Color("#FF9999"))
	else:
		var waiver_note: String = " + Parceria Campeira (3 rod. sem aluguel)." if _trade_waiver_enabled else ""
		_trade_summary_label.text = "A proposta exige aceite explícito do estanceiro convidado.%s" % waiver_note
		_trade_summary_label.add_theme_color_override("font_color", Color("#B7F0CC"))

func _emit_trade() -> void:
	var target_meta: Variant = _trade_target_select.get_selected_metadata()
	if target_meta == null:
		return
	var offer_meta: Variant = _trade_offer_select.get_selected_metadata()
	var req_meta: Variant = _trade_request_select.get_selected_metadata()
	var offer_idx: int = int(offer_meta) if offer_meta != null else -1
	var req_idx: int = int(req_meta) if req_meta != null else -1
	var check: Dictionary = TradeAndAuctionHelper.evaluate_trade_counterpart(offer_idx, req_idx, _trade_cash_value)
	if not bool(check.get("valid", false)):
		return
	var waiver_rounds: int = 3 if _trade_waiver_enabled else 0
	hide_trade_modal()
	trade_executed.emit(int(target_meta), offer_idx, req_idx, _trade_cash_value, waiver_rounds)

# 2B. Modal de Confirmação Obrigatória de Proposta de Troca (Local ou Remoto P2P)
func _build_trade_confirm_modal() -> void:
	_trade_confirm_overlay = _create_modal_backdrop(Callable())

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_confirm_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(580.0 if _is_touch_mode else 520.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#121E18", "#F3C969", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.70)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	_trade_confirm_title_label = Label.new()
	_trade_confirm_title_label.text = "PROPOSTA DE NEGOCIAÇÃO"
	_trade_confirm_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_confirm_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _bold_font != null:
		_trade_confirm_title_label.add_theme_font_override("font", _bold_font)
	_trade_confirm_title_label.add_theme_font_size_override("font_size", _fs(18.0))
	_trade_confirm_title_label.add_theme_color_override("font_color", Color("#F5D06F"))
	vb.add_child(_trade_confirm_title_label)

	var g_box: PanelContainer = PanelContainer.new()
	var g_sb: StyleBoxFlat = _make_panel_style("#102219", "#52B788", 10, 1)
	g_sb.content_margin_left = 14.0
	g_sb.content_margin_right = 14.0
	g_sb.content_margin_top = 10.0
	g_sb.content_margin_bottom = 10.0
	g_box.add_theme_stylebox_override("panel", g_sb)
	vb.add_child(g_box)
	_trade_confirm_gives_label = Label.new()
	_trade_confirm_gives_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_confirm_gives_label.add_theme_font_size_override("font_size", _fs(14.0))
	_trade_confirm_gives_label.add_theme_color_override("font_color", Color("#C9FFE1"))
	g_box.add_child(_trade_confirm_gives_label)

	var r_box: PanelContainer = PanelContainer.new()
	var r_sb: StyleBoxFlat = _make_panel_style("#231819", "#FF8FA3", 10, 1)
	r_sb.content_margin_left = 14.0
	r_sb.content_margin_right = 14.0
	r_sb.content_margin_top = 10.0
	r_sb.content_margin_bottom = 10.0
	r_box.add_theme_stylebox_override("panel", r_sb)
	vb.add_child(r_box)
	_trade_confirm_receives_label = Label.new()
	_trade_confirm_receives_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_confirm_receives_label.add_theme_font_size_override("font_size", _fs(14.0))
	_trade_confirm_receives_label.add_theme_color_override("font_color", Color("#FFD6DE"))
	r_box.add_child(_trade_confirm_receives_label)

	_trade_confirm_pact_label = Label.new()
	_trade_confirm_pact_label.visible = false
	_trade_confirm_pact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_confirm_pact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_confirm_pact_label.add_theme_font_size_override("font_size", _fs(13.0))
	_trade_confirm_pact_label.add_theme_color_override("font_color", Color("#8DF2B5"))
	vb.add_child(_trade_confirm_pact_label)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vb.add_child(btn_row)

	var btn_reject: Button = Button.new()
	btn_reject.text = "Recusar Proposta"
	btn_reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(btn_reject, "#4A2124", "#662D31", "#331618", "#FF758F", Color("#FFE8E8"), false, _bh(46.0), _fs(14.0), 10.0, true)
	btn_reject.pressed.connect(func() -> void:
		var oid: int = _trade_confirm_offer_id
		hide_trade_confirm_modal()
		trade_offer_responded.emit(oid, false)
	)
	btn_row.add_child(btn_reject)

	var btn_accept: Button = Button.new()
	btn_accept.text = "Aceitar Troca"
	btn_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(btn_accept, "#227557", "#2C946E", "#185740", "#A8FF78", Color.WHITE, true, _bh(46.0), _fs(14.0), 10.0, true)
	btn_accept.pressed.connect(func() -> void:
		var oid: int = _trade_confirm_offer_id
		hide_trade_confirm_modal()
		trade_offer_responded.emit(oid, true)
	)
	btn_row.add_child(btn_accept)

func show_trade_confirm_modal(offer_data: Dictionary) -> void:
	if _trade_confirm_overlay == null:
		return
	_trade_confirm_offer_id = int(offer_data.get("offer_id", -1))
	var s_name: String = str(offer_data.get("sender_name", "Estanceiro"))
	var t_name: String = str(offer_data.get("target_name", "Você"))
	_trade_confirm_title_label.text = "%s propôs uma troca para %s" % [s_name, t_name]
	_trade_confirm_gives_label.text = "Você recebe de %s:\n%s" % [s_name, str(offer_data.get("gives_text", "-"))]
	_trade_confirm_receives_label.text = "Você entrega em contrapartida:\n%s" % str(offer_data.get("receives_text", "-"))
	var waiver_r: int = int(offer_data.get("rent_waiver_rounds", 0))
	if _trade_confirm_pact_label != null:
		if waiver_r > 0:
			_trade_confirm_pact_label.text = "Cláusula de Parceria: isenção mútua de aluguel por %d rodada(s)!" % waiver_r
			_trade_confirm_pact_label.visible = true
		else:
			_trade_confirm_pact_label.visible = false
	_trade_confirm_overlay.move_to_front()
	_trade_confirm_overlay.visible = true

func hide_trade_confirm_modal() -> void:
	if _trade_confirm_overlay != null:
		_trade_confirm_overlay.visible = false
	_trade_confirm_offer_id = -1

# 2C. Modal Dedicado de Leilão Periódico de Terrenos
func _build_auction_modal() -> void:
	_auction_overlay = _create_modal_backdrop(Callable())

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auction_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(620.0 if _is_touch_mode else 560.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#111D17", "#F5D06F", 18, 2)
	card_style.shadow_size = 28
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var main_vb: VBoxContainer = VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 0)
	card.add_child(main_vb)

	_auction_banner = PanelContainer.new()
	var ab_sb: StyleBoxFlat = StyleBoxFlat.new()
	ab_sb.bg_color = Color("#2D5248")
	ab_sb.corner_radius_top_left = 16
	ab_sb.corner_radius_top_right = 16
	_auction_banner.add_theme_stylebox_override("panel", ab_sb)
	main_vb.add_child(_auction_banner)
	_enable_modal_drag(card, _auction_banner, _auction_overlay)

	var bm: MarginContainer = MarginContainer.new()
	bm.add_theme_constant_override("margin_left", 22)
	bm.add_theme_constant_override("margin_right", 22)
	bm.add_theme_constant_override("margin_top", 14)
	bm.add_theme_constant_override("margin_bottom", 14)
	_auction_banner.add_child(bm)

	var b_vb: VBoxContainer = VBoxContainer.new()
	b_vb.add_theme_constant_override("separation", 3)
	bm.add_child(b_vb)

	var hdr_tag: Label = Label.new()
	hdr_tag.text = "LEILÃO PERIÓDICO DO PAMPA"
	hdr_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		hdr_tag.add_theme_font_override("font", _bold_font)
	hdr_tag.add_theme_font_size_override("font_size", _fs(11.5))
	hdr_tag.add_theme_color_override("font_color", Color("#FFF3C4"))
	b_vb.add_child(hdr_tag)

	_auction_title_label = Label.new()
	_auction_title_label.text = "Terreno"
	_auction_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_auction_title_label.add_theme_font_override("font", _bold_font)
	_auction_title_label.add_theme_font_size_override("font_size", _fs(21.0))
	_auction_title_label.add_theme_color_override("font_color", Color.WHITE)
	b_vb.add_child(_auction_title_label)

	var body_m: MarginContainer = MarginContainer.new()
	body_m.add_theme_constant_override("margin_left", 24)
	body_m.add_theme_constant_override("margin_right", 24)
	body_m.add_theme_constant_override("margin_top", 16)
	body_m.add_theme_constant_override("margin_bottom", 20)
	main_vb.add_child(body_m)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	body_m.add_child(vb)

	_auction_meta_label = Label.new()
	_auction_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_auction_meta_label.add_theme_font_size_override("font_size", _fs(13.5))
	_auction_meta_label.add_theme_color_override("font_color", Color("#BDD3C6"))
	vb.add_child(_auction_meta_label)

	var bid_card: PanelContainer = PanelContainer.new()
	var bid_sb: StyleBoxFlat = _make_panel_style("#0B1410", "#355043", 10, 1)
	bid_sb.content_margin_left = 14.0
	bid_sb.content_margin_right = 14.0
	bid_sb.content_margin_top = 12.0
	bid_sb.content_margin_bottom = 12.0
	bid_card.add_theme_stylebox_override("panel", bid_sb)
	vb.add_child(bid_card)

	_auction_bid_label = Label.new()
	_auction_bid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_auction_bid_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _bold_font != null:
		_auction_bid_label.add_theme_font_override("font", _bold_font)
	_auction_bid_label.add_theme_font_size_override("font_size", _fs(16.0))
	_auction_bid_label.add_theme_color_override("font_color", Color("#F8D568"))
	bid_card.add_child(_auction_bid_label)

	_auction_turn_label = Label.new()
	_auction_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_auction_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auction_turn_label.add_theme_font_size_override("font_size", _fs(14.0))
	_auction_turn_label.add_theme_color_override("font_color", Color("#90E0EF"))
	vb.add_child(_auction_turn_label)

	var bid_row: HBoxContainer = HBoxContainer.new()
	bid_row.add_theme_constant_override("separation", 8)
	vb.add_child(bid_row)

	var btn_h: float = _bh(44.0)
	_auction_btn_min = Button.new()
	_auction_btn_min.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_auction_btn_min, "#227557", "#2C946E", "#185740", "#A8FF78", Color.WHITE, true, btn_h, _fs(13.0), 6.0, true)
	_auction_btn_min.pressed.connect(func() -> void: auction_bid_submitted.emit(_auction_min_next_val))
	bid_row.add_child(_auction_btn_min)

	_auction_btn_20 = Button.new()
	_auction_btn_20.text = "+P$ 20"
	_auction_btn_20.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_auction_btn_20, "#1D4434", "#275C46", "#143025", "#52B788", Color("#D8FFE8"), false, btn_h, _fs(13.0), 6.0, true)
	_auction_btn_20.pressed.connect(func() -> void: auction_bid_submitted.emit(_auction_min_next_val + 20))
	bid_row.add_child(_auction_btn_20)

	_auction_btn_50 = Button.new()
	_auction_btn_50.text = "+P$ 50"
	_auction_btn_50.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_auction_btn_50, "#1D4434", "#275C46", "#143025", "#52B788", Color("#D8FFE8"), false, btn_h, _fs(13.0), 6.0, true)
	_auction_btn_50.pressed.connect(func() -> void: auction_bid_submitted.emit(_auction_min_next_val + 50))
	bid_row.add_child(_auction_btn_50)

	_auction_btn_100 = Button.new()
	_auction_btn_100.text = "+P$ 100"
	_auction_btn_100.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_auction_btn_100, "#1D4434", "#275C46", "#143025", "#52B788", Color("#D8FFE8"), false, btn_h, _fs(13.0), 6.0, true)
	_auction_btn_100.pressed.connect(func() -> void: auction_bid_submitted.emit(_auction_min_next_val + 100))
	bid_row.add_child(_auction_btn_100)

	_auction_btn_pass = Button.new()
	_auction_btn_pass.text = "Desistir do Leilão"
	_apply_button_theme(_auction_btn_pass, "#4A2124", "#662D31", "#331618", "#FF758F", Color("#FFE8E8"), false, _bh(42.0), _fs(13.5), 10.0, true)
	_auction_btn_pass.pressed.connect(func() -> void: auction_pass_submitted.emit())
	vb.add_child(_auction_btn_pass)

func refresh_auction_modal(auction_data: Dictionary, local_player_id: int, is_online: bool) -> void:
	if _auction_overlay == null:
		return
	if auction_data.is_empty() or not bool(auction_data.get("active", false)):
		hide_auction_modal()
		return

	var tile_name: String = str(auction_data.get("tile_name", "Terreno"))
	var base_price: int = int(auction_data.get("tile_price", 0))
	var min_open: int = int(auction_data.get("min_bid", 20))
	var cur_bid: int = int(auction_data.get("current_bid", 0))
	var high_name: String = str(auction_data.get("highest_bidder_name", ""))
	var seller_id: int = int(auction_data.get("seller_id", -1))
	var seller_name: String = str(auction_data.get("seller_name", ""))
	var color_hex: String = str(auction_data.get("color_hex", "#2D5248"))

	var ab_sb: StyleBoxFlat = StyleBoxFlat.new()
	ab_sb.bg_color = Color(color_hex)
	ab_sb.corner_radius_top_left = 16
	ab_sb.corner_radius_top_right = 16
	_auction_banner.add_theme_stylebox_override("panel", ab_sb)
	_auction_title_label.text = tile_name
	var seller_prefix: String = ("Vendedor: %s • " % seller_name) if (seller_id >= 0 and seller_name != "") else ""
	_auction_meta_label.text = "%sTabela: %s • Lance mínimo inicial: %s" % [seller_prefix, _format_brl(base_price), _format_brl(min_open)]
	_auction_bid_label.text = TradeAndAuctionHelper.format_auction_status(cur_bid, min_open, high_name)

	_auction_min_next_val = min_open if cur_bid <= 0 else (cur_bid + 10)
	var elig: Array = auction_data.get("eligible_ids", [])
	var t_idx: int = clampi(int(auction_data.get("turn_bidder_index", 0)), 0, maxi(0, elig.size() - 1))
	var bidder_id: int = int(elig[t_idx]) if not elig.is_empty() else -1

	var bidder_name: String = "Estanceiro"
	var bidder_is_bot: bool = false
	var bidder_money: int = 0
	for p: Dictionary in _cached_players:
		if int(p.get("id", -1)) == bidder_id:
			bidder_name = str(p.get("name", "Estanceiro"))
			bidder_is_bot = bool(p.get("is_bot", false))
			bidder_money = int(p.get("money", 0))
			break

	var can_local_act: bool = (bidder_id >= 0 and not bidder_is_bot)
	if is_online:
		can_local_act = can_local_act and (bidder_id == local_player_id)

	if bidder_is_bot:
		_auction_turn_label.text = "Vez de %s [BOT] decidir o lance..." % bidder_name
	elif can_local_act:
		_auction_turn_label.text = "Sua vez (%s • Saldo: %s): cubra ou desista!" % [bidder_name, _format_brl(bidder_money)]
	else:
		_auction_turn_label.text = "Aguardando lance de %s..." % bidder_name

	_auction_btn_min.text = "Cobrir %s" % _format_brl(_auction_min_next_val)
	_auction_btn_min.disabled = (not can_local_act) or (bidder_money < _auction_min_next_val)
	_auction_btn_20.disabled = (not can_local_act) or (bidder_money < _auction_min_next_val + 20)
	_auction_btn_50.disabled = (not can_local_act) or (bidder_money < _auction_min_next_val + 50)
	_auction_btn_100.disabled = (not can_local_act) or (bidder_money < _auction_min_next_val + 100)
	_auction_btn_pass.disabled = not can_local_act

	_auction_overlay.move_to_front()
	_auction_overlay.visible = true

func hide_auction_modal() -> void:
	if _auction_overlay != null:
		_auction_overlay.visible = false
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

	var b_trophies: Button = Button.new()
	b_trophies.text = "Troféus de Carreira"
	_apply_button_theme(b_trophies, "#262313", "#38331B", "#1A180D", "#D4AF37", Color("#FFF2C6"), false, btn_h, btn_fs, 12.0, true)
	b_trophies.pressed.connect(func() -> void:
		hide_pause_modal()
		trophies_requested.emit()
	)
	vbox.add_child(b_trophies)

	_pause_bot_leave_btn = Button.new()
	_pause_bot_leave_btn.text = "Passar Vaga para [BOT]"
	_apply_button_theme(_pause_bot_leave_btn, "#18364A", "#214A66", "#112736", "#4EA8DE", Color("#D8F3FF"), false, btn_h, btn_fs, 12.0, true)
	_pause_bot_leave_btn.pressed.connect(func() -> void:
		hide_pause_modal()
		leave_to_bot_requested.emit()
	)
	vbox.add_child(_pause_bot_leave_btn)

	_pause_forfeit_btn = Button.new()
	_pause_forfeit_btn.text = "Declarar Desistência"
	_apply_button_theme(_pause_forfeit_btn, "#4D2024", "#6B2C32", "#361619", "#FF758F", Color("#FFE4E4"), false, btn_h, btn_fs, 12.0, true)
	_pause_forfeit_btn.pressed.connect(func() -> void:
		hide_pause_modal()
		forfeit_match_requested.emit()
	)
	vbox.add_child(_pause_forfeit_btn)

	_pause_menu_btn = Button.new()
	_pause_menu_btn.text = "Voltar à Tela Inicial"
	_apply_button_theme(_pause_menu_btn, "#3A2322", "#50302E", "#291817", "#C46E5F", Color("#FFE4E4"), false, btn_h, btn_fs, 12.0, true)
	_pause_menu_btn.pressed.connect(func() -> void:
		hide_pause_modal()
		menu_requested.emit()
	)
	vbox.add_child(_pause_menu_btn)

	_pause_quit_btn = Button.new()
	_pause_quit_btn.text = "Fechar o Jogo"
	_pause_quit_btn.visible = not OS.has_feature("web")
	_apply_button_theme(_pause_quit_btn, "#3E1B20", "#58272E", "#2A1216", "#C95D69", Color("#FFE4E8"), false, btn_h, btn_fs, 12.0, true)
	_pause_quit_btn.pressed.connect(func() -> void:
		hide_pause_modal()
		quit_game_requested.emit()
	)
	vbox.add_child(_pause_quit_btn)

func show_pause_modal() -> void:
	var active_count: int = 0
	var local_human_active: bool = false
	for p: Dictionary in _cached_players:
		if not bool(p.get("bankrupt", false)):
			active_count += 1
			if not bool(p.get("is_bot", false)):
				if not _net_is_online or int(p.get("id", -1)) == _net_local_player_id:
					local_human_active = true
	if _pause_bot_leave_btn != null:
		var can_pass_to_bot: bool = local_human_active and (active_count >= 2) and (not (_net_is_online and _net_is_host))
		_pause_bot_leave_btn.visible = can_pass_to_bot
		if _net_is_online and not _net_is_host:
			_pause_bot_leave_btn.text = "Passar Vaga para [BOT] e Sair"
		else:
			_pause_bot_leave_btn.text = "Passar Minha Vez para [BOT]"
	if _pause_forfeit_btn != null:
		_pause_forfeit_btn.visible = local_human_active and (active_count >= 2) and (not (_net_is_online and _net_is_host))
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

	_help_card = PanelContainer.new()
	_help_card.custom_minimum_size = Vector2(680.0 if _is_touch_mode else 620.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#121D17", "#D4AF37", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	_help_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_help_card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_help_card.add_child(margin)

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
	_enable_modal_drag(_help_card, title, _help_overlay)

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
		["Economia Base (PILA)", "Cada estanceiro começa com P$ 2.558 (2.558 Pilas). O Banco possui 32 casas e 12 estâncias/hotéis."],
		["Estações do Pampa", "No modo Estância Dinâmica, o clima alterna entre Primavera (+25% Galpão), Verão (+25% safra), Outono (-20% obras) e Inverno (+25% taxas)."],
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

func _build_trophies_modal() -> void:
	_trophies_overlay = _create_modal_backdrop(hide_trophies_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trophies_overlay.add_child(center)

	_trophies_card = PanelContainer.new()
	_trophies_card.custom_minimum_size = Vector2(540.0 if _is_touch_mode else 500.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#121B16", "#D4AF37", 18, 2)
	card_style.shadow_size = 24
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	_trophies_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_trophies_card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_trophies_card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "GALERIA DE TROFÉUS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", _fs(20.0))
	title_lbl.add_theme_color_override("font_color", Color("#F5D06F"))
	vbox.add_child(title_lbl)

	_enable_modal_drag(_trophies_card, title_lbl, _trophies_overlay)

	_trophies_summary_label = Label.new()
	_trophies_summary_label.text = "0 de 6 troféus conquistados"
	_trophies_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trophies_summary_label.add_theme_font_size_override("font_size", _fs(12.5))
	_trophies_summary_label.add_theme_color_override("font_color", Color("#B9D4C4"))
	vbox.add_child(_trophies_summary_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 320.0 if _is_touch_mode else 280.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_trophies_list_box = VBoxContainer.new()
	_trophies_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trophies_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_trophies_list_box)

	var btn_close: Button = Button.new()
	btn_close.text = "Fechar" if _is_touch_mode else "Fechar [ESC]"
	_apply_button_theme(btn_close, "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), true, _bh(42.0), _fs(14.0), 12.0, true)
	btn_close.pressed.connect(hide_trophies_modal)
	vbox.add_child(btn_close)

func show_trophies_modal(trophies: Array[Dictionary]) -> void:
	if _trophies_overlay == null or _trophies_list_box == null:
		return
	for ch: Node in _trophies_list_box.get_children():
		ch.queue_free()
	var unlocked_cnt: int = 0
	for item: Dictionary in trophies:
		var is_unlocked: bool = bool(item.get("unlocked", false))
		if is_unlocked:
			unlocked_cnt += 1
		var card: PanelContainer = PanelContainer.new()
		var c_sb: StyleBoxFlat = _make_panel_style("#172C20" if is_unlocked else "#121A16", "#D4AF37" if is_unlocked else "#2B3D34", 10, 1)
		c_sb.content_margin_left = 12.0
		c_sb.content_margin_right = 12.0
		c_sb.content_margin_top = 8.0
		c_sb.content_margin_bottom = 8.0
		card.add_theme_stylebox_override("panel", c_sb)
		_trophies_list_box.add_child(card)

		var row_vb: VBoxContainer = VBoxContainer.new()
		row_vb.add_theme_constant_override("separation", 2)
		card.add_child(row_vb)

		var hdr_lbl: Label = Label.new()
		var badge_prefix: String = "[CONQUISTADO] " if is_unlocked else "[BLOQUEADO] "
		hdr_lbl.text = badge_prefix + str(item.get("title", "Troféu"))
		if _bold_font != null:
			hdr_lbl.add_theme_font_override("font", _bold_font)
		hdr_lbl.add_theme_font_size_override("font_size", _fs(13.5))
		hdr_lbl.add_theme_color_override("font_color", Color("#F8D568") if is_unlocked else Color("#7F9588"))
		row_vb.add_child(hdr_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = str(item.get("desc", ""))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", _fs(12.0))
		desc_lbl.add_theme_color_override("font_color", Color("#E4F2EA") if is_unlocked else Color("#6C7E73"))
		row_vb.add_child(desc_lbl)

	if _trophies_summary_label != null:
		_trophies_summary_label.text = "%d de %d troféus conquistados" % [unlocked_cnt, trophies.size()]
	_trophies_overlay.move_to_front()
	_trophies_overlay.visible = true

func hide_trophies_modal() -> void:
	if _trophies_overlay != null:
		_trophies_overlay.visible = false

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
	var team_name: String = str(info.get("team_name", ""))
	var team_members: String = str(info.get("team_members", ""))
	var display_name: String = ("EQUIPE %s VENCEU!" % team_name.to_upper()) if team_name != "" else ("%s [BOT]" % winner_name if is_bot else winner_name)
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
	if team_name != "" and team_members != "":
		_add_victory_stat_row("Integrantes (%s)" % team_name, team_members, Color(str(info.get("team_color_hex", "#F8D568"))), false)

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
	_enable_modal_drag(_chance_card, banner, _chance_overlay)

	var body_panel: PanelContainer = PanelContainer.new()
	var bp_style: StyleBoxFlat = StyleBoxFlat.new()
	bp_style.bg_color = Color("#0D1913")
	bp_style.corner_radius_bottom_left = 16
	bp_style.corner_radius_bottom_right = 16
	body_panel.add_theme_stylebox_override("panel", bp_style)
	body_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	card_vbox.add_child(body_panel)

	if ResourceLoader.exists("res://assets/brand/chance_card_bg.jpg"):
		var bg_tex: Texture2D = load("res://assets/brand/chance_card_bg.jpg") as Texture2D
		if bg_tex != null:
			var bg_rect: TextureRect = TextureRect.new()
			bg_rect.texture = bg_tex
			bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bg_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			bg_rect.modulate = Color(0.92, 0.96, 0.92, 0.72)
			bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body_panel.add_child(bg_rect)

	var body_margin: MarginContainer = MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 26)
	body_margin.add_theme_constant_override("margin_right", 26)
	body_margin.add_theme_constant_override("margin_top", 22)
	body_margin.add_theme_constant_override("margin_bottom", 22)
	body_panel.add_child(body_margin)

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
	var tf_style: StyleBoxFlat = _make_panel_style("#0B1410", "#C9A227", 12, 1)
	tf_style.bg_color = Color(0.035, 0.070, 0.052, 0.82)
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
	_enable_modal_drag(_settings_card, title, _settings_overlay)

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

	# Leilão Periódico de Terrenos
	var auc_lbl: Label = Label.new()
	auc_lbl.text = "Leilão periódico de terrenos livres:"
	auc_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	auc_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	s2_vb.add_child(auc_lbl)

	var auc_row: HBoxContainer = HBoxContainer.new()
	auc_row.add_theme_constant_override("separation", 8)
	s2_vb.add_child(auc_row)
	_settings_auction_btns.clear()
	var auc_specs: Array[Array] = [
		["0", "Desativado"],
		["3", "A cada 3 rodadas"],
		["4", "A cada 4 rodadas"]
	]
	for spec: Array in auc_specs:
		var a_key: String = str(spec[0])
		var a_val: int = int(a_key)
		var a_btn: Button = Button.new()
		a_btn.text = str(spec[1])
		a_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a_btn.pressed.connect(func() -> void: _set_global_pref("auction_interval_rounds", a_val))
		auc_row.add_child(a_btn)
		_settings_auction_btns[a_key] = a_btn

	# --- Seção 3: Áudio & Efeitos Sonoros ---
	var sec3: PanelContainer = PanelContainer.new()
	var sec3_style: StyleBoxFlat = _make_panel_style("#0B1410", "#273C31", 12, 1)
	sec3_style.content_margin_left = 14.0
	sec3_style.content_margin_right = 14.0
	sec3_style.content_margin_top = 12.0
	sec3_style.content_margin_bottom = 12.0
	sec3.add_theme_stylebox_override("panel", sec3_style)
	content_vb.add_child(sec3)

	var s3_vb: VBoxContainer = VBoxContainer.new()
	s3_vb.add_theme_constant_override("separation", 10)
	sec3.add_child(s3_vb)

	var s3_hdr: Label = Label.new()
	s3_hdr.text = "ÁUDIO & EFEITOS SONOROS"
	if _bold_font != null:
		s3_hdr.add_theme_font_override("font", _bold_font)
	s3_hdr.add_theme_font_size_override("font_size", _fs(13.0))
	s3_hdr.add_theme_color_override("font_color", Color("#F3C969"))
	s3_vb.add_child(s3_hdr)

	var audio_lbl: Label = Label.new()
	audio_lbl.text = "Efeitos sonoros da partida:"
	audio_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	audio_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	s3_vb.add_child(audio_lbl)

	var audio_row: HBoxContainer = HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 8)
	s3_vb.add_child(audio_row)
	_settings_audio_btns.clear()
	var audio_specs: Array[Array] = [
		["on", "Som Ativo"],
		["off", "Silenciado (Mudo)"]
	]
	for spec: Array in audio_specs:
		var au_key: String = str(spec[0])
		var au_val: bool = (au_key == "on")
		var au_btn: Button = Button.new()
		au_btn.text = str(spec[1])
		au_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		au_btn.pressed.connect(func() -> void: _set_global_pref("audio_enabled", au_val))
		audio_row.add_child(au_btn)
		_settings_audio_btns[au_key] = au_btn

	var vol_lbl: Label = Label.new()
	vol_lbl.text = "Volume dos efeitos:"
	vol_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	vol_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	s3_vb.add_child(vol_lbl)

	var vol_row: HBoxContainer = HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 8)
	s3_vb.add_child(vol_row)
	_settings_volume_btns.clear()
	var vol_specs: Array[Array] = [
		["0.25", "25%"],
		["0.50", "50%"],
		["0.75", "75%"],
		["1.00", "100%"]
	]
	for spec: Array in vol_specs:
		var v_key: String = str(spec[0])
		var v_val: float = float(v_key)
		var v_btn: Button = Button.new()
		v_btn.text = str(spec[1])
		v_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v_btn.pressed.connect(func() -> void: _set_global_pref("audio_volume", v_val))
		vol_row.add_child(v_btn)
		_settings_volume_btns[v_key] = v_btn

	var step_lbl: Label = Label.new()
	step_lbl.text = "Sons sutis (passos dos peões e cliques):"
	step_lbl.add_theme_font_size_override("font_size", _fs(12.5))
	step_lbl.add_theme_color_override("font_color", Color("#CFE0D6"))
	s3_vb.add_child(step_lbl)

	var step_row: HBoxContainer = HBoxContainer.new()
	step_row.add_theme_constant_override("separation", 8)
	s3_vb.add_child(step_row)
	_settings_step_sfx_btns.clear()
	var step_specs: Array[Array] = [
		["on", "Passos e Cliques ON"],
		["off", "Só Alertas"]
	]
	for spec: Array in step_specs:
		var st_key: String = str(spec[0])
		var st_val: bool = (st_key == "on")
		var st_btn: Button = Button.new()
		st_btn.text = str(spec[1])
		st_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st_btn.pressed.connect(func() -> void: _set_global_pref("audio_step_sfx", st_val))
		step_row.add_child(st_btn)
		_settings_step_sfx_btns[st_key] = st_btn

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
	_refresh_sound_button()
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

	var auc_interval: String = str(int(_prefs_cache.get("auction_interval_rounds", 3)))
	for a_key: String in _settings_auction_btns.keys():
		_style_seg_btn(_settings_auction_btns[a_key], a_key == auc_interval)

	var audio_on: bool = bool(_prefs_cache.get("audio_enabled", true))
	for au_key: String in _settings_audio_btns.keys():
		_style_seg_btn(_settings_audio_btns[au_key], (au_key == "on") == audio_on)

	var cur_vol: float = float(_prefs_cache.get("audio_volume", 0.75))
	for v_key: String in _settings_volume_btns.keys():
		var v_btn: Button = _settings_volume_btns[v_key]
		v_btn.disabled = not audio_on
		_style_seg_btn(v_btn, absf(float(v_key) - cur_vol) < 0.08)

	var step_sfx_on: bool = bool(_prefs_cache.get("audio_step_sfx", true))
	for st_key: String in _settings_step_sfx_btns.keys():
		var st_btn: Button = _settings_step_sfx_btns[st_key]
		st_btn.disabled = not audio_on
		_style_seg_btn(st_btn, (st_key == "on") == step_sfx_on)

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
	_enable_modal_drag(_portfolio_card, _portfolio_banner, _portfolio_overlay)

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
	_portfolio_money_label.text = "P$ 0"
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
	list_hdr.text = "ESCRITURAS E HIPOTECAS (TOQUE PARA ABRIR A CARTA)"
	if _bold_font != null:
		list_hdr.add_theme_font_override("font", _bold_font)
	list_hdr.add_theme_font_size_override("font_size", _fs(11.0))
	list_hdr.add_theme_color_override("font_color", Color("#A7C2B2"))
	body_vb.add_child(list_hdr)

	_portfolio_debt_banner = PanelContainer.new()
	_portfolio_debt_banner.visible = false
	var db_sb: StyleBoxFlat = _make_panel_style("#3D1B1E", "#FF758F", 9, 1)
	db_sb.content_margin_left = 10.0
	db_sb.content_margin_right = 10.0
	db_sb.content_margin_top = 6.0
	db_sb.content_margin_bottom = 6.0
	_portfolio_debt_banner.add_theme_stylebox_override("panel", db_sb)
	body_vb.add_child(_portfolio_debt_banner)

	_portfolio_debt_label = Label.new()
	_portfolio_debt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_portfolio_debt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_portfolio_debt_label.add_theme_font_override("font", _bold_font)
	_portfolio_debt_label.add_theme_font_size_override("font_size", _fs(12.0))
	_portfolio_debt_label.add_theme_color_override("font_color", Color("#FFD6DD"))
	_portfolio_debt_banner.add_child(_portfolio_debt_label)

	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	body_vb.add_child(filter_row)
	_portfolio_filter_btns.clear()
	var filter_specs: Array[Array] = [
		["all", "Todas"],
		["mortgageable", "Hipotecáveis"],
		["mortgaged", "Hipotecadas"]
	]
	for spec: Array in filter_specs:
		var f_key: String = str(spec[0])
		var f_btn: Button = Button.new()
		f_btn.text = str(spec[1])
		f_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f_btn.pressed.connect(func() -> void: _set_portfolio_filter(f_key))
		filter_row.add_child(f_btn)
		_portfolio_filter_btns[f_key] = f_btn

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

	var p_btn_row: HBoxContainer = HBoxContainer.new()
	p_btn_row.add_theme_constant_override("separation", 10)
	body_vb.add_child(p_btn_row)

	_portfolio_cart_btn = Button.new()
	_portfolio_cart_btn.text = "Carrinho de Obras"
	_portfolio_cart_btn.visible = false
	_portfolio_cart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(_portfolio_cart_btn, "#1D4A38", "#27644C", "#143528", "#52B788", Color("#E4FFF2"), true, _bh(42.0), _fs(13.5), 12.0, true)
	_portfolio_cart_btn.pressed.connect(func() -> void:
		hide_player_portfolio_modal()
		show_construction_cart_modal("")
	)
	p_btn_row.add_child(_portfolio_cart_btn)

	var btn_close: Button = Button.new()
	btn_close.text = "Fechar" if _is_touch_mode else "Fechar [ESC]"
	btn_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(btn_close, "#213329", "#2E473A", "#17241D", "#D4AF37", Color.WHITE, false, _bh(42.0), _fs(14.0), 14.0, true)
	btn_close.pressed.connect(hide_player_portfolio_modal)
	p_btn_row.add_child(btn_close)

func show_player_portfolio_modal(info: Dictionary) -> void:
	if _portfolio_overlay == null:
		return
	_portfolio_last_info = info.duplicate(true)
	_portfolio_open_pid = int(info.get("id", -1))
	_render_portfolio_modal_contents()
	_portfolio_overlay.visible = true

func _set_portfolio_filter(filter_key: String) -> void:
	_portfolio_filter = filter_key
	if not _portfolio_last_info.is_empty():
		_render_portfolio_modal_contents()

func _render_portfolio_modal_contents() -> void:
	var info: Dictionary = _portfolio_last_info
	for ch: Node in _portfolio_monopoly_box.get_children():
		ch.queue_free()
	for ch: Node in _portfolio_list_box.get_children():
		ch.queue_free()

	var info_pid: int = int(info.get("id", -1))
	var p_name: String = str(info.get("name", "Estanceiro"))
	var is_bot: bool = bool(info.get("is_bot", false))
	var is_bankrupt: bool = bool(info.get("is_bankrupt", false))
	var in_jail: bool = bool(info.get("in_jail", false))
	var jail_cards: int = int(info.get("jail_free_cards", 0))
	var money: int = int(info.get("money", 0))
	var max_liq: int = int(info.get("max_liquidatable", 0))
	var can_manage_owner: bool = bool(info.get("can_manage_owner", false))
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

	if _portfolio_debt_banner != null and _portfolio_debt_label != null:
		var show_debt: bool = (not is_bankrupt) and (money < 0)
		_portfolio_debt_banner.visible = show_debt
		if show_debt:
			_portfolio_debt_label.text = "DÍVIDA: -%s • Máximo liquidável em bens: %s (use os botões abaixo)" % [_format_brl(absi(money)), _format_brl(max_liq)]

	var count_all: int = deeds.size()
	var count_mortgaged: int = 0
	var count_mortgageable: int = 0
	for d_item: Variant in deeds:
		if d_item is Dictionary:
			var dd: Dictionary = d_item
			if bool(dd.get("is_mortgaged", false)):
				count_mortgaged += 1
			else:
				count_mortgageable += 1

	if _portfolio_filter_btns.has("all"):
		_portfolio_filter_btns["all"].text = "Todas (%d)" % count_all
	if _portfolio_filter_btns.has("mortgageable"):
		_portfolio_filter_btns["mortgageable"].text = "Hipotecáveis (%d)" % count_mortgageable
	if _portfolio_filter_btns.has("mortgaged"):
		_portfolio_filter_btns["mortgaged"].text = "Hipotecadas (%d)" % count_mortgaged
	for f_key: String in _portfolio_filter_btns.keys():
		_style_seg_btn(_portfolio_filter_btns[f_key], f_key == _portfolio_filter)

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

	var shown_count: int = 0
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

		if _portfolio_filter == "mortgaged" and not is_mort:
			continue
		if _portfolio_filter == "mortgageable" and is_mort:
			continue
		shown_count += 1

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
					hide_player_portfolio_modal()
					inspect_tile_requested.emit(tile_ref)
		)
		_portfolio_list_box.add_child(row_card)

		var row_vb: VBoxContainer = VBoxContainer.new()
		row_vb.add_theme_constant_override("separation", 6)
		row_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_card.add_child(row_vb)

		var r_hb: HBoxContainer = HBoxContainer.new()
		r_hb.add_theme_constant_override("separation", 10)
		r_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		r_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vb.add_child(r_hb)

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

		if can_manage_owner:
			var can_sell: bool = bool(d.get("can_sell_building", false))
			var can_mort: bool = bool(d.get("can_mortgage", false))
			if can_sell or can_mort:
				var q_row: HBoxContainer = HBoxContainer.new()
				q_row.add_theme_constant_override("separation", 6)
				row_vb.add_child(q_row)
				var q_h: float = _bh(30.0)
				var q_fs: int = _fs(11.5)
				if can_sell:
					var q_sell: Button = Button.new()
					q_sell.text = str(d.get("sell_building_label", "-Casa"))
					q_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					_apply_button_theme(q_sell, "#3D2724", "#553631", "#2B1B19", "#C46E5F", Color.WHITE, false, q_h, q_fs, 8.0, true)
					q_sell.pressed.connect(func() -> void: sell_building_pressed.emit(tile_ref))
					q_row.add_child(q_sell)
				if can_mort:
					var q_mort: Button = Button.new()
					q_mort.text = str(d.get("mortgage_label", "Hipotecar"))
					q_mort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					if is_mort:
						_apply_button_theme(q_mort, "#1B4236", "#255949", "#132E26", "#52B788", Color("#E8FFF2"), false, q_h, q_fs, 8.0, true)
					else:
						_apply_button_theme(q_mort, "#2B323C", "#3B4553", "#1F242B", "#8FA3B8", Color.WHITE, false, q_h, q_fs, 8.0, true)
					q_mort.pressed.connect(func() -> void: mortgage_pressed.emit(tile_ref))
					q_row.add_child(q_mort)

	_portfolio_empty_label.visible = (shown_count == 0)
	if deeds.is_empty():
		_portfolio_empty_label.text = "Este estanceiro ainda não possui escrituras."
	elif shown_count == 0:
		_portfolio_empty_label.text = "Nenhuma escritura corresponde ao filtro selecionado."
	if _portfolio_cart_btn != null:
		var can_cart_here: bool = (
			not _cached_is_bot_turn
			and info_pid >= 0
			and info_pid == _cached_active_pid
			and not monopolies.is_empty()
		)
		_portfolio_cart_btn.visible = can_cart_here

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
	_portfolio_open_pid = -1
	if _portfolio_overlay != null:
		_portfolio_overlay.visible = false

func get_open_portfolio_player_id() -> int:
	if _portfolio_overlay != null and _portfolio_overlay.visible:
		return _portfolio_open_pid
	return -1

# 9. Modal de Carrinho de Obras (Construção/Venda Equilibrada em Lote nos Monopólios)
func _build_construction_cart_modal() -> void:
	_cart_overlay = _create_modal_backdrop(hide_construction_cart_modal)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cart_overlay.add_child(center)

	_cart_card = PanelContainer.new()
	_cart_card.custom_minimum_size = Vector2(680.0 if _is_touch_mode else 620.0, 0.0)
	var card_style: StyleBoxFlat = _make_panel_style("#121E18", "#52B788", 18, 2)
	card_style.shadow_size = 26
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	_cart_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_cart_card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_cart_card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var hdr_row: HBoxContainer = HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 10)
	vbox.add_child(hdr_row)
	_enable_modal_drag(_cart_card, hdr_row, _cart_overlay)

	var title_vb: VBoxContainer = VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vb.add_theme_constant_override("separation", 2)
	hdr_row.add_child(title_vb)

	var title_lbl: Label = Label.new()
	title_lbl.text = "CARRINHO DE OBRAS (MONOPÓLIOS)"
	if _bold_font != null:
		title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", _fs(18.0))
	title_lbl.add_theme_color_override("font_color", Color("#9CF6B8"))
	title_vb.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "Planeje casas e hotéis respeitando o equilíbrio por grupo e o estoque do Banco."
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", _fs(11.5))
	sub_lbl.add_theme_color_override("font_color", Color("#A7C2B2"))
	title_vb.add_child(sub_lbl)

	_cart_bank_label = Label.new()
	_cart_bank_label.text = "Banco: 32C • 12H"
	_cart_bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _bold_font != null:
		_cart_bank_label.add_theme_font_override("font", _bold_font)
	_cart_bank_label.add_theme_font_size_override("font_size", _fs(12.5))
	_cart_bank_label.add_theme_color_override("font_color", Color("#F5CA5C"))
	hdr_row.add_child(_cart_bank_label)

	_cart_scroll = ScrollContainer.new()
	_cart_scroll.custom_minimum_size = Vector2(0.0, 360.0 if _is_touch_mode else 320.0)
	_cart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cart_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(_cart_scroll)

	_cart_list_box = VBoxContainer.new()
	_cart_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cart_list_box.add_theme_constant_override("separation", 10)
	_cart_scroll.add_child(_cart_list_box)

	var summary_panel: PanelContainer = PanelContainer.new()
	var sum_sb: StyleBoxFlat = _make_panel_style("#0E1712", "#2F4E3F", 10, 1)
	sum_sb.content_margin_left = 12.0
	sum_sb.content_margin_right = 12.0
	sum_sb.content_margin_top = 8.0
	sum_sb.content_margin_bottom = 8.0
	summary_panel.add_theme_stylebox_override("panel", sum_sb)
	vbox.add_child(summary_panel)

	_cart_summary_label = Label.new()
	_cart_summary_label.text = ""
	_cart_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cart_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _bold_font != null:
		_cart_summary_label.add_theme_font_override("font", _bold_font)
	_cart_summary_label.add_theme_font_size_override("font_size", _fs(12.5))
	_cart_summary_label.add_theme_color_override("font_color", Color("#E4F2EA"))
	summary_panel.add_child(_cart_summary_label)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var btn_reset: Button = Button.new()
	btn_reset.text = "Zerar"
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset.size_flags_stretch_ratio = 0.65
	_apply_button_theme(btn_reset, "#26302B", "#34433C", "#1A221E", "#5A7366", Color("#D8E8DE"), false, _bh(42.0), _fs(13.0), 10.0, true)
	btn_reset.pressed.connect(_reset_cart_draft)
	btn_row.add_child(btn_reset)

	var btn_cancel: Button = Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.size_flags_stretch_ratio = 0.75
	_apply_button_theme(btn_cancel, "#242D29", "#33403A", "#19201D", "#6C8477", Color.WHITE, false, _bh(42.0), _fs(13.5), 10.0, true)
	btn_cancel.pressed.connect(hide_construction_cart_modal)
	btn_row.add_child(btn_cancel)

	_cart_confirm_btn = Button.new()
	_cart_confirm_btn.text = "Confirmar Obras"
	_cart_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cart_confirm_btn.size_flags_stretch_ratio = 1.4
	_apply_button_theme(_cart_confirm_btn, "#227557", "#2C946E", "#185740", "#A8FF78", Color.WHITE, true, _bh(42.0), _fs(14.0), 10.0, true)
	_cart_confirm_btn.pressed.connect(_apply_cart_confirm)
	btn_row.add_child(_cart_confirm_btn)

func show_construction_cart_modal(focus_group: String = "") -> void:
	if _cart_overlay == null or _cached_is_bot_turn:
		return
	if _cached_current_idx < 0 or _cached_current_idx >= _cached_players.size():
		return
	_cart_focus_group = focus_group
	_reset_cart_draft()
	_cart_overlay.visible = true

func hide_construction_cart_modal() -> void:
	if _cart_overlay != null:
		_cart_overlay.visible = false

func _reset_cart_draft() -> void:
	_cart_draft_levels.clear()
	if _cached_current_idx >= 0 and _cached_current_idx < _cached_players.size():
		var pid: int = int(_cached_players[_cached_current_idx].get("id", _cached_current_idx))
		var monos: Array[Dictionary] = ConstructionCartHelper.collect_player_monopolies(
			pid, _cached_tiles, _cached_owners_map, _cached_mortgaged_map
		)
		for m: Dictionary in monos:
			var g_tiles: Array = m.get("tiles", [])
			for tid_var: Variant in g_tiles:
				var tid: int = int(tid_var)
				_cart_draft_levels[tid] = clampi(int(_cached_buildings_map.get(tid, 0)), 0, 5)
	_rebuild_construction_cart_ui()

func _step_cart_tile_level(tile_idx: int, delta: int) -> void:
	var cur_lvl: int = int(_cart_draft_levels.get(tile_idx, int(_cached_buildings_map.get(tile_idx, 0))))
	_cart_draft_levels[tile_idx] = clampi(cur_lvl + delta, 0, 5)
	_rebuild_construction_cart_ui()

func _apply_cart_confirm() -> void:
	var payload: Dictionary = {}
	for tid: int in _cart_draft_levels.keys():
		payload[tid] = int(_cart_draft_levels[tid])
	hide_construction_cart_modal()
	build_cart_applied.emit(payload)

func _rebuild_construction_cart_ui() -> void:
	if _cart_list_box == null:
		return
	for child: Node in _cart_list_box.get_children():
		child.queue_free()

	if _cached_current_idx < 0 or _cached_current_idx >= _cached_players.size():
		_cart_summary_label.text = "Nenhum jogador ativo."
		_cart_confirm_btn.disabled = true
		return

	var active_p: Dictionary = _cached_players[_cached_current_idx]
	var active_pid: int = int(active_p.get("id", _cached_current_idx))
	var active_money: int = int(active_p.get("money", 0))
	var monos: Array[Dictionary] = ConstructionCartHelper.collect_player_monopolies(
		active_pid, _cached_tiles, _cached_owners_map, _cached_mortgaged_map
	)

	if _cart_focus_group != "":
		var sorted_monos: Array[Dictionary] = []
		for m: Dictionary in monos:
			if str(m.get("group", "")) == _cart_focus_group:
				sorted_monos.append(m)
		for m: Dictionary in monos:
			if str(m.get("group", "")) != _cart_focus_group:
				sorted_monos.append(m)
		monos = sorted_monos

	if monos.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "Você ainda não possui um grupo de cor completo (monopólio) para construir."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", _fs(13.0))
		empty_lbl.add_theme_color_override("font_color", Color("#9CB6A7"))
		_cart_list_box.add_child(empty_lbl)
		_cart_bank_label.text = "Banco: %dC • %dH" % [_cached_houses_left, _cached_hotels_left]
		_cart_summary_label.text = "Complete todos os terrenos de uma mesma cor para liberar construções."
		_cart_confirm_btn.disabled = true
		return

	var eval: Dictionary = ConstructionCartHelper.evaluate_cart_state(
		monos, _cached_tiles, _cached_buildings_map, _cart_draft_levels, _cached_houses_left, _cached_hotels_left, active_money
	)
	var proj_houses: int = int(eval.get("projected_houses_left", _cached_houses_left))
	var proj_hotels: int = int(eval.get("projected_hotels_left", _cached_hotels_left))
	var net_cost: int = int(eval.get("net_cost", 0))
	var proj_money: int = int(eval.get("projected_money", active_money))
	var is_valid: bool = bool(eval.get("valid", false))
	var changed_count: int = int(eval.get("changed_count", 0))
	var reason: String = str(eval.get("reason", ""))

	_cart_bank_label.text = "Banco após obras: %dC • %dH" % [proj_houses, proj_hotels]
	_cart_bank_label.add_theme_color_override("font_color", Color("#FF758F") if (proj_houses < 0 or proj_hotels < 0) else Color("#F5CA5C"))

	for m: Dictionary in monos:
		var g_name: String = str(m.get("group", "")).replace("_", " ")
		var g_col_hex: String = str(m.get("color_hex", "#2A9D8F"))
		var any_mort: bool = bool(m.get("any_mortgaged", false))
		var g_tiles: Array = m.get("tiles", [])
		var is_focused: bool = (_cart_focus_group != "" and str(m.get("group", "")) == _cart_focus_group)

		var g_card: PanelContainer = PanelContainer.new()
		var g_sb: StyleBoxFlat = _make_panel_style("#16231C", "#F5CA5C" if is_focused else g_col_hex, 12, 2 if is_focused else 1)
		g_sb.content_margin_left = 12.0
		g_sb.content_margin_right = 12.0
		g_sb.content_margin_top = 10.0
		g_sb.content_margin_bottom = 10.0
		g_card.add_theme_stylebox_override("panel", g_sb)
		_cart_list_box.add_child(g_card)

		var g_vb: VBoxContainer = VBoxContainer.new()
		g_vb.add_theme_constant_override("separation", 6)
		g_card.add_child(g_vb)

		var g_hdr_hb: HBoxContainer = HBoxContainer.new()
		g_hdr_hb.add_theme_constant_override("separation", 8)
		g_vb.add_child(g_hdr_hb)

		var dot: Panel = Panel.new()
		dot.custom_minimum_size = Vector2(12.0, 12.0)
		var dot_sb: StyleBoxFlat = StyleBoxFlat.new()
		dot_sb.bg_color = Color(g_col_hex)
		dot_sb.set_corner_radius_all(3)
		dot.add_theme_stylebox_override("panel", dot_sb)
		g_hdr_hb.add_child(dot)

		var g_title: Label = Label.new()
		g_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g_title.text = "GRUPO %s%s" % [g_name, " (DESIPOTEQUE ANTES DE CONSTRUIR)" if any_mort else ""]
		if _bold_font != null:
			g_title.add_theme_font_override("font", _bold_font)
		g_title.add_theme_font_size_override("font_size", _fs(12.5))
		g_title.add_theme_color_override("font_color", Color("#FF8FA3") if any_mort else Color("#FFE699"))
		g_hdr_hb.add_child(g_title)

		for tid_var: Variant in g_tiles:
			var tid: int = int(tid_var)
			if tid < 0 or tid >= _cached_tiles.size():
				continue
			var tile: Dictionary = _cached_tiles[tid]
			var base_l: int = clampi(int(_cached_buildings_map.get(tid, 0)), 0, 5)
			var draft_l: int = clampi(int(_cart_draft_levels.get(tid, base_l)), 0, 5)
			var house_cost: int = int(tile.get("house_cost", 50))
			var sell_unit: int = floori(float(house_cost) * 0.5)

			var row_hb: HBoxContainer = HBoxContainer.new()
			row_hb.add_theme_constant_override("separation", 8)
			row_hb.alignment = BoxContainer.ALIGNMENT_CENTER
			g_vb.add_child(row_hb)

			var t_vb: VBoxContainer = VBoxContainer.new()
			t_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t_vb.add_theme_constant_override("separation", 1)
			row_hb.add_child(t_vb)

			var t_name: Label = Label.new()
			t_name.text = str(tile.get("name", "Lote"))
			t_name.clip_text = true
			if _bold_font != null:
				t_name.add_theme_font_override("font", _bold_font)
			t_name.add_theme_font_size_override("font_size", _fs(13.0))
			t_name.add_theme_color_override("font_color", Color("#FFFDF5"))
			t_vb.add_child(t_name)

			var lvl_now_str: String = "Hotel" if base_l >= 5 else ("%dc" % base_l)
			var lvl_new_str: String = "Hotel" if draft_l >= 5 else ("%dc" % draft_l)
			var t_sub: Label = Label.new()
			t_sub.text = "Atual: %s -> Plano: %s • Obra %s | Venda +%s" % [lvl_now_str, lvl_new_str, _format_brl(house_cost), _format_brl(sell_unit)]
			t_sub.add_theme_font_size_override("font_size", _fs(11.0))
			t_sub.add_theme_color_override("font_color", Color("#9CF6B8") if draft_l != base_l else Color("#9BB5A6"))
			t_vb.add_child(t_sub)

			var step_btn_h: float = _bh(34.0)
			var btn_minus: Button = Button.new()
			btn_minus.text = "−"
			btn_minus.custom_minimum_size = Vector2(40.0 if _is_touch_mode else 34.0, step_btn_h)
			btn_minus.disabled = (draft_l <= 0)
			_apply_button_theme(btn_minus, "#3D2724", "#553631", "#2B1B19", "#C46E5F", Color.WHITE, false, step_btn_h, _fs(15.0), 8.0, true)
			var minus_tid: int = tid
			btn_minus.pressed.connect(func() -> void: _step_cart_tile_level(minus_tid, -1))
			row_hb.add_child(btn_minus)

			var lvl_badge: Label = Label.new()
			lvl_badge.custom_minimum_size = Vector2(56.0, 0.0)
			lvl_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lvl_badge.text = "HOTEL" if draft_l >= 5 else "%d C" % draft_l
			if _bold_font != null:
				lvl_badge.add_theme_font_override("font", _bold_font)
			lvl_badge.add_theme_font_size_override("font_size", _fs(13.0))
			lvl_badge.add_theme_color_override("font_color", Color("#FFE28A") if draft_l >= 5 else Color("#E8FFF2"))
			row_hb.add_child(lvl_badge)

			var btn_plus: Button = Button.new()
			btn_plus.text = "+"
			btn_plus.custom_minimum_size = Vector2(40.0 if _is_touch_mode else 34.0, step_btn_h)
			btn_plus.disabled = any_mort or (draft_l >= 5)
			_apply_button_theme(btn_plus, "#1D4A38", "#27644C", "#143528", "#52B788", Color.WHITE, false, step_btn_h, _fs(15.0), 8.0, true)
			var plus_tid: int = tid
			btn_plus.pressed.connect(func() -> void: _step_cart_tile_level(plus_tid, 1))
			row_hb.add_child(btn_plus)

	if changed_count == 0:
		_cart_summary_label.text = "Nenhuma alteração pendente. Ajuste + ou − nos terrenos."
		_cart_summary_label.add_theme_color_override("font_color", Color("#BDD3C6"))
		_cart_confirm_btn.text = "Confirmar Obras"
		_cart_confirm_btn.disabled = true
	elif not is_valid:
		_cart_summary_label.text = reason
		_cart_summary_label.add_theme_color_override("font_color", Color("#FF8FA3"))
		_cart_confirm_btn.text = "Ajustar Carrinho"
		_cart_confirm_btn.disabled = true
	else:
		var cost_txt: String = ("Custo líquido: %s" % _format_brl(net_cost)) if net_cost > 0 else (("Reembolso líquido: +%s" % _format_brl(absi(net_cost))) if net_cost < 0 else "Troca neutra (P$ 0)")
		_cart_summary_label.text = "%s • Saldo projetado: %s" % [cost_txt, _format_brl(proj_money)]
		_cart_summary_label.add_theme_color_override("font_color", Color("#A8FF78"))
		_cart_confirm_btn.text = "Confirmar (%d lote%s)" % [changed_count, "" if changed_count == 1 else "s"]
		_cart_confirm_btn.disabled = false

func hide_all_modals() -> void:
	hide_chance_card_modal(true)
	hide_player_portfolio_modal()
	hide_construction_cart_modal()
	hide_settings_modal()
	hide_deed_modal()
	hide_trade_modal()
	hide_trade_confirm_modal()
	hide_auction_modal()
	hide_pause_modal()
	hide_help_modal()
	hide_trophies_modal()
	hide_victory_modal()
	hide_event_toast()

func reset_hud_state() -> void:
	hide_all_modals()
	clear_log()
	_cached_players.clear()
	_cached_current_idx = 0
	_cached_active_pid = -1
	_cached_player_colors.clear()
	_cached_owned_options.clear()
	_cached_selected_tile = -1
	_cached_owners_map.clear()
	_cached_buildings_map.clear()
	_cached_mortgaged_map.clear()
	_cached_tradable_map.clear()
	_cart_draft_levels.clear()
	_cart_focus_group = ""
	_deed_open_tile_idx = -1
	_portfolio_open_pid = -1
	_portfolio_filter = "all"
	_portfolio_last_info.clear()
	_cached_houses_left = 32
	_cached_hotels_left = 12
	_cached_is_bot_turn = false
	_switch_tab(TAB_PLAYERS)

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

func set_round_info(round_num: int, is_market_cycle: bool, season_info: Dictionary = {}) -> void:
	if _round_label == null or _round_badge_style == null:
		return
	var safe_round: int = maxi(1, round_num)
	var season_short: String = str(season_info.get("short_label", "")).strip_edges()
	var season_label: String = str(season_info.get("label", "")).strip_edges()
	var season_effect: String = str(season_info.get("effect_desc", "")).strip_edges()
	var season_col: String = str(season_info.get("color_hex", "#3B5949"))
	var suffix: String = " • %s" % season_short if season_short != "" else ""
	if is_market_cycle:
		_round_label.text = "ROD. %d%s ★" % [safe_round, suffix]
		_round_badge_style.bg_color = Color("#342A12")
		_round_badge_style.border_color = Color("#F5CA5C")
		_round_label.add_theme_color_override("font_color", Color("#FFF3C4"))
		if _round_badge != null:
			var s_tip: String = "\nEstação (%s): %s" % [season_label, season_effect] if season_label != "" else ""
			_round_badge.tooltip_text = ("Rodada %d • Feira de Negócios: maior estímulo a trocas e obras." % safe_round) + s_tip
	else:
		_round_label.text = "ROD. %d%s" % [safe_round, suffix]
		_round_badge_style.bg_color = Color("#182820")
		_round_badge_style.border_color = Color(season_col if season_col != "" else "#3B5949")
		_round_label.add_theme_color_override("font_color", Color("#D8ECE0"))
		if _round_badge != null:
			var s_tip2: String = "\nEstação (%s): %s" % [season_label, season_effect] if season_label != "" else ""
			_round_badge.tooltip_text = ("Rodada %d (avança quando todos os jogadores ativos completam sua vez)" % safe_round) + s_tip2

func set_secret_mission(mission: Dictionary) -> void:
	if _mission_bar == null or _mission_label == null:
		return
	if mission.is_empty():
		_mission_bar.visible = false
		return
	var title: String = str(mission.get("title", "Missão"))
	var desc: String = str(mission.get("desc", ""))
	var reward: int = int(mission.get("reward", 600))
	var completed: bool = bool(mission.get("completed", false))
	_mission_bar.visible = true
	if completed:
		_mission_label.text = "★ Missão Cumprida (%s): +P$ %d creditados!" % [title, reward]
		_mission_bar_style.bg_color = Color("#163826")
		_mission_bar_style.border_color = Color("#52B788")
		_mission_label.add_theme_color_override("font_color", Color("#B7FFD6"))
	else:
		_mission_label.text = "Missão Secreta (%s): %s (+P$ %d)" % [title, desc, reward]
		_mission_bar_style.bg_color = Color("#182112")
		_mission_bar_style.border_color = Color("#D4AF37")
		_mission_label.add_theme_color_override("font_color", Color("#F6DF8F"))

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

func _refresh_sound_button() -> void:
	if _btn_sound == null:
		return
	var qb_h: float = _bh(34.0)
	var qb_fs: int = _fs(12.0)
	var audio_on: bool = bool(_prefs_cache.get("audio_enabled", true))
	if audio_on:
		_btn_sound.text = "Som: ON"
		_apply_button_theme(_btn_sound, "#1B362E", "#264C40", "#132620", "#52B788", Color("#D8FFE8"), false, qb_h, qb_fs, 10.0, true)
	else:
		_btn_sound.text = "Mudo"
		_apply_button_theme(_btn_sound, "#2B1E1E", "#3B2828", "#1E1414", "#A44A4A", Color("#F5C2C2"), false, qb_h, qb_fs, 10.0, true)

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
	_cached_houses_left = houses_left
	_cached_hotels_left = hotels_left
	_cached_is_bot_turn = is_bot_turn

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
	_cached_active_pid = active_pid
	if has_active:
		var active_p: Dictionary = players[current_idx]
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
		var active_team_name: String = str(active_p.get("team_name", ""))
		var team_prefix: String = ("[%s] " % active_team_name.to_upper()) if active_team_name != "" else ""
		_hero_pawn_name_label.text = "%s%s%s" % [team_prefix, active_pawn_name, pawn_status_suffix]
		_hero_pawn_name_label.add_theme_color_override("font_color", Color("#F8D568") if active_in_jail else Color("#BDD3C6"))
	else:
		_hero_name_label.text = "-"
		_hero_money_label.text = "P$ 0"
		_hero_phase_label.text = state_name.to_upper()
		_hero_pawn_name_label.text = ""

	_refresh_net_identity_banner(players, active_pid)

	_bank_label.text = "%dC • %dH" % [houses_left, hotels_left]
	_tile_info_label.text = tile_info

	# Atualizar badges das abas (Estanceiros | Diário)
	if _tab_buttons.size() >= 2:
		_tab_buttons[TAB_PLAYERS].text = "Estanceiros (%d)" % players.size()
		_tab_buttons[TAB_LOG].text = "Diário"

	_rebuild_players_list(players, current_idx, player_colors, is_bot_turn)

	var lock_controls: bool = is_bot_turn
	if lock_controls:
		hide_construction_cart_modal()

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
		_btn_end_turn.text = "Declarar Falência" if can_end else "Liquide seus bens"
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
		_btn_deeds_jump.text = "Minhas Escrituras (%d)" % owned_options.size()
		_apply_button_theme(_btn_deeds_jump, "#1B2E25", "#254033", "#13211A", "#52B788", Color("#E9F5EE"), false, _bh(38.0), _fs(13.0), 10.0, true)
	_btn_deeds_jump.disabled = not has_active

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

func _get_player_monopoly_groups(player: Dictionary, tiles: Array[Dictionary], all_players: Array[Dictionary] = []) -> Array[String]:
	var result: Array[String] = []
	var owned_props: Array = []
	var team_id: int = int(player.get("team_id", -1))
	if team_id >= 0 and not all_players.is_empty():
		for other: Dictionary in all_players:
			if int(other.get("team_id", -1)) == team_id:
				for p_idx: Variant in other.get("properties", []):
					owned_props.append(p_idx)
	else:
		owned_props = player.get("properties", [])
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
		var mono_groups: Array[String] = _get_player_monopoly_groups(p, _cached_tiles, players)

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
		var p_team_name: String = str(p.get("team_name", ""))
		if p_team_name != "":
			tags.append(p_team_name.to_upper())
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
