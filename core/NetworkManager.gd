extends Node

enum NetMode { LOCAL, HOST, CLIENT }
enum TransportMode { NONE, ENET, WEBRTC }

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 5 # Host (peer 1) + até 5 clientes remotos = 6 jogadores máx.
const DEFAULT_SIGNALING_URL: String = "wss://magnata-do-pampa-signaling.onrender.com"
const SIGNALING_CONNECT_TIMEOUT_SEC: float = 45.0

const DEFAULT_STUN_SERVERS: Array[String] = [
	"stun:stun.l.google.com:19302",
	"stun:stun1.l.google.com:19302",
	"stun:stun.cloudflare.com:3478"
]

signal network_status_changed(mode: int, status_text: String, connected_peers: Array[Dictionary])
signal web_room_code_changed(room_code: String)
signal lobby_synced(lobby_data: Dictionary)
signal peer_joined_room(peer_id: int, peer_name: String)
signal peer_left_room(peer_id: int, peer_name: String)
signal connection_failed_error(message: String)
signal host_disconnected(reason: String)

signal client_action_received(sender_peer_id: int, session_id: int, action_name: String, params: Dictionary)
signal client_lobby_pref_received(sender_peer_id: int, pawn_idx: int, color_idx: int, player_name: String)
signal remote_match_started(session_id: int, snapshot: Dictionary)
signal remote_state_received(session_id: int, snapshot: Dictionary)
signal remote_event_received(session_id: int, event_type: String, payload: Dictionary)

var net_mode: NetMode = NetMode.LOCAL
var transport_mode: TransportMode = TransportMode.NONE
var local_player_name: String = "Jogador 1"
var current_port: int = DEFAULT_PORT
var current_address: String = "127.0.0.1"
var current_signaling_url: String = DEFAULT_SIGNALING_URL
var current_room_code: String = ""
var active_session_id: int = 0

# Configuração opcional de servidor TURN (para contornar CGNAT / NAT simétrico restrito)
var turn_url: String = ""
var turn_username: String = ""
var turn_credential: String = ""

var _enet_peer: ENetMultiplayerPeer = null
var _rtc_peer: WebRTCMultiplayerPeer = null
var _rtc_conns: Dictionary[int, WebRTCPeerConnection] = {}
var _pending_ice_candidates: Dictionary[int, Array] = {}

var _ws: WebSocketPeer = null
var _ws_opened: bool = false
var _ws_connect_elapsed: float = 0.0
var _ws_pending_role: String = "" # "host" ou "client"
var _ws_pending_room_code: String = ""
var _webrtc_local_peer_id: int = 1
var _webrtc_data_connected: bool = false

var _room_peers: Dictionary[int, Dictionary] = {}
var _peer_order: Array[int] = []
var _signals_connected: bool = false
var _prewarm_in_flight: bool = false
var _last_prewarm_url: String = ""

func _ready() -> void:
	_connect_multiplayer_signals()

func _exit_tree() -> void:
	disconnect_network("")

func _process(delta: float) -> void:
	if _ws != null:
		_poll_signaling_socket(delta)

func _connect_multiplayer_signals() -> void:
	if _signals_connected or multiplayer == null:
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_signals_connected = true

# --- Consultas de Estado e Transporte ---

func is_online() -> bool:
	return net_mode != NetMode.LOCAL and (_enet_peer != null or _rtc_peer != null or _ws != null)

func is_host() -> bool:
	return net_mode == NetMode.HOST and (_enet_peer != null or _rtc_peer != null or _ws != null)

func is_client() -> bool:
	return net_mode == NetMode.CLIENT and (_enet_peer != null or _rtc_peer != null or _ws != null)

func is_webrtc() -> bool:
	return transport_mode == TransportMode.WEBRTC

func is_enet() -> bool:
	return transport_mode == TransportMode.ENET

func get_transport_label() -> String:
	match transport_mode:
		TransportMode.WEBRTC:
			return "WEB P2P"
		TransportMode.ENET:
			return "LAN P2P"
		_:
			return "LOCAL"

func get_room_code() -> String:
	return current_room_code

func get_local_peer_id() -> int:
	if not is_online():
		return 1
	if transport_mode == TransportMode.WEBRTC:
		if _rtc_peer != null and multiplayer != null and multiplayer.has_multiplayer_peer():
			return multiplayer.get_unique_id()
		return _webrtc_local_peer_id
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return 1
	return multiplayer.get_unique_id()

func get_connected_peers_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pid: int in _peer_order:
		if _room_peers.has(pid):
			result.append((_room_peers[pid] as Dictionary).duplicate(true))
	return result

func get_local_ip_hint() -> String:
	var addrs: PackedStringArray = IP.get_local_addresses()
	for addr: String in addrs:
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"

func configure_turn_server(url: String, username: String, credential: String) -> void:
	turn_url = url.strip_edges()
	turn_username = username.strip_edges()
	turn_credential = credential.strip_edges()

func has_turn_configured() -> bool:
	return turn_url.strip_edges() != ""

func build_webrtc_ice_config() -> Dictionary:
	var ice_servers: Array[Dictionary] = [
		{
			"urls": DEFAULT_STUN_SERVERS.duplicate()
		}
	]
	var clean_turn: String = turn_url.strip_edges()
	if clean_turn != "":
		var turn_entry: Dictionary = {
			"urls": [clean_turn]
		}
		if turn_username.strip_edges() != "":
			turn_entry["username"] = turn_username.strip_edges()
		if turn_credential.strip_edges() != "":
			turn_entry["credential"] = turn_credential.strip_edges()
		ice_servers.append(turn_entry)
	return {
		"iceServers": ice_servers
	}

# --- Transporte 1: P2P LAN / Desktop via ENet ---

func host_room(port: int, host_name: String) -> Error:
	if OS.has_feature("web"):
		var web_err_msg: String = "ENet (UDP) não está disponível no navegador. Use a aba Multiplayer Web (WebRTC)."
		connection_failed_error.emit(web_err_msg)
		return ERR_UNAVAILABLE

	disconnect_network("")
	var safe_port: int = clampi(port, 1024, 65535)
	var clean_name: String = host_name.strip_edges()
	if clean_name == "":
		clean_name = "Anfitrião"

	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = server_peer.create_server(safe_port, MAX_CLIENTS)
	if err != OK:
		connection_failed_error.emit("Não foi possível abrir a porta %d (código %d)." % [safe_port, int(err)])
		return err

	_enet_peer = server_peer
	multiplayer.multiplayer_peer = _enet_peer
	net_mode = NetMode.HOST
	transport_mode = TransportMode.ENET
	current_port = safe_port
	current_address = get_local_ip_hint()
	current_room_code = ""
	local_player_name = clean_name
	active_session_id = _next_session_id()

	_room_peers.clear()
	_peer_order.clear()
	_room_peers[1] = {
		"peer_id": 1,
		"name": clean_name,
		"is_host": true,
		"status": "connected"
	}
	_peer_order.append(1)

	web_room_code_changed.emit("")
	var status_msg: String = "LAN ENet • Hospedando na porta %d (IP local: %s) • 1/6 estanceiro conectado" % [safe_port, current_address]
	network_status_changed.emit(int(net_mode), status_msg, get_connected_peers_list())
	return OK

func join_room(address: String, port: int, client_name: String) -> Error:
	if OS.has_feature("web"):
		var web_err_msg: String = "ENet (UDP) não está disponível no navegador. Use a aba Multiplayer Web (WebRTC)."
		connection_failed_error.emit(web_err_msg)
		return ERR_UNAVAILABLE

	disconnect_network("")
	var clean_addr: String = address.strip_edges()
	if clean_addr == "":
		clean_addr = "127.0.0.1"
	var safe_port: int = clampi(port, 1024, 65535)
	var clean_name: String = client_name.strip_edges()
	if clean_name == "":
		clean_name = "Estanceiro"

	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = client_peer.create_client(clean_addr, safe_port)
	if err != OK:
		connection_failed_error.emit("Erro ao conectar em %s:%d (código %d)." % [clean_addr, safe_port, int(err)])
		return err

	_enet_peer = client_peer
	multiplayer.multiplayer_peer = _enet_peer
	net_mode = NetMode.CLIENT
	transport_mode = TransportMode.ENET
	current_address = clean_addr
	current_port = safe_port
	current_room_code = ""
	local_player_name = clean_name
	active_session_id = 0
	_room_peers.clear()
	_peer_order.clear()

	web_room_code_changed.emit("")
	network_status_changed.emit(int(net_mode), "LAN ENet • Conectando a %s:%d..." % [clean_addr, safe_port], get_connected_peers_list())
	return OK

# --- Transporte 2: Multiplayer Web via WebRTC (Topologia Estrela: 1 Host + até 5 Clientes) ---

func host_web_room(signaling_url: String, host_name: String, turn_cfg: Dictionary = {}) -> Error:
	disconnect_network("")
	if not turn_cfg.is_empty():
		configure_turn_server(
			str(turn_cfg.get("url", "")),
			str(turn_cfg.get("username", "")),
			str(turn_cfg.get("credential", ""))
		)

	var clean_ws_url: String = _normalize_signaling_url(signaling_url)
	var clean_name: String = host_name.strip_edges()
	if clean_name == "":
		clean_name = "Anfitrião"

	if not _is_valid_ws_url(clean_ws_url):
		connection_failed_error.emit("URL de sinalização inválida. Use ws:// ou wss:// (ex.: %s)." % DEFAULT_SIGNALING_URL)
		return ERR_INVALID_PARAMETER

	# Criar WebRTCMultiplayerPeer em modo Host (peer 1, estrela até 5 clientes)
	var rtc_server: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
	var rtc_err: Error = rtc_server.create_server()
	if rtc_err != OK:
		connection_failed_error.emit("Não foi possível inicializar WebRTC Host (código %d)." % int(rtc_err))
		return rtc_err

	var ws: WebSocketPeer = WebSocketPeer.new()
	var ws_err: Error = ws.connect_to_url(clean_ws_url)
	if ws_err != OK:
		rtc_server.close()
		connection_failed_error.emit("Servidor de sinalização inacessível (%s). Verifique se o servidor WebSocket está online ou use Modo Local / ENet LAN." % clean_ws_url)
		return ws_err

	_rtc_peer = rtc_server
	multiplayer.multiplayer_peer = _rtc_peer
	_ws = ws
	_ws_opened = false
	_ws_connect_elapsed = 0.0
	_ws_pending_role = "host"
	_ws_pending_room_code = ""
	_webrtc_local_peer_id = 1
	_webrtc_data_connected = true

	net_mode = NetMode.HOST
	transport_mode = TransportMode.WEBRTC
	current_signaling_url = clean_ws_url
	current_room_code = ""
	local_player_name = clean_name
	active_session_id = _next_session_id()

	_room_peers.clear()
	_peer_order.clear()
	_room_peers[1] = {
		"peer_id": 1,
		"name": clean_name,
		"is_host": true,
		"status": "connected"
	}
	_peer_order.append(1)

	web_room_code_changed.emit("")
	var ice_tag: String = "STUN+TURN" if has_turn_configured() else "STUN"
	network_status_changed.emit(int(net_mode), "WebRTC (%s) • Conectando à sinalização %s (pode levar ~30s se o Render estiver acordando)..." % [ice_tag, clean_ws_url], get_connected_peers_list())
	return OK

func join_web_room(signaling_url: String, room_code: String, client_name: String, turn_cfg: Dictionary = {}) -> Error:
	disconnect_network("")
	if not turn_cfg.is_empty():
		configure_turn_server(
			str(turn_cfg.get("url", "")),
			str(turn_cfg.get("username", "")),
			str(turn_cfg.get("credential", ""))
		)

	var clean_ws_url: String = _normalize_signaling_url(signaling_url)
	var clean_code: String = room_code.strip_edges().to_upper()
	var clean_name: String = client_name.strip_edges()
	if clean_name == "":
		clean_name = "Estanceiro"

	if clean_code.length() < 4:
		connection_failed_error.emit("Informe um Código de Sala válido (mínimo 4 caracteres).")
		return ERR_INVALID_PARAMETER

	if not _is_valid_ws_url(clean_ws_url):
		connection_failed_error.emit("URL de sinalização inválida. Use ws:// ou wss:// (ex.: %s)." % DEFAULT_SIGNALING_URL)
		return ERR_INVALID_PARAMETER

	var ws: WebSocketPeer = WebSocketPeer.new()
	var ws_err: Error = ws.connect_to_url(clean_ws_url)
	if ws_err != OK:
		connection_failed_error.emit("Servidor de sinalização inacessível (%s). Verifique se o servidor WebSocket está online ou use Modo Local / ENet LAN." % clean_ws_url)
		return ws_err

	_ws = ws
	_ws_opened = false
	_ws_connect_elapsed = 0.0
	_ws_pending_role = "client"
	_ws_pending_room_code = clean_code
	_webrtc_local_peer_id = 0
	_webrtc_data_connected = false

	net_mode = NetMode.CLIENT
	transport_mode = TransportMode.WEBRTC
	current_signaling_url = clean_ws_url
	current_room_code = clean_code
	local_player_name = clean_name
	active_session_id = 0
	_room_peers.clear()
	_peer_order.clear()

	web_room_code_changed.emit(clean_code)
	var ice_tag: String = "STUN+TURN" if has_turn_configured() else "STUN"
	network_status_changed.emit(int(net_mode), "WebRTC (%s) • Entrando na sala %s via %s..." % [ice_tag, clean_code, clean_ws_url], get_connected_peers_list())
	return OK

func _normalize_signaling_url(raw_url: String) -> String:
	var s: String = raw_url.strip_edges()
	while s.ends_with("/"):
		s = s.substr(0, s.length() - 1)
	if s.begins_with("https://"):
		s = "wss://" + s.substr(8)
	elif s.begins_with("http://"):
		s = "ws://" + s.substr(7)
	if s == "":
		return DEFAULT_SIGNALING_URL
	return s

func prewarm_signaling_server(raw_url: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ws_url: String = _normalize_signaling_url(raw_url)
	if not _is_valid_ws_url(ws_url):
		return
	var health_url: String = ""
	if ws_url.begins_with("wss://"):
		health_url = "https://" + ws_url.substr(6) + "/health"
	elif ws_url.begins_with("ws://"):
		health_url = "http://" + ws_url.substr(5) + "/health"
	if health_url == "" or _prewarm_in_flight or _last_prewarm_url == health_url:
		return
	_prewarm_in_flight = true
	_last_prewarm_url = health_url
	var req: HTTPRequest = HTTPRequest.new()
	req.timeout = 30.0
	add_child(req)
	req.request_completed.connect(func(_res: int, _code: int, _hdrs: PackedStringArray, _body: PackedByteArray) -> void:
		_prewarm_in_flight = false
		if is_instance_valid(req):
			req.queue_free()
	)
	var err: Error = req.request(health_url)
	if err != OK:
		_prewarm_in_flight = false
		req.queue_free()

func _is_valid_ws_url(url_str: String) -> bool:
	return url_str.begins_with("ws://") or url_str.begins_with("wss://")

# --- Sinalização WebSocket (Protocolo Estrela por Código de Sala) ---

func _poll_signaling_socket(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state: WebSocketPeer.State = _ws.get_ready_state()

	if state == WebSocketPeer.STATE_CONNECTING:
		_ws_connect_elapsed += delta
		if _ws_connect_elapsed >= SIGNALING_CONNECT_TIMEOUT_SEC:
			var failed_url: String = current_signaling_url
			disconnect_network("Sinalização indisponível (tempo esgotado).")
			connection_failed_error.emit("Servidor de sinalização inacessível em %s (tempo esgotado). Verifique o servidor WS ou jogue em Modo Local / ENet LAN." % failed_url)
		return

	if state == WebSocketPeer.STATE_OPEN:
		if not _ws_opened:
			_ws_opened = true
			if _ws_pending_role == "host":
				_send_ws_json({
					"type": "create_room",
					"name": local_player_name,
					"max_clients": MAX_CLIENTS
				})
			elif _ws_pending_role == "client":
				_send_ws_json({
					"type": "join_room",
					"room_code": _ws_pending_room_code,
					"name": local_player_name
				})

		while _ws != null and _ws.get_available_packet_count() > 0:
			var pkt: PackedByteArray = _ws.get_packet()
			var text: String = pkt.get_string_from_utf8()
			_handle_signaling_message(text)
		return

	if state == WebSocketPeer.STATE_CLOSED:
		var was_opened: bool = _ws_opened
		var failed_url: String = current_signaling_url
		_ws = null
		_ws_opened = false
		if not was_opened:
			disconnect_network("Sinalização inacessível.")
			connection_failed_error.emit("Não foi possível conectar à sinalização (%s). Confira se o servidor WebSocket está ativo ou use Modo Local / ENet LAN." % failed_url)
		elif is_client() and not _webrtc_data_connected:
			disconnect_network("Conexão de sinalização encerrada antes do enlace P2P.")
			connection_failed_error.emit("Sinalização encerrada antes de concluir a conexão WebRTC com o Host.")
		elif is_host() and current_room_code == "":
			disconnect_network("Sinalização encerrada antes de criar a sala.")
			connection_failed_error.emit("Sinalização encerrada antes de gerar o Código da Sala.")

func _send_ws_json(data: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var _err: Error = _ws.send_text(JSON.stringify(data))

func _handle_signaling_message(raw_text: String) -> void:
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		return
	var msg: Dictionary = parsed
	var msg_type: String = str(msg.get("type", ""))

	match msg_type:
		"room_created":
			if not is_host() or transport_mode != TransportMode.WEBRTC:
				return
			current_room_code = str(msg.get("room_code", "")).strip_edges().to_upper()
			web_room_code_changed.emit(current_room_code)
			_emit_host_status()

		"room_joined":
			if not is_client() or transport_mode != TransportMode.WEBRTC:
				return
			var assigned_id: int = int(msg.get("peer_id", 0))
			if assigned_id < 2:
				disconnect_network("Peer ID inválido recebido da sinalização.")
				connection_failed_error.emit("Servidor de sinalização retornou identificador inválido.")
				return
			current_room_code = str(msg.get("room_code", current_room_code)).strip_edges().to_upper()
			_webrtc_local_peer_id = assigned_id
			web_room_code_changed.emit(current_room_code)

			var rtc_client: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
			var c_err: Error = rtc_client.create_client(assigned_id)
			if c_err != OK:
				disconnect_network("Falha ao criar WebRTCMultiplayerPeer cliente.")
				connection_failed_error.emit("Falha ao inicializar cliente WebRTC (código %d)." % int(c_err))
				return

			_rtc_peer = rtc_client
			multiplayer.multiplayer_peer = _rtc_peer

			# Topologia estrela: cliente cria ligação direta APENAS com o Host (peer 1)
			var link_err: Error = _create_webrtc_link(1, false)
			if link_err != OK:
				return

			network_status_changed.emit(
				int(net_mode),
				"WebRTC • Sala %s localizada! Negociando ligação P2P com o Host..." % current_room_code,
				get_connected_peers_list()
			)

		"peer_joined":
			if not is_host() or transport_mode != TransportMode.WEBRTC:
				return
			var remote_id: int = int(msg.get("peer_id", 0))
			var remote_name: String = str(msg.get("name", "Estanceiro %d" % remote_id)).strip_edges()
			if remote_name == "":
				remote_name = "Estanceiro %d" % remote_id
			if remote_id < 2:
				return
			if _peer_order.size() >= (MAX_CLIENTS + 1) and not _room_peers.has(remote_id):
				return

			if not _room_peers.has(remote_id):
				_peer_order.append(remote_id)
			_room_peers[remote_id] = {
				"peer_id": remote_id,
				"name": remote_name,
				"is_host": false,
				"status": "connecting"
			}
			_emit_host_status()

			# Topologia estrela: Host (peer 1) cria ligação direta e oferta SDP para o novo cliente
			var link_err: Error = _create_webrtc_link(remote_id, true)
			if link_err != OK:
				_room_peers.erase(remote_id)
				_peer_order.erase(remote_id)
				_emit_host_status()

		"peer_left":
			if not is_host() or transport_mode != TransportMode.WEBRTC:
				return
			var left_id: int = int(msg.get("peer_id", 0))
			if left_id >= 2 and _room_peers.has(left_id):
				var p_info: Dictionary = _room_peers[left_id]
				# Se ainda estava em handshake (nunca concluiu DataChannel), remove do lobby
				if str(p_info.get("status", "")) == "connecting":
					_close_webrtc_link(left_id)
					_room_peers.erase(left_id)
					_peer_order.erase(left_id)
					_emit_host_status()

		"host_left":
			if is_client() and transport_mode == TransportMode.WEBRTC and not _webrtc_data_connected:
				var reason_str: String = str(msg.get("reason", "O Host encerrou a sala."))
				disconnect_network(reason_str)
				host_disconnected.emit(reason_str)

		"offer":
			var from_id: int = int(msg.get("from_id", 1))
			var sdp_str: String = str(msg.get("sdp", ""))
			if is_client() and from_id == 1 and sdp_str != "":
				if not _rtc_conns.has(1):
					var l_err: Error = _create_webrtc_link(1, false)
					if l_err != OK:
						return
				var conn: WebRTCPeerConnection = _rtc_conns[1]
				var _sd_err: Error = conn.set_remote_description("offer", sdp_str)

		"answer":
			var from_id: int = int(msg.get("from_id", 0))
			var sdp_str: String = str(msg.get("sdp", ""))
			if is_host() and from_id >= 2 and sdp_str != "" and _rtc_conns.has(from_id):
				var conn: WebRTCPeerConnection = _rtc_conns[from_id]
				var _sd_err: Error = conn.set_remote_description("answer", sdp_str)

		"candidate":
			var from_id: int = int(msg.get("from_id", 0))
			var media_str: String = str(msg.get("media", ""))
			var idx_val: int = int(msg.get("index", 0))
			var cand_name: String = str(msg.get("name", ""))
			if from_id <= 0 or cand_name == "":
				return
			if _rtc_conns.has(from_id):
				var conn: WebRTCPeerConnection = _rtc_conns[from_id]
				var _c_err: Error = conn.add_ice_candidate(media_str, idx_val, cand_name)
			else:
				if not _pending_ice_candidates.has(from_id):
					_pending_ice_candidates[from_id] = []
				var q_arr: Array = _pending_ice_candidates[from_id]
				q_arr.append({
					"media": media_str,
					"index": idx_val,
					"name": cand_name
				})

		"error":
			var err_text: String = str(msg.get("message", "Erro na sala de sinalização."))
			disconnect_network(err_text)
			connection_failed_error.emit(err_text)

func _create_webrtc_link(remote_peer_id: int, create_offer_now: bool) -> Error:
	if _rtc_peer == null:
		return ERR_UNCONFIGURED
	_close_webrtc_link(remote_peer_id)

	var conn: WebRTCPeerConnection = WebRTCPeerConnection.new()
	var init_err: Error = conn.initialize(build_webrtc_ice_config())
	if init_err != OK:
		var platform_hint: String = "No Desktop nativo, WebRTC requer a extensão webrtc-native (use a aba P2P LAN ENet ou o build Web HTML5)."
		if OS.has_feature("web"):
			platform_hint = "Verifique a configuração STUN/TURN e as permissões WebRTC do navegador."
		disconnect_network("Falha ao inicializar WebRTCPeerConnection.")
		connection_failed_error.emit("WebRTC indisponível neste ambiente (código %d). %s" % [int(init_err), platform_hint])
		return init_err

	conn.session_description_created.connect(_on_rtc_session_description_created.bind(remote_peer_id))
	conn.ice_candidate_created.connect(_on_rtc_ice_candidate_created.bind(remote_peer_id))

	var add_err: Error = _rtc_peer.add_peer(conn, remote_peer_id)
	if add_err != OK:
		conn.close()
		return add_err

	_rtc_conns[remote_peer_id] = conn

	# Aplicar eventuais candidatos ICE recebidos antes da criação do link
	if _pending_ice_candidates.has(remote_peer_id):
		var queued: Array = _pending_ice_candidates[remote_peer_id]
		for item: Variant in queued:
			if item is Dictionary:
				var cd: Dictionary = item
				var _ic_err: Error = conn.add_ice_candidate(
					str(cd.get("media", "")),
					int(cd.get("index", 0)),
					str(cd.get("name", ""))
				)
		_pending_ice_candidates.erase(remote_peer_id)

	if create_offer_now:
		var off_err: Error = conn.create_offer()
		if off_err != OK:
			return off_err
	return OK

func _close_webrtc_link(remote_peer_id: int) -> void:
	if _rtc_conns.has(remote_peer_id):
		var conn: WebRTCPeerConnection = _rtc_conns[remote_peer_id]
		conn.close()
		_rtc_conns.erase(remote_peer_id)
	if _rtc_peer != null and _rtc_peer.has_peer(remote_peer_id):
		_rtc_peer.remove_peer(remote_peer_id)
	_pending_ice_candidates.erase(remote_peer_id)

func _on_rtc_session_description_created(sdp_type: String, sdp: String, remote_peer_id: int) -> void:
	if not _rtc_conns.has(remote_peer_id):
		return
	var conn: WebRTCPeerConnection = _rtc_conns[remote_peer_id]
	var _loc_err: Error = conn.set_local_description(sdp_type, sdp)
	_send_ws_json({
		"type": sdp_type,
		"target_id": remote_peer_id,
		"sdp": sdp
	})

func _on_rtc_ice_candidate_created(media: String, index: int, cand_name: String, remote_peer_id: int) -> void:
	_send_ws_json({
		"type": "candidate",
		"target_id": remote_peer_id,
		"media": media,
		"index": index,
		"name": cand_name
	})

# --- Encerramento e Sessão ---

func disconnect_network(reason: String = "") -> void:
	var was_online: bool = (net_mode != NetMode.LOCAL or _enet_peer != null or _rtc_peer != null or _ws != null)
	active_session_id += 1
	net_mode = NetMode.LOCAL
	transport_mode = TransportMode.NONE
	current_room_code = ""
	_ws_opened = false
	_ws_connect_elapsed = 0.0
	_ws_pending_role = ""
	_ws_pending_room_code = ""
	_webrtc_local_peer_id = 1
	_webrtc_data_connected = false

	_room_peers.clear()
	_peer_order.clear()
	_pending_ice_candidates.clear()

	for pid_key: int in _rtc_conns.keys():
		var c: WebRTCPeerConnection = _rtc_conns[pid_key]
		if c != null:
			c.close()
	_rtc_conns.clear()

	if _ws != null:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN or _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
			_ws.close(1000, "client_disconnect")
		_ws = null

	if _enet_peer != null:
		_enet_peer.close()
		_enet_peer = null

	if _rtc_peer != null:
		_rtc_peer.close()
		_rtc_peer = null

	if multiplayer != null and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null

	if was_online:
		web_room_code_changed.emit("")
		var msg: String = reason if reason != "" else "Desconectado (Modo Local)."
		network_status_changed.emit(int(net_mode), msg, get_connected_peers_list())

func begin_new_match_session() -> int:
	active_session_id = _next_session_id()
	return active_session_id

func _next_session_id() -> int:
	var t_ms: int = Time.get_ticks_msec()
	var candidate: int = maxi(active_session_id + 1, t_ms)
	if candidate == active_session_id:
		candidate += 1
	return candidate

# --- Broadcasts do Host Autoritativo (Agnóstico de Transporte: ENet ou WebRTC) ---

func _can_send_host_rpc() -> bool:
	if not is_host() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return not multiplayer.get_peers().is_empty()

func _can_send_client_rpc() -> bool:
	if not is_client() or active_session_id <= 0 or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func broadcast_lobby_state(lobby_data: Dictionary) -> void:
	if not is_host():
		return
	var payload: Dictionary = lobby_data.duplicate(true)
	payload["peers"] = get_connected_peers_list()
	payload["port"] = current_port
	payload["host_ip"] = current_address
	payload["room_code"] = current_room_code
	payload["transport"] = int(transport_mode)
	lobby_synced.emit(payload)
	if _can_send_host_rpc():
		_rpc_sync_lobby.rpc(active_session_id, payload)

func broadcast_match_started(session_id: int, snapshot: Dictionary) -> void:
	if not is_host():
		return
	active_session_id = session_id
	if _can_send_host_rpc():
		_rpc_match_started.rpc(session_id, snapshot)

func broadcast_state_snapshot(session_id: int, snapshot: Dictionary) -> void:
	if not is_host():
		return
	if _can_send_host_rpc():
		_rpc_state_snapshot.rpc(session_id, snapshot)

func broadcast_match_event(session_id: int, event_type: String, payload: Dictionary) -> void:
	if not is_host():
		return
	if _can_send_host_rpc():
		_rpc_match_event.rpc(session_id, event_type, payload)

func send_match_event_to_peer(target_peer_id: int, session_id: int, event_type: String, payload: Dictionary) -> void:
	if not is_host() or target_peer_id <= 1:
		return
	if _can_send_host_rpc() and (target_peer_id in multiplayer.get_peers()):
		_rpc_match_event.rpc_id(target_peer_id, session_id, event_type, payload)

func send_action_to_host(action_name: String, params: Dictionary = {}) -> void:
	if not _can_send_client_rpc():
		return
	_rpc_request_action.rpc_id(1, active_session_id, action_name, params)

func send_lobby_pref_to_host(pawn_idx: int, color_idx: int, player_name: String = "") -> void:
	if not is_client() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_rpc_set_lobby_pref.rpc_id(1, pawn_idx, color_idx, player_name)

func update_peer_display_name(peer_id: int, clean_name: String) -> void:
	if peer_id == 1:
		local_player_name = clean_name
		if _room_peers.has(1):
			(_room_peers[1] as Dictionary)["name"] = clean_name
		_emit_host_status()
	elif _room_peers.has(peer_id):
		(_room_peers[peer_id] as Dictionary)["name"] = clean_name
		_emit_host_status()

# --- Callbacks do MultiplayerAPI (ENet e WebRTC Estrela) ---

func _on_peer_connected(peer_id: int) -> void:
	if not is_host():
		return
	var existing_name: String = "Estanceiro %d" % (_peer_order.size() + 1)
	if _room_peers.has(peer_id):
		existing_name = str((_room_peers[peer_id] as Dictionary).get("name", existing_name))
	else:
		_peer_order.append(peer_id)
	_room_peers[peer_id] = {
		"peer_id": peer_id,
		"name": existing_name,
		"is_host": false,
		"status": "connected"
	}
	_emit_host_status()

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host():
		return
	var left_name: String = "Jogador"
	if _room_peers.has(peer_id):
		left_name = str((_room_peers[peer_id] as Dictionary).get("name", "Jogador"))
		_room_peers.erase(peer_id)
	_peer_order.erase(peer_id)
	if transport_mode == TransportMode.WEBRTC:
		_close_webrtc_link(peer_id)
	_emit_host_status()
	peer_left_room.emit(peer_id, left_name)

func _on_connected_to_server() -> void:
	if not is_client():
		return
	_webrtc_data_connected = true
	var status_msg: String = "Conectado ao Host %s:%d! Aguardando dados da sala..." % [current_address, current_port]
	if transport_mode == TransportMode.WEBRTC:
		status_msg = "WebRTC • Conectado ao Host da sala %s! Sincronizando lobby..." % current_room_code
	network_status_changed.emit(int(net_mode), status_msg, get_connected_peers_list())
	_rpc_register_peer.rpc_id(1, local_player_name)

func _on_connection_failed() -> void:
	var failed_target: String = current_room_code if transport_mode == TransportMode.WEBRTC else "%s:%d" % [current_address, current_port]
	disconnect_network("Falha ao conectar em %s." % failed_target)
	if transport_mode == TransportMode.WEBRTC:
		connection_failed_error.emit("Não foi possível estabelecer conexão WebRTC com o Host. Em redes com CGNAT/NAT restrito, configure um servidor TURN.")
	else:
		connection_failed_error.emit("Não foi possível conectar em %s. Verifique IP, porta e firewall." % failed_target)

func _on_server_disconnected() -> void:
	disconnect_network("O Host encerrou a sala ou a conexão caiu.")
	host_disconnected.emit("A conexão com o Host foi encerrada.")

func _emit_host_status() -> void:
	var connected_count: int = 0
	var connecting_count: int = 0
	for pid: int in _peer_order:
		if _room_peers.has(pid):
			var st: String = str((_room_peers[pid] as Dictionary).get("status", "connected"))
			if st == "connecting":
				connecting_count += 1
			else:
				connected_count += 1
	var msg: String = ""
	if transport_mode == TransportMode.WEBRTC:
		var ice_tag: String = "STUN+TURN" if has_turn_configured() else "STUN"
		var code_str: String = current_room_code if current_room_code != "" else "..."
		var pending_txt: String = " (+%d conectando)" % connecting_count if connecting_count > 0 else ""
		msg = "WebRTC (%s) • Sala: %s • %d/6 conectados%s" % [ice_tag, code_str, connected_count, pending_txt]
	else:
		var suffix: String = "estanceiro conectado" if connected_count == 1 else "estanceiros conectados"
		msg = "LAN ENet • Porta %d (IP: %s) • %d/6 %s" % [current_port, current_address, connected_count, suffix]
	network_status_changed.emit(int(net_mode), msg, get_connected_peers_list())

# --- RPCs (Compartilhados por ENet e WebRTC Estrela) ---

@rpc("any_peer", "reliable")
func _rpc_register_peer(peer_name: String) -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 1:
		return
	var clean_name: String = peer_name.strip_edges()
	if clean_name == "":
		clean_name = "Estanceiro %d" % (_peer_order.size() + 1)
	if clean_name.length() > 22:
		clean_name = clean_name.substr(0, 22)
	if not _room_peers.has(sender_id):
		_peer_order.append(sender_id)
	_room_peers[sender_id] = {
		"peer_id": sender_id,
		"name": clean_name,
		"is_host": false,
		"status": "connected"
	}
	_emit_host_status()
	peer_joined_room.emit(sender_id, clean_name)

@rpc("authority", "reliable")
func _rpc_sync_lobby(session_id: int, lobby_data: Dictionary) -> void:
	if not is_client():
		return
	active_session_id = session_id
	_room_peers.clear()
	_peer_order.clear()
	var peers_raw: Variant = lobby_data.get("peers", [])
	if peers_raw is Array:
		for item: Variant in (peers_raw as Array):
			if item is Dictionary:
				var pd: Dictionary = item
				var pid: int = int(pd.get("peer_id", 0))
				if pid > 0:
					_room_peers[pid] = pd.duplicate(true)
					_peer_order.append(pid)
	var synced_code: String = str(lobby_data.get("room_code", current_room_code)).strip_edges().to_upper()
	if synced_code != "" and synced_code != current_room_code:
		current_room_code = synced_code
		web_room_code_changed.emit(current_room_code)
	var count: int = _peer_order.size()
	var status_msg: String = ""
	if transport_mode == TransportMode.WEBRTC:
		status_msg = "WebRTC • Sala %s • %d/6 na mesa — aguardando Host iniciar" % [current_room_code, count]
	else:
		status_msg = "LAN ENet • Conectado a %s:%d • %d/6 na mesa — aguardando Host iniciar" % [current_address, current_port, count]
	network_status_changed.emit(int(net_mode), status_msg, get_connected_peers_list())
	lobby_synced.emit(lobby_data)

@rpc("authority", "reliable")
func _rpc_match_started(session_id: int, snapshot: Dictionary) -> void:
	if not is_client():
		return
	active_session_id = session_id
	remote_match_started.emit(session_id, snapshot)

@rpc("authority", "reliable")
func _rpc_state_snapshot(session_id: int, snapshot: Dictionary) -> void:
	if not is_client():
		return
	if session_id != active_session_id:
		return
	remote_state_received.emit(session_id, snapshot)

@rpc("authority", "reliable")
func _rpc_match_event(session_id: int, event_type: String, payload: Dictionary) -> void:
	if not is_client():
		return
	if session_id != active_session_id:
		return
	remote_event_received.emit(session_id, event_type, payload)

@rpc("any_peer", "reliable")
func _rpc_request_action(session_id: int, action_name: String, params: Dictionary) -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 1:
		return
	if session_id != active_session_id:
		return
	client_action_received.emit(sender_id, session_id, action_name, params)

@rpc("any_peer", "reliable")
func _rpc_set_lobby_pref(pawn_idx: int, color_idx: int, player_name: String = "") -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 1:
		return
	client_lobby_pref_received.emit(sender_id, pawn_idx, color_idx, player_name)
