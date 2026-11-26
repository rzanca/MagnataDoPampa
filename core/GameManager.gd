extends Node

enum TurnState { WAITING_ROLL, MOVING, EVALUATING, MANAGEMENT, GAME_OVER }

signal turn_state_changed(state: int, player_id: int, round_number: int)
signal hud_state_synced(snapshot: Dictionary)
signal property_purchased(player_id: int, tile_index: int, price: int)
signal match_event_logged(message: String)
signal match_finished(victory_info: Dictionary)

const Board3DClass = preload("res://entities/Board3D.gd")
const GameHUDClass = preload("res://ui/GameHUD.gd")
const SetupScreenClass = preload("res://ui/SetupScreen.gd")
const DesktopGameHUDClass = preload("res://ui/desktop/DesktopGameHUD.gd")
const AndroidGameHUDClass = preload("res://ui/android/AndroidGameHUD.gd")
const DesktopSetupScreenClass = preload("res://ui/desktop/DesktopSetupScreen.gd")
const AndroidSetupScreenClass = preload("res://ui/android/AndroidSetupScreen.gd")
const BotAIClass = preload("res://core/BotAI.gd")
const NetworkManagerClass = preload("res://core/NetworkManager.gd")
const SoundManagerClass = preload("res://core/SoundManager.gd")

const BOT_ACTION_DELAY: float = 0.45
const BOT_MAX_ACTIONS_PER_TURN: int = 32
const TRADE_CYCLE_INTERVAL: int = 3
const SEASON_CYCLE_ROUNDS: int = 3
const DYNAMIC_ROUND_LIMIT: int = 30
const DYNAMIC_NET_WORTH_GOAL: int = 12000
const DYNAMIC_MONOPOLY_GOAL: int = 3
const SEASON_ORDER: Array[String] = ["PRIMAVERA", "VERAO", "OUTONO", "INVERNO"]
const PREFS_FILE_PATH: String = "user://preferences.cfg"
const CHANCE_AUTO_DURATIONS: Dictionary[String, float] = {
	"short": 2.5,
	"default": 4.5,
	"long": 7.0
}
const CHANCE_BOT_DURATIONS: Dictionary[String, float] = {
	"short": 1.6,
	"default": 2.6,
	"long": 3.8
}
const BOT_SPEED_DELAYS: Dictionary[String, float] = {
	"calm": 0.80,
	"normal": 0.45,
	"fast": 0.22
}

var board_config: Dictionary = {}
var tiles: Array[Dictionary] = []
var _all_chance_cards: Array[Dictionary] = []
var chance_cards: Array[Dictionary] = []
var _held_jail_cards: Array[Dictionary] = []
var players: Array[Dictionary] = []

var property_owners: Dictionary[int, int] = {}    # tile_index -> player_id
var property_buildings: Dictionary[int, int] = {} # tile_index -> level (0..4 casas, 5 hotel)
var mortgaged_tiles: Dictionary[int, bool] = {}   # tile_index -> is_mortgaged

var bank_houses_left: int = 32
var bank_hotels_left: int = 12

var current_player_index: int = 0
var current_state: TurnState = TurnState.WAITING_ROLL
var doubles_count: int = 0
var current_round: int = 1
var _acted_in_current_round: Dictionary[int, bool] = {}
var _bot_traded_this_turn: bool = false
var _game_rules_mode: String = "classic"
var _seasons_enabled: bool = false
var _current_season_index: int = 0
var _round_limit: int = 0
var _net_worth_goal: int = 0
var _team_mode: String = "ffa" # "ffa" | "2v2" | "3v3"
var _team_wallets: Dictionary[int, int] = {}

var board_view: Board3DClass = null
var hud: GameHUDClass = null
var setup_screen: SetupScreenClass = null
var bot_ai: BotAIClass = BotAIClass.new()
var network: NetworkManagerClass = null
var sound_manager: SoundManagerClass = null

var _active_net_session_id: int = 0
var _applying_remote_state: bool = false
var _last_victory_info: Dictionary = {}
const DEFAULT_RENT_WAIVER_ROUNDS: int = 3

var _pending_trade_offer: Dictionary = {}
var _next_trade_offer_id: int = 1
var _rent_waiver_pacts: Array[Dictionary] = []
var _auction_state: Dictionary = {}
var _pending_periodic_auction: bool = false
var _auction_bot_token: int = 0
var _player_auctioned_this_turn: bool = false

var _last_tile_summary: String = "Configure a partida para começar"
var _selected_property_tile: int = -1
var _has_extra_roll: bool = false
var _last_dice_sum: int = 0
var _last_creditor_id: int = -1 # player_id do último credor de aluguel, ou -1 para banco/imposto/carta
var _bot_turn_token: int = 0
var _match_session_token: int = 0
var _is_bot_thinking: bool = false
var _is_animating: bool = false
var _match_active: bool = false
var _last_player_configs: Array[Dictionary] = []
var _preferences: Dictionary = {
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

func _ready() -> void:
	_load_preferences()
	load_board_data()
	load_chance_cards()
	_setup_visuals()
	open_setup_screen()

func _unhandled_input(event: InputEvent) -> void:
	if not _match_active:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return

	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var focus_owner: Control = vp.gui_get_focus_owner()
	if focus_owner != null and focus_owner.is_visible_in_tree() and (focus_owner is LineEdit or focus_owner is TextEdit):
		return
	if hud != null and hud.has_blocking_modal_open():
		return

	if key_event.keycode == KEY_TAB:
		toggle_camera_view()
		vp.set_input_as_handled()
		return

	if _is_human_input_blocked() or current_state == TurnState.GAME_OVER:
		return

	match key_event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if _can_roll_dice():
				_on_human_roll_pressed()
				vp.set_input_as_handled()
			elif current_state == TurnState.MANAGEMENT and _can_end_turn() and _get_current_player_money() >= 0:
				_on_human_end_turn_pressed()
				vp.set_input_as_handled()
		KEY_C:
			if _can_buy_current_tile():
				_on_human_buy_pressed()
				vp.set_input_as_handled()
		KEY_R:
			if current_state == TurnState.EVALUATING:
				_on_human_decline_pressed()
				vp.set_input_as_handled()
		KEY_E:
			if _can_end_turn():
				_on_human_end_turn_pressed()
				vp.set_input_as_handled()
		KEY_F:
			if _can_pay_bail():
				_on_human_bail_pressed()
				vp.set_input_as_handled()
		KEY_L:
			if _can_use_jail_free_card():
				_on_human_use_jail_card_pressed()
				vp.set_input_as_handled()
		KEY_N:
			if _can_open_trade() and hud != null:
				hud.show_trade_modal()
				vp.set_input_as_handled()

func load_board_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/board_data.json", FileAccess.READ)
	if file == null:
		push_error("Erro ao abrir res://data/board_data.json")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("JSON inválido em res://data/board_data.json")
		return

	var parsed_dict: Dictionary = parsed
	if not parsed_dict.has("config") or not parsed_dict.has("tiles"):
		push_error("JSON incompleto em res://data/board_data.json")
		return

	var raw_config: Variant = parsed_dict["config"]
	var raw_tiles: Variant = parsed_dict["tiles"]
	if not (raw_config is Dictionary) or not (raw_tiles is Array):
		push_error("Estrutura de config/tiles inválida em res://data/board_data.json")
		return

	board_config = raw_config
	tiles.clear()
	for entry: Variant in raw_tiles:
		if entry is Dictionary:
			tiles.append(entry)

	bank_houses_left = int(board_config.get("max_houses_bank", 32))
	bank_hotels_left = int(board_config.get("max_hotels_bank", 12))
	print("Tabuleiro carregado com %d casas." % tiles.size())

func load_chance_cards() -> void:
	var file: FileAccess = FileAccess.open("res://data/chance_cards.json", FileAccess.READ)
	if file == null:
		push_error("Erro ao abrir res://data/chance_cards.json")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("JSON inválido em res://data/chance_cards.json")
		return

	var parsed_dict: Dictionary = parsed
	if not parsed_dict.has("cards") or not (parsed_dict["cards"] is Array):
		push_error("Lista de cartas ausente em res://data/chance_cards.json")
		return

	var raw_cards: Array = parsed_dict["cards"]
	_all_chance_cards.clear()
	for entry: Variant in raw_cards:
		if entry is Dictionary:
			_all_chance_cards.append(entry)

	_reset_chance_deck()
	print("Baralho 'Sorte ou Azar, Tchê!' carregado (%d cartas)." % chance_cards.size())

func _reset_chance_deck() -> void:
	chance_cards.clear()
	_held_jail_cards.clear()
	for card: Dictionary in _all_chance_cards:
		chance_cards.append(card.duplicate(true))
	chance_cards.shuffle()

func _is_mobile_platform_active() -> bool:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		var platform_cfg: Node = tree.root.get_node_or_null("PlatformConfig")
		if platform_cfg != null and platform_cfg.has_method("is_mobile_ui_active"):
			return bool(platform_cfg.call("is_mobile_ui_active"))
	return OS.get_name() == "Android"

func _setup_visuals() -> void:
	board_view = Board3DClass.new()
	board_view.name = "Board3D"
	add_child(board_view)
	board_view.build_board(tiles)
	board_view.tile_clicked.connect(_on_tile_inspected)
	board_view.dice_clicked.connect(_on_human_roll_pressed)
	board_view.hop_step_played.connect(_on_board_hop_step_played)

	sound_manager = SoundManagerClass.new()
	sound_manager.name = "SoundManager"
	add_child(sound_manager)
	sound_manager.apply_preferences(_preferences)

	var use_mobile_ui: bool = _is_mobile_platform_active()
	if use_mobile_ui:
		hud = AndroidGameHUDClass.new()
		hud.name = "AndroidGameHUD"
	else:
		hud = DesktopGameHUDClass.new()
		hud.name = "DesktopGameHUD"
	add_child(hud)
	hud.bind_core_signals(self)
	hud.set_camera_mode_label(board_view.is_2d_camera_active())
	hud.roll_pressed.connect(_on_human_roll_pressed)
	hud.buy_pressed.connect(_on_human_buy_pressed)
	hud.decline_buy_pressed.connect(_on_human_decline_pressed)
	hud.bail_pressed.connect(_on_human_bail_pressed)
	hud.use_jail_card_pressed.connect(_on_human_use_jail_card_pressed)
	hud.property_selected.connect(_on_human_property_selected)
	hud.build_pressed.connect(_on_human_build_pressed)
	hud.sell_building_pressed.connect(_on_human_sell_building_pressed)
	hud.build_cart_applied.connect(_on_human_build_cart_applied)
	hud.mortgage_pressed.connect(_on_human_mortgage_pressed)
	hud.end_turn_pressed.connect(_on_human_end_turn_pressed)
	hud.trade_executed.connect(_on_human_trade_executed)
	hud.trade_offer_responded.connect(_on_human_trade_offer_responded)
	hud.auction_bid_submitted.connect(_on_human_auction_bid_submitted)
	hud.auction_pass_submitted.connect(_on_human_auction_pass_submitted)
	hud.auction_owned_requested.connect(_on_human_auction_owned_requested)
	hud.leave_to_bot_requested.connect(_on_human_leave_to_bot_requested)
	hud.forfeit_match_requested.connect(_on_human_forfeit_requested)
	hud.menu_requested.connect(open_setup_screen)
	hud.restart_match_requested.connect(_on_restart_match_requested)
	hud.quit_game_requested.connect(_on_quit_game_requested)
	hud.camera_toggle_requested.connect(toggle_camera_view)
	hud.camera_follow_toggle_requested.connect(_on_camera_follow_toggled)
	hud.camera_reset_requested.connect(_on_camera_reset_requested)
	hud.camera_zoom_in_requested.connect(_on_camera_zoom_in_requested)
	hud.camera_zoom_out_requested.connect(_on_camera_zoom_out_requested)
	hud.inspect_tile_requested.connect(_on_tile_inspected)
	hud.player_inspected.connect(_on_player_inspected)
	hud.board_layout_updated.connect(_on_board_layout_updated)
	hud.settings_updated.connect(_on_settings_updated)

	var cam_follow_pref: bool = bool(_preferences.get("camera_follow", true))
	board_view.set_camera_follow_enabled(cam_follow_pref)
	hud.set_camera_follow_label(board_view.is_camera_follow_enabled())
	hud.apply_preferences(_preferences)

	network = NetworkManagerClass.new()
	network.name = "NetworkManager"
	add_child(network)
	network.network_status_changed.connect(_on_network_status_changed)
	network.web_room_code_changed.connect(_on_network_web_room_code_changed)
	network.lobby_synced.connect(_on_network_lobby_synced)
	network.peer_joined_room.connect(_on_network_peer_joined)
	network.peer_left_room.connect(_on_network_peer_left)
	network.connection_failed_error.connect(_on_network_error)
	network.host_disconnected.connect(_on_network_host_disconnected)
	network.client_action_received.connect(_on_network_client_action)
	network.client_lobby_pref_received.connect(_on_network_client_lobby_pref)
	network.remote_match_started.connect(_on_network_remote_match_started)
	network.remote_state_received.connect(_on_network_remote_state_received)
	network.remote_event_received.connect(_on_network_remote_event_received)

	if use_mobile_ui:
		setup_screen = AndroidSetupScreenClass.new()
		setup_screen.name = "AndroidSetupScreen"
	else:
		setup_screen = DesktopSetupScreenClass.new()
		setup_screen.name = "DesktopSetupScreen"
	add_child(setup_screen)
	setup_screen.start_match_requested.connect(start_match_from_setup)
	setup_screen.help_requested.connect(_on_help_requested)
	setup_screen.settings_requested.connect(_on_settings_requested)
	setup_screen.quit_game_requested.connect(_on_quit_game_requested)
	setup_screen.host_room_requested.connect(_on_host_room_requested)
	setup_screen.join_room_requested.connect(_on_join_room_requested)
	setup_screen.host_web_room_requested.connect(_on_host_web_room_requested)
	setup_screen.join_web_room_requested.connect(_on_join_web_room_requested)
	setup_screen.disconnect_network_requested.connect(_on_disconnect_network_requested)
	setup_screen.lobby_config_changed.connect(_on_lobby_config_changed)
	setup_screen.lobby_slot_pref_requested.connect(_on_setup_lobby_pref_requested)
	setup_screen.rules_mode_changed.connect(set_rules_mode)
	set_rules_mode(setup_screen.get_rules_mode())

func _on_board_layout_updated(board_rect: Rect2) -> void:
	if board_view != null:
		board_view.set_viewport_rect(board_rect)

func _on_help_requested() -> void:
	if hud != null:
		hud.show_help_modal()

func _on_settings_requested() -> void:
	if hud != null:
		hud.apply_preferences(_preferences)
		hud.show_settings_modal()

func _on_quit_game_requested() -> void:
	_match_active = false
	_match_session_token += 1
	_bot_turn_token += 1
	_save_preferences()
	if network != null:
		network.disconnect_all()
	var tree: SceneTree = get_tree()
	if tree != null and not OS.has_feature("web"):
		tree.quit()

func _load_preferences() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(PREFS_FILE_PATH)
	if err != OK:
		return
	_preferences["chance_close_mode"] = str(cfg.get_value("gameplay", "chance_close_mode", "auto"))
	_preferences["chance_auto_duration"] = str(cfg.get_value("gameplay", "chance_auto_duration", "default"))
	_preferences["bot_speed"] = str(cfg.get_value("gameplay", "bot_speed", "normal"))
	_preferences["camera_follow"] = bool(cfg.get_value("visual", "camera_follow", true))
	_preferences["ui_comfort_scale"] = str(cfg.get_value("visual", "ui_comfort_scale", "normal"))
	_preferences["show_event_toasts"] = bool(cfg.get_value("visual", "show_event_toasts", true))
	_preferences["auction_interval_rounds"] = int(cfg.get_value("gameplay", "auction_interval_rounds", 3))
	_preferences["audio_enabled"] = bool(cfg.get_value("audio", "audio_enabled", true))
	_preferences["audio_volume"] = clampf(float(cfg.get_value("audio", "audio_volume", 0.75)), 0.0, 1.0)
	_preferences["audio_step_sfx"] = bool(cfg.get_value("audio", "audio_step_sfx", true))

func _save_preferences() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("gameplay", "chance_close_mode", str(_preferences.get("chance_close_mode", "auto")))
	cfg.set_value("gameplay", "chance_auto_duration", str(_preferences.get("chance_auto_duration", "default")))
	cfg.set_value("gameplay", "bot_speed", str(_preferences.get("bot_speed", "normal")))
	cfg.set_value("gameplay", "auction_interval_rounds", int(_preferences.get("auction_interval_rounds", 3)))
	cfg.set_value("visual", "camera_follow", bool(_preferences.get("camera_follow", true)))
	cfg.set_value("visual", "ui_comfort_scale", str(_preferences.get("ui_comfort_scale", "normal")))
	cfg.set_value("visual", "show_event_toasts", bool(_preferences.get("show_event_toasts", true)))
	cfg.set_value("audio", "audio_enabled", bool(_preferences.get("audio_enabled", true)))
	cfg.set_value("audio", "audio_volume", clampf(float(_preferences.get("audio_volume", 0.75)), 0.0, 1.0))
	cfg.set_value("audio", "audio_step_sfx", bool(_preferences.get("audio_step_sfx", true)))
	var _save_err: Error = cfg.save(PREFS_FILE_PATH)

func _on_settings_updated(new_prefs: Dictionary) -> void:
	_preferences = new_prefs.duplicate(true)
	if not _preferences.has("player_chance_overrides") or not (_preferences["player_chance_overrides"] is Dictionary):
		_preferences["player_chance_overrides"] = {}
	var cam_follow: bool = bool(_preferences.get("camera_follow", true))
	if board_view != null:
		board_view.set_camera_follow_enabled(cam_follow)
	if sound_manager != null:
		sound_manager.apply_preferences(_preferences)
	if hud != null:
		hud.set_camera_follow_label(cam_follow)
		hud.apply_preferences(_preferences)
	_save_preferences()

func _play_sfx(event_name: String) -> void:
	if sound_manager != null:
		sound_manager.play_sfx(event_name)

func _on_board_hop_step_played() -> void:
	_play_sfx("hop")

func _get_bot_action_delay() -> float:
	var speed_key: String = str(_preferences.get("bot_speed", "normal"))
	return float(BOT_SPEED_DELAYS.get(speed_key, BOT_ACTION_DELAY))

func _resolve_chance_card_prefs(player: Dictionary) -> Dictionary:
	var global_mode: String = str(_preferences.get("chance_close_mode", "auto"))
	var global_dur_key: String = str(_preferences.get("chance_auto_duration", "default"))
	var is_bot: bool = bool(player.get("is_bot", false))

	# Bots nunca aguardam ação manual para não travar a partida
	if is_bot:
		var bot_sec: float = float(CHANCE_BOT_DURATIONS.get(global_dur_key, 2.6))
		return {
			"manual_close": false,
			"duration_sec": bot_sec
		}

	var eff_mode: String = global_mode
	var eff_dur_key: String = global_dur_key
	var overrides_var: Variant = _preferences.get("player_chance_overrides", {})
	if overrides_var is Dictionary:
		var overrides: Dictionary = overrides_var
		var pid_key: String = str(int(player.get("id", 0)))
		if overrides.has(pid_key) and overrides[pid_key] is Dictionary:
			var ov: Dictionary = overrides[pid_key]
			var ov_mode: String = str(ov.get("mode", "inherit"))
			if ov_mode == "auto" or ov_mode == "manual":
				eff_mode = ov_mode
			var ov_dur: String = str(ov.get("duration", ""))
			if CHANCE_AUTO_DURATIONS.has(ov_dur):
				eff_dur_key = ov_dur

	var human_sec: float = float(CHANCE_AUTO_DURATIONS.get(eff_dur_key, 4.5))
	return {
		"manual_close": (eff_mode == "manual"),
		"duration_sec": human_sec
	}

func _on_camera_follow_toggled() -> void:
	if board_view == null:
		return
	var enabled: bool = board_view.toggle_camera_follow()
	_preferences["camera_follow"] = enabled
	_save_preferences()
	if hud != null:
		hud.set_camera_follow_label(enabled)
		hud.apply_preferences(_preferences)

func _on_camera_reset_requested() -> void:
	if board_view != null:
		board_view.reset_camera_framing(true)

func _on_camera_zoom_in_requested() -> void:
	if board_view != null:
		board_view.zoom_in()

func _on_camera_zoom_out_requested() -> void:
	if board_view != null:
		board_view.zoom_out()

func toggle_camera_view() -> void:
	if board_view == null:
		return
	var is_2d: bool = board_view.toggle_camera_view()
	if hud != null:
		hud.set_camera_mode_label(is_2d)

func _reset_match_state() -> void:
	_match_session_token += 1
	_bot_turn_token += 1
	_auction_bot_token += 1
	_is_bot_thinking = false
	_is_animating = false
	_match_active = false
	players.clear()
	property_owners.clear()
	property_buildings.clear()
	mortgaged_tiles.clear()
	bank_houses_left = int(board_config.get("max_houses_bank", 32))
	bank_hotels_left = int(board_config.get("max_hotels_bank", 12))
	current_player_index = 0
	current_state = TurnState.WAITING_ROLL
	doubles_count = 0
	current_round = 1
	_acted_in_current_round.clear()
	_team_mode = "ffa"
	_team_wallets.clear()
	_bot_traded_this_turn = false
	_selected_property_tile = -1
	_has_extra_roll = false
	_last_dice_sum = 0
	_last_creditor_id = -1
	_pending_trade_offer.clear()
	_rent_waiver_pacts.clear()
	_auction_state.clear()
	_pending_periodic_auction = false
	_player_auctioned_this_turn = false
	_last_victory_info.clear()
	_last_tile_summary = "Configure a partida para começar"
	_reset_chance_deck()
	if board_view != null:
		board_view.reset_board_state()
	if hud != null:
		hud.reset_hud_state()
		hud.set_match_ui_visible(false)

func open_setup_screen() -> void:
	var was_match_active: bool = _match_active
	if network != null:
		if network.is_host() and was_match_active:
			network.broadcast_match_event(_active_net_session_id, "RETURN_TO_LOBBY", {
				"reason": "O Host encerrou a partida e voltou à sala."
			})
		elif network.is_client() and was_match_active:
			network.disconnect_network("Você saiu da sala online.")

	_reset_match_state()
	if setup_screen != null:
		setup_screen.open_screen()
		if network != null and network.is_host():
			_broadcast_current_lobby()
	_sync_hud()

func _on_restart_match_requested() -> void:
	if network != null and network.is_client():
		return
	if _last_player_configs.is_empty():
		open_setup_screen()
		return
	start_match_from_setup(_last_player_configs)

func set_rules_mode(mode_id: String) -> void:
	_game_rules_mode = "dynamic" if mode_id == "dynamic" else "classic"
	if _game_rules_mode == "dynamic":
		_seasons_enabled = true
		_round_limit = DYNAMIC_ROUND_LIMIT
		_net_worth_goal = DYNAMIC_NET_WORTH_GOAL
	else:
		_seasons_enabled = false
		_round_limit = 0
		_net_worth_goal = 0
	if setup_screen != null and setup_screen.get_rules_mode() != _game_rules_mode:
		setup_screen.set_rules_mode(_game_rules_mode, false)

func get_current_season_id() -> String:
	if not _seasons_enabled:
		return ""
	return SEASON_ORDER[clampi(_current_season_index, 0, SEASON_ORDER.size() - 1)]

func is_team_mode() -> bool:
	return _team_mode == "2v2" or _team_mode == "3v3"

func get_team_mode() -> String:
	return _team_mode

func get_player_team_id(player_id: int) -> int:
	if not is_team_mode() or player_id < 0:
		return -1
	var p: Dictionary = _get_player_by_id(player_id)
	if p.is_empty():
		return -1
	return int(p.get("team_id", -1))

func are_allied_players(pid_a: int, pid_b: int) -> bool:
	if pid_a < 0 or pid_b < 0:
		return false
	if pid_a == pid_b:
		return true
	if not is_team_mode():
		return false
	var ta: int = get_player_team_id(pid_a)
	var tb: int = get_player_team_id(pid_b)
	return ta >= 0 and ta == tb

func has_rent_waiver_pact(pid_a: int, pid_b: int) -> Dictionary:
	if pid_a < 0 or pid_b < 0 or pid_a == pid_b or _rent_waiver_pacts.is_empty():
		return {}
	for pact: Dictionary in _rent_waiver_pacts:
		var rounds_left: int = int(pact.get("rounds_left", 0))
		if rounds_left <= 0:
			continue
		var pa: int = int(pact.get("a", -1))
		var pb: int = int(pact.get("b", -1))
		var direct_match: bool = (pa == pid_a and pb == pid_b) or (pa == pid_b and pb == pid_a)
		var team_match: bool = is_team_mode() and ((are_allied_players(pa, pid_a) and are_allied_players(pb, pid_b)) or (are_allied_players(pa, pid_b) and are_allied_players(pb, pid_a)))
		if direct_match or team_match:
			return pact
	return {}

func _register_rent_waiver_pact(pid_a: int, pid_b: int, duration_rounds: int) -> void:
	var safe_rounds: int = clampi(duration_rounds, 0, 5)
	if safe_rounds <= 0 or pid_a < 0 or pid_b < 0 or pid_a == pid_b:
		return
	var lo: int = mini(pid_a, pid_b)
	var hi: int = maxi(pid_a, pid_b)
	for pact: Dictionary in _rent_waiver_pacts:
		if int(pact.get("a", -1)) == lo and int(pact.get("b", -1)) == hi:
			pact["rounds_left"] = maxi(int(pact.get("rounds_left", 0)), safe_rounds)
			return
	_rent_waiver_pacts.append({
		"a": lo,
		"b": hi,
		"rounds_left": safe_rounds
	})

func _is_owned_by_player_or_team(tile_idx: int, player_id: int) -> bool:
	var owner_id: int = property_owners.get(tile_idx, -1)
	if owner_id < 0 or player_id < 0:
		return false
	return are_allied_players(owner_id, player_id)

func _get_actor_or_team_properties(player_id: int) -> Array[int]:
	var result: Array[int] = []
	if not is_team_mode():
		var p: Dictionary = _get_player_by_id(player_id)
		for tid_var: Variant in p.get("properties", []):
			result.append(int(tid_var))
		result.sort()
		return result
	for p: Dictionary in players:
		if are_allied_players(int(p.get("id", -1)), player_id):
			for tid_var: Variant in p.get("properties", []):
				var tid: int = int(tid_var)
				if not (tid in result):
					result.append(tid)
	result.sort()
	return result

func _adjust_player_money(player: Dictionary, delta: int) -> void:
	if player.is_empty():
		return
	var pid: int = int(player.get("id", -1))
	var tid: int = get_player_team_id(pid)
	if is_team_mode() and tid >= 0:
		var updated: int = int(_team_wallets.get(tid, int(player.get("money", 0)))) + delta
		_team_wallets[tid] = updated
		for member: Dictionary in players:
			if int(member.get("team_id", -1)) == tid:
				member["money"] = updated
	else:
		player["money"] = int(player.get("money", 0)) + delta

func _build_player_teams_map() -> Dictionary[int, int]:
	var out: Dictionary[int, int] = {}
	if not is_team_mode():
		return out
	for p: Dictionary in players:
		out[int(p.get("id", -1))] = int(p.get("team_id", -1))
	return out

func _count_active_teams() -> int:
	if not is_team_mode():
		return _count_active_players()
	var seen: Dictionary[int, bool] = {}
	for p: Dictionary in players:
		if not bool(p.get("bankrupt", false)):
			seen[int(p.get("team_id", -1))] = true
	return seen.size()

func get_current_season_info() -> Dictionary:
	if not _seasons_enabled:
		return {}
	match get_current_season_id():
		"PRIMAVERA":
			return {
				"id": "PRIMAVERA",
				"label": "Primavera",
				"short_label": "PRIM.",
				"effect_desc": "Brote no Pampa: +25% no Galpão Central e +20% em Companhias/lotes iniciais.",
				"color_hex": "#52B788"
			}
		"VERAO":
			return {
				"id": "VERAO",
				"label": "Verão",
				"short_label": "VERÃO",
				"effect_desc": "Safra & Fandango: +25% em aluguéis dos grupos Laranja, Vermelho e Amarelo.",
				"color_hex": "#F5CA5C"
			}
		"OUTONO":
			return {
				"id": "OUTONO",
				"label": "Outono",
				"short_label": "OUTON.",
				"effect_desc": "Vindima & Obras: -20% no custo para construir casas e estâncias.",
				"color_hex": "#F3722C"
			}
		_:
			return {
				"id": "INVERNO",
				"label": "Inverno",
				"short_label": "INVER.",
				"effect_desc": "Geada & Minuano: Impostos +25%; lotes sem obra rendem -10%.",
				"color_hex": "#4EA8DE"
			}

func start_match_from_setup(player_configs: Array[Dictionary]) -> void:
	if network != null and network.is_client():
		return
	if setup_screen != null and setup_screen.visible:
		set_rules_mode(setup_screen.get_rules_mode())
	var saved_configs: Array[Dictionary] = []
	for cfg: Dictionary in player_configs:
		saved_configs.append(cfg.duplicate(true))
	_last_player_configs = saved_configs

	if board_view != null:
		board_view.cancel_animations()
	var vp: Viewport = get_viewport()
	if vp != null:
		var stale_focus: Control = vp.gui_get_focus_owner()
		if stale_focus != null:
			stale_focus.release_focus()
	if hud != null:
		hud.clear_log()
		hud.hide_all_modals()
		hud.set_match_ui_visible(true)
	if network != null and network.is_host():
		_active_net_session_id = network.begin_new_match_session()
	else:
		_active_net_session_id = 0
	setup_match(player_configs)
	if board_view != null:
		if hud != null:
			board_view.set_viewport_rect(hud.get_board_viewport_rect())
		board_view.setup_tokens(players)
		_sync_board_visuals()
	if network != null and network.is_host():
		network.broadcast_match_started(_active_net_session_id, _build_network_snapshot())
	_sync_hud()
	call_deferred("_maybe_start_bot_turn")

func setup_match(player_configs: Array[Dictionary]) -> void:
	var start_money: int = int(board_config.get("starting_money", 2558))
	bank_houses_left = int(board_config.get("max_houses_bank", 32))
	bank_hotels_left = int(board_config.get("max_hotels_bank", 12))

	var bot_count: int = 0
	for cfg: Dictionary in player_configs:
		if bool(cfg.get("is_bot", false)):
			bot_count += 1
	var hidden_profiles: Array[String] = bot_ai.assign_hidden_profiles(bot_count)
	var bot_profile_cursor: int = 0

	players.clear()
	for i: int in range(player_configs.size()):
		var cfg: Dictionary = player_configs[i]
		var is_bot: bool = bool(cfg.get("is_bot", false))
		var assigned_profile: String = ""
		if is_bot:
			var forced_profile: String = str(cfg.get("bot_profile", ""))
			if forced_profile != "":
				assigned_profile = forced_profile
			elif bot_profile_cursor < hidden_profiles.size():
				assigned_profile = hidden_profiles[bot_profile_cursor]
				bot_profile_cursor += 1
			else:
				assigned_profile = BotAIClass.PROFILE_CONSERVADOR

		var peer_owner_id: int = 0 if is_bot else int(cfg.get("peer_id", 1))
		players.append({
			"id": i,
			"peer_id": peer_owner_id,
			"name": str(cfg.get("name", "Jogador %d" % (i + 1))),
			"money": start_money,
			"position": 0,
			"in_jail": false,
			"jail_turns": 0,
			"jail_free_cards": 0,
			"properties": [],
			"bankrupt": false,
			"is_bot": is_bot,
			"bot_profile": assigned_profile,
			"pawn_id": str(cfg.get("pawn_id", "cuia")),
			"pawn_name": str(cfg.get("pawn_name", "Cuia de Chimarrão")),
			"pawn_code": str(cfg.get("pawn_code", "CU")),
			"color_hex": str(cfg.get("color_hex", "")),
			"team_id": int(cfg.get("team_id", -1)),
			"team_name": str(cfg.get("team_name", "")),
			"team_color_hex": str(cfg.get("team_color_hex", ""))
		})

	_team_wallets.clear()
	var team_counts: Dictionary[int, int] = {}
	for pl: Dictionary in players:
		var t_id: int = int(pl.get("team_id", -1))
		if t_id >= 0:
			team_counts[t_id] = team_counts.get(t_id, 0) + 1
	if team_counts.size() >= 2:
		var max_per_team: int = 0
		for tc: int in team_counts.values():
			max_per_team = maxi(max_per_team, tc)
		_team_mode = "3v3" if max_per_team >= 3 else ("2v2" if max_per_team >= 2 else "ffa")
	else:
		_team_mode = "ffa"
	if is_team_mode():
		for t_k: int in team_counts.keys():
			_team_wallets[t_k] = start_money
	else:
		for pl: Dictionary in players:
			pl["team_id"] = -1
			pl["team_name"] = ""
			pl["team_color_hex"] = ""

	property_owners.clear()
	property_buildings.clear()
	mortgaged_tiles.clear()
	_pending_trade_offer.clear()
	_rent_waiver_pacts.clear()
	_auction_state.clear()
	_pending_periodic_auction = false
	_player_auctioned_this_turn = false
	_auction_bot_token += 1
	_last_victory_info.clear()
	current_player_index = 0
	current_state = TurnState.WAITING_ROLL
	doubles_count = 0
	current_round = 1
	_current_season_index = 0
	_acted_in_current_round.clear()
	_bot_traded_this_turn = false
	_selected_property_tile = -1
	_has_extra_roll = false
	_last_dice_sum = 0
	_last_creditor_id = -1
	_match_session_token += 1
	_bot_turn_token += 1
	_is_bot_thinking = false
	_is_animating = false
	_match_active = true
	_last_tile_summary = "Ponto de Partida — Galpão Central"

	_reset_chance_deck()
	if _game_rules_mode == "dynamic":
		_apply_dynamic_initial_draft()
	var mode_badge_txt: String = "Estância Dinâmica" if _game_rules_mode == "dynamic" else "Clássico"
	var team_badge_txt: String = " • Times %s" % _team_mode.replace("v", "x") if is_team_mode() else ""
	_log_both("Partida (%s%s) iniciada com %d estanceiros! Saldo inicial: %d Pilas." % [mode_badge_txt, team_badge_txt, players.size(), start_money])
	if _seasons_enabled:
		var s_info: Dictionary = get_current_season_info()
		_log_both("Estação inicial: %s — %s" % [str(s_info.get("label", "")), str(s_info.get("effect_desc", ""))])
	_log_both("=== Rodada 1 iniciada ===")
	if not players.is_empty():
		_log_both("Vez de %s, tchê!" % str(players[0]["name"]))

func _would_complete_monopoly(player_id: int, tile_idx: int) -> bool:
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	var t: Dictionary = tiles[tile_idx]
	if str(t.get("type", "")) != "PROPERTY":
		return false
	var g_name: String = str(t.get("group", ""))
	if g_name == "":
		return false
	for g_tid: int in _get_group_tile_indices(g_name):
		if g_tid != tile_idx and not _is_owned_by_player_or_team(g_tid, player_id):
			return false
	return true

func _apply_dynamic_initial_draft() -> void:
	var candidates: Array[int] = []
	for i: int in range(tiles.size()):
		var t: Dictionary = tiles[i]
		var tt: String = str(t.get("type", ""))
		if (tt == "PROPERTY" or tt == "COMPANY") and int(t.get("price", 999)) <= 200 and not property_owners.has(i):
			candidates.append(i)
	candidates.shuffle()
	for p: Dictionary in players:
		var pid: int = int(p.get("id", -1))
		var p_props: Array = p.get("properties", [])
		var picked_names: Array[String] = []
		var picked_count: int = 0
		for c_idx: int in range(candidates.size()):
			var tid: int = candidates[c_idx]
			if property_owners.has(tid):
				continue
			if _would_complete_monopoly(pid, tid):
				continue
			property_owners[tid] = pid
			p_props.append(tid)
			picked_names.append(str(tiles[tid].get("name", "Lote")))
			picked_count += 1
			if picked_count >= 2:
				break
		if not picked_names.is_empty():
			_log_both("Draft Inicial: %s recebeu %s." % [str(p.get("name", "Estanceiro")), " e ".join(picked_names)])

func _build_deed_inspection_info(tile_idx: int) -> Dictionary:
	var tile: Dictionary = tiles[tile_idx]
	var tile_type: String = str(tile.get("type", ""))
	var is_owned: bool = property_owners.has(tile_idx)
	var owner_id: int = property_owners.get(tile_idx, -1)
	var owner: Dictionary = _get_player_by_id(owner_id) if is_owned else {}
	var owner_name: String = str(owner.get("name", "")) if not owner.is_empty() else ""
	var owner_pawn: String = str(owner.get("pawn_name", "")) if not owner.is_empty() else ""
	var owner_color: Color = board_view.get_player_color(owner_id) if (is_owned and board_view != null) else Color.WHITE
	var group_name: String = str(tile.get("group", ""))
	var has_monopoly: bool = is_owned and _has_monopoly(owner_id, group_name)

	var active_pid: int = int(players[current_player_index].get("id", -1)) if (not players.is_empty() and current_player_index >= 0 and current_player_index < players.size()) else -1
	var human_can_act: bool = (active_pid >= 0) and (not _is_human_input_blocked()) and (not _is_auction_active())
	var is_owner_active: bool = is_owned and are_allied_players(owner_id, active_pid) and human_can_act
	var can_trade_this_tile: bool = (
		is_owned
		and not are_allied_players(owner_id, active_pid)
		and human_can_act
		and _can_open_trade()
		and not _group_has_buildings(tile_idx)
	)
	var can_offer_in_trade: bool = (
		is_owner_active
		and _can_open_trade()
		and not _group_has_buildings(tile_idx)
	)
	var can_cart_this_tile: bool = (
		is_owner_active
		and tile_type == "PROPERTY"
		and has_monopoly
	)
	var can_auction_owned: bool = (
		is_owner_active
		and _can_auction_owned_tile(active_pid, tile_idx)
	)
	var group_peers: Array[Dictionary] = []
	if tile_type == "PROPERTY" and group_name != "":
		for g_tid: int in _get_group_tile_indices(group_name):
			var g_tile: Dictionary = tiles[g_tid]
			var g_owned: bool = property_owners.has(g_tid)
			var g_owner_id: int = property_owners.get(g_tid, -1)
			var g_owner_col: Color = board_view.get_player_color(g_owner_id) if (g_owned and board_view != null) else Color("#3A4D43")
			group_peers.append({
				"tile_index": g_tid,
				"name": str(g_tile.get("name", "Lote %d" % g_tid)),
				"is_current": (g_tid == tile_idx),
				"is_owned": g_owned,
				"owner_id": g_owner_id,
				"owner_color_hex": "#" + g_owner_col.to_html(false)
			})

	var can_build: bool = is_owner_active and _can_build_on(active_pid, tile_idx)
	var build_label: String = "+Casa"
	if tile_type == "PROPERTY":
		var h_cost: int = _get_effective_house_cost(tile)
		var cur_lvl: int = property_buildings.get(tile_idx, 0)
		build_label = "+Hotel (P$ %d)" % h_cost if cur_lvl == 4 else "+Casa (P$ %d)" % h_cost

	var can_sell: bool = is_owner_active and _can_sell_building_on(active_pid, tile_idx)
	var sell_label: String = "-Casa"
	var cur_lvl_s: int = property_buildings.get(tile_idx, 0)
	var refund_unit: int = _get_building_sell_value(tile)
	if cur_lvl_s >= 5:
		sell_label = "Vender Hotel (+P$ %d)" % refund_unit
	elif cur_lvl_s > 0:
		sell_label = "Vender Casa (+P$ %d)" % refund_unit

	var can_mortgage: bool = is_owner_active and _can_toggle_mortgage(active_pid, tile_idx)
	var mortgage_label: String = "Hipotecar"
	if mortgaged_tiles.get(tile_idx, false):
		mortgage_label = "Desipotecar (-P$ %d)" % _get_redeem_cost(tile)
	elif tile_type == "PROPERTY" or tile_type == "COMPANY":
		mortgage_label = "Hipotecar (+P$ %d)" % _get_mortgage_value(tile)

	return {
		"tile_index": tile_idx,
		"tile": tile,
		"mortgage_value": _get_mortgage_value(tile),
		"redeem_cost": _get_redeem_cost(tile),
		"is_owned": is_owned,
		"owner_id": owner_id,
		"owner_name": owner_name,
		"owner_pawn": owner_pawn,
		"owner_color": owner_color,
		"is_mortgaged": mortgaged_tiles.get(tile_idx, false),
		"building_level": property_buildings.get(tile_idx, 0),
		"has_monopoly": has_monopoly,
		"is_owner_active": is_owner_active,
		"can_build": can_build,
		"build_label": build_label,
		"can_sell_building": can_sell,
		"sell_building_label": sell_label,
		"can_mortgage": can_mortgage,
		"mortgage_label": mortgage_label,
		"can_offer_in_trade": can_offer_in_trade,
		"can_propose_trade": can_trade_this_tile,
		"can_open_build_cart": can_cart_this_tile,
		"can_auction_owned": can_auction_owned,
		"group_peers": group_peers
	}

func _on_tile_inspected(tile_idx: int) -> void:
	if not _match_active or hud == null:
		return
	if tile_idx < 0 or tile_idx >= tiles.size():
		return
	hud.show_deed_modal(_build_deed_inspection_info(tile_idx))

func _build_portfolio_inspection_info(player_id: int) -> Dictionary:
	var target: Dictionary = _get_player_by_id(player_id)
	if target.is_empty():
		return {}

	var active_pid: int = int(players[current_player_index].get("id", -1)) if (not players.is_empty() and current_player_index >= 0 and current_player_index < players.size()) else -1
	var can_manage_owner: bool = (
		active_pid >= 0
		and are_allied_players(active_pid, player_id)
		and (not _is_human_input_blocked())
		and (not _is_auction_active())
	)

	var deeds_list: Array[Dictionary] = []
	var mono_seen: Dictionary[String, bool] = {}
	var monopolies: Array[Dictionary] = []
	var houses_total: int = 0
	var hotels_total: int = 0
	var mortgaged_count: int = 0

	var sorted_ids: Array[int] = _get_actor_or_team_properties(player_id)

	for tid: int in sorted_ids:
		if tid < 0 or tid >= tiles.size():
			continue
		var tile: Dictionary = tiles[tid]
		var tile_type: String = str(tile.get("type", ""))
		var group_name: String = str(tile.get("group", ""))
		var color_hex: String = str(tile.get("color", ""))
		if color_hex == "":
			color_hex = "#4EA8DE" if tile_type == "COMPANY" else "#365C4E"
		var b_lvl: int = property_buildings.get(tid, 0)
		var is_mort: bool = mortgaged_tiles.get(tid, false)
		var has_mono: bool = (tile_type == "PROPERTY") and _has_monopoly(player_id, group_name)

		if is_mort:
			mortgaged_count += 1
		if b_lvl >= 5:
			hotels_total += 1
		elif b_lvl > 0:
			houses_total += b_lvl

		if has_mono and group_name != "" and not mono_seen.has(group_name):
			mono_seen[group_name] = true
			monopolies.append({
				"group": group_name,
				"color_hex": color_hex
			})

		var rent_text: String = ""
		if is_mort:
			rent_text = "Sem aluguel (hipotecada)"
		elif tile_type == "COMPANY":
			var mult: int = int(tile.get("multiplier", 50))
			rent_text = "Aluguel: dados × P$ %d" % mult
		elif tile_type == "PROPERTY":
			var rents: Array = tile.get("rent", [0])
			var safe_lvl: int = clampi(b_lvl, 0, maxi(0, rents.size() - 1))
			var rent_val: int = int(rents[safe_lvl]) if not rents.is_empty() else 0
			if b_lvl == 0 and has_mono:
				rent_val *= 2
			rent_text = "Aluguel atual: P$ %d" % rent_val

		var m_val: int = _get_mortgage_value(tile)
		var r_cost: int = _get_redeem_cost(tile)
		var sell_val: int = _get_building_sell_value(tile)
		var can_mort: bool = can_manage_owner and _can_toggle_mortgage(player_id, tid)
		var can_sell: bool = can_manage_owner and _can_sell_building_on(player_id, tid)
		var mort_lbl: String = ("Desipotecar (-P$ %d)" % r_cost) if is_mort else ("Hipotecar (+P$ %d)" % m_val)
		var sell_lbl: String = ("-Hotel (+P$ %d)" % sell_val) if b_lvl >= 5 else ("-Casa (+P$ %d)" % sell_val)

		deeds_list.append({
			"tile_index": tid,
			"name": str(tile.get("name", "Casa %d" % tid)),
			"group": group_name if group_name != "" else ("Companhia" if tile_type == "COMPANY" else ""),
			"color_hex": color_hex,
			"tile_type": tile_type,
			"building_level": b_lvl,
			"is_mortgaged": is_mort,
			"has_monopoly": has_mono,
			"rent_text": rent_text,
			"mortgage_value": m_val,
			"redeem_cost": r_cost,
			"can_mortgage": can_mort,
			"mortgage_label": mort_lbl,
			"can_sell_building": can_sell,
			"sell_building_label": sell_lbl
		})

	var p_color: Color = board_view.get_player_color(player_id) if board_view != null else Color("#2A9D8F")
	return {
		"id": player_id,
		"name": str(target.get("name", "Estanceiro")),
		"is_bot": bool(target.get("is_bot", false)),
		"is_bankrupt": bool(target.get("bankrupt", false)),
		"in_jail": bool(target.get("in_jail", false)),
		"jail_free_cards": int(target.get("jail_free_cards", 0)),
		"money": int(target.get("money", 0)),
		"max_liquidatable": _get_max_liquidatable_cash(player_id),
		"can_manage_owner": can_manage_owner,
		"pawn_id": str(target.get("pawn_id", "cuia")),
		"pawn_name": str(target.get("pawn_name", "")),
		"color": p_color,
		"houses_total": houses_total,
		"hotels_total": hotels_total,
		"mortgaged_count": mortgaged_count,
		"monopolies": monopolies,
		"deeds": deeds_list
	}

func _on_player_inspected(player_id: int) -> void:
	if not _match_active or hud == null:
		return
	var info: Dictionary = _build_portfolio_inspection_info(player_id)
	if not info.is_empty():
		hud.show_player_portfolio_modal(info)

func _is_current_player_bot() -> bool:
	if not _match_active or players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return false
	var current_player: Dictionary = players[current_player_index]
	return bool(current_player.get("is_bot", false)) and not bool(current_player.get("bankrupt", false))

func _is_current_player_bot_owner() -> bool:
	if not _match_active or players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return false
	return bool(players[current_player_index].get("is_bot", false))

func _is_current_player_bankrupt() -> bool:
	if not _match_active or players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return false
	return bool(players[current_player_index].get("bankrupt", false))

func _is_online_match() -> bool:
	return network != null and network.is_online()

func _is_network_client() -> bool:
	return network != null and network.is_client()

func _is_network_host() -> bool:
	return network != null and network.is_host()

func _get_local_player_id() -> int:
	if not _is_online_match() or players.is_empty():
		return -1
	var my_peer: int = network.get_local_peer_id()
	for p: Dictionary in players:
		if not bool(p.get("is_bot", false)) and int(p.get("peer_id", 0)) == my_peer:
			return int(p.get("id", -1))
	return -1

func _is_local_players_turn() -> bool:
	if not _match_active or players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return false
	var cur: Dictionary = players[current_player_index]
	if bool(cur.get("is_bot", false)) or bool(cur.get("bankrupt", false)):
		return false
	if not _is_online_match():
		return true
	return int(cur.get("peer_id", 1)) == network.get_local_peer_id()

func _is_human_input_blocked() -> bool:
	if not _match_active or _is_animating or _is_bot_thinking or _is_current_player_bot_owner() or current_state == TurnState.MOVING:
		return true
	if _is_auction_active():
		return true
	if _is_online_match() and not _is_local_players_turn():
		return true
	return false

func _is_auction_active() -> bool:
	return bool(_auction_state.get("active", false))

func _on_human_trade_offer_responded(offer_id: int, accepted: bool) -> void:
	if not _match_active:
		return
	if _is_network_client():
		network.send_action_to_host("TRADE_RESPOND", {
			"offer_id": offer_id,
			"accept": accepted
		})
		return
	respond_to_trade_offer(offer_id, accepted)

func _on_human_auction_bid_submitted(bid_amount: int) -> void:
	if not _match_active or not _is_auction_active():
		return
	if _is_network_client():
		network.send_action_to_host("AUCTION_BID", { "amount": bid_amount })
		return
	var bidder_id: int = _get_auction_current_bidder_id()
	submit_auction_bid(bidder_id, bid_amount)

func _on_human_auction_pass_submitted() -> void:
	if not _match_active or not _is_auction_active():
		return
	if _is_network_client():
		network.send_action_to_host("AUCTION_PASS", {})
		return
	var bidder_id: int = _get_auction_current_bidder_id()
	pass_auction_turn(bidder_id)

func _on_human_roll_pressed() -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("ROLL", {})
		return
	roll_dice()

func _on_human_buy_pressed() -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("BUY", {})
		return
	buy_current_property()

func _on_human_decline_pressed() -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("DECLINE", {})
		return
	decline_buy_property()

func _on_human_bail_pressed() -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("BAIL", {})
		return
	pay_bail()

func _on_human_use_jail_card_pressed() -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("JAIL_CARD", {})
		return
	use_jail_free_card()

func _on_human_property_selected(tile_idx: int) -> void:
	if _is_human_input_blocked():
		return
	_selected_property_tile = tile_idx
	_sync_hud()

func _on_human_build_pressed(tile_idx: int) -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("BUILD", { "tile_index": tile_idx })
		return
	build_on_property(tile_idx)

func _on_human_sell_building_pressed(tile_idx: int) -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("SELL_BUILDING", { "tile_index": tile_idx })
		return
	sell_building_on_property(tile_idx)

func _on_human_build_cart_applied(target_levels: Dictionary) -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("BUILD_CART", { "levels": target_levels.duplicate(true) })
		return
	apply_construction_cart(target_levels)

func _on_human_mortgage_pressed(tile_idx: int) -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("MORTGAGE", { "tile_index": tile_idx })
		return
	toggle_mortgage(tile_idx)

func _on_human_auction_owned_requested(tile_idx: int) -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("AUCTION_OWNED", { "tile_index": tile_idx })
		return
	start_owned_property_auction(tile_idx)

func _on_human_leave_to_bot_requested() -> void:
	if not _match_active or current_state == TurnState.GAME_OVER:
		return
	if _is_network_client():
		network.send_action_to_host("RESIGN_TO_BOT", {})
		network.disconnect_network("Você passou sua vaga para um [BOT] e saiu da sala.")
		_reset_match_state()
		if setup_screen != null:
			setup_screen.open_screen()
		return
	var target_pid: int = _get_local_leave_candidate_id()
	if target_pid >= 0:
		resign_to_bot(target_pid)

func _on_human_forfeit_requested() -> void:
	if not _match_active or current_state == TurnState.GAME_OVER:
		return
	if _is_network_client():
		network.send_action_to_host("FORFEIT", {})
		network.disconnect_network("Você declarou desistência e saiu da sala.")
		_reset_match_state()
		if setup_screen != null:
			setup_screen.open_screen()
		return
	var target_pid: int = _get_local_leave_candidate_id()
	if target_pid >= 0:
		forfeit_player(target_pid)

func _get_local_leave_candidate_id() -> int:
	if players.is_empty():
		return -1
	if _is_online_match():
		return _get_local_player_id()
	if current_player_index >= 0 and current_player_index < players.size():
		var cp: Dictionary = players[current_player_index]
		if not bool(cp.get("is_bot", false)) and not bool(cp.get("bankrupt", false)):
			return int(cp.get("id", -1))
	for p: Dictionary in players:
		if not bool(p.get("is_bot", false)) and not bool(p.get("bankrupt", false)):
			return int(p.get("id", -1))
	return -1

func resign_to_bot(player_id: int) -> bool:
	if not _match_active or current_state == TurnState.GAME_OVER or _is_network_client():
		return false
	var target: Dictionary = _get_player_by_id(player_id)
	if target.is_empty() or bool(target.get("bankrupt", false)) or bool(target.get("is_bot", false)):
		return false
	if _count_active_players() < 2:
		return false

	var hidden_arr: Array[String] = bot_ai.assign_hidden_profiles(1)
	var assigned_prof: String = hidden_arr[0] if not hidden_arr.is_empty() else BotAIClass.PROFILE_CONSERVADOR
	var p_name: String = str(target.get("name", "Estanceiro"))
	target["is_bot"] = true
	target["peer_id"] = 0
	target["bot_profile"] = assigned_prof

	_log_both("%s saiu e passou a vaga para [BOT]." % p_name)
	_last_tile_summary = "%s passou a vaga para [BOT]." % p_name
	_broadcast_toast_event("Assumido por [BOT]", "%s deixou a mesa e agora joga como [BOT]." % p_name, "turn")
	_sync_hud()

	var cur_pid: int = int(players[current_player_index].get("id", -1)) if (current_player_index >= 0 and current_player_index < players.size()) else -1
	if _is_auction_active():
		_maybe_step_auction_bot()
	elif cur_pid == player_id:
		call_deferred("_maybe_start_bot_turn")
	return true

func forfeit_player(player_id: int) -> bool:
	if not _match_active or current_state == TurnState.GAME_OVER or _is_network_client():
		return false
	var target: Dictionary = _get_player_by_id(player_id)
	if target.is_empty() or bool(target.get("bankrupt", false)):
		return false

	var p_name: String = str(target.get("name", "Estanceiro"))
	var was_active: bool = (
		current_player_index >= 0
		and current_player_index < players.size()
		and int(players[current_player_index].get("id", -1)) == player_id
	)
	_log_both("%s declarou desistência da partida!" % p_name)
	_last_creditor_id = -1
	_check_bankruptcy(target, true, -1)
	if current_state != TurnState.GAME_OVER and was_active:
		_advance_turn_after_bankruptcy(player_id)
	else:
		_sync_hud()
	return true

func _on_human_end_turn_pressed() -> void:
	if _is_human_input_blocked():
		return
	if _is_network_client():
		network.send_action_to_host("END_TURN", {})
		return
	end_turn()

func _on_human_trade_executed(target_id: int, offer_tile: int, request_tile: int, cash_delta: int, rent_waiver_rounds: int = 0) -> void:
	if _is_human_input_blocked():
		return
	var safe_waiver: int = clampi(rent_waiver_rounds, 0, DEFAULT_RENT_WAIVER_ROUNDS)
	if _is_network_client():
		network.send_action_to_host("TRADE", {
			"target_id": target_id,
			"offer_tile": offer_tile,
			"request_tile": request_tile,
			"cash_delta": cash_delta,
			"rent_waiver_rounds": safe_waiver
		})
		return
	execute_trade(target_id, offer_tile, request_tile, cash_delta, safe_waiver)

func _log_both(msg: String) -> void:
	print(msg)
	if hud != null:
		hud.push_log(msg)
	match_event_logged.emit(msg)
	if _is_network_host() and _match_active and not _applying_remote_state:
		network.broadcast_match_event(_active_net_session_id, "LOG", { "msg": msg })

func _broadcast_toast_event(title: String, detail: String, tone: String) -> void:
	if hud != null:
		hud.show_event_toast(title, detail, tone)
	if _is_network_host() and _match_active and not _applying_remote_state:
		network.broadcast_match_event(_active_net_session_id, "TOAST", {
			"title": title,
			"detail": detail,
			"tone": tone
		})

func _broadcast_tile_pulse(tile_idx: int, col: Color, text: String) -> void:
	if board_view != null:
		board_view.play_tile_pulse(tile_idx, col, text)
	if _is_network_host() and _match_active and not _applying_remote_state:
		network.broadcast_match_event(_active_net_session_id, "TILE_PULSE", {
			"tile": tile_idx,
			"color_hex": "#" + col.to_html(false),
			"text": text
		})

func _state_label() -> String:
	if not _match_active:
		return "Configurando"
	match current_state:
		TurnState.WAITING_ROLL:
			return "Rolar Dados"
		TurnState.EVALUATING:
			return "Avaliando Casa"
		TurnState.MANAGEMENT:
			return "Gerenciar / Encerrar"
		TurnState.GAME_OVER:
			return "Fim de Jogo"
		_:
			return "Movendo"

func _get_player_by_id(player_id: int) -> Dictionary:
	for p: Dictionary in players:
		if int(p["id"]) == player_id:
			return p
	return {}

func _get_player_colors_map() -> Dictionary[int, Color]:
	var colors_map: Dictionary[int, Color] = {}
	for p: Dictionary in players:
		var pid: int = int(p["id"])
		if board_view != null:
			colors_map[pid] = board_view.get_player_color(pid)
		else:
			colors_map[pid] = Color.WHITE
	return colors_map

func _sync_active_player_highlight() -> void:
	if board_view == null:
		return
	if not _match_active or players.is_empty():
		board_view.set_active_player(-1)
		return
	if current_state == TurnState.GAME_OVER:
		for p: Dictionary in players:
			if not bool(p.get("bankrupt", false)):
				board_view.set_active_player(int(p["id"]))
				return
		board_view.set_active_player(-1)
		return
	if current_player_index >= 0 and current_player_index < players.size():
		board_view.set_active_player(int(players[current_player_index]["id"]))

func _sync_board_visuals() -> void:
	if board_view == null:
		return
	board_view.update_ownership(property_owners, mortgaged_tiles)
	board_view.update_buildings(property_buildings)
	board_view.update_token_positions(players)
	_sync_active_player_highlight()

func _count_active_players() -> int:
	var active: int = 0
	for p: Dictionary in players:
		if not bool(p.get("bankrupt", false)):
			active += 1
	return active

func _count_unowned_buyables() -> int:
	var count: int = 0
	for i: int in range(tiles.size()):
		var tile_type: String = str(tiles[i].get("type", ""))
		if (tile_type == "PROPERTY" or tile_type == "COMPANY") and not property_owners.has(i):
			count += 1
	return count

func _build_bot_board_state() -> Dictionary:
	return {
		"tiles": tiles,
		"property_owners": property_owners,
		"property_buildings": property_buildings,
		"mortgaged_tiles": mortgaged_tiles,
		"player_teams": _build_player_teams_map(),
		"bank_houses_left": bank_houses_left,
		"bank_hotels_left": bank_hotels_left,
		"unowned_buyables": _count_unowned_buyables()
	}

func _get_mortgage_value(tile: Dictionary) -> int:
	if tile.has("mortgage"):
		return int(tile["mortgage"])
	return floori(float(tile.get("price", 0)) * 0.5)

func _get_redeem_cost(tile: Dictionary) -> int:
	var mortgage_val: int = _get_mortgage_value(tile)
	var interest_rate: float = float(board_config.get("unmortgage_interest_rate", 0.1))
	return roundi(float(mortgage_val) * (1.0 + interest_rate))

func _get_building_sell_value(tile: Dictionary) -> int:
	var house_cost: int = int(tile.get("house_cost", 50))
	return floori(float(house_cost) * 0.5)

func _get_effective_house_cost(tile: Dictionary) -> int:
	var base_cost: int = int(tile.get("house_cost", 50))
	if _seasons_enabled and get_current_season_id() == "OUTONO":
		return maxi(20, roundi(float(base_cost) * 0.8))
	return base_cost

func _get_effective_pass_go_bonus() -> int:
	var base_bonus: int = int(board_config.get("pass_go_bonus", 200))
	if _seasons_enabled and get_current_season_id() == "PRIMAVERA":
		return roundi(float(base_bonus) * 1.25)
	return base_bonus

func _get_effective_tax_amount(tile: Dictionary) -> int:
	var base_tax: int = int(tile.get("amount", 0))
	if _seasons_enabled and get_current_season_id() == "INVERNO":
		return roundi(float(base_tax) * 1.25)
	return base_tax

func _get_current_player_money() -> int:
	if players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return 0
	return int(players[current_player_index].get("money", 0))

func _can_open_trade() -> bool:
	if not _match_active or _is_animating or _is_auction_active() or not _pending_trade_offer.is_empty() or players.is_empty():
		return false
	if current_player_index < 0 or current_player_index >= players.size():
		return false
	var player: Dictionary = players[current_player_index]
	if bool(player.get("bankrupt", false)):
		return false
	var valid_phase: bool = (
		current_state == TurnState.WAITING_ROLL
		or current_state == TurnState.EVALUATING
		or current_state == TurnState.MANAGEMENT
	)
	return valid_phase and _count_active_players() > 1

func _can_roll_dice() -> bool:
	if not _match_active or _is_animating or _is_auction_active() or players.is_empty() or tiles.is_empty():
		return false
	var player: Dictionary = players[current_player_index]
	if bool(player.get("bankrupt", false)) or int(player.get("money", 0)) < 0:
		return false
	if current_state == TurnState.WAITING_ROLL:
		return true
	if current_state == TurnState.MANAGEMENT and _has_extra_roll:
		return not bool(player.get("in_jail", false))
	return false

func _has_liquidatable_assets(player_id: int) -> bool:
	var player: Dictionary = _get_player_by_id(player_id)
	if player.is_empty() or bool(player.get("bankrupt", false)):
		return false
	for tid: int in _get_actor_or_team_properties(player_id):
		if property_buildings.get(tid, 0) > 0:
			return true
		if not mortgaged_tiles.get(tid, false):
			return true
	return false

func _get_max_liquidatable_cash(player_id: int) -> int:
	var player: Dictionary = _get_player_by_id(player_id)
	if player.is_empty() or bool(player.get("bankrupt", false)):
		return 0
	var total: int = 0
	for tid: int in _get_actor_or_team_properties(player_id):
		if tid < 0 or tid >= tiles.size():
			continue
		var tile: Dictionary = tiles[tid]
		var lvl: int = property_buildings.get(tid, 0)
		if lvl > 0:
			total += _get_building_sell_value(tile) * lvl
		if not mortgaged_tiles.get(tid, false):
			total += _get_mortgage_value(tile)
	return total

func _can_end_turn() -> bool:
	if not _match_active or _is_animating or _is_auction_active() or players.is_empty():
		return false
	if current_state == TurnState.GAME_OVER:
		return false
	if _is_current_player_bankrupt():
		return true
	var player: Dictionary = players[current_player_index]
	if int(player.get("money", 0)) < 0:
		# Não permite encerrar/declarar falência enquanto houver construções ou escrituras desipotecadas para liquidar
		return not _has_liquidatable_assets(int(player.get("id", -1)))
	if current_state == TurnState.MANAGEMENT:
		return true
	if current_state == TurnState.EVALUATING and not _has_extra_roll:
		return true
	return false

func _can_buy_current_tile() -> bool:
	if not _match_active or _is_animating or current_state != TurnState.EVALUATING or players.is_empty() or tiles.is_empty():
		return false
	var player: Dictionary = players[current_player_index]
	if bool(player.get("bankrupt", false)):
		return false
	var pos: int = int(player["position"])
	if pos < 0 or pos >= tiles.size():
		return false
	var tile: Dictionary = tiles[pos]
	var tile_type: String = str(tile.get("type", ""))
	if tile_type != "PROPERTY" and tile_type != "COMPANY":
		return false
	if property_owners.has(pos):
		return false
	return int(player["money"]) >= int(tile.get("price", 0))

func _can_pay_bail() -> bool:
	if not _match_active or _is_animating or players.is_empty():
		return false
	if current_state != TurnState.WAITING_ROLL and current_state != TurnState.MANAGEMENT:
		return false
	var player: Dictionary = players[current_player_index]
	if bool(player.get("bankrupt", false)) or not bool(player.get("in_jail", false)):
		return false
	# Regra clássica do Xadrez: bloqueia fiança antes da 1ª tentativa nos dados (jail_turns == 0);
	# libera pagamento opcional após tentativa (jail_turns >= 1) e torna obrigatório após 3ª falha.
	if int(player.get("jail_turns", 0)) < 1:
		return false
	var bail: int = int(board_config.get("bail_cost", 50))
	return int(player["money"]) >= bail

func _can_use_jail_free_card() -> bool:
	if not _match_active or _is_animating or players.is_empty() or current_state != TurnState.WAITING_ROLL:
		return false
	var player: Dictionary = players[current_player_index]
	if bool(player.get("bankrupt", false)):
		return false
	return bool(player.get("in_jail", false)) and int(player.get("jail_free_cards", 0)) > 0

func _get_group_tile_indices(group_name: String) -> Array[int]:
	var list: Array[int] = []
	if group_name == "":
		return list
	for i: int in range(tiles.size()):
		var t: Dictionary = tiles[i]
		if str(t.get("type", "")) == "PROPERTY" and str(t.get("group", "")) == group_name:
			list.append(i)
	return list

func _has_monopoly(owner_id: int, group_name: String) -> bool:
	var group_indices: Array[int] = _get_group_tile_indices(group_name)
	if group_indices.is_empty():
		return false
	for idx: int in group_indices:
		if not are_allied_players(property_owners.get(idx, -1), owner_id):
			return false
	return true

func _group_has_buildings(tile_idx: int) -> bool:
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	if property_buildings.get(tile_idx, 0) > 0:
		return true
	var group_name: String = str(tiles[tile_idx].get("group", ""))
	for g_idx: int in _get_group_tile_indices(group_name):
		if property_buildings.get(g_idx, 0) > 0:
			return true
	return false

func _can_build_on(player_id: int, tile_idx: int) -> bool:
	if not _match_active or _is_animating or _is_auction_active() or current_state == TurnState.GAME_OVER or current_state == TurnState.MOVING:
		return false
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	var player: Dictionary = _get_player_by_id(player_id)
	if player.is_empty() or bool(player.get("bankrupt", false)):
		return false
	var tile: Dictionary = tiles[tile_idx]
	if str(tile.get("type", "")) != "PROPERTY":
		return false
	if not _is_owned_by_player_or_team(tile_idx, player_id):
		return false
	if mortgaged_tiles.get(tile_idx, false):
		return false
	var group_name: String = str(tile.get("group", ""))
	if not _has_monopoly(player_id, group_name):
		return false

	var group_indices: Array[int] = _get_group_tile_indices(group_name)
	for g_idx: int in group_indices:
		if mortgaged_tiles.get(g_idx, false):
			return false

	var current_level: int = property_buildings.get(tile_idx, 0)
	if current_level >= 5:
		return false

	if current_level == 4:
		if bank_hotels_left <= 0:
			return false
	else:
		if bank_houses_left <= 0:
			return false

	for g_idx: int in group_indices:
		var g_level: int = property_buildings.get(g_idx, 0)
		if current_level > g_level:
			return false

	var house_cost: int = _get_effective_house_cost(tile)
	return int(player["money"]) >= house_cost

func _can_sell_building_on(player_id: int, tile_idx: int) -> bool:
	if not _match_active or _is_animating or _is_auction_active() or current_state == TurnState.GAME_OVER or current_state == TurnState.MOVING:
		return false
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	var player: Dictionary = _get_player_by_id(player_id)
	if player.is_empty() or bool(player.get("bankrupt", false)):
		return false
	var tile: Dictionary = tiles[tile_idx]
	if str(tile.get("type", "")) != "PROPERTY":
		return false
	if not _is_owned_by_player_or_team(tile_idx, player_id):
		return false

	var current_level: int = property_buildings.get(tile_idx, 0)
	if current_level <= 0:
		return false

	var group_name: String = str(tile.get("group", ""))
	var group_indices: Array[int] = _get_group_tile_indices(group_name)
	for g_idx: int in group_indices:
		var g_level: int = property_buildings.get(g_idx, 0)
		if current_level < g_level:
			return false

	return true

func _can_toggle_mortgage(player_id: int, tile_idx: int) -> bool:
	if not _match_active or _is_animating or _is_auction_active() or current_state == TurnState.GAME_OVER or current_state == TurnState.MOVING:
		return false
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	var player: Dictionary = _get_player_by_id(player_id)
	if player.is_empty() or bool(player.get("bankrupt", false)):
		return false
	if property_owners.get(tile_idx, -1) < 0 or not _is_owned_by_player_or_team(tile_idx, player_id):
		return false

	var tile: Dictionary = tiles[tile_idx]
	if mortgaged_tiles.get(tile_idx, false):
		var redeem_cost: int = _get_redeem_cost(tile)
		return int(player["money"]) >= redeem_cost

	if _group_has_buildings(tile_idx):
		return false
	return true

func _get_buildable_tiles_for(player_id: int) -> Array[int]:
	var result: Array[int] = []
	for tid: int in _get_actor_or_team_properties(player_id):
		if _can_build_on(player_id, tid):
			result.append(tid)
	return result

func _get_sellable_tiles_for(player_id: int) -> Array[int]:
	var result: Array[int] = []
	for tid: int in _get_actor_or_team_properties(player_id):
		if _can_sell_building_on(player_id, tid):
			result.append(tid)
	return result

func _get_mortgageable_tiles_for(player_id: int) -> Array[int]:
	var result: Array[int] = []
	for tid: int in _get_actor_or_team_properties(player_id):
		if not mortgaged_tiles.get(tid, false) and _can_toggle_mortgage(player_id, tid):
			result.append(tid)
	return result

func _get_unmortgageable_tiles_for(player_id: int) -> Array[int]:
	var result: Array[int] = []
	for tid: int in _get_actor_or_team_properties(player_id):
		if mortgaged_tiles.get(tid, false) and _can_toggle_mortgage(player_id, tid):
			result.append(tid)
	return result

func _build_owned_options(player: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var pid: int = int(player.get("id", -1))
	for tile_idx: int in _get_actor_or_team_properties(pid):
		if tile_idx < 0 or tile_idx >= tiles.size():
			continue
		var t: Dictionary = tiles[tile_idx]
		var lvl: int = property_buildings.get(tile_idx, 0)
		var b_tag: String = " [HOTEL]" if lvl >= 5 else (" [%d casa(s)]" % lvl if lvl > 0 else "")
		var m_tag: String = " [HIPOTECADA]" if mortgaged_tiles.get(tile_idx, false) else ""
		options.append({
			"tile_index": tile_idx,
			"label": "%s%s%s" % [str(t["name"]), b_tag, m_tag]
		})
	return options

func is_market_push_round() -> bool:
	if current_round >= TRADE_CYCLE_INTERVAL and current_round % TRADE_CYCLE_INTERVAL == 0:
		return true
	return _count_unowned_buyables() <= 10

func _advance_round_if_complete(finished_player_id: int) -> void:
	_acted_in_current_round[finished_player_id] = true
	var active_count: int = 0
	for p: Dictionary in players:
		if bool(p.get("bankrupt", false)):
			continue
		active_count += 1
		var pid: int = int(p.get("id", -1))
		if not _acted_in_current_round.has(pid):
			return
	if active_count <= 1:
		return
	current_round += 1
	_acted_in_current_round.clear()
	if not _rent_waiver_pacts.is_empty():
		var surviving_pacts: Array[Dictionary] = []
		for pact: Dictionary in _rent_waiver_pacts:
			var left: int = int(pact.get("rounds_left", 0)) - 1
			if left > 0:
				pact["rounds_left"] = left
				surviving_pacts.append(pact)
			else:
				var p_a: Dictionary = _get_player_by_id(int(pact.get("a", -1)))
				var p_b: Dictionary = _get_player_by_id(int(pact.get("b", -1)))
				_log_both("Contrato de Parceria entre %s e %s encerrou (aluguel volta ao normal)." % [str(p_a.get("name", "Estanceiro")), str(p_b.get("name", "Estanceiro"))])
		_rent_waiver_pacts = surviving_pacts
	if _seasons_enabled:
		var next_s: int = floori(float(current_round - 1) / float(SEASON_CYCLE_ROUNDS)) % SEASON_ORDER.size()
		if next_s != _current_season_index:
			_current_season_index = next_s
			var s_info: Dictionary = get_current_season_info()
			_play_sfx("season_change")
			_log_both("Mudança de Estação! Chegou %s: %s" % [str(s_info.get("label", "")), str(s_info.get("effect_desc", ""))])
			_broadcast_toast_event("Estação: %s!" % str(s_info.get("label", "")), str(s_info.get("effect_desc", "")), "chance")
	var auction_interval: int = int(_preferences.get("auction_interval_rounds", 3))
	if not _applying_remote_state and not _is_network_client() and auction_interval > 0 and current_round >= auction_interval and current_round % auction_interval == 0:
		if _count_unowned_buyables() > 0 and _count_active_players() >= 2:
			_pending_periodic_auction = true
	if current_round % TRADE_CYCLE_INTERVAL == 0:
		_log_both("=== Rodada %d • Feira de Negócios: estanceiros mais abertos a trocas e obras! ===" % current_round)
		_broadcast_toast_event("Rodada %d • Feira de Negócios!" % current_round, "Ciclo ativo: trocas estratégicas e obras aquecidas na mesa.", "turn")
	else:
		_log_both("=== Rodada %d iniciada ===" % current_round)

func _sync_hud() -> void:
	if hud == null:
		return
	hud.set_round_info(current_round, is_market_push_round(), get_current_season_info())
	if board_view != null:
		board_view.apply_season_visuals(get_current_season_id(), true)
	var online_now: bool = _is_online_match()
	var local_pid: int = _get_local_player_id()
	var local_peer: int = network.get_local_peer_id() if online_now else 1
	var wait_text: String = ""
	if online_now and _match_active and not players.is_empty() and current_player_index >= 0 and current_player_index < players.size():
		var cp: Dictionary = players[current_player_index]
		if not bool(cp.get("is_bot", false)) and int(cp.get("peer_id", 1)) != local_peer:
			var role_tag: String = "[HOST]" if int(cp.get("peer_id", 1)) == 1 else "[ONLINE]"
			wait_text = "Aguardando %s %s jogar..." % [str(cp.get("name", "Estanceiro")), role_tag]
	var transport_lbl: String = network.get_transport_label() if (online_now and network != null) else "LOCAL"
	var room_code_str: String = network.get_room_code() if (online_now and network != null) else ""
	hud.set_network_identity(online_now, _is_network_host(), local_peer, local_pid, wait_text, transport_lbl, room_code_str)
	var tradable_map: Dictionary[int, bool] = {}
	for owner_tid: int in property_owners.keys():
		tradable_map[owner_tid] = not _group_has_buildings(owner_tid)
	hud.set_board_snapshot_meta(property_owners, property_buildings, mortgaged_tiles, tradable_map)

	var default_bail_label: String = "Fiança P$%d" % int(board_config.get("bail_cost", 50))
	if players.is_empty() or not _match_active:
		hud.refresh_hud(
			players,
			0,
			tiles,
			_get_player_colors_map(),
			_state_label(),
			_last_tile_summary,
			bank_houses_left,
			bank_hotels_left,
			true,
			"NONE",
			false,
			false,
			"Comprar",
			false,
			false,
			default_bail_label,
			false,
			"Carta Livre",
			[],
			-1,
			false,
			"+Casa",
			false,
			"-Casa",
			false,
			"Hipotec.",
			false,
			false
		)
		return

	var player: Dictionary = players[current_player_index]
	var pid: int = int(player["id"])
	var is_bankrupt: bool = bool(player.get("bankrupt", false))
	var is_remote_human_turn: bool = _is_online_match() and not bool(player.get("is_bot", false)) and not _is_local_players_turn()
	var is_bot_turn: bool = _is_current_player_bot_owner() or _is_bot_thinking or is_remote_human_turn

	var can_roll: bool = _can_roll_dice()
	var can_buy: bool = _can_buy_current_tile()
	var buy_label: String = "Comprar"
	var pos: int = int(player["position"])
	if current_state == TurnState.EVALUATING and pos >= 0 and pos < tiles.size():
		var cur_tile: Dictionary = tiles[pos]
		var cur_type: String = str(cur_tile.get("type", ""))
		if (cur_type == "PROPERTY" or cur_type == "COMPANY") and not property_owners.has(pos):
			buy_label = "Comprar P$%d" % int(cur_tile.get("price", 0))

	var can_decline: bool = (not _is_animating and current_state == TurnState.EVALUATING and not is_bankrupt)
	var can_bail: bool = _can_pay_bail()
	var can_use_jail_card: bool = _can_use_jail_free_card()
	var jail_cards_count: int = int(player.get("jail_free_cards", 0))
	var jail_card_label: String = "Carta Livre (%d)" % jail_cards_count if jail_cards_count > 0 else "Carta Livre"

	var owned_opts: Array[Dictionary] = _build_owned_options(player)
	var actor_props: Array[int] = _get_actor_or_team_properties(pid)
	if not (_selected_property_tile in actor_props):
		_selected_property_tile = int(owned_opts[0]["tile_index"]) if owned_opts.size() > 0 else -1

	var can_build: bool = (_selected_property_tile >= 0) and _can_build_on(pid, _selected_property_tile)
	var build_label: String = "+Casa"
	if _selected_property_tile >= 0 and _selected_property_tile < tiles.size():
		var sel_tile: Dictionary = tiles[_selected_property_tile]
		if str(sel_tile.get("type", "")) == "PROPERTY":
			var sel_build_cost: int = _get_effective_house_cost(sel_tile)
			var sel_cur_lvl: int = property_buildings.get(_selected_property_tile, 0)
			build_label = "+Hotel P$%d" % sel_build_cost if sel_cur_lvl == 4 else "+Casa P$%d" % sel_build_cost

	var can_sell_building: bool = (_selected_property_tile >= 0) and _can_sell_building_on(pid, _selected_property_tile)
	var sell_building_label: String = "-Casa"
	if _selected_property_tile >= 0:
		var sel_lvl: int = property_buildings.get(_selected_property_tile, 0)
		var refund_unit: int = _get_building_sell_value(tiles[_selected_property_tile])
		if sel_lvl >= 5:
			sell_building_label = "-Hotel +P$%d" % refund_unit
		elif sel_lvl > 0:
			sell_building_label = "-Casa +P$%d" % refund_unit

	var can_mortgage: bool = (_selected_property_tile >= 0) and _can_toggle_mortgage(pid, _selected_property_tile)
	var mortgage_label: String = "Hipotec."
	if _selected_property_tile >= 0 and _selected_property_tile < tiles.size():
		var sel_m_tile: Dictionary = tiles[_selected_property_tile]
		if mortgaged_tiles.get(_selected_property_tile, false):
			var redeem_cost: int = _get_redeem_cost(sel_m_tile)
			mortgage_label = "Desip. -P$%d" % redeem_cost
		else:
			var m_val: int = _get_mortgage_value(sel_m_tile)
			mortgage_label = "Hip. +P$%d" % m_val

	var can_end: bool = _can_end_turn()
	var can_trade: bool = _can_open_trade()

	var primary_action: String = "NONE"
	if not is_bot_turn and not _is_animating and current_state != TurnState.GAME_OVER:
		if can_roll:
			primary_action = "ROLL"
		elif can_buy:
			primary_action = "BUY"
		elif current_state == TurnState.EVALUATING and can_decline:
			primary_action = "DECLINE"
		elif current_state == TurnState.MANAGEMENT and can_end:
			primary_action = "END_TURN"

	hud.refresh_hud(
		players,
		current_player_index,
		tiles,
		_get_player_colors_map(),
		_state_label(),
		_last_tile_summary,
		bank_houses_left,
		bank_hotels_left,
		is_bot_turn,
		primary_action,
		can_roll,
		can_buy,
		buy_label,
		can_decline,
		can_bail,
		default_bail_label,
		can_use_jail_card,
		jail_card_label,
		owned_opts,
		_selected_property_tile,
		can_build,
		build_label,
		can_sell_building,
		sell_building_label,
		can_mortgage,
		mortgage_label,
		can_trade,
		can_end
	)
	var active_player_id: int = int(player.get("id", -1))
	turn_state_changed.emit(int(current_state), active_player_id, current_round)
	hud_state_synced.emit({
		"state": int(current_state),
		"state_label": _state_label(),
		"current_player_index": current_player_index,
		"current_player_id": active_player_id,
		"current_round": current_round,
		"bank_houses_left": bank_houses_left,
		"bank_hotels_left": bank_hotels_left,
		"match_active": _match_active
	})
	if _match_active and not players.is_empty():
		if hud.has_method("get_open_deed_tile_index"):
			var open_deed_idx: int = int(hud.call("get_open_deed_tile_index"))
			if open_deed_idx >= 0 and open_deed_idx < tiles.size():
				hud.show_deed_modal(_build_deed_inspection_info(open_deed_idx))
		if hud.has_method("get_open_portfolio_player_id"):
			var open_port_pid: int = int(hud.call("get_open_portfolio_player_id"))
			if open_port_pid >= 0:
				var p_info: Dictionary = _build_portfolio_inspection_info(open_port_pid)
				if not p_info.is_empty():
					hud.show_player_portfolio_modal(p_info)
	_broadcast_state_if_host()

func _maybe_start_bot_turn() -> void:
	if _is_network_client():
		return
	if not _match_active or _is_bot_thinking or current_state == TurnState.GAME_OVER:
		return
	if _is_current_player_bot_owner() and _is_current_player_bankrupt():
		current_state = TurnState.MANAGEMENT
		end_turn()
		return
	if not _is_current_player_bot():
		return
	_run_bot_turn(_bot_turn_token)

func _wait_bot_delay(expected_token: int) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(_get_bot_action_delay()).timeout
	return (
		is_inside_tree()
		and _match_active
		and expected_token == _bot_turn_token
		and current_state != TurnState.GAME_OVER
		and _is_current_player_bot()
	)

func _run_bot_turn(expected_token: int) -> void:
	if _is_bot_thinking:
		return
	_is_bot_thinking = true
	_bot_traded_this_turn = false
	_sync_hud()

	var actions_taken: int = 0
	while (
		_match_active
		and expected_token == _bot_turn_token
		and not _is_auction_active()
		and current_state != TurnState.GAME_OVER
		and _is_current_player_bot()
		and actions_taken < BOT_MAX_ACTIONS_PER_TURN
	):
		if not await _wait_bot_delay(expected_token):
			break

		var bot: Dictionary = players[current_player_index]
		var bot_id: int = int(bot["id"])
		var bot_name: String = str(bot["name"])
		actions_taken += 1

		if current_state == TurnState.WAITING_ROLL:
			if _can_use_jail_free_card() and bot_ai.should_use_jail_free_card(bot, _build_bot_board_state()):
				_log_both(bot_ai.get_flavor_message("JAIL_CARD", bot_name))
				use_jail_free_card()
				continue
			if _can_pay_bail():
				var bail_cost: int = int(board_config.get("bail_cost", 50))
				if bot_ai.should_pay_bail(bot, bail_cost, _build_bot_board_state()):
					_log_both(bot_ai.get_flavor_message("BAIL", bot_name))
					pay_bail()
					continue
			await roll_dice()
			if _is_current_player_bankrupt():
				break
			continue

		if current_state == TurnState.EVALUATING:
			var pos: int = int(bot["position"])
			var tile: Dictionary = tiles[pos] if pos >= 0 and pos < tiles.size() else {}
			if _can_buy_current_tile() and bot_ai.should_buy_property(bot, tile, pos, _build_bot_board_state()):
				_log_both(bot_ai.get_flavor_message("BUY", bot_name))
				buy_current_property()
			else:
				_log_both(bot_ai.get_flavor_message("DECLINE", bot_name))
				decline_buy_property()
			continue

		if current_state == TurnState.MANAGEMENT:
			if int(bot["money"]) < 0:
				var liq: Dictionary = bot_ai.choose_liquidation_action(
					bot,
					_get_sellable_tiles_for(bot_id),
					_get_mortgageable_tiles_for(bot_id),
					tiles,
					property_buildings,
					property_owners
				)
				var liq_action: String = str(liq.get("action", "NONE"))
				var liq_tile: int = int(liq.get("tile_index", -1))
				if liq_action == "MORTGAGE" and liq_tile >= 0:
					_log_both(bot_ai.get_flavor_message("LIQUIDATE", bot_name))
					toggle_mortgage(liq_tile)
					continue
				if liq_action == "SELL_BUILDING" and liq_tile >= 0:
					_log_both(bot_ai.get_flavor_message("LIQUIDATE", bot_name))
					sell_building_on_property(liq_tile)
					continue

			if _can_roll_dice():
				await roll_dice()
				if expected_token != _bot_turn_token or _is_current_player_bankrupt():
					break
				continue

			if int(bot["money"]) >= 0:
				var interest_rate: float = float(board_config.get("unmortgage_interest_rate", 0.1))
				var unmortgage_tile: int = bot_ai.choose_tile_to_unmortgage(
					bot,
					_get_unmortgageable_tiles_for(bot_id),
					tiles,
					interest_rate,
					property_owners
				)
				if unmortgage_tile >= 0:
					_log_both(bot_ai.get_flavor_message("UNMORTGAGE", bot_name))
					toggle_mortgage(unmortgage_tile)
					continue

				# Negociação estratégica dinâmica entre bots (máximo 1 negócio por turno)
				if not _bot_traded_this_turn and _can_open_trade():
					var proposal: Dictionary = bot_ai.choose_bot_trade_proposal(
						bot,
						players,
						_build_bot_board_state(),
						current_round,
						is_market_push_round()
					)
					if not proposal.is_empty():
						_bot_traded_this_turn = true
						var t_id: int = int(proposal.get("target_id", -1))
						var off_t: int = int(proposal.get("offer_tile", -1))
						var req_t: int = int(proposal.get("request_tile", -1))
						var c_delta: int = int(proposal.get("cash_delta", 0))
						execute_trade(t_id, off_t, req_t, c_delta)
						continue

				var build_tile: int = bot_ai.choose_building_to_buy(
					bot,
					_get_buildable_tiles_for(bot_id),
					tiles,
					property_buildings,
					current_round,
					is_market_push_round()
				)
				if build_tile >= 0:
					_log_both(bot_ai.get_flavor_message("BUILD", bot_name))
					build_on_property(build_tile)
					continue

			if bot_ai.should_end_turn(_can_end_turn(), false):
				_log_both(bot_ai.get_flavor_message("END_TURN", bot_name))
				end_turn()
			break

		break

	if _match_active and expected_token == _bot_turn_token and current_state != TurnState.GAME_OVER and _is_current_player_bot_owner():
		if _is_auction_active():
			_is_bot_thinking = false
			_sync_hud()
		elif _is_current_player_bankrupt():
			_is_animating = false
			current_state = TurnState.MANAGEMENT
			end_turn()
		elif _can_end_turn():
			end_turn()
		else:
			_is_bot_thinking = false
			_sync_hud()
	elif expected_token == _bot_turn_token:
		_is_bot_thinking = false
		_sync_hud()

func _finish_post_move_step(player: Dictionary) -> void:
	if current_state == TurnState.GAME_OVER:
		return
	if bool(player.get("bankrupt", false)) or int(player.get("money", 0)) < 0:
		_has_extra_roll = false
		doubles_count = 0
		current_state = TurnState.MANAGEMENT
		return
	if _has_extra_roll and not bool(player.get("in_jail", false)):
		_log_both("Tirou dupla! Pode rolar os dados de novo.")
		current_state = TurnState.WAITING_ROLL
	else:
		current_state = TurnState.MANAGEMENT

func decline_buy_property() -> void:
	if not _match_active or _is_animating or current_state != TurnState.EVALUATING:
		return
	var player: Dictionary = players[current_player_index]
	var pos: int = int(player["position"])
	if pos >= 0 and pos < tiles.size():
		_last_tile_summary = "%s recusou a compra de %s." % [str(player["name"]), str(tiles[pos]["name"])]
	else:
		_last_tile_summary = "%s recusou a compra." % str(player["name"])
	_log_both(_last_tile_summary)
	_finish_post_move_step(player)
	_sync_hud()
	if hud != null:
		hud.flash_action_feedback("warning")

func build_on_property(tile_idx: int) -> void:
	var player: Dictionary = players[current_player_index]
	var pid: int = int(player["id"])
	if not _can_build_on(pid, tile_idx):
		return

	var tile: Dictionary = tiles[tile_idx]
	var cost: int = _get_effective_house_cost(tile)
	var current_lvl: int = property_buildings.get(tile_idx, 0)

	_adjust_player_money(player, -cost)
	if current_lvl == 4:
		bank_houses_left += 4
		bank_hotels_left -= 1
		property_buildings[tile_idx] = 5
		_log_both("Bah, estância de luxo! %s construiu um HOTEL em %s (%d Pilas)." % [str(player["name"]), str(tile["name"]), cost])
	else:
		bank_houses_left -= 1
		property_buildings[tile_idx] = current_lvl + 1
		_log_both("%s construiu casa (%d/4) em %s por %d Pilas." % [str(player["name"]), current_lvl + 1, str(tile["name"]), cost])

	if board_view != null:
		board_view.update_buildings(property_buildings)
		_broadcast_tile_pulse(tile_idx, Color("#FFD166"), "HOTEL!" if current_lvl == 4 else "+1 CASA")
	_play_sfx("build")
	_sync_hud()
	if hud != null:
		hud.flash_action_feedback("positive")
	var b_title: String = "Hotel Construído!" if current_lvl == 4 else "Casa Construída!"
	_broadcast_toast_event(b_title, "%s ampliou %s (P$ %d)." % [str(player["name"]), str(tile["name"]), cost], "build")

func sell_building_on_property(tile_idx: int) -> void:
	var player: Dictionary = players[current_player_index]
	var pid: int = int(player["id"])
	if not _can_sell_building_on(pid, tile_idx):
		return

	var tile: Dictionary = tiles[tile_idx]
	var half_cost: int = _get_building_sell_value(tile)
	var current_lvl: int = property_buildings.get(tile_idx, 0)

	if current_lvl >= 5:
		var houses_to_place: int = mini(4, bank_houses_left)
		var levels_liquidated: int = 5 - houses_to_place
		var refund: int = half_cost * levels_liquidated
		bank_hotels_left += 1
		bank_houses_left -= houses_to_place
		property_buildings[tile_idx] = houses_to_place
		_adjust_player_money(player, refund)
		if houses_to_place == 4:
			_log_both("%s vendeu o HOTEL de %s por %d Pilas (voltou para 4 casas)." % [str(player["name"]), str(tile["name"]), refund])
		else:
			_log_both("Banco sem 4 casas em estoque! %s demoliu o HOTEL de %s para %d casa(s) e recebeu %d Pilas." % [str(player["name"]), str(tile["name"]), houses_to_place, refund])
	else:
		var next_lvl: int = current_lvl - 1
		bank_houses_left += 1
		property_buildings[tile_idx] = next_lvl
		_adjust_player_money(player, half_cost)
		_log_both("%s vendeu 1 casa em %s por %d Pilas (%d/4 restante)." % [str(player["name"]), str(tile["name"]), half_cost, next_lvl])

	if int(player["money"]) >= 0:
		_last_creditor_id = -1

	if board_view != null:
		board_view.update_buildings(property_buildings)
	_play_sfx("mortgage")
	_check_post_liquidation_bankruptcy(player)
	if current_state != TurnState.GAME_OVER:
		_sync_hud()
	if hud != null:
		hud.flash_action_feedback("warning")

func apply_construction_cart(raw_target_levels: Dictionary) -> bool:
	if not _match_active or _is_animating or _is_auction_active() or current_state == TurnState.GAME_OVER or current_state == TurnState.MOVING:
		return false
	if players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return false
	var player: Dictionary = players[current_player_index]
	var pid: int = int(player["id"])
	if bool(player.get("bankrupt", false)):
		return false

	var target_levels: Dictionary[int, int] = {}
	for k: Variant in raw_target_levels.keys():
		var tid: int = int(k)
		if tid < 0 or tid >= tiles.size():
			return false
		target_levels[tid] = clampi(int(raw_target_levels[k]), 0, 5)

	if target_levels.is_empty():
		return false

	# Agrupar por grupo de cor e validar monopólio, hipotecas, equilíbrio e estoque do Banco
	var touched_groups: Dictionary[String, bool] = {}
	for tid: int in target_levels.keys():
		var tile: Dictionary = tiles[tid]
		if str(tile.get("type", "")) != "PROPERTY":
			return false
		if not _is_owned_by_player_or_team(tid, pid):
			return false
		var g_name: String = str(tile.get("group", ""))
		if not _has_monopoly(pid, g_name):
			return false
		touched_groups[g_name] = true

	var net_cost: int = 0
	var houses_delta: int = 0
	var hotels_delta: int = 0
	var changes_count: int = 0

	for g_name: String in touched_groups.keys():
		var g_indices: Array[int] = _get_group_tile_indices(g_name)
		var any_mort: bool = false
		for g_idx: int in g_indices:
			if mortgaged_tiles.get(g_idx, false):
				any_mort = true
				break

		var min_lvl: int = 99
		var max_lvl: int = -1
		for g_idx: int in g_indices:
			var old_lvl: int = clampi(property_buildings.get(g_idx, 0), 0, 5)
			var new_lvl: int = target_levels.get(g_idx, old_lvl)
			if any_mort and new_lvl > old_lvl:
				_log_both("Carrinho recusado: desipoteque todo o grupo %s antes de construir." % g_name)
				return false
			min_lvl = mini(min_lvl, new_lvl)
			max_lvl = maxi(max_lvl, new_lvl)
			if new_lvl != old_lvl:
				changes_count += 1
				var tile: Dictionary = tiles[g_idx]
				var h_cost: int = _get_effective_house_cost(tile)
				var sell_unit: int = _get_building_sell_value(tile)
				if new_lvl > old_lvl:
					net_cost += (new_lvl - old_lvl) * h_cost
				else:
					net_cost -= (old_lvl - new_lvl) * sell_unit

				var old_h: int = old_lvl if old_lvl <= 4 else 0
				var old_ht: int = 1 if old_lvl >= 5 else 0
				var new_h: int = new_lvl if new_lvl <= 4 else 0
				var new_ht: int = 1 if new_lvl >= 5 else 0
				houses_delta += (new_h - old_h)
				hotels_delta += (new_ht - old_ht)

		if max_lvl - min_lvl > 1:
			_log_both("Carrinho recusado: mantenha o equilíbrio entre os terrenos do grupo %s." % g_name)
			return false

	if changes_count == 0:
		return false
	if bank_houses_left - houses_delta < 0 or bank_hotels_left - hotels_delta < 0:
		_log_both("Carrinho recusado: estoque insuficiente de casas/hotéis no Banco (32C / 12H).")
		return false
	if int(player["money"]) - net_cost < 0:
		_log_both("Carrinho recusado: saldo insuficiente para confirmar as obras.")
		return false

	# Aplicar todas as alterações em lote de forma atômica
	bank_houses_left -= houses_delta
	bank_hotels_left -= hotels_delta
	_adjust_player_money(player, -net_cost)
	if int(player["money"]) >= 0:
		_last_creditor_id = -1

	for tid: int in target_levels.keys():
		var new_lvl: int = target_levels[tid]
		if new_lvl <= 0:
			property_buildings.erase(tid)
		else:
			property_buildings[tid] = new_lvl
		if board_view != null:
			_broadcast_tile_pulse(tid, Color("#FFD166") if new_lvl >= 5 else Color("#52B788"), "HOTEL!" if new_lvl >= 5 else "OBRAS!")

	if board_view != null:
		board_view.update_buildings(property_buildings)
	_play_sfx("build" if net_cost >= 0 else "mortgage")
	var verb_txt: String = "investiu %d Pilas" % net_cost if net_cost >= 0 else "recebeu %d Pilas em demolições" % absi(net_cost)
	_log_both("%s confirmou carrinho de obras (%d lotes atualizados, %s)." % [str(player["name"]), changes_count, verb_txt])
	_check_post_liquidation_bankruptcy(player)
	if current_state != TurnState.GAME_OVER:
		_sync_hud()
	if hud != null:
		hud.flash_action_feedback("positive" if net_cost >= 0 else "warning")
	_broadcast_toast_event("Obras Confirmadas!", "%s atualizou %d lote(s) (%s)." % [str(player["name"]), changes_count, verb_txt], "build")
	return true

func toggle_mortgage(tile_idx: int) -> void:
	var player: Dictionary = players[current_player_index]
	var pid: int = int(player["id"])
	if not _can_toggle_mortgage(pid, tile_idx):
		return

	var tile: Dictionary = tiles[tile_idx]
	var m_val: int = _get_mortgage_value(tile)

	var was_mortgaged: bool = mortgaged_tiles.get(tile_idx, false)
	if was_mortgaged:
		var redeem_cost: int = _get_redeem_cost(tile)
		_adjust_player_money(player, -redeem_cost)
		mortgaged_tiles[tile_idx] = false
		_last_tile_summary = "%s desipotecou %s por %d Pilas." % [str(player["name"]), str(tile["name"]), redeem_cost]
		_log_both(_last_tile_summary)
	else:
		_adjust_player_money(player, m_val)
		mortgaged_tiles[tile_idx] = true
		_last_tile_summary = "%s hipotecou %s e levantou %d Pilas." % [str(player["name"]), str(tile["name"]), m_val]
		_log_both(_last_tile_summary)

	if int(player["money"]) >= 0:
		_last_creditor_id = -1

	if board_view != null:
		board_view.update_ownership(property_owners, mortgaged_tiles)
	_play_sfx("build" if was_mortgaged else "mortgage")
	_check_post_liquidation_bankruptcy(player)
	if current_state != TurnState.GAME_OVER:
		_sync_hud()
	if hud != null:
		hud.flash_action_feedback("positive" if was_mortgaged else "warning")

func _check_post_liquidation_bankruptcy(player: Dictionary) -> void:
	if int(player.get("money", 0)) >= 0 or bool(player.get("bankrupt", false)):
		return
	var pid: int = int(player.get("id", -1))
	if _has_liquidatable_assets(pid):
		return
	_check_bankruptcy(player, false)
	if bool(player.get("bankrupt", false)) and current_state != TurnState.GAME_OVER:
		if not players.is_empty() and current_player_index >= 0 and current_player_index < players.size():
			if int(players[current_player_index].get("id", -1)) == pid:
				_advance_turn_after_bankruptcy(pid)

func pay_bail() -> void:
	if not _can_pay_bail():
		return
	var player: Dictionary = players[current_player_index]
	var bail: int = int(board_config.get("bail_cost", 50))
	_adjust_player_money(player, -bail)
	player["in_jail"] = false
	player["jail_turns"] = 0
	var rolled_this_turn: bool = (current_state == TurnState.MANAGEMENT)
	_last_tile_summary = "%s pagou %d Pilas de fiança e saiu do Xadrez!" % [str(player["name"]), bail]
	if rolled_this_turn:
		_last_tile_summary = "%s pagou %d Pilas de fiança e estará livre na próxima rodada." % [str(player["name"]), bail]
	_log_both(_last_tile_summary)
	_sync_hud()
	if hud != null:
		hud.flash_action_feedback("positive")

func use_jail_free_card() -> void:
	if not _can_use_jail_free_card():
		return
	var player: Dictionary = players[current_player_index]
	player["jail_free_cards"] = maxi(0, int(player.get("jail_free_cards", 0)) - 1)
	player["in_jail"] = false
	player["jail_turns"] = 0
	if not _held_jail_cards.is_empty():
		var returned_card: Dictionary = _held_jail_cards.pop_front()
		chance_cards.append(returned_card)
	_last_tile_summary = "%s usou a carta 'Sair Livre do Xadrez' e está solto para rolar!" % str(player["name"])
	_log_both(_last_tile_summary)
	_sync_hud()
	if hud != null:
		hud.flash_action_feedback("positive")

func roll_dice() -> void:
	if not _can_roll_dice() or _is_animating:
		return

	var session_token: int = _match_session_token
	var d1: int = randi_range(1, 6)
	var d2: int = randi_range(1, 6)
	var total: int = d1 + d2
	var is_double: bool = (d1 == d2)
	var player: Dictionary = players[current_player_index]

	_is_animating = true
	current_state = TurnState.MOVING
	_last_dice_sum = total
	_has_extra_roll = false
	_last_tile_summary = "%s arremessou os dados..." % str(player["name"])
	_play_sfx("roll")
	_sync_hud()

	if _is_network_host():
		network.broadcast_match_event(_active_net_session_id, "DICE_ANIM", { "d1": d1, "d2": d2 })

	if board_view != null:
		var dice_ok: bool = await board_view.play_dice_roll(d1, d2)
		if not dice_ok or session_token != _match_session_token or not _match_active:
			if session_token == _match_session_token:
				_is_animating = false
			return

	_log_both("%s rolou [%d] e [%d] (Soma: %d)." % [str(player["name"]), d1, d2, total])

	if bool(player.get("in_jail", false)):
		if is_double:
			player["in_jail"] = false
			player["jail_turns"] = 0
			doubles_count = 0
			_log_both("Mandou bem, tchê! Tirou dupla e escapou do Xadrez!")
			await move_player(player, total, true, total)
			if session_token != _match_session_token or not _match_active:
				return
			if current_state != TurnState.EVALUATING and current_state != TurnState.GAME_OVER:
				current_state = TurnState.MANAGEMENT
		else:
			player["jail_turns"] = int(player.get("jail_turns", 0)) + 1
			if int(player["jail_turns"]) >= 3:
				var bail: int = int(board_config.get("bail_cost", 50))
				_adjust_player_money(player, -bail)
				player["in_jail"] = false
				player["jail_turns"] = 0
				_last_creditor_id = -1
				_log_both("3ª tentativa sem dupla! %s pagou %d Pilas de fiança e andou %d casas." % [str(player["name"]), bail, total])
				_check_bankruptcy(player, false)
				if current_state == TurnState.GAME_OVER:
					_is_animating = false
					return
				if bool(player.get("bankrupt", false)):
					_advance_turn_after_bankruptcy(int(player["id"]))
					return
				if not bool(player.get("bankrupt", false)):
					await move_player(player, total, true, total)
					if session_token != _match_session_token or not _match_active:
						return
					if bool(player.get("bankrupt", false)):
						if current_state != TurnState.GAME_OVER:
							_advance_turn_after_bankruptcy(int(player["id"]))
						return
					if current_state != TurnState.EVALUATING and current_state != TurnState.GAME_OVER:
						current_state = TurnState.MANAGEMENT
			else:
				_log_both("Nada de dupla (%d/3 no Xadrez). Continua preso." % int(player["jail_turns"]))
				_last_tile_summary = "%s continua no Xadrez (%d/3 tentativas)." % [str(player["name"]), int(player["jail_turns"])]
				current_state = TurnState.MANAGEMENT
		_is_animating = false
		_sync_hud()
		return

	if is_double:
		doubles_count += 1
		if doubles_count == 3:
			_log_both("Capaz! Três duplas seguidas! %s foi pro Xadrez!" % str(player["name"]))
			send_to_jail(player)
			_is_animating = false
			_sync_hud()
			return
		_has_extra_roll = true
	else:
		doubles_count = 0

	await move_player(player, total, true, total)
	if session_token != _match_session_token or not _match_active:
		return

	_is_animating = false
	if current_state == TurnState.GAME_OVER:
		return
	if bool(player.get("bankrupt", false)):
		_advance_turn_after_bankruptcy(int(player["id"]))
		return
	if current_state != TurnState.EVALUATING:
		_finish_post_move_step(player)

	_sync_hud()

func move_player(player: Dictionary, steps: int, allow_pass_go: bool = true, dice_sum: int = 0) -> void:
	if tiles.is_empty():
		return
	var session_token: int = _match_session_token
	current_state = TurnState.MOVING
	var old_pos: int = int(player["position"])
	var size: int = tiles.size()
	var new_pos: int = posmod(old_pos + steps, size)

	player["position"] = new_pos
	if _is_network_host():
		network.broadcast_match_event(_active_net_session_id, "PAWN_MOVE", {
			"player_id": int(player["id"]),
			"from_pos": old_pos,
			"steps": steps,
			"to_pos": new_pos
		})
	if board_view != null:
		var move_ok: bool = await board_view.animate_token_move(int(player["id"]), old_pos, steps, players)
		if not move_ok or session_token != _match_session_token or not _match_active:
			return

	if allow_pass_go and steps > 0 and (old_pos + steps) >= size:
		var bonus: int = _get_effective_pass_go_bonus()
		_adjust_player_money(player, bonus)
		if int(player["money"]) >= 0:
			_last_creditor_id = -1
		_log_both("Cruzou o Galpão Central! Ganhou %d Pilas." % bonus)
		if board_view != null:
			board_view.play_tile_pulse(0, Color("#52B788"), "+P$ %d" % bonus)
		if hud != null:
			hud.show_event_toast("Galpão Central!", "%s recebeu +%d Pilas pela volta." % [str(player["name"]), bonus], "positive")

	var landed_tile: Dictionary = tiles[new_pos]
	_log_both("%s parou em [%d] %s." % [str(player["name"]), new_pos, str(landed_tile["name"])])
	await evaluate_tile(player, landed_tile, new_pos, dice_sum)

func _calculate_rent(tile: Dictionary, pos: int, owner_id: int, dice_sum: int) -> int:
	if mortgaged_tiles.get(pos, false):
		return 0

	var season_id: String = get_current_season_id() if _seasons_enabled else ""
	if str(tile.get("type", "")) == "COMPANY":
		var mult: int = int(tile.get("multiplier", 40))
		var roll_ref: int = dice_sum if dice_sum > 0 else (_last_dice_sum if _last_dice_sum > 0 else randi_range(2, 12))
		var comp_rent: int = roll_ref * mult
		if season_id == "PRIMAVERA":
			comp_rent = roundi(float(comp_rent) * 1.20)
		return comp_rent

	var rent_list: Array = tile.get("rent", [])
	var max_rent_idx: int = maxi(0, rent_list.size() - 1)
	var b_lvl: int = clampi(property_buildings.get(pos, 0), 0, max_rent_idx)
	var rent_val: int = int(rent_list[b_lvl]) if rent_list.size() > 0 else 0

	var group_name: String = str(tile.get("group", ""))
	if b_lvl == 0:
		if _has_monopoly(owner_id, group_name):
			rent_val *= 2

	if season_id == "PRIMAVERA" and (group_name == "MARROM" or group_name == "AZUL_CLARO" or group_name == "ROSA"):
		rent_val = roundi(float(rent_val) * 1.20)
	elif season_id == "VERAO" and (group_name == "LARANJA" or group_name == "VERMELHO" or group_name == "AMARELO"):
		rent_val = roundi(float(rent_val) * 1.25)
	elif season_id == "INVERNO" and b_lvl == 0:
		rent_val = maxi(1, roundi(float(rent_val) * 0.90))

	return rent_val

func evaluate_tile(player: Dictionary, tile: Dictionary, pos: int, dice_sum: int = 0) -> void:
	var tile_type: String = str(tile.get("type", ""))
	match tile_type:
		"PROPERTY", "COMPANY":
			var price: int = int(tile.get("price", 0))
			if not property_owners.has(pos):
				if tile_type == "COMPANY":
					var mult: int = int(tile.get("multiplier", 40))
					_last_tile_summary = "Livre: %s | Preço: P$ %d | Aluguel: %dx soma dos dados" % [str(tile["name"]), price, mult]
				else:
					var rent_preview: int = _calculate_rent(tile, pos, -1, 7)
					_last_tile_summary = "Livre: %s | Preço: P$ %d | Aluguel base: P$ %d" % [str(tile["name"]), price, rent_preview]
				current_state = TurnState.EVALUATING
			else:
				var owner_id: int = property_owners[pos]
				var landing_pid: int = int(player["id"])
				if owner_id == landing_pid:
					_last_tile_summary = "Sua propriedade: %s" % str(tile["name"])
					current_state = TurnState.MANAGEMENT
				elif are_allied_players(owner_id, landing_pid):
					var ally_name: String = str(_get_player_by_id(owner_id).get("name", "Aliado"))
					var ally_team: String = str(player.get("team_name", "Equipe"))
					_last_tile_summary = "Estadia aliada (%s • %s): %s sem aluguel!" % [ally_team, ally_name, str(tile["name"])]
					_log_both(_last_tile_summary)
					current_state = TurnState.MANAGEMENT
				elif not has_rent_waiver_pact(owner_id, landing_pid).is_empty():
					var partner_pact: Dictionary = has_rent_waiver_pact(owner_id, landing_pid)
					var rounds_rem: int = int(partner_pact.get("rounds_left", 1))
					var partner_name: String = str(_get_player_by_id(owner_id).get("name", "Parceiro"))
					_last_tile_summary = "Parceria Campeira (%s • %d rod.): %s sem aluguel!" % [partner_name, rounds_rem, str(tile["name"])]
					_log_both("Contrato de Parceria ativo (%s x %s, %d rod. restante(s)): isenção de aluguel em %s!" % [str(player["name"]), partner_name, rounds_rem, str(tile["name"])])
					if hud != null:
						hud.show_event_toast("Parceria Campeira!", "Isenção temporária de aluguel em %s (%d rod.)." % [str(tile["name"]), rounds_rem], "turn")
					current_state = TurnState.MANAGEMENT
				else:
					var owner: Dictionary = _get_player_by_id(owner_id)
					var rent_amount: int = _calculate_rent(tile, pos, owner_id, dice_sum)
					if rent_amount <= 0:
						_last_tile_summary = "%s está hipotecada! Nenhum aluguel cobrado." % str(tile["name"])
						_log_both(_last_tile_summary)
					else:
						_adjust_player_money(player, -rent_amount)
						if not owner.is_empty():
							_adjust_player_money(owner, rent_amount)
						if int(player["money"]) < 0:
							_last_creditor_id = owner_id
						var owner_name: String = str(owner.get("name", "Banco"))
						_last_tile_summary = "Pagou %d Pilas de aluguel em %s para %s!" % [rent_amount, str(tile["name"]), owner_name]
						_log_both(_last_tile_summary)
						_play_sfx("pay")
						if board_view != null:
							board_view.play_tile_pulse(pos, Color("#FF6B6B"), "-P$ %d" % rent_amount)
						if hud != null:
							hud.show_event_toast("Aluguel Pago!", "%s pagou %d Pilas para %s." % [str(player["name"]), rent_amount, owner_name], "negative")
						_check_bankruptcy(player, false)
					if current_state != TurnState.GAME_OVER:
						current_state = TurnState.MANAGEMENT
		"TAX":
			var tax: int = _get_effective_tax_amount(tile)
			_adjust_player_money(player, -tax)
			if int(player["money"]) < 0:
				_last_creditor_id = -1
			_last_tile_summary = "%s: pagou %d Pilas." % [str(tile["name"]), tax]
			_log_both(_last_tile_summary)
			_play_sfx("pay")
			if board_view != null:
				board_view.play_tile_pulse(pos, Color("#FF6B6B"), "-P$ %d" % tax)
			if hud != null:
				hud.show_event_toast(str(tile["name"]), "%s pagou %d Pilas ao Banco." % [str(player["name"]), tax], "negative")
			_check_bankruptcy(player, false)
			if current_state != TurnState.GAME_OVER:
				current_state = TurnState.MANAGEMENT
		"GO_TO_JAIL":
			_last_tile_summary = "Deu ruim! Mandaram pro Xadrez!"
			send_to_jail(player)
		"FREE_PARKING":
			_trigger_20_setembro_event(player, pos)
		"CHANCE":
			await _draw_chance_card(player)
		_:
			_last_tile_summary = "Casa: %s" % str(tile["name"])
			current_state = TurnState.MANAGEMENT

func _trigger_20_setembro_event(player: Dictionary, pos: int) -> void:
	# Evento temático Feriadão de 20 de Setembro (Opção A - Festa Farroupilha equilibrada no Modo Clássico):
	# 1. Havendo lote livre e quórum (>=2 solventes), convoca Acampamento de Remates (Leilão Farroupilha) imediato.
	# 2. Caso contrário, promove o Rateio de Chimarrão no Galpão (+20 Pilas por adversário solvente, soma zero).
	var p_name: String = str(player.get("name", "Estanceiro"))
	_play_sfx("festival")
	if board_view != null:
		_broadcast_tile_pulse(pos, Color("#22C55E"), "20 DE SETEMBRO!")
	current_state = TurnState.MANAGEMENT

	var auc_tile: int = _pick_periodic_auction_tile()
	if auc_tile >= 0 and start_periodic_land_auction(auc_tile):
		var auc_name: String = str(tiles[auc_tile].get("name", "Terreno"))
		_last_tile_summary = "20 de Setembro! %s convocou Leilão Farroupilha por %s!" % [p_name, auc_name]
		_log_both("Festa de 20 de Setembro! %s abriu o Acampamento de Remates para leiloar %s!" % [p_name, auc_name])
		_broadcast_toast_event("Feriadão de 20 de Setembro!", "%s convocou Leilão Farroupilha por %s!" % [p_name, auc_name], "chance")
		return

	var payer_contrib: int = 20
	var active_pid: int = int(player.get("id", -1))
	var collected_total: int = 0
	var contributors_count: int = 0
	for other: Dictionary in players:
		var other_id: int = int(other.get("id", -1))
		if are_allied_players(other_id, active_pid) or bool(other.get("bankrupt", false)):
			continue
		if int(other.get("money", 0)) >= payer_contrib:
			_adjust_player_money(other, -payer_contrib)
			_adjust_player_money(player, payer_contrib)
			collected_total += payer_contrib
			contributors_count += 1

	if collected_total > 0:
		if int(player.get("money", 0)) >= 0:
			_last_creditor_id = -1
		_last_tile_summary = "20 de Setembro! Rateio de Chimarrão rendeu +%d Pilas para %s!" % [collected_total, p_name]
		_log_both("Festa de 20 de Setembro! Rateio de Chimarrão no Galpão: %d estanceiro(s) contribuíram com %d Pilas cada (+%d Pilas para %s)." % [contributors_count, payer_contrib, collected_total, p_name])
		_broadcast_toast_event("Feriadão de 20 de Setembro!", "Rateio de Chimarrão no Galpão: %s recebeu +%d Pilas!" % [p_name, collected_total], "chance")
	else:
		var bank_gift: int = 50
		_adjust_player_money(player, bank_gift)
		if int(player.get("money", 0)) >= 0:
			_last_creditor_id = -1
		_last_tile_summary = "20 de Setembro! %s recebeu pró-labore farroupilha de +%d Pilas!" % [p_name, bank_gift]
		_log_both("Festa de 20 de Setembro! Sem lotes para leilão nem rateio — %s recebeu +%d Pilas da Semana Farroupilha." % [p_name, bank_gift])
		_broadcast_toast_event("Feriadão de 20 de Setembro!", "Semana Farroupilha: %s ganhou +%d Pilas." % [p_name, bank_gift], "chance")

func _resolve_seasonal_card_amount(card: Dictionary) -> Dictionary:
	var match_s: String = str(card.get("season_match", ""))
	var is_match: bool = _seasons_enabled and match_s != "" and get_current_season_id() == match_s
	var base_amt: int = int(card.get("amount", 0))
	var eff_amt: int = int(card.get("season_amount", base_amt)) if is_match else base_amt
	return { "amount": eff_amt, "matched": is_match, "season": match_s }

func _describe_chance_card_effect(card: Dictionary) -> Dictionary:
	var ctype: String = str(card.get("type", ""))
	match ctype:
		"GAIN_MONEY":
			return { "badge": "+ RECEITA • +P$ %d" % int(card.get("amount", 0)), "tone": "positive" }
		"SEASONAL_GAIN":
			var s_info: Dictionary = _resolve_seasonal_card_amount(card)
			var s_amt: int = int(s_info.get("amount", 0))
			if bool(s_info.get("matched", false)):
				return { "badge": "+ SAFRA SAZONAL ATIVA • +P$ %d" % s_amt, "tone": "positive" }
			return { "badge": "+ SAZONAL • +P$ %d" % s_amt, "tone": "positive" }
		"COLLECT_FROM_ALL":
			return { "badge": "+ RECEITA • +P$ %d DE CADA JOGADOR" % int(card.get("amount", 0)), "tone": "positive" }
		"PAY_MONEY":
			return { "badge": "- DESPESA • -P$ %d" % int(card.get("amount", 0)), "tone": "negative" }
		"SEASONAL_PAY":
			var p_info: Dictionary = _resolve_seasonal_card_amount(card)
			var p_amt: int = int(p_info.get("amount", 0))
			if bool(p_info.get("matched", false)):
				return { "badge": "- CLIMA SAZONAL ATIVO • -P$ %d" % p_amt, "tone": "negative" }
			return { "badge": "- SAZONAL • -P$ %d" % p_amt, "tone": "negative" }
		"REPAIR_BUILDINGS":
			return { "badge": "- MANUTENÇÃO • P$ %d/CASA • P$ %d/HOTEL" % [int(card.get("house_cost", 25)), int(card.get("hotel_cost", 100))], "tone": "negative" }
		"MOVE_TO_START":
			return { "badge": "➜ MOVIMENTO • GALPÃO CENTRAL (+P$ %d)" % _get_effective_pass_go_bonus(), "tone": "move" }
		"MOVE_STEPS":
			var st: int = int(card.get("steps", 1))
			var dir_txt: String = "AVANCE %d CASA(S)" % st if st > 0 else "RECUE %d CASA(S)" % absi(st)
			return { "badge": "➜ MOVIMENTO • %s" % dir_txt, "tone": "move" }
		"GO_TO_JAIL":
			return { "badge": "⚖ XADREZ • VÁ DIRETO PARA A CELA", "tone": "jail" }
		"GET_OUT_OF_JAIL_FREE":
			return { "badge": "★ CARTA ESPECIAL • SAIR LIVRE DO XADREZ", "tone": "special" }
		_:
			return { "badge": "SORTE OU AZAR", "tone": "chance" }

func _draw_chance_card(player: Dictionary) -> void:
	if chance_cards.is_empty():
		_last_tile_summary = "Sorte ou Azar, Tchê! (Sem cartas no monte)"
		current_state = TurnState.MANAGEMENT
		return

	var session_token: int = _match_session_token
	var card: Dictionary = chance_cards.pop_front()
	var card_type: String = str(card.get("type", ""))
	if card_type != "GET_OUT_OF_JAIL_FREE":
		chance_cards.append(card)

	var card_text: String = str(card.get("text", "Carta misteriosa"))
	_last_tile_summary = card_text
	_sync_hud()
	if board_view != null:
		_broadcast_tile_pulse(int(player["position"]), Color("#F5CA5C"), "")
		var card_ok: bool = await board_view.play_chance_card_animation(card_text, 0.18)
		if not card_ok or session_token != _match_session_token or not _match_active:
			return

	var effect_info: Dictionary = _describe_chance_card_effect(card)
	var eff_tone: String = str(effect_info.get("tone", "chance"))
	_play_sfx("chance_bad" if (eff_tone == "negative" or eff_tone == "jail") else "chance_good")
	if _is_network_host():
		network.broadcast_match_event(_active_net_session_id, "CHANCE_CARD", {
			"player_name": str(player.get("name", "Estanceiro")),
			"is_bot": bool(player.get("is_bot", false)),
			"owner_peer_id": int(player.get("peer_id", 1)),
			"card_text": card_text,
			"effect_badge": str(effect_info.get("badge", "")),
			"effect_tone": str(effect_info.get("tone", "chance"))
		})

	if hud != null:
		var chance_prefs: Dictionary = _resolve_chance_card_prefs(player)
		var is_remote_owner: bool = _is_online_match() and not bool(player.get("is_bot", false)) and int(player.get("peer_id", 1)) != network.get_local_peer_id()
		var manual_for_host: bool = bool(chance_prefs.get("manual_close", false)) and not is_remote_owner
		var dur_for_host: float = float(chance_prefs.get("duration_sec", 4.5))
		if is_remote_owner:
			dur_for_host = minf(dur_for_host, 3.2)
		hud.show_chance_card_modal({
			"player_name": str(player.get("name", "Estanceiro")),
			"is_bot": bool(player.get("is_bot", false)),
			"card_text": card_text,
			"effect_badge": str(effect_info.get("badge", "")),
			"effect_tone": str(effect_info.get("tone", "chance")),
			"manual_close": manual_for_host,
			"duration_sec": dur_for_host
		})
		await hud.chance_card_dismissed
		if session_token != _match_session_token or not _match_active:
			return

	_log_both("CARTA: %s" % card_text)

	match card_type:
		"GAIN_MONEY":
			var amt: int = int(card.get("amount", 0))
			_adjust_player_money(player, amt)
			if int(player["money"]) >= 0:
				_last_creditor_id = -1
			current_state = TurnState.MANAGEMENT
		"SEASONAL_GAIN":
			var sg_info: Dictionary = _resolve_seasonal_card_amount(card)
			var sg_amt: int = int(sg_info.get("amount", 0))
			_adjust_player_money(player, sg_amt)
			if int(player["money"]) >= 0:
				_last_creditor_id = -1
			if bool(sg_info.get("matched", false)):
				_log_both("Bônus de Estação (%s)! %s recebeu %d Pilas." % [str(get_current_season_info().get("label", "")), str(player["name"]), sg_amt])
			current_state = TurnState.MANAGEMENT
		"PAY_MONEY":
			var amt: int = int(card.get("amount", 0))
			_adjust_player_money(player, -amt)
			if int(player["money"]) < 0:
				_last_creditor_id = -1
			_check_bankruptcy(player, false)
			if current_state != TurnState.GAME_OVER and not bool(player.get("bankrupt", false)):
				current_state = TurnState.MANAGEMENT
		"SEASONAL_PAY":
			var sp_info: Dictionary = _resolve_seasonal_card_amount(card)
			var sp_amt: int = int(sp_info.get("amount", 0))
			_adjust_player_money(player, -sp_amt)
			if int(player["money"]) < 0:
				_last_creditor_id = -1
			if bool(sp_info.get("matched", false)):
				_log_both("Agravante de Estação (%s)! %s arcou com %d Pilas." % [str(get_current_season_info().get("label", "")), str(player["name"]), sp_amt])
			_check_bankruptcy(player, false)
			if current_state != TurnState.GAME_OVER and not bool(player.get("bankrupt", false)):
				current_state = TurnState.MANAGEMENT
		"MOVE_TO_START":
			var bonus: int = _get_effective_pass_go_bonus()
			player["position"] = 0
			_adjust_player_money(player, bonus)
			if int(player["money"]) >= 0:
				_last_creditor_id = -1
			if board_view != null:
				board_view.update_token_positions(players)
			_log_both("%s recebeu %d Pilas no Galpão Central!" % [str(player["name"]), bonus])
			current_state = TurnState.MANAGEMENT
		"GO_TO_JAIL":
			send_to_jail(player)
		"MOVE_STEPS":
			var steps: int = int(card.get("steps", 1))
			await move_player(player, steps, steps > 0, _last_dice_sum)
			if session_token != _match_session_token or not _match_active:
				return
			if current_state != TurnState.EVALUATING and current_state != TurnState.GAME_OVER:
				current_state = TurnState.MANAGEMENT
		"GET_OUT_OF_JAIL_FREE":
			_held_jail_cards.append(card)
			player["jail_free_cards"] = int(player.get("jail_free_cards", 0)) + 1
			_log_both("%s guardou a carta 'Sair Livre do Xadrez' (total: %d)." % [str(player["name"]), int(player["jail_free_cards"])])
			current_state = TurnState.MANAGEMENT
		"REPAIR_BUILDINGS":
			var per_house: int = int(card.get("house_cost", 25))
			var per_hotel: int = int(card.get("hotel_cost", 100))
			var houses_count: int = 0
			var hotels_count: int = 0
			var owned_props: Array = player.get("properties", [])
			for p_idx: Variant in owned_props:
				var lvl: int = property_buildings.get(int(p_idx), 0)
				if lvl >= 5:
					hotels_count += 1
				elif lvl > 0:
					houses_count += lvl
			var repair_total: int = houses_count * per_house + hotels_count * per_hotel
			if repair_total > 0:
				_adjust_player_money(player, -repair_total)
				if int(player["money"]) < 0:
					_last_creditor_id = -1
				_log_both("Manutenção: %s pagou %d Pilas (%d casa(s), %d hotel(is))." % [str(player["name"]), repair_total, houses_count, hotels_count])
				_check_bankruptcy(player, false)
			else:
				_log_both("%s não possui construções e escapou do custo de manutenção!" % str(player["name"]))
			if current_state != TurnState.GAME_OVER and not bool(player.get("bankrupt", false)):
				current_state = TurnState.MANAGEMENT
		"COLLECT_FROM_ALL":
			var per_player: int = int(card.get("amount", 50))
			var collector_id: int = int(player["id"])
			var collected_total: int = 0
			for other: Dictionary in players:
				var other_id: int = int(other.get("id", -1))
				if are_allied_players(other_id, collector_id) or bool(other.get("bankrupt", false)):
					continue
				_adjust_player_money(other, -per_player)
				_adjust_player_money(player, per_player)
				collected_total += per_player
				if int(other["money"]) < 0:
					_check_bankruptcy(other, false, collector_id)
					if current_state == TurnState.GAME_OVER:
						break
			if int(player["money"]) >= 0:
				_last_creditor_id = -1
			_log_both("%s arrecadou %d Pilas no total dos demais estanceiros!" % [str(player["name"]), collected_total])
			if current_state != TurnState.GAME_OVER and not bool(player.get("bankrupt", false)):
				current_state = TurnState.MANAGEMENT
		"PAY_ALL":
			var per_player: int = int(card.get("amount", 50))
			var payer_id: int = int(player["id"])
			var paid_total: int = 0
			for other: Dictionary in players:
				var other_id: int = int(other.get("id", -1))
				if are_allied_players(other_id, payer_id) or bool(other.get("bankrupt", false)):
					continue
				_adjust_player_money(other, per_player)
				paid_total += per_player
			_adjust_player_money(player, -paid_total)
			if int(player["money"]) < 0:
				_last_creditor_id = -1
			_log_both("%s pagou %d Pilas no total (%d Pilas para cada estanceiro ativo)." % [str(player["name"]), paid_total, per_player])
			_check_bankruptcy(player, false)
			if current_state != TurnState.GAME_OVER and not bool(player.get("bankrupt", false)):
				current_state = TurnState.MANAGEMENT
		_:
			current_state = TurnState.MANAGEMENT

func _check_bankruptcy(player: Dictionary, force_bankrupt: bool = false, creditor_override: int = -2) -> void:
	var target_pid: int = int(player["id"])
	var is_active_turn_player: bool = (not players.is_empty() and int(players[current_player_index]["id"]) == target_pid)

	if not force_bankrupt and int(player["money"]) >= 0:
		if is_active_turn_player:
			_last_creditor_id = -1
		return

	# Regra Clássica + Liquidação Inteligente:
	# Se houver patrimônio liquidável que cubra a dívida, exige liquidação antes de falir.
	# Se o máximo liquidável não compensar a dívida (saldo + máximo < 0), decreta falência automática imediata!
	if not force_bankrupt and _has_liquidatable_assets(target_pid):
		var max_liq: int = _get_max_liquidatable_cash(target_pid)
		if (int(player["money"]) + max_liq) >= 0:
			if is_active_turn_player:
				_has_extra_roll = false
				doubles_count = 0
			_log_both("Atenção! %s está no vermelho (%d Pilas): liquide até %d Pilas em obras/hipotecas antes de falir." % [str(player["name"]), int(player["money"]), max_liq])
			return
		_log_both("Dívida de %s (%d Pilas) supera o patrimônio liquidável máximo (%d Pilas): falência automática decretada!" % [str(player["name"]), int(player["money"]), max_liq])

	player["bankrupt"] = true
	if is_active_turn_player:
		_has_extra_roll = false
		doubles_count = 0
		if current_state != TurnState.GAME_OVER:
			current_state = TurnState.MANAGEMENT
	_log_both("Quebrou a banca! %s faliu e saiu da rodada." % str(player["name"]))

	var effective_creditor_id: int = _last_creditor_id if creditor_override == -2 else creditor_override
	var creditor: Dictionary = {}
	if effective_creditor_id >= 0 and effective_creditor_id != target_pid:
		var candidate: Dictionary = _get_player_by_id(effective_creditor_id)
		if not candidate.is_empty() and not bool(candidate.get("bankrupt", false)):
			creditor = candidate

	var props_to_process: Array[int] = _get_actor_or_team_properties(target_pid) if is_team_mode() else []
	if not is_team_mode():
		for p_v: Variant in player.get("properties", []):
			props_to_process.append(int(p_v))
	if is_team_mode():
		var loser_tid: int = get_player_team_id(target_pid)
		for member: Dictionary in players:
			if int(member.get("team_id", -1)) == loser_tid:
				member["bankrupt"] = true
				(member["properties"] as Array).clear()
	var transferred_count: int = 0
	for tid: int in props_to_process:
		var lvl: int = property_buildings.get(tid, 0)
		if lvl >= 5:
			bank_hotels_left += 1
		elif lvl > 0:
			bank_houses_left += lvl
		property_buildings.erase(tid)

		if not creditor.is_empty():
			property_owners[tid] = int(creditor["id"])
			var creditor_props: Array = creditor["properties"]
			if not (tid in creditor_props):
				creditor_props.append(tid)
			transferred_count += 1
		else:
			property_owners.erase(tid)
			mortgaged_tiles.erase(tid)

	if not is_team_mode():
		(player["properties"] as Array).clear()

	var held_cards: int = int(player.get("jail_free_cards", 0))
	if held_cards > 0:
		player["jail_free_cards"] = 0
		if not creditor.is_empty():
			creditor["jail_free_cards"] = int(creditor.get("jail_free_cards", 0)) + held_cards
		else:
			for _c: int in range(held_cards):
				if not _held_jail_cards.is_empty():
					var ret_card: Dictionary = _held_jail_cards.pop_front()
					chance_cards.append(ret_card)

	if is_active_turn_player:
		_last_creditor_id = -1

	if not creditor.is_empty():
		if transferred_count > 0:
			_log_both("Credor %s recebeu %d escritura(s) de %s (hipotecas preservadas, construções devolvidas ao banco)." % [str(creditor["name"]), transferred_count, str(player["name"])])
	else:
		_log_both("As propriedades de %s foram devolvidas livres ao Banco." % str(player["name"]))

	_sync_board_visuals()

	var active_count: int = 0
	var winner_player: Dictionary = {}
	for p: Dictionary in players:
		if not bool(p.get("bankrupt", false)):
			active_count += 1
			winner_player = p

	var sides_left: int = _count_active_teams() if is_team_mode() else active_count
	if sides_left > 1:
		_play_sfx("bankrupt")
	if sides_left <= 1:
		_trigger_victory(winner_player)

func _trigger_victory(winner_player: Dictionary, custom_summary: String = "", victory_reason: String = "") -> void:
	current_state = TurnState.GAME_OVER
	_play_sfx("victory")
	_match_session_token += 1
	_bot_turn_token += 1
	_is_bot_thinking = false
	_is_animating = false
	if board_view != null:
		board_view.cancel_animations()
	var w_id: int = int(winner_player.get("id", 0)) if not winner_player.is_empty() else 0
	var w_team_name: String = str(winner_player.get("team_name", "")) if (not winner_player.is_empty() and is_team_mode()) else ""
	var w_team_hex: String = str(winner_player.get("team_color_hex", "")) if (not winner_player.is_empty() and is_team_mode()) else ""
	var last_winner: String = ("Equipe %s" % w_team_name) if w_team_name != "" else (str(winner_player.get("name", "Campeão")) if not winner_player.is_empty() else "-")
	if custom_summary != "":
		_last_tile_summary = custom_summary
	else:
		_last_tile_summary = "Vitória de %s! Dominou os pampas!" % last_winner
	_log_both(_last_tile_summary)
	_sync_active_player_highlight()
	_sync_hud()
	if not winner_player.is_empty():
		var w_prop_ids: Array[int] = _get_actor_or_team_properties(w_id)
		var w_houses: int = 0
		var w_hotels: int = 0
		for tid_int: int in w_prop_ids:
			var b_lvl: int = property_buildings.get(tid_int, 0)
			if b_lvl >= 5:
				w_hotels += 1
			elif b_lvl > 0:
				w_houses += b_lvl
		var team_member_names: Array[String] = []
		if w_team_name != "":
			for tm: Dictionary in players:
				if are_allied_players(int(tm.get("id", -1)), w_id):
					var m_lbl: String = "%s [BOT]" % str(tm.get("name", "")) if bool(tm.get("is_bot", false)) else str(tm.get("name", ""))
					team_member_names.append(m_lbl)
		var w_color: Color = Color(w_team_hex) if w_team_hex != "" else (board_view.get_player_color(w_id) if board_view != null else Color("#E9C46A"))
		var victory_info: Dictionary = {
			"name": str(winner_player.get("name", "Campeão")),
			"is_bot": bool(winner_player.get("is_bot", false)),
			"pawn_id": str(winner_player.get("pawn_id", "cuia")),
			"pawn_name": str(winner_player.get("pawn_name", "Cuia de Chimarrão")),
			"pawn_code": str(winner_player.get("pawn_code", "")),
			"team_id": get_player_team_id(w_id),
			"team_name": w_team_name,
			"team_color_hex": w_team_hex,
			"team_members": ", ".join(team_member_names),
			"color": w_color,
			"color_hex": "#" + w_color.to_html(false),
			"money": int(winner_player.get("money", 0)),
			"net_worth": _compute_player_net_worth(winner_player),
			"monopolies_count": _count_player_monopolies(w_id),
			"victory_reason": victory_reason,
			"properties_count": w_prop_ids.size(),
			"houses_count": w_houses,
			"hotels_count": w_hotels,
			"rounds_played": current_round,
			"total_players": players.size()
		}
		_last_victory_info = victory_info.duplicate(true)
		if hud != null:
			hud.show_victory_modal(victory_info)
		match_finished.emit(victory_info.duplicate(true))
		_broadcast_state_if_host()

func _count_player_monopolies(player_id: int) -> int:
	var groups_seen: Dictionary[String, bool] = {}
	for tile: Dictionary in tiles:
		var g_name: String = str(tile.get("group", ""))
		if g_name == "" or str(tile.get("type", "")) != "PROPERTY":
			continue
		if not groups_seen.has(g_name):
			groups_seen[g_name] = _has_monopoly(player_id, g_name)
	var count: int = 0
	for ok: bool in groups_seen.values():
		if ok:
			count += 1
	return count

func _compute_player_net_worth(player: Dictionary) -> int:
	var worth: int = int(player.get("money", 0))
	var pid: int = int(player.get("id", -1))
	for tid: int in _get_actor_or_team_properties(pid):
		if tid < 0 or tid >= tiles.size():
			continue
		var tile: Dictionary = tiles[tid]
		var price: int = int(tile.get("price", 0))
		worth += _get_mortgage_value(tile) if mortgaged_tiles.get(tid, false) else price
		var b_lvl: int = clampi(property_buildings.get(tid, 0), 0, 5)
		if b_lvl > 0:
			worth += b_lvl * int(tile.get("house_cost", 50))
	return worth

func _check_dynamic_victory_conditions() -> bool:
	if _game_rules_mode != "dynamic" or not _match_active or current_state == TurnState.GAME_OVER:
		return false

	for p: Dictionary in players:
		if bool(p.get("bankrupt", false)):
			continue
		var pid: int = int(p.get("id", -1))
		var actor_label: String = ("Equipe %s" % str(p.get("team_name", ""))) if is_team_mode() else str(p.get("name", "Campeão"))
		var mono_count: int = _count_player_monopolies(pid)
		if mono_count >= DYNAMIC_MONOPOLY_GOAL:
			var m_summary: String = "%s atingiu %d monopólios e venceu na Estância Dinâmica!" % [actor_label, mono_count]
			_trigger_victory(p, m_summary, "3 Monopólios")
			return true
		var net_worth: int = _compute_player_net_worth(p)
		if _net_worth_goal > 0 and net_worth >= _net_worth_goal:
			var n_summary: String = "%s alcançou %d Pilas de patrimônio e dominou a Estância Dinâmica!" % [actor_label, net_worth]
			_trigger_victory(p, n_summary, "Meta de Patrimônio")
			return true

	if _round_limit > 0 and current_round > _round_limit:
		var best_p: Dictionary = {}
		var best_worth: int = -999999999
		var best_cash: int = -999999999
		for p: Dictionary in players:
			if bool(p.get("bankrupt", false)):
				continue
			var w: int = _compute_player_net_worth(p)
			var c: int = int(p.get("money", 0))
			if best_p.is_empty() or w > best_worth or (w == best_worth and c > best_cash):
				best_p = p
				best_worth = w
				best_cash = c
		if not best_p.is_empty():
			var b_label: String = ("Equipe %s" % str(best_p.get("team_name", ""))) if is_team_mode() else str(best_p.get("name", "Campeão"))
			var r_summary: String = "Fim das %d rodadas! %s venceu por patrimônio (%d Pilas)!" % [_round_limit, b_label, best_worth]
			_trigger_victory(best_p, r_summary, "Maior Patrimônio (30 Rodadas)")
			return true

	return false

func buy_current_property() -> void:
	if not _can_buy_current_tile():
		return
	var player: Dictionary = players[current_player_index]
	var pos: int = int(player["position"])
	var tile: Dictionary = tiles[pos]
	var price: int = int(tile.get("price", 0))

	_adjust_player_money(player, -price)
	property_owners[pos] = int(player["id"])
	var owned_props: Array = player["properties"]
	owned_props.append(pos)
	_selected_property_tile = pos
	_last_tile_summary = "%s comprou %s por %d Pilas!" % [str(player["name"]), str(tile["name"]), price]
	_log_both(_last_tile_summary)
	_play_sfx("buy")
	property_purchased.emit(int(player["id"]), pos, price)
	if board_view != null:
		board_view.update_ownership(property_owners, mortgaged_tiles)
		_broadcast_tile_pulse(pos, board_view.get_player_color(int(player["id"])), "COMPRADO! -P$ %d" % price)
	_finish_post_move_step(player)
	_sync_hud()
	if hud != null:
		hud.flash_action_feedback("positive")
	_broadcast_toast_event("Nova Escritura!", "%s adquiriu %s por P$ %d." % [str(player["name"]), str(tile["name"]), price], "positive")

func send_to_jail(player: Dictionary) -> void:
	var jail_idx: int = int(board_config.get("jail_tile_index", 10))
	player["position"] = jail_idx
	player["in_jail"] = true
	player["jail_turns"] = 0
	doubles_count = 0
	_has_extra_roll = false
	if board_view != null:
		board_view.update_token_positions(players)
		_broadcast_tile_pulse(jail_idx, Color("#FF595E"), "PRO XADREZ!")
	_broadcast_toast_event("Pro Xadrez!", "%s foi direto para o Xadrez." % str(player["name"]), "negative")
	current_state = TurnState.MANAGEMENT

func _advance_turn_after_bankruptcy(finished_player_id: int) -> void:
	if not _match_active or current_state == TurnState.GAME_OVER or players.is_empty():
		return
	doubles_count = 0
	_has_extra_roll = false
	_last_creditor_id = -1
	_selected_property_tile = -1
	_bot_turn_token += 1
	_is_bot_thinking = false
	_is_animating = false
	_bot_traded_this_turn = false
	_player_auctioned_this_turn = false
	if not _pending_trade_offer.is_empty():
		_pending_trade_offer.clear()
		if hud != null:
			hud.hide_trade_confirm_modal()
		if _is_network_host():
			network.broadcast_match_event(_active_net_session_id, "TRADE_OFFER_CLOSED", {})

	_advance_round_if_complete(finished_player_id)
	if _check_dynamic_victory_conditions():
		return

	var total_p: int = players.size()
	for _step: int in range(total_p):
		current_player_index = (current_player_index + 1) % total_p
		var candidate: Dictionary = players[current_player_index]
		if not bool(candidate.get("bankrupt", false)):
			break

	var next_p: Dictionary = players[current_player_index]
	if int(next_p.get("money", 0)) < 0 and not bool(next_p.get("bankrupt", false)):
		if not _has_liquidatable_assets(int(next_p["id"])):
			_check_bankruptcy(next_p, true)
			if current_state == TurnState.GAME_OVER:
				return
			_advance_turn_after_bankruptcy(int(next_p["id"]))
			return
		current_state = TurnState.MANAGEMENT
		_last_tile_summary = "%s precisa quitar dívida antes de prosseguir!" % str(next_p["name"])
	else:
		current_state = TurnState.WAITING_ROLL
		_last_tile_summary = "Aguardando %s rolar os dados..." % str(next_p["name"])

	_log_both("Vez de %s, tchê!" % str(next_p["name"]))
	_sync_active_player_highlight()
	_sync_hud()
	if hud != null:
		hud.flash_action_feedback("turn")
	if _pending_periodic_auction:
		_pending_periodic_auction = false
		if start_periodic_land_auction():
			return
	call_deferred("_maybe_start_bot_turn")

func end_turn() -> void:
	if not _can_end_turn():
		var blocked_p: Dictionary = players[current_player_index] if not players.is_empty() else {}
		if not blocked_p.is_empty() and int(blocked_p.get("money", 0)) < 0 and _has_liquidatable_assets(int(blocked_p["id"])):
			_log_both("Liquide seus bens! Venda construções ou hipoteque escrituras antes de encerrar o turno.")
			_sync_hud()
		return

	var current_player: Dictionary = players[current_player_index]
	if current_state == TurnState.EVALUATING:
		var pos: int = int(current_player["position"])
		if pos >= 0 and pos < tiles.size():
			_log_both("%s passou sem comprar %s." % [str(current_player["name"]), str(tiles[pos]["name"])])

	if int(current_player["money"]) < 0 and not bool(current_player.get("bankrupt", false)):
		if _has_liquidatable_assets(int(current_player["id"])):
			_log_both("Liquide seus bens antes de declarar falência!")
			_sync_hud()
			return
		_check_bankruptcy(current_player, true)
		if current_state == TurnState.GAME_OVER:
			_bot_turn_token += 1
			_is_bot_thinking = false
			_sync_hud()
			return

	_advance_turn_after_bankruptcy(int(current_player["id"]))

func _validate_trade_proposal(
	sender_id: int,
	target_id: int,
	offer_tile: int,
	request_tile: int,
	cash_delta: int
) -> Dictionary:
	if not _match_active or _is_animating or _is_auction_active() or current_state == TurnState.GAME_OVER or current_state == TurnState.MOVING:
		return { "ok": false, "reason": "Negociação indisponível neste momento." }
	if offer_tile < 0 and request_tile < 0:
		return { "ok": false, "reason": "Troca negada: selecione pelo menos uma escritura (transferência só em dinheiro é bloqueada)." }
	if request_tile >= 0 and offer_tile < 0 and cash_delta <= 0:
		return { "ok": false, "reason": "Troca negada: ofereça uma escritura ou dinheiro pelo lote pedido." }
	if offer_tile >= 0 and request_tile < 0 and cash_delta >= 0:
		return { "ok": false, "reason": "Troca negada: peça uma escritura ou pagamento em dinheiro pelo lote ofertado." }

	var sender: Dictionary = _get_player_by_id(sender_id)
	var target: Dictionary = _get_player_by_id(target_id)
	if sender.is_empty() or target.is_empty() or sender_id == target_id:
		return { "ok": false, "reason": "Troca negada: participante inválido." }
	if are_allied_players(sender_id, target_id):
		return { "ok": false, "reason": "Troca negada: aliados de equipe já compartilham caixa e escrituras." }
	if bool(sender.get("bankrupt", false)) or bool(target.get("bankrupt", false)):
		return { "ok": false, "reason": "Troca negada: participante falido." }

	if offer_tile >= 0:
		if offer_tile >= tiles.size() or not _is_owned_by_player_or_team(offer_tile, sender_id):
			return { "ok": false, "reason": "Troca negada: você não é dono dessa escritura." }
		if _group_has_buildings(offer_tile):
			return { "ok": false, "reason": "Troca negada: remova as construções do grupo antes de trocar." }

	if request_tile >= 0:
		if request_tile >= tiles.size() or not _is_owned_by_player_or_team(request_tile, target_id):
			return { "ok": false, "reason": "Troca negada: o outro jogador não possui essa escritura." }
		if _group_has_buildings(request_tile):
			return { "ok": false, "reason": "Troca negada: propriedade em grupo com construção não pode ser trocada." }

	if cash_delta > 0 and int(sender["money"]) < cash_delta:
		return { "ok": false, "reason": "Troca negada: saldo insuficiente para dar %d Pilas." % cash_delta }
	var abs_cash: int = absi(cash_delta)
	if cash_delta < 0 and int(target["money"]) < abs_cash:
		return { "ok": false, "reason": "Troca negada: %s não tem %d Pilas em caixa." % [str(target["name"]), abs_cash] }

	return { "ok": true, "reason": "" }

func execute_trade(target_id: int, offer_tile: int, request_tile: int, cash_delta: int, rent_waiver_rounds: int = 0) -> void:
	propose_trade(target_id, offer_tile, request_tile, cash_delta, rent_waiver_rounds)

func propose_trade(target_id: int, offer_tile: int, request_tile: int, cash_delta: int, rent_waiver_rounds: int = 0) -> void:
	if not _match_active or players.is_empty():
		return
	if not _pending_trade_offer.is_empty():
		_log_both("Já existe uma proposta de troca aguardando confirmação.")
		return
	var safe_waiver: int = clampi(rent_waiver_rounds, 0, DEFAULT_RENT_WAIVER_ROUNDS)
	var sender: Dictionary = players[current_player_index]
	var sender_id: int = int(sender["id"])
	var check: Dictionary = _validate_trade_proposal(sender_id, target_id, offer_tile, request_tile, cash_delta)
	if not bool(check.get("ok", false)):
		_log_both(str(check.get("reason", "Troca inválida.")))
		return

	var target: Dictionary = _get_player_by_id(target_id)
	if bool(target.get("is_bot", false)):
		var accepted_by_bot: bool = bot_ai.evaluate_bot_trade_offer(
			target,
			sender,
			offer_tile,
			request_tile,
			cash_delta,
			_build_bot_board_state(),
			current_round,
			is_market_push_round(),
			safe_waiver
		)
		if accepted_by_bot:
			_commit_trade_agreement(sender_id, target_id, offer_tile, request_tile, cash_delta, safe_waiver)
		else:
			_log_both("%s [BOT] recusou a proposta de troca." % str(target["name"]))
			_broadcast_toast_event("Proposta Recusada", "%s [BOT] não aceitou os termos da negociação." % str(target["name"]), "warning")
		return

	var offer_id: int = _next_trade_offer_id
	_next_trade_offer_id += 1
	var offer_name: String = str(tiles[offer_tile]["name"]) if (offer_tile >= 0 and offer_tile < tiles.size()) else ""
	var req_name: String = str(tiles[request_tile]["name"]) if (request_tile >= 0 and request_tile < tiles.size()) else ""
	var abs_cash: int = absi(cash_delta)
	var sender_items: Array[String] = []
	var target_items: Array[String] = []
	if offer_name != "":
		sender_items.append(offer_name)
	if cash_delta > 0:
		sender_items.append("P$ %d" % cash_delta)
	if req_name != "":
		target_items.append(req_name)
	if cash_delta < 0:
		target_items.append("P$ %d" % abs_cash)

	_pending_trade_offer = {
		"offer_id": offer_id,
		"sender_id": sender_id,
		"target_id": target_id,
		"sender_name": str(sender["name"]),
		"target_name": str(target["name"]),
		"target_peer_id": int(target.get("peer_id", 1)),
		"offer_tile": offer_tile,
		"request_tile": request_tile,
		"cash_delta": cash_delta,
		"rent_waiver_rounds": safe_waiver,
		"gives_text": " + ".join(sender_items) if not sender_items.is_empty() else "Nada",
		"receives_text": " + ".join(target_items) if not target_items.is_empty() else "Nada"
	}

	_log_both("%s enviou proposta de troca para %s (aguardando aceite)." % [str(sender["name"]), str(target["name"])])

	var target_peer: int = int(target.get("peer_id", 1))
	if _is_network_host() and target_peer > 1:
		network.send_match_event_to_peer(target_peer, _active_net_session_id, "TRADE_OFFER", _pending_trade_offer.duplicate(true))
		_broadcast_toast_event("Proposta Enviada!", "Aguardando %s aceitar ou recusar a troca." % str(target["name"]), "turn")
	elif hud != null:
		hud.hide_trade_modal()
		hud.show_trade_confirm_modal(_pending_trade_offer.duplicate(true))

func respond_to_trade_offer(offer_id: int, accepted: bool) -> void:
	if _pending_trade_offer.is_empty():
		return
	if int(_pending_trade_offer.get("offer_id", -1)) != offer_id:
		return

	var offer: Dictionary = _pending_trade_offer.duplicate(true)
	_pending_trade_offer.clear()
	if hud != null:
		hud.hide_trade_confirm_modal()
	if _is_network_host():
		network.broadcast_match_event(_active_net_session_id, "TRADE_OFFER_CLOSED", {})

	var sender_id: int = int(offer.get("sender_id", -1))
	var target_id: int = int(offer.get("target_id", -1))
	var target_name: String = str(offer.get("target_name", "Estanceiro"))

	if not accepted:
		_log_both("%s recusou a proposta de troca." % target_name)
		_broadcast_toast_event("Proposta Recusada", "%s recusou a negociação." % target_name, "warning")
		return

	var offer_tile: int = int(offer.get("offer_tile", -1))
	var req_tile: int = int(offer.get("request_tile", -1))
	var cash_delta: int = int(offer.get("cash_delta", 0))
	var offer_waiver: int = int(offer.get("rent_waiver_rounds", 0))
	var check: Dictionary = _validate_trade_proposal(sender_id, target_id, offer_tile, req_tile, cash_delta)
	if not bool(check.get("ok", false)):
		_log_both(str(check.get("reason", "Proposta expirou ou ficou inválida.")))
		return

	_commit_trade_agreement(sender_id, target_id, offer_tile, req_tile, cash_delta, offer_waiver)

func _commit_trade_agreement(
	sender_id: int,
	target_id: int,
	offer_tile: int,
	request_tile: int,
	cash_delta: int,
	rent_waiver_rounds: int = 0
) -> void:
	var sender: Dictionary = _get_player_by_id(sender_id)
	var target: Dictionary = _get_player_by_id(target_id)
	if sender.is_empty() or target.is_empty():
		return

	var abs_cash: int = absi(cash_delta)
	if cash_delta > 0:
		_adjust_player_money(sender, -cash_delta)
		_adjust_player_money(target, cash_delta)
	elif cash_delta < 0:
		_adjust_player_money(target, -abs_cash)
		_adjust_player_money(sender, abs_cash)

	if int(sender["money"]) >= 0 and not players.is_empty() and int(players[current_player_index]["id"]) == sender_id:
		_last_creditor_id = -1

	var sender_props: Array = sender["properties"]
	var target_props: Array = target["properties"]
	if offer_tile >= 0:
		var old_off_owner: Dictionary = _get_player_by_id(property_owners.get(offer_tile, sender_id))
		if not old_off_owner.is_empty():
			(old_off_owner["properties"] as Array).erase(offer_tile)
		sender_props.erase(offer_tile)
		target_props.append(offer_tile)
		property_owners[offer_tile] = target_id

	if request_tile >= 0:
		var old_req_owner: Dictionary = _get_player_by_id(property_owners.get(request_tile, target_id))
		if not old_req_owner.is_empty():
			(old_req_owner["properties"] as Array).erase(request_tile)
		target_props.erase(request_tile)
		sender_props.append(request_tile)
		property_owners[request_tile] = sender_id

	var sender_gives: Array[String] = []
	var target_gives: Array[String] = []
	if offer_tile >= 0:
		sender_gives.append(str(tiles[offer_tile]["name"]))
	if cash_delta > 0:
		sender_gives.append("P$ %d" % cash_delta)
	if request_tile >= 0:
		target_gives.append(str(tiles[request_tile]["name"]))
	if cash_delta < 0:
		target_gives.append("P$ %d" % abs_cash)

	var sender_label: String = "%s [BOT]" % str(sender["name"]) if bool(sender.get("is_bot", false)) else str(sender["name"])
	var target_label: String = "%s [BOT]" % str(target["name"]) if bool(target.get("is_bot", false)) else str(target["name"])
	var s_part: String = " + ".join(sender_gives) if not sender_gives.is_empty() else "acordo"
	var t_part: String = " + ".join(target_gives) if not target_gives.is_empty() else "acordo"

	var completed_mono: bool = false
	if request_tile >= 0:
		var req_g: String = str(tiles[request_tile].get("group", ""))
		if req_g != "" and _has_monopoly(sender_id, req_g):
			completed_mono = true
	if offer_tile >= 0:
		var off_g: String = str(tiles[offer_tile].get("group", ""))
		if off_g != "" and _has_monopoly(target_id, off_g):
			completed_mono = true

	if board_view != null:
		board_view.update_ownership(property_owners, mortgaged_tiles)
		if offer_tile >= 0:
			_broadcast_tile_pulse(offer_tile, board_view.get_player_color(target_id), "TROCA!")
		if request_tile >= 0:
			_broadcast_tile_pulse(request_tile, board_view.get_player_color(sender_id), "MONOPÓLIO!" if completed_mono else "TROCA!")

	var safe_waiver: int = clampi(rent_waiver_rounds, 0, DEFAULT_RENT_WAIVER_ROUNDS)
	if safe_waiver > 0:
		_register_rent_waiver_pact(sender_id, target_id, safe_waiver)

	var mono_suffix: String = " ★ Monopólio completo!" if completed_mono else ""
	var pact_suffix: String = " 🤝 Parceria sem aluguel (%d rod.)!" % safe_waiver if safe_waiver > 0 else ""
	var trade_msg: String = "Negócio fechado: %s entregou %s para %s por %s.%s%s" % [sender_label, s_part, target_label, t_part, mono_suffix, pact_suffix]
	_log_both(trade_msg)
	_last_tile_summary = trade_msg
	_sync_hud()
	if hud != null:
		hud.flash_action_feedback("positive")
	_broadcast_toast_event("Negócio Fechado!", "%s ⇄ %s (%s ↔ %s)" % [sender_label, target_label, s_part, t_part], "positive")

# --- Sistema de Leilão Periódico de Terrenos (a cada 3 ou 4 rodadas) ---

func _pick_periodic_auction_tile() -> int:
	var candidates: Array[int] = []
	for i: int in range(tiles.size()):
		var t: Dictionary = tiles[i]
		var t_type: String = str(t.get("type", ""))
		if (t_type == "PROPERTY" or t_type == "COMPANY") and not property_owners.has(i):
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[randi_range(0, candidates.size() - 1)]

func _can_auction_owned_tile(player_id: int, tile_idx: int) -> bool:
	if not _match_active or _is_animating or _is_auction_active() or _player_auctioned_this_turn or current_state == TurnState.GAME_OVER or current_state == TurnState.MOVING:
		return false
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	if not _is_owned_by_player_or_team(tile_idx, player_id):
		return false
	var t_type: String = str(tiles[tile_idx].get("type", ""))
	if t_type != "PROPERTY" and t_type != "COMPANY":
		return false
	if mortgaged_tiles.get(tile_idx, false) or _group_has_buildings(tile_idx):
		return false
	return _count_active_players() >= 2

func start_owned_property_auction(tile_idx: int) -> bool:
	if not _match_active or _is_network_client() or _is_auction_active() or players.is_empty():
		return false
	if current_player_index < 0 or current_player_index >= players.size():
		return false
	var seller: Dictionary = players[current_player_index]
	var seller_id: int = int(seller.get("id", -1))
	if not _can_auction_owned_tile(seller_id, tile_idx):
		return false

	var tile: Dictionary = tiles[tile_idx]
	var t_type: String = str(tile.get("type", ""))
	var base_price: int = int(tile.get("price", 100))
	var min_bid: int = maxi(20, roundi((float(base_price) * 0.5) / 10.0) * 10)
	var eligible: Array[int] = []
	for p: Dictionary in players:
		var pid: int = int(p.get("id", -1))
		if not are_allied_players(pid, seller_id) and not bool(p.get("bankrupt", false)) and int(p.get("money", 0)) >= min_bid:
			eligible.append(pid)
	if eligible.is_empty():
		_log_both("Nenhum adversário possui saldo mínimo (%d Pilas) para abrir leilão de %s." % [min_bid, str(tile.get("name", "Lote"))])
		return false

	var color_hex: String = str(tile.get("color", "#2D5248"))
	if color_hex == "":
		color_hex = "#2D5248"

	_player_auctioned_this_turn = true
	_auction_bot_token += 1
	_auction_state = {
		"active": true,
		"tile_index": tile_idx,
		"tile_name": str(tile.get("name", "Terreno")),
		"tile_type": t_type,
		"group_name": str(tile.get("group", "")),
		"color_hex": color_hex,
		"tile_price": base_price,
		"min_bid": min_bid,
		"current_bid": 0,
		"highest_bidder_id": -1,
		"highest_bidder_name": "",
		"seller_id": seller_id,
		"seller_name": str(seller.get("name", "Estanceiro")),
		"eligible_ids": eligible,
		"passed_ids": [],
		"turn_bidder_index": 0
	}

	_log_both("=== LEILÃO PARTICULAR: %s ofertou %s (lance inicial %d Pilas)! ===" % [str(seller.get("name", "Estanceiro")), str(tile["name"]), min_bid])
	_broadcast_toast_event("Leilão de Terreno!", "%s colocou %s à venda a partir de P$ %d." % [str(seller.get("name", "Estanceiro")), str(tile["name"]), min_bid], "turn")
	if hud != null:
		hud.hide_deed_modal()
	_sync_auction_ui_and_network()
	_maybe_step_auction_bot()
	return true

func start_periodic_land_auction(forced_tile_idx: int = -1) -> bool:
	if not _match_active or _is_network_client() or _is_auction_active() or current_state == TurnState.GAME_OVER:
		return false
	var tile_idx: int = forced_tile_idx if forced_tile_idx >= 0 else _pick_periodic_auction_tile()
	if tile_idx < 0 or tile_idx >= tiles.size() or property_owners.has(tile_idx):
		return false
	var tile: Dictionary = tiles[tile_idx]
	var t_type: String = str(tile.get("type", ""))
	if t_type != "PROPERTY" and t_type != "COMPANY":
		return false

	var base_price: int = int(tile.get("price", 100))
	var min_bid: int = maxi(20, roundi((float(base_price) * 0.5) / 10.0) * 10)
	var eligible: Array[int] = []
	for p: Dictionary in players:
		if not bool(p.get("bankrupt", false)) and int(p.get("money", 0)) >= min_bid:
			eligible.append(int(p["id"]))
	if eligible.size() < 2:
		return false

	var color_hex: String = str(tile.get("color", "#2D5248"))
	if color_hex == "":
		color_hex = "#2D5248"

	_auction_bot_token += 1
	_auction_state = {
		"active": true,
		"tile_index": tile_idx,
		"tile_name": str(tile.get("name", "Terreno")),
		"tile_type": t_type,
		"group_name": str(tile.get("group", "")),
		"color_hex": color_hex,
		"tile_price": base_price,
		"min_bid": min_bid,
		"current_bid": 0,
		"highest_bidder_id": -1,
		"highest_bidder_name": "",
		"eligible_ids": eligible,
		"passed_ids": [],
		"turn_bidder_index": 0
	}

	_log_both("=== LEILÃO DA RODADA %d: %s (Preço base P$ %d • Lance inicial P$ %d)! ===" % [current_round, str(tile["name"]), base_price, min_bid])
	_broadcast_toast_event("Leilão Aberto!", "%s em disputa a partir de P$ %d!" % [str(tile["name"]), min_bid], "turn")
	_sync_auction_ui_and_network()
	_maybe_step_auction_bot()
	return true

func _get_auction_current_bidder_id() -> int:
	if not _is_auction_active():
		return -1
	var elig: Array = _auction_state.get("eligible_ids", [])
	if elig.is_empty():
		return -1
	var idx: int = clampi(int(_auction_state.get("turn_bidder_index", 0)), 0, elig.size() - 1)
	return int(elig[idx])

func _get_auction_min_next_bid() -> int:
	var cur: int = int(_auction_state.get("current_bid", 0))
	var min_open: int = int(_auction_state.get("min_bid", 20))
	return min_open if cur <= 0 else (cur + 10)

func submit_auction_bid(bidder_id: int, bid_amount: int) -> void:
	if not _is_auction_active():
		return
	var expected_id: int = _get_auction_current_bidder_id()
	if bidder_id != expected_id or bidder_id < 0:
		return
	var bidder: Dictionary = _get_player_by_id(bidder_id)
	if bidder.is_empty() or bool(bidder.get("bankrupt", false)):
		pass_auction_turn(bidder_id)
		return

	var min_next: int = _get_auction_min_next_bid()
	var bidder_money: int = int(bidder.get("money", 0))
	if bid_amount < min_next or bid_amount > bidder_money:
		_log_both("Lance inválido de %s (%d Pilas)." % [str(bidder["name"]), bid_amount])
		return

	_auction_state["current_bid"] = bid_amount
	_auction_state["highest_bidder_id"] = bidder_id
	_auction_state["highest_bidder_name"] = "%s [BOT]" % str(bidder["name"]) if bool(bidder.get("is_bot", false)) else str(bidder["name"])

	_log_both("Leilão: %s cobriu para %d Pilas!" % [str(_auction_state["highest_bidder_name"]), bid_amount])
	_play_sfx("auction_bid")
	_advance_auction_turn(bidder_id)

func pass_auction_turn(bidder_id: int) -> void:
	if not _is_auction_active():
		return
	var expected_id: int = _get_auction_current_bidder_id()
	if bidder_id != expected_id:
		return

	var bidder: Dictionary = _get_player_by_id(bidder_id)
	var b_name: String = str(bidder.get("name", "Estanceiro"))
	var elig: Array = _auction_state.get("eligible_ids", [])
	var passed: Array = _auction_state.get("passed_ids", [])
	if not (bidder_id in passed):
		passed.append(bidder_id)
	elig.erase(bidder_id)
	_auction_state["eligible_ids"] = elig
	_auction_state["passed_ids"] = passed

	_log_both("Leilão: %s desistiu da disputa." % b_name)
	_advance_auction_turn(-1)

func _advance_auction_turn(just_bidder_id: int) -> void:
	if not _is_auction_active():
		return
	var elig: Array = _auction_state.get("eligible_ids", [])
	var winner_id: int = int(_auction_state.get("highest_bidder_id", -1))
	var next_min: int = _get_auction_min_next_bid()

	# Remover automaticamente quem não possui saldo para o próximo lance (exceto quem já detém o maior lance)
	var filtered: Array[int] = []
	for pid_var: Variant in elig:
		var pid: int = int(pid_var)
		var p: Dictionary = _get_player_by_id(pid)
		if p.is_empty() or bool(p.get("bankrupt", false)):
			continue
		if pid == winner_id or int(p.get("money", 0)) >= next_min:
			filtered.append(pid)
	_auction_state["eligible_ids"] = filtered

	if filtered.is_empty() or (filtered.size() == 1 and winner_id >= 0 and int(filtered[0]) == winner_id):
		_finalize_auction()
		return

	var next_idx: int = 0
	if just_bidder_id >= 0:
		var pos_in_f: int = filtered.find(just_bidder_id)
		next_idx = (pos_in_f + 1) % filtered.size() if pos_in_f >= 0 else 0
	else:
		next_idx = clampi(int(_auction_state.get("turn_bidder_index", 0)), 0, filtered.size() - 1)
		if int(filtered[next_idx]) == winner_id and filtered.size() > 1:
			next_idx = (next_idx + 1) % filtered.size()

	_auction_state["turn_bidder_index"] = next_idx
	_sync_auction_ui_and_network()
	_maybe_step_auction_bot()

func _finalize_auction() -> void:
	if not _is_auction_active():
		return
	_auction_bot_token += 1
	var tile_idx: int = int(_auction_state.get("tile_index", -1))
	var tile_name: String = str(_auction_state.get("tile_name", "Terreno"))
	var winner_id: int = int(_auction_state.get("highest_bidder_id", -1))
	var winning_bid: int = int(_auction_state.get("current_bid", 0))
	var seller_id: int = int(_auction_state.get("seller_id", -1))
	_auction_state.clear()

	if winner_id >= 0 and winning_bid > 0 and tile_idx >= 0 and tile_idx < tiles.size():
		var winner: Dictionary = _get_player_by_id(winner_id)
		var is_valid_bank_sale: bool = (seller_id < 0 and not property_owners.has(tile_idx))
		var is_valid_player_sale: bool = (seller_id >= 0 and _is_owned_by_player_or_team(tile_idx, seller_id) and not are_allied_players(winner_id, seller_id))
		if (is_valid_bank_sale or is_valid_player_sale) and not winner.is_empty() and int(winner.get("money", 0)) >= winning_bid:
			_adjust_player_money(winner, -winning_bid)
			if seller_id >= 0:
				var seller: Dictionary = _get_player_by_id(property_owners.get(tile_idx, seller_id))
				if not seller.is_empty():
					_adjust_player_money(seller, winning_bid)
					(seller["properties"] as Array).erase(tile_idx)
					if int(seller["money"]) >= 0 and not players.is_empty() and are_allied_players(int(players[current_player_index].get("id", -1)), seller_id):
						_last_creditor_id = -1
			property_owners[tile_idx] = winner_id
			var w_props: Array = winner["properties"]
			if not (tile_idx in w_props):
				w_props.append(tile_idx)
			property_purchased.emit(winner_id, tile_idx, winning_bid)
			_play_sfx("auction_win")
			if seller_id >= 0:
				_log_both("Martelo batido! %s comprou %s de %s em leilão por %d Pilas!" % [str(winner["name"]), tile_name, str(_get_player_by_id(seller_id).get("name", "Vendedor")), winning_bid])
			else:
				_log_both("Martelo batido! %s arrematou %s no leilão por %d Pilas!" % [str(winner["name"]), tile_name, winning_bid])
			_broadcast_toast_event("Leilão Arrematado!", "%s levou %s por P$ %d." % [str(winner["name"]), tile_name, winning_bid], "positive")
			if board_view != null:
				board_view.update_ownership(property_owners, mortgaged_tiles)
				_broadcast_tile_pulse(tile_idx, board_view.get_player_color(winner_id), "LEILÃO P$%d" % winning_bid)
		else:
			_log_both("Leilão encerrado sem arremate válido para %s." % tile_name)
	else:
		if seller_id >= 0:
			_log_both("Leilão encerrado sem lances — %s continua com o dono atual." % tile_name)
		else:
			_log_both("Leilão encerrado sem lances — %s permanece livre no Banco." % tile_name)

	_sync_hud()
	if hud != null:
		hud.hide_auction_modal()
	call_deferred("_maybe_start_bot_turn")

func _maybe_step_auction_bot() -> void:
	if not _is_auction_active() or _is_network_client():
		return
	var bidder_id: int = _get_auction_current_bidder_id()
	if bidder_id < 0:
		return
	var bidder: Dictionary = _get_player_by_id(bidder_id)
	if bidder.is_empty() or not bool(bidder.get("is_bot", false)):
		return
	var my_token: int = _auction_bot_token
	_run_auction_bot_step(my_token, bidder_id)

func _run_auction_bot_step(expected_token: int, bidder_id: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(minf(0.45, _get_bot_action_delay())).timeout
	if not is_inside_tree() or not _match_active or expected_token != _auction_bot_token or not _is_auction_active():
		return
	if _get_auction_current_bidder_id() != bidder_id:
		return
	var bidder: Dictionary = _get_player_by_id(bidder_id)
	var tile_idx: int = int(_auction_state.get("tile_index", -1))
	if bidder.is_empty() or tile_idx < 0 or tile_idx >= tiles.size():
		pass_auction_turn(bidder_id)
		return
	var high_id: int = int(_auction_state.get("highest_bidder_id", -1))
	if high_id >= 0 and are_allied_players(bidder_id, high_id):
		pass_auction_turn(bidder_id)
		return
	var bid_val: int = bot_ai.choose_auction_bid(
		bidder,
		tiles[tile_idx],
		tile_idx,
		int(_auction_state.get("current_bid", 0)),
		_get_auction_min_next_bid(),
		_build_bot_board_state()
	)
	if bid_val >= _get_auction_min_next_bid() and bid_val <= int(bidder.get("money", 0)):
		submit_auction_bid(bidder_id, bid_val)
	else:
		pass_auction_turn(bidder_id)

func _sync_auction_ui_and_network() -> void:
	if hud != null:
		var local_pid: int = _get_local_player_id() if _is_online_match() else -1
		hud.refresh_auction_modal(_auction_state, local_pid, _is_online_match())
	_sync_hud()

# --- Camada de Multiplayer P2P (ENet • Host Autoritativo) ---

func _on_host_room_requested(port: int, player_name: String) -> void:
	if network == null:
		return
	var err: Error = network.host_room(port, player_name)
	if err == OK:
		_broadcast_current_lobby()

func _on_join_room_requested(address: String, port: int, player_name: String) -> void:
	if network == null:
		return
	var _err: Error = network.join_room(address, port, player_name)

func _on_host_web_room_requested(signaling_url: String, player_name: String, turn_cfg: Dictionary) -> void:
	if network == null:
		return
	var err: Error = network.host_web_room(signaling_url, player_name, turn_cfg)
	if err == OK:
		_broadcast_current_lobby()

func _on_join_web_room_requested(signaling_url: String, room_code: String, player_name: String, turn_cfg: Dictionary) -> void:
	if network == null:
		return
	var _err: Error = network.join_web_room(signaling_url, room_code, player_name, turn_cfg)

func _on_network_web_room_code_changed(room_code: String) -> void:
	if setup_screen != null:
		setup_screen.set_web_room_code(room_code)
	if _is_network_host() and not _match_active and room_code != "":
		_broadcast_current_lobby()

func _on_disconnect_network_requested() -> void:
	if network == null:
		return
	if network.is_host() and _match_active:
		network.broadcast_match_event(_active_net_session_id, "RETURN_TO_LOBBY", {
			"reason": "O Host encerrou a sala."
		})
	network.disconnect_network("Desconectado (Modo Local).")
	if _match_active:
		open_setup_screen()

func _on_lobby_config_changed() -> void:
	if _is_network_host() and not _match_active:
		if setup_screen != null and network != null:
			var snap: Dictionary = setup_screen.get_lobby_snapshot_for_network()
			var raw_slots: Variant = snap.get("slots", [])
			if raw_slots is Array and not (raw_slots as Array).is_empty() and (raw_slots as Array)[0] is Dictionary:
				var host_name: String = str(((raw_slots as Array)[0] as Dictionary).get("name", "")).strip_edges()
				if host_name != "":
					network.update_peer_display_name(1, host_name)
		_broadcast_current_lobby()

func _on_setup_lobby_pref_requested(pawn_idx: int, color_idx: int, player_name: String = "") -> void:
	if _is_network_client() and not _match_active and network != null:
		network.send_lobby_pref_to_host(pawn_idx, color_idx, player_name)

func _on_network_client_lobby_pref(sender_peer_id: int, pawn_idx: int, color_idx: int, player_name: String = "") -> void:
	if not _is_network_host() or _match_active or setup_screen == null:
		return
	var _applied: bool = setup_screen.apply_remote_peer_selection(sender_peer_id, pawn_idx, color_idx, player_name)
	var clean_name: String = player_name.strip_edges()
	if clean_name != "" and network != null:
		if clean_name.length() > 20:
			clean_name = clean_name.substr(0, 20)
		network.update_peer_display_name(sender_peer_id, clean_name)
	_broadcast_current_lobby()

func _broadcast_current_lobby() -> void:
	if not _is_network_host() or setup_screen == null:
		return
	var lobby_data: Dictionary = setup_screen.get_lobby_snapshot_for_network()
	network.broadcast_lobby_state(lobby_data)

func _on_network_status_changed(mode: int, status_text: String, connected_peers: Array[Dictionary]) -> void:
	if setup_screen != null:
		var t_mode: int = int(network.transport_mode) if network != null else 0
		setup_screen.set_network_status(mode, status_text, connected_peers, network.get_local_peer_id() if network != null else 1, t_mode)

func _on_network_lobby_synced(lobby_data: Dictionary) -> void:
	if setup_screen != null and _is_network_client():
		setup_screen.apply_remote_lobby_snapshot(lobby_data, network.get_local_peer_id())

func _on_network_peer_joined(_peer_id: int, _peer_name: String) -> void:
	if not _is_network_host():
		return
	if not _match_active:
		_broadcast_current_lobby()

func _on_network_peer_left(peer_id: int, peer_name: String) -> void:
	if not _is_network_host():
		return
	if not _match_active:
		_broadcast_current_lobby()
		return

	# Em partida ativa: converte o jogador desconectado em [BOT] para nunca travar a mesa
	var converted_active_turn: bool = false
	for i: int in range(players.size()):
		var p: Dictionary = players[i]
		if int(p.get("peer_id", 0)) == peer_id and not bool(p.get("bankrupt", false)):
			var hidden_arr: Array[String] = bot_ai.assign_hidden_profiles(1)
			var assigned_prof: String = hidden_arr[0] if not hidden_arr.is_empty() else BotAIClass.PROFILE_CONSERVADOR
			p["is_bot"] = true
			p["peer_id"] = 0
			p["bot_profile"] = assigned_prof
			_log_both("%s desconectou — assumido por [BOT] para a partida continuar." % str(p.get("name", peer_name)))
			_broadcast_toast_event("Jogador Desconectou", "%s foi assumido por [BOT]." % str(p.get("name", peer_name)), "turn")
			if i == current_player_index:
				converted_active_turn = true
			break
	_sync_hud()
	if converted_active_turn and current_state != TurnState.GAME_OVER:
		call_deferred("_maybe_start_bot_turn")

func _on_network_error(message: String) -> void:
	if setup_screen != null:
		setup_screen.show_network_error(message)

func _on_network_host_disconnected(reason: String) -> void:
	_active_net_session_id = 0
	if _match_active:
		open_setup_screen()
	if setup_screen != null:
		setup_screen.show_network_error(reason)

func _build_network_snapshot() -> Dictionary:
	# Serializa o estado autoritativo OMITINDO completamente bot_profile (sigilo absoluto em rede!)
	var clean_players: Array[Dictionary] = []
	for p: Dictionary in players:
		var props_copy: Array[int] = []
		var raw_props: Array = p.get("properties", [])
		for tid_var: Variant in raw_props:
			props_copy.append(int(tid_var))
		clean_players.append({
			"id": int(p.get("id", 0)),
			"peer_id": int(p.get("peer_id", 0)),
			"name": str(p.get("name", "Estanceiro")),
			"money": int(p.get("money", 0)),
			"position": int(p.get("position", 0)),
			"in_jail": bool(p.get("in_jail", false)),
			"jail_turns": int(p.get("jail_turns", 0)),
			"jail_free_cards": int(p.get("jail_free_cards", 0)),
			"properties": props_copy,
			"bankrupt": bool(p.get("bankrupt", false)),
			"is_bot": bool(p.get("is_bot", false)),
			"pawn_id": str(p.get("pawn_id", "cuia")),
			"pawn_name": str(p.get("pawn_name", "Cuia de Chimarrão")),
			"pawn_code": str(p.get("pawn_code", "CU")),
			"color_hex": str(p.get("color_hex", "")),
			"team_id": int(p.get("team_id", -1)),
			"team_name": str(p.get("team_name", "")),
			"team_color_hex": str(p.get("team_color_hex", ""))
		})

	var owners_out: Dictionary = {}
	for k: int in property_owners.keys():
		owners_out[k] = property_owners[k]
	var buildings_out: Dictionary = {}
	for k: int in property_buildings.keys():
		buildings_out[k] = property_buildings[k]
	var mortgaged_out: Dictionary = {}
	for k: int in mortgaged_tiles.keys():
		mortgaged_out[k] = mortgaged_tiles[k]

	var victory_out: Dictionary = {}
	if current_state == TurnState.GAME_OVER and not _last_victory_info.is_empty():
		victory_out = _last_victory_info.duplicate(true)
		victory_out.erase("color")

	var team_wallets_out: Dictionary = {}
	for tk: int in _team_wallets.keys():
		team_wallets_out[tk] = _team_wallets[tk]

	return {
		"session_id": _active_net_session_id,
		"team_mode": _team_mode,
		"team_wallets": team_wallets_out,
		"rent_waiver_pacts": _rent_waiver_pacts.duplicate(true),
		"players": clean_players,
		"property_owners": owners_out,
		"property_buildings": buildings_out,
		"mortgaged_tiles": mortgaged_out,
		"bank_houses_left": bank_houses_left,
		"bank_hotels_left": bank_hotels_left,
		"current_player_index": current_player_index,
		"current_state": int(current_state),
		"current_round": current_round,
		"game_rules_mode": _game_rules_mode,
		"seasons_enabled": _seasons_enabled,
		"current_season_index": _current_season_index,
		"round_limit": _round_limit,
		"net_worth_goal": _net_worth_goal,
		"has_extra_roll": _has_extra_roll,
		"last_dice_sum": _last_dice_sum,
		"last_tile_summary": _last_tile_summary,
		"is_animating": _is_animating,
		"is_market_push": is_market_push_round(),
		"auction_state": _auction_state.duplicate(true),
		"victory_info": victory_out
	}

func _broadcast_state_if_host() -> void:
	if not _is_network_host() or not _match_active or _applying_remote_state or _active_net_session_id <= 0:
		return
	network.broadcast_state_snapshot(_active_net_session_id, _build_network_snapshot())

func _apply_network_snapshot(snapshot: Dictionary, is_initial_start: bool) -> void:
	_applying_remote_state = true
	var raw_players: Variant = snapshot.get("players", [])
	players.clear()
	if raw_players is Array:
		for item: Variant in (raw_players as Array):
			if item is Dictionary:
				var pd: Dictionary = (item as Dictionary).duplicate(true)
				pd["bot_profile"] = ""
				players.append(pd)

	property_owners.clear()
	var raw_owners: Variant = snapshot.get("property_owners", {})
	if raw_owners is Dictionary:
		for k: Variant in (raw_owners as Dictionary).keys():
			property_owners[int(k)] = int((raw_owners as Dictionary)[k])

	property_buildings.clear()
	var raw_blds: Variant = snapshot.get("property_buildings", {})
	if raw_blds is Dictionary:
		for k: Variant in (raw_blds as Dictionary).keys():
			property_buildings[int(k)] = int((raw_blds as Dictionary)[k])

	mortgaged_tiles.clear()
	var raw_morts: Variant = snapshot.get("mortgaged_tiles", {})
	if raw_morts is Dictionary:
		for k: Variant in (raw_morts as Dictionary).keys():
			mortgaged_tiles[int(k)] = bool((raw_morts as Dictionary)[k])

	bank_houses_left = int(snapshot.get("bank_houses_left", 32))
	bank_hotels_left = int(snapshot.get("bank_hotels_left", 12))
	current_player_index = clampi(int(snapshot.get("current_player_index", 0)), 0, maxi(0, players.size() - 1))
	current_state = int(snapshot.get("current_state", int(TurnState.WAITING_ROLL))) as TurnState
	current_round = maxi(1, int(snapshot.get("current_round", 1)))
	_game_rules_mode = str(snapshot.get("game_rules_mode", "classic"))
	_seasons_enabled = bool(snapshot.get("seasons_enabled", false))
	_current_season_index = posmod(int(snapshot.get("current_season_index", 0)), SEASON_ORDER.size())
	_round_limit = int(snapshot.get("round_limit", 0))
	_net_worth_goal = int(snapshot.get("net_worth_goal", 0))
	_team_mode = str(snapshot.get("team_mode", "ffa"))
	_team_wallets.clear()
	var raw_tw: Variant = snapshot.get("team_wallets", {})
	if raw_tw is Dictionary:
		for tk: Variant in (raw_tw as Dictionary).keys():
			_team_wallets[int(tk)] = int((raw_tw as Dictionary)[tk])
	_rent_waiver_pacts.clear()
	var raw_pacts: Variant = snapshot.get("rent_waiver_pacts", [])
	if raw_pacts is Array:
		for p_item: Variant in (raw_pacts as Array):
			if p_item is Dictionary:
				_rent_waiver_pacts.append((p_item as Dictionary).duplicate(true))
	_has_extra_roll = bool(snapshot.get("has_extra_roll", false))
	_last_dice_sum = int(snapshot.get("last_dice_sum", 0))
	_last_tile_summary = str(snapshot.get("last_tile_summary", ""))
	_is_animating = bool(snapshot.get("is_animating", false))
	_is_bot_thinking = false
	_match_active = true
	var raw_auction: Variant = snapshot.get("auction_state", {})
	if raw_auction is Dictionary:
		_auction_state = (raw_auction as Dictionary).duplicate(true)
	else:
		_auction_state.clear()

	if board_view != null:
		if is_initial_start:
			board_view.cancel_animations()
			if hud != null:
				board_view.set_viewport_rect(hud.get_board_viewport_rect())
			board_view.setup_tokens(players)
		_sync_board_visuals()

	_sync_hud()
	if hud != null:
		if _is_auction_active():
			hud.refresh_auction_modal(_auction_state, _get_local_player_id(), _is_online_match())
		else:
			hud.hide_auction_modal()

	var raw_victory: Variant = snapshot.get("victory_info", {})
	if current_state == TurnState.GAME_OVER and raw_victory is Dictionary and not (raw_victory as Dictionary).is_empty() and hud != null:
		var v_info: Dictionary = (raw_victory as Dictionary).duplicate(true)
		var v_hex: String = str(v_info.get("color_hex", "#E9C46A"))
		v_info["color"] = Color(v_hex)
		hud.show_victory_modal(v_info)

	_applying_remote_state = false

func _on_network_remote_match_started(session_id: int, snapshot: Dictionary) -> void:
	if not _is_network_client():
		return
	_active_net_session_id = session_id
	_match_session_token += 1
	if setup_screen != null:
		setup_screen.close_screen()
	if hud != null:
		hud.clear_log()
		hud.hide_all_modals()
		hud.set_match_ui_visible(true)
	_apply_network_snapshot(snapshot, true)

func _on_network_remote_state_received(session_id: int, snapshot: Dictionary) -> void:
	if not _is_network_client() or session_id != _active_net_session_id or not _match_active:
		return
	_apply_network_snapshot(snapshot, false)

func _on_network_remote_event_received(session_id: int, event_type: String, payload: Dictionary) -> void:
	if not _is_network_client() or session_id != _active_net_session_id:
		return
	match event_type:
		"LOG":
			if hud != null:
				hud.push_log(str(payload.get("msg", "")))
		"TOAST":
			if hud != null:
				hud.show_event_toast(str(payload.get("title", "")), str(payload.get("detail", "")), str(payload.get("tone", "positive")))
		"DICE_ANIM":
			if board_view != null:
				board_view.play_dice_roll(int(payload.get("d1", 1)), int(payload.get("d2", 1)))
		"PAWN_MOVE":
			var move_pid: int = int(payload.get("player_id", -1))
			var from_pos: int = int(payload.get("from_pos", 0))
			var steps: int = int(payload.get("steps", 0))
			var to_pos: int = int(payload.get("to_pos", posmod(from_pos + steps, maxi(1, tiles.size()))))
			for p: Dictionary in players:
				if int(p.get("id", -1)) == move_pid:
					p["position"] = to_pos
					break
			if board_view != null and move_pid >= 0:
				board_view.animate_token_move(move_pid, from_pos, steps, players)
		"TILE_PULSE":
			if board_view != null:
				board_view.play_tile_pulse(int(payload.get("tile", 0)), Color(str(payload.get("color_hex", "#F5CA5C"))), str(payload.get("text", "")))
		"CHANCE_CARD":
			var c_text: String = str(payload.get("card_text", ""))
			if board_view != null:
				board_view.play_chance_card_animation(c_text, 0.18)
			if hud != null:
				var dur_key: String = str(_preferences.get("chance_auto_duration", "default"))
				var auto_sec: float = float(CHANCE_AUTO_DURATIONS.get(dur_key, 4.5))
				hud.show_chance_card_modal({
					"player_name": str(payload.get("player_name", "Estanceiro")),
					"is_bot": bool(payload.get("is_bot", false)),
					"card_text": c_text,
					"effect_badge": str(payload.get("effect_badge", "")),
					"effect_tone": str(payload.get("effect_tone", "chance")),
					"manual_close": false,
					"duration_sec": minf(auto_sec, 4.5)
				})
		"TRADE_OFFER":
			if hud != null:
				hud.hide_trade_modal()
				hud.show_trade_confirm_modal(payload.duplicate(true))
		"TRADE_OFFER_CLOSED":
			if hud != null:
				hud.hide_trade_confirm_modal()
		"RETURN_TO_LOBBY":
			_reset_match_state()
			if setup_screen != null:
				setup_screen.open_screen()
				var reason: String = str(payload.get("reason", "O Host retornou à sala."))
				setup_screen.show_network_error(reason)

func _on_network_client_action(sender_peer_id: int, session_id: int, action_name: String, params: Dictionary) -> void:
	# Autoridade estrita do Host: valida sessão, estado e dono legítimo do turno!
	if not _is_network_host() or not _match_active:
		return
	if session_id != _active_net_session_id:
		return

	if action_name == "RESIGN_TO_BOT" or action_name == "FORFEIT":
		for p: Dictionary in players:
			if not bool(p.get("is_bot", false)) and not bool(p.get("bankrupt", false)) and int(p.get("peer_id", 0)) == sender_peer_id:
				var target_pid: int = int(p.get("id", -1))
				if action_name == "RESIGN_TO_BOT":
					resign_to_bot(target_pid)
				else:
					forfeit_player(target_pid)
				break
		return

	if action_name == "TRADE_RESPOND":
		if _pending_trade_offer.is_empty():
			return
		if int(_pending_trade_offer.get("target_peer_id", -1)) != sender_peer_id:
			return
		respond_to_trade_offer(int(params.get("offer_id", -1)), bool(params.get("accept", false)))
		return

	if action_name == "AUCTION_BID" or action_name == "AUCTION_PASS":
		if not _is_auction_active():
			return
		var bidder_id: int = _get_auction_current_bidder_id()
		var bidder_p: Dictionary = _get_player_by_id(bidder_id)
		if bidder_p.is_empty() or bool(bidder_p.get("is_bot", false)) or int(bidder_p.get("peer_id", 1)) != sender_peer_id:
			return
		if action_name == "AUCTION_BID":
			submit_auction_bid(bidder_id, int(params.get("amount", 0)))
		else:
			pass_auction_turn(bidder_id)
		return

	if _is_animating or _is_bot_thinking or _is_auction_active() or current_state == TurnState.GAME_OVER or current_state == TurnState.MOVING:
		return
	if players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return
	var cur_p: Dictionary = players[current_player_index]
	if bool(cur_p.get("is_bot", false)) or bool(cur_p.get("bankrupt", false)):
		return
	if int(cur_p.get("peer_id", 1)) != sender_peer_id:
		return

	match action_name:
		"ROLL":
			roll_dice()
		"BUY":
			buy_current_property()
		"DECLINE":
			decline_buy_property()
		"BAIL":
			pay_bail()
		"JAIL_CARD":
			use_jail_free_card()
		"BUILD":
			build_on_property(int(params.get("tile_index", -1)))
		"SELL_BUILDING":
			sell_building_on_property(int(params.get("tile_index", -1)))
		"BUILD_CART":
			var raw_lvls: Variant = params.get("levels", {})
			if raw_lvls is Dictionary:
				apply_construction_cart(raw_lvls as Dictionary)
		"MORTGAGE":
			toggle_mortgage(int(params.get("tile_index", -1)))
		"AUCTION_OWNED":
			start_owned_property_auction(int(params.get("tile_index", -1)))
		"TRADE":
			propose_trade(
				int(params.get("target_id", -1)),
				int(params.get("offer_tile", -1)),
				int(params.get("request_tile", -1)),
				int(params.get("cash_delta", 0)),
				int(params.get("rent_waiver_rounds", 0))
			)
		"END_TURN":
			end_turn()
