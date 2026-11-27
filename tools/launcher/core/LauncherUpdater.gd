extends Node

signal state_changed(state_key: String, status_text: String)
signal version_info_updated(info: Dictionary)
signal download_progress_changed(downloaded_bytes: int, total_bytes: int, ratio: float)
signal update_finished(success: bool, message: String)

const CONFIG_RES_PATH: String = "res://launcher_config.json"
const SETTINGS_USER_PATH: String = "user://launcher_settings.json"
const INSTALLED_FALLBACK_PATH: String = "user://installed_version.json"
const DOWNLOAD_TEMP_PATH: String = "user://update_download.tmp"

enum LauncherState {
	IDLE,
	NO_REPO,
	CHECKING,
	NOT_INSTALLED,
	UPDATE_AVAILABLE,
	UP_TO_DATE,
	DOWNLOADING,
	INSTALLING,
	ERROR
}

var current_state: LauncherState = LauncherState.IDLE
var _base_config: Dictionary = {}
var _settings: Dictionary = {}
var _remote_release: Dictionary = {}
var _remote_manifest: Dictionary = {}
var _auto_launch_after_update: bool = false
var _last_error: String = ""

var _api_http: HTTPRequest = null
var _manifest_http: HTTPRequest = null
var _download_http: HTTPRequest = null

func _ready() -> void:
	_load_base_config()
	_load_settings()
	_setup_http_nodes()
	set_process(false)
	_emit_snapshot(LauncherState.IDLE, "Pronto para verificar atualizações.")

func _setup_http_nodes() -> void:
	_api_http = HTTPRequest.new()
	_api_http.name = "ApiHttp"
	_api_http.timeout = 12.0
	_api_http.request_completed.connect(_on_api_request_completed)
	add_child(_api_http)

	_manifest_http = HTTPRequest.new()
	_manifest_http.name = "ManifestHttp"
	_manifest_http.timeout = 12.0
	_manifest_http.request_completed.connect(_on_manifest_request_completed)
	add_child(_manifest_http)

	_download_http = HTTPRequest.new()
	_download_http.name = "DownloadHttp"
	_download_http.timeout = 120.0
	_download_http.use_threads = true
	_download_http.request_completed.connect(_on_download_request_completed)
	add_child(_download_http)

func _load_base_config() -> void:
	_base_config = {
		"product_name": "Magnata do Pampa",
		"github_repo": "",
		"game_exe_name": "MagnataDoPampa.exe",
		"manifest_asset_name": "manifest.json",
		"release_channel": "stable"
	}
	if FileAccess.file_exists(CONFIG_RES_PATH):
		var raw: String = FileAccess.get_file_as_string(CONFIG_RES_PATH)
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			var src: Dictionary = parsed as Dictionary
			for k: Variant in src.keys():
				_base_config[str(k)] = src[k]

func _load_settings() -> void:
	_settings = {
		"github_repo": str(_base_config.get("github_repo", "")).strip_edges(),
		"github_token": "",
		"custom_install_dir": ""
	}
	if FileAccess.file_exists(SETTINGS_USER_PATH):
		var raw: String = FileAccess.get_file_as_string(SETTINGS_USER_PATH)
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			var src: Dictionary = parsed as Dictionary
			for k: Variant in src.keys():
				var k_str: String = str(k)
				# O repositorio oficial vem sempre fixo do launcher_config.json embutido
				if k_str != "github_repo":
					_settings[k_str] = src[k]
	_settings["github_repo"] = str(_base_config.get("github_repo", "")).strip_edges()

func save_settings(github_repo: String, github_token: String, custom_install_dir: String) -> void:
	_settings["github_repo"] = github_repo.strip_edges()
	_settings["github_token"] = github_token.strip_edges()
	_settings["custom_install_dir"] = custom_install_dir.strip_edges()
	var file: FileAccess = FileAccess.open(SETTINGS_USER_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_settings, "\t"))
		file.close()
	_remote_release.clear()
	_remote_manifest.clear()
	_emit_snapshot(LauncherState.IDLE, "Configurações salvas.")

func get_settings() -> Dictionary:
	return _settings.duplicate(true)

func resolve_install_dir() -> String:
	var custom_dir: String = str(_settings.get("custom_install_dir", "")).strip_edges()
	if custom_dir != "" and DirAccess.dir_exists_absolute(custom_dir):
		return custom_dir.simplify_path()
	if OS.has_feature("standalone"):
		return OS.get_executable_path().get_base_dir().simplify_path()
	var dev_builds: String = ProjectSettings.globalize_path("res://../../builds/latest").simplify_path()
	if DirAccess.dir_exists_absolute(dev_builds):
		return dev_builds
	return OS.get_executable_path().get_base_dir().simplify_path()

func get_game_exe_name() -> String:
	var name_val: String = str(_base_config.get("game_exe_name", "MagnataDoPampa.exe")).strip_edges()
	return name_val if name_val != "" else "MagnataDoPampa.exe"

func get_installed_info() -> Dictionary:
	var dir_path: String = resolve_install_dir()
	var exe_path: String = dir_path.path_join(get_game_exe_name())
	var exe_exists: bool = FileAccess.file_exists(exe_path)
	var ver_path: String = dir_path.path_join("version.json")
	var ver_data: Dictionary = {}
	if FileAccess.file_exists(ver_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ver_path))
		if parsed is Dictionary:
			ver_data = parsed as Dictionary
	elif exe_exists and FileAccess.file_exists(INSTALLED_FALLBACK_PATH):
		var parsed_fb: Variant = JSON.parse_string(FileAccess.get_file_as_string(INSTALLED_FALLBACK_PATH))
		if parsed_fb is Dictionary:
			ver_data = parsed_fb as Dictionary

	var installed_ver: String = normalize_version_tag(str(ver_data.get("version", "")))
	var installed_build: int = int(ver_data.get("build_number", 0))
	if exe_exists and installed_ver == "":
		installed_ver = "0.0.0"
	return {
		"install_dir": dir_path,
		"exe_path": exe_path,
		"exe_exists": exe_exists,
		"installed_version": installed_ver,
		"installed_build": installed_build
	}

static func normalize_version_tag(raw_ver: String) -> String:
	var cleaned: String = raw_ver.strip_edges()
	if cleaned.begins_with("v") or cleaned.begins_with("V"):
		cleaned = cleaned.substr(1)
	var dash_idx: int = cleaned.find("-")
	if dash_idx >= 0:
		cleaned = cleaned.substr(0, dash_idx)
	var plus_idx: int = cleaned.find("+")
	if plus_idx >= 0:
		cleaned = cleaned.substr(0, plus_idx)
	return cleaned.strip_edges()

static func parse_semver_parts(raw_ver: String) -> Array[int]:
	var norm: String = normalize_version_tag(raw_ver)
	var parts: PackedStringArray = norm.split(".", false)
	var out: Array[int] = [0, 0, 0]
	for i: int in range(mini(3, parts.size())):
		var seg: String = parts[i].strip_edges()
		if seg.is_valid_int():
			out[i] = maxi(0, int(seg))
	return out

static func compare_semver(ver_a: String, ver_b: String) -> int:
	var pa: Array[int] = parse_semver_parts(ver_a)
	var pb: Array[int] = parse_semver_parts(ver_b)
	for i: int in range(3):
		if pa[i] < pb[i]:
			return -1
		if pa[i] > pb[i]:
			return 1
	return 0

static func is_remote_newer(local_ver: String, local_build: int, remote_ver: String, remote_build: int = 0) -> bool:
	var cmp: int = compare_semver(local_ver, remote_ver)
	if cmp < 0:
		return true
	if cmp > 0:
		return false
	if remote_build > 0 and local_build > 0:
		return remote_build > local_build
	return false

func _build_github_headers(is_binary_download: bool = false) -> PackedStringArray:
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: MagnataDoPampaLauncher",
		"Accept: application/octet-stream" if is_binary_download else "Accept: application/vnd.github+json"
	])
	var token: String = str(_settings.get("github_token", "")).strip_edges()
	if token != "":
		headers.append("Authorization: Bearer %s" % token)
	return headers

func check_for_updates() -> void:
	if current_state == LauncherState.DOWNLOADING or current_state == LauncherState.INSTALLING:
		return
	var repo: String = str(_settings.get("github_repo", "")).strip_edges()
	if repo == "" or not repo.contains("/"):
		_remote_release.clear()
		_remote_manifest.clear()
		_emit_snapshot(LauncherState.NO_REPO, "Configure o repositório GitHub (usuario/repo) para checar atualizações.")
		return
	if DisplayServer.get_name() == "headless":
		return
	_last_error = ""
	_remote_release.clear()
	_remote_manifest.clear()
	_emit_snapshot(LauncherState.CHECKING, "Consultando GitHub Releases (%s)..." % repo)
	var url: String = "https://api.github.com/repos/%s/releases/latest" % repo
	var err: int = _api_http.request(url, _build_github_headers(false))
	if err != OK:
		_last_error = "Não foi possível iniciar a requisição HTTP (código %d)." % err
		_emit_snapshot(LauncherState.ERROR, _last_error)

func _on_api_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_last_error = "Falha de rede ao consultar GitHub Releases (erro %d)." % result
		_emit_snapshot(LauncherState.ERROR, _last_error)
		return
	if response_code == 404:
		_last_error = "Nenhuma release publicada ou repositório privado sem token."
		_emit_snapshot(LauncherState.ERROR, _last_error)
		return
	if response_code != 200:
		_last_error = "GitHub retornou HTTP %d ao buscar releases/latest." % response_code
		_emit_snapshot(LauncherState.ERROR, _last_error)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_last_error = "Resposta JSON inválida recebida do GitHub."
		_emit_snapshot(LauncherState.ERROR, _last_error)
		return

	apply_github_release_dict(parsed as Dictionary, true)

func apply_github_release_dict(payload: Dictionary, fetch_manifest_asset: bool = false) -> void:
	var tag_name: String = str(payload.get("tag_name", "")).strip_edges()
	var rem_ver: String = normalize_version_tag(tag_name)
	if rem_ver == "":
		rem_ver = normalize_version_tag(str(payload.get("name", "")))
	var manifest_asset: Dictionary = {}
	var win_zip_asset: Dictionary = {}
	var win_exe_asset: Dictionary = {}
	var apk_asset: Dictionary = {}

	var raw_assets: Variant = payload.get("assets", [])
	if raw_assets is Array:
		for asset_var: Variant in (raw_assets as Array):
			if not (asset_var is Dictionary):
				continue
			var asset: Dictionary = asset_var as Dictionary
			var a_name: String = str(asset.get("name", "")).strip_edges()
			var a_low: String = a_name.to_lower()
			var a_info: Dictionary = {
				"name": a_name,
				"download_url": str(asset.get("browser_download_url", "")).strip_edges(),
				"api_url": str(asset.get("url", "")).strip_edges(),
				"size": int(asset.get("size", 0))
			}
			if a_low == "manifest.json":
				manifest_asset = a_info
			elif a_low.ends_with(".zip") and a_low.contains("windows") and not a_low.contains("launcher"):
				win_zip_asset = a_info
			elif a_low.ends_with(".zip") and win_zip_asset.is_empty() and not a_low.contains("launcher"):
				win_zip_asset = a_info
			elif a_low.ends_with(".exe") and not a_low.contains("launcher"):
				win_exe_asset = a_info
			elif a_low.ends_with(".apk"):
				apk_asset = a_info

	_remote_release = {
		"tag_name": tag_name,
		"version": rem_ver,
		"html_url": str(payload.get("html_url", "")).strip_edges(),
		"body": str(payload.get("body", "")).strip_edges(),
		"published_at": str(payload.get("published_at", "")).strip_edges(),
		"manifest_asset": manifest_asset,
		"windows_zip_asset": win_zip_asset,
		"windows_exe_asset": win_exe_asset,
		"android_apk_asset": apk_asset
	}

	if fetch_manifest_asset and not manifest_asset.is_empty() and DisplayServer.get_name() != "headless":
		var dl_url: String = _pick_asset_url(manifest_asset)
		if dl_url != "":
			var err: int = _manifest_http.request(dl_url, _build_github_headers(str(_settings.get("github_token", "")).strip_edges() != ""))
			if err == OK:
				return

	_finalize_version_evaluation()

func _pick_asset_url(asset: Dictionary) -> String:
	var has_token: bool = str(_settings.get("github_token", "")).strip_edges() != ""
	var api_url: String = str(asset.get("api_url", "")).strip_edges()
	var br_url: String = str(asset.get("download_url", "")).strip_edges()
	if has_token and api_url != "":
		return api_url
	return br_url if br_url != "" else api_url

func _on_manifest_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			apply_remote_manifest_dict(parsed as Dictionary)
			return
	_finalize_version_evaluation()

func apply_remote_manifest_dict(manifest: Dictionary) -> void:
	_remote_manifest = manifest.duplicate(true)
	_finalize_version_evaluation()

func _finalize_version_evaluation() -> void:
	var local_info: Dictionary = get_installed_info()
	var exe_exists: bool = bool(local_info.get("exe_exists", false))
	var local_ver: String = str(local_info.get("installed_version", ""))
	var local_build: int = int(local_info.get("installed_build", 0))

	var rem_ver: String = str(_remote_manifest.get("version", _remote_release.get("version", "")))
	rem_ver = normalize_version_tag(rem_ver)
	var rem_build: int = int(_remote_manifest.get("build_number", 0))

	if not exe_exists:
		_emit_snapshot(LauncherState.NOT_INSTALLED, "Jogo não instalado nesta pasta. Versão disponível: v%s" % rem_ver)
	elif rem_ver != "" and is_remote_newer(local_ver, local_build, rem_ver, rem_build):
		_emit_snapshot(LauncherState.UPDATE_AVAILABLE, "Nova versão v%s disponível (instalado: v%s)!" % [rem_ver, local_ver])
	else:
		_emit_snapshot(LauncherState.UP_TO_DATE, "Você já está na versão mais recente (v%s)." % local_ver)

func start_one_click_update(auto_launch: bool = false) -> void:
	if current_state == LauncherState.DOWNLOADING or current_state == LauncherState.INSTALLING:
		return
	var target_asset: Dictionary = _get_preferred_windows_asset()
	if target_asset.is_empty():
		_last_error = "Nenhum pacote Windows (.zip ou .exe) encontrado nesta release."
		_emit_snapshot(LauncherState.ERROR, _last_error)
		update_finished.emit(false, _last_error)
		return
	var dl_url: String = _pick_asset_url(target_asset)
	if dl_url == "":
		_last_error = "URL de download do build Windows está vazia."
		_emit_snapshot(LauncherState.ERROR, _last_error)
		update_finished.emit(false, _last_error)
		return

	_auto_launch_after_update = auto_launch
	_last_error = ""
	if FileAccess.file_exists(DOWNLOAD_TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DOWNLOAD_TEMP_PATH))
	_download_http.download_file = DOWNLOAD_TEMP_PATH
	var has_token: bool = str(_settings.get("github_token", "")).strip_edges() != ""
	var err: int = _download_http.request(dl_url, _build_github_headers(has_token))
	if err != OK:
		_last_error = "Erro ao iniciar download (código %d)." % err
		_emit_snapshot(LauncherState.ERROR, _last_error)
		update_finished.emit(false, _last_error)
		return

	set_process(true)
	_emit_snapshot(LauncherState.DOWNLOADING, "Baixando %s..." % str(target_asset.get("name", "atualização")))

func _get_preferred_windows_asset() -> Dictionary:
	var z_asset: Variant = _remote_release.get("windows_zip_asset", {})
	if z_asset is Dictionary and not (z_asset as Dictionary).is_empty():
		return z_asset as Dictionary
	var e_asset: Variant = _remote_release.get("windows_exe_asset", {})
	if e_asset is Dictionary and not (e_asset as Dictionary).is_empty():
		return e_asset as Dictionary
	return {}

func _process(_delta: float) -> void:
	if current_state != LauncherState.DOWNLOADING or _download_http == null:
		set_process(false)
		return
	var dl_bytes: int = _download_http.get_downloaded_bytes()
	var total_bytes: int = _download_http.get_body_size()
	if total_bytes <= 0:
		var target_asset: Dictionary = _get_preferred_windows_asset()
		total_bytes = int(target_asset.get("size", 0))
	var ratio: float = clampf(float(dl_bytes) / float(total_bytes), 0.0, 1.0) if total_bytes > 0 else 0.0
	download_progress_changed.emit(dl_bytes, total_bytes, ratio)

func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	set_process(false)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_last_error = "Falha no download da atualização (result=%d, HTTP=%d)." % [result, response_code]
		_emit_snapshot(LauncherState.ERROR, _last_error)
		update_finished.emit(false, _last_error)
		return

	var target_asset: Dictionary = _get_preferred_windows_asset()
	var asset_name: String = str(target_asset.get("name", "")).to_lower()
	var expected_sha: String = ""
	var win_manifest: Variant = _remote_manifest.get("windows", {})
	if win_manifest is Dictionary:
		var wm: Dictionary = win_manifest as Dictionary
		if asset_name.ends_with(".zip"):
			expected_sha = str(wm.get("sha256_zip", "")).strip_edges().to_lower()
		else:
			expected_sha = str(wm.get("sha256_exe", "")).strip_edges().to_lower()

	var ok: bool = install_downloaded_package(DOWNLOAD_TEMP_PATH, asset_name, expected_sha)
	if ok and _auto_launch_after_update:
		_auto_launch_after_update = false
		if launch_game() and DisplayServer.get_name() != "headless":
			get_tree().quit()

func install_downloaded_package(package_path: String, asset_name: String, expected_sha256: String = "") -> bool:
	_emit_snapshot(LauncherState.INSTALLING, "Verificando integridade e instalando atualização...")
	if not FileAccess.file_exists(package_path):
		_last_error = "Arquivo baixado não encontrado para instalação."
		_emit_snapshot(LauncherState.ERROR, _last_error)
		update_finished.emit(false, _last_error)
		return false

	if expected_sha256 != "":
		var actual_sha: String = compute_file_sha256(package_path)
		if actual_sha == "" or actual_sha != expected_sha256.to_lower():
			_last_error = "Checksum SHA-256 inválido! Instalação abortada por segurança."
			_emit_snapshot(LauncherState.ERROR, _last_error)
			update_finished.emit(false, _last_error)
			return false

	var install_dir: String = resolve_install_dir()
	var make_err: int = DirAccess.make_dir_recursive_absolute(install_dir)
	if make_err != OK and not DirAccess.dir_exists_absolute(install_dir):
		_last_error = "Não foi possível criar a pasta de destino: %s" % install_dir
		_emit_snapshot(LauncherState.ERROR, _last_error)
		update_finished.emit(false, _last_error)
		return false

	var installed_ok: bool = false
	if asset_name.to_lower().ends_with(".zip"):
		installed_ok = _extract_zip_safely(package_path, install_dir)
	else:
		var exe_bytes: PackedByteArray = FileAccess.get_file_as_bytes(package_path)
		if exe_bytes.size() < 1024 or exe_bytes[0] != 0x4D or exe_bytes[1] != 0x5A:
			_last_error = "Executável baixado inválido (assinatura PE ausente)."
			_emit_snapshot(LauncherState.ERROR, _last_error)
			update_finished.emit(false, _last_error)
			return false
		installed_ok = _write_file_with_backup(install_dir.path_join(get_game_exe_name()), exe_bytes)

	if FileAccess.file_exists(package_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(package_path))

	if not installed_ok:
		_emit_snapshot(LauncherState.ERROR, _last_error)
		update_finished.emit(false, _last_error)
		return false

	_persist_installed_version_metadata(install_dir)
	_finalize_version_evaluation()
	var msg: String = "Atualização concluída com sucesso!"
	update_finished.emit(true, msg)
	return true

func _extract_zip_safely(zip_path: String, dest_dir: String) -> bool:
	var reader: ZIPReader = ZIPReader.new()
	var open_err: int = reader.open(zip_path)
	if open_err != OK:
		_last_error = "Falha ao abrir pacote ZIP (erro %d)." % open_err
		return false

	var entries: PackedStringArray = reader.get_files()
	var running_exe_name: String = OS.get_executable_path().get_file().to_lower() if OS.has_feature("standalone") else ""
	var wrote_any: bool = false
	for entry: String in entries:
		if entry.ends_with("/") or entry.contains(".."):
			continue
		var rel_clean: String = entry.trim_prefix("./").trim_prefix("/")
		if rel_clean == "":
			continue
		var target_path: String = dest_dir.path_join(rel_clean)
		if running_exe_name != "" and rel_clean.get_file().to_lower() == running_exe_name:
			target_path = dest_dir.path_join(rel_clean + ".pending")
		var parent_dir: String = target_path.get_base_dir()
		if parent_dir != "":
			DirAccess.make_dir_recursive_absolute(parent_dir)
		var data: PackedByteArray = reader.read_file(entry)
		if not _write_file_with_backup(target_path, data):
			reader.close()
			return false
		wrote_any = true

	reader.close()
	if not wrote_any:
		_last_error = "Pacote ZIP não continha arquivos instaláveis."
		return false
	return true

func _write_file_with_backup(target_path: String, bytes: PackedByteArray) -> bool:
	var had_prev: bool = FileAccess.file_exists(target_path)
	var bak_path: String = target_path + ".bak"
	if had_prev:
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var ren_err: int = DirAccess.rename_absolute(target_path, bak_path)
		if ren_err != OK:
			_last_error = "Não foi possível substituir '%s' (feche o jogo caso esteja aberto)." % target_path.get_file()
			return false

	var out_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if out_file == null:
		if had_prev and FileAccess.file_exists(bak_path):
			DirAccess.rename_absolute(bak_path, target_path)
		_last_error = "Erro de permissão ao gravar '%s'." % target_path
		return false
	out_file.store_buffer(bytes)
	out_file.close()

	if had_prev and FileAccess.file_exists(bak_path):
		DirAccess.remove_absolute(bak_path)
	return true

func _persist_installed_version_metadata(install_dir: String) -> void:
	var rem_ver: String = normalize_version_tag(str(_remote_manifest.get("version", _remote_release.get("version", "0.8.0"))))
	var rem_build: int = int(_remote_manifest.get("build_number", 0))
	var v_dict: Dictionary = {
		"product_name": str(_base_config.get("product_name", "Magnata do Pampa")),
		"version": rem_ver,
		"build_number": rem_build,
		"github_repo": str(_settings.get("github_repo", "")).strip_edges(),
		"installed_at": Time.get_datetime_string_from_system(true)
	}
	var json_txt: String = JSON.stringify(v_dict, "\t") + "\n"
	var sidecar: FileAccess = FileAccess.open(install_dir.path_join("version.json"), FileAccess.WRITE)
	if sidecar != null:
		sidecar.store_string(json_txt)
		sidecar.close()
	var fb: FileAccess = FileAccess.open(INSTALLED_FALLBACK_PATH, FileAccess.WRITE)
	if fb != null:
		fb.store_string(json_txt)
		fb.close()

static func compute_file_sha256(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var ctx: HashingContext = HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		file.close()
		return ""
	while not file.eof_reached():
		var chunk: PackedByteArray = file.get_buffer(65536)
		if chunk.size() > 0:
			ctx.update(chunk)
	file.close()
	return ctx.finish().hex_encode().to_lower()

func launch_game() -> bool:
	var info: Dictionary = get_installed_info()
	var exe_path: String = str(info.get("exe_path", ""))
	if not bool(info.get("exe_exists", false)):
		_last_error = "Executável do jogo não encontrado em: %s" % exe_path
		_emit_snapshot(LauncherState.NOT_INSTALLED, _last_error)
		return false
	var pid: int = OS.create_process(exe_path, PackedStringArray())
	if pid <= 0:
		_last_error = "Falha ao iniciar %s" % exe_path
		_emit_snapshot(LauncherState.ERROR, _last_error)
		return false
	_emit_snapshot(LauncherState.UP_TO_DATE, "Magnata do Pampa iniciado (PID %d)!" % pid)
	return true

func _state_to_key(st: LauncherState) -> String:
	match st:
		LauncherState.NO_REPO: return "NO_REPO"
		LauncherState.CHECKING: return "CHECKING"
		LauncherState.NOT_INSTALLED: return "NOT_INSTALLED"
		LauncherState.UPDATE_AVAILABLE: return "UPDATE_AVAILABLE"
		LauncherState.UP_TO_DATE: return "UP_TO_DATE"
		LauncherState.DOWNLOADING: return "DOWNLOADING"
		LauncherState.INSTALLING: return "INSTALLING"
		LauncherState.ERROR: return "ERROR"
		_: return "IDLE"

func _emit_snapshot(st: LauncherState, status_text: String) -> void:
	current_state = st
	var local_info: Dictionary = get_installed_info()
	var apk_asset: Variant = _remote_release.get("android_apk_asset", {})
	var apk_dict: Dictionary = apk_asset as Dictionary if apk_asset is Dictionary else {}
	var win_asset: Dictionary = _get_preferred_windows_asset()
	var rem_ver: String = normalize_version_tag(str(_remote_manifest.get("version", _remote_release.get("version", ""))))
	var rem_build: int = int(_remote_manifest.get("build_number", 0))
	var notes: String = str(_remote_manifest.get("notes", _remote_release.get("body", ""))).strip_edges()

	var snap: Dictionary = {
		"state_key": _state_to_key(st),
		"status_text": status_text,
		"github_repo": str(_settings.get("github_repo", "")).strip_edges(),
		"has_token": str(_settings.get("github_token", "")).strip_edges() != "",
		"install_dir": str(local_info.get("install_dir", "")),
		"exe_path": str(local_info.get("exe_path", "")),
		"exe_exists": bool(local_info.get("exe_exists", false)),
		"installed_version": str(local_info.get("installed_version", "")),
		"installed_build": int(local_info.get("installed_build", 0)),
		"remote_version": rem_ver,
		"remote_build": rem_build,
		"has_update": st == LauncherState.UPDATE_AVAILABLE or st == LauncherState.NOT_INSTALLED,
		"release_notes": notes,
		"html_url": str(_remote_release.get("html_url", "")),
		"win_asset_name": str(win_asset.get("name", "")),
		"win_asset_size": int(win_asset.get("size", 0)),
		"apk_name": str(apk_dict.get("name", "")),
		"apk_url": str(apk_dict.get("download_url", ""))
	}
	state_changed.emit(str(snap["state_key"]), status_text)
	version_info_updated.emit(snap)
