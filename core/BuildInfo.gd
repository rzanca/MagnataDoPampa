extends RefCounted

const VERSION_FILE_PATH: String = "res://data/version.json"

static func load_version_info(path: String = VERSION_FILE_PATH) -> Dictionary:
	var fallback: Dictionary = {
		"product_name": "Magnata do Pampa",
		"version": "0.8.0",
		"build_number": 8,
		"channel": "stable",
		"github_repo": "",
		"release_notes": "",
		"built_at": "",
		"git_commit": ""
	}
	if not FileAccess.file_exists(path):
		return fallback
	var raw_text: String = FileAccess.get_file_as_string(path)
	if raw_text.strip_edges() == "":
		return fallback
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		var merged: Dictionary = fallback.duplicate(true)
		var src: Dictionary = parsed as Dictionary
		for key_var: Variant in src.keys():
			merged[str(key_var)] = src[key_var]
		return merged
	return fallback

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

static func get_display_version(info: Dictionary = {}) -> String:
	var data: Dictionary = info if not info.is_empty() else load_version_info()
	var ver_str: String = normalize_version_tag(str(data.get("version", "0.8.0")))
	if ver_str == "":
		ver_str = "0.8.0"
	var b_num: int = int(data.get("build_number", 0))
	if b_num > 0:
		return "v%s (build %d)" % [ver_str, b_num]
	return "v%s" % ver_str

static func parse_github_release_payload(payload: Dictionary, current_ver: String, current_build: int = 0) -> Dictionary:
	var tag_name: String = str(payload.get("tag_name", "")).strip_edges()
	var remote_ver: String = normalize_version_tag(tag_name)
	if remote_ver == "":
		remote_ver = normalize_version_tag(str(payload.get("name", "")))
	var html_url: String = str(payload.get("html_url", "")).strip_edges()
	var body_text: String = str(payload.get("body", "")).strip_edges()
	var published_at: String = str(payload.get("published_at", "")).strip_edges()

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
			elif a_low.ends_with(".zip") and a_low.contains("windows"):
				win_zip_asset = a_info
			elif a_low.ends_with(".zip") and win_zip_asset.is_empty() and not a_low.contains("launcher"):
				win_zip_asset = a_info
			elif a_low.ends_with(".exe") and not a_low.contains("launcher"):
				win_exe_asset = a_info
			elif a_low.ends_with(".apk"):
				apk_asset = a_info

	var has_update: bool = remote_ver != "" and is_remote_newer(current_ver, current_build, remote_ver, 0)
	return {
		"tag_name": tag_name,
		"version": remote_ver,
		"html_url": html_url,
		"body": body_text,
		"published_at": published_at,
		"has_update": has_update,
		"manifest_asset": manifest_asset,
		"windows_zip_asset": win_zip_asset,
		"windows_exe_asset": win_exe_asset,
		"android_apk_asset": apk_asset
	}
