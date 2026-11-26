extends Node

const ENV_FORCE_MOBILE: String = "MAGNATA_FORCE_MOBILE"

@export var force_mobile_ui: bool = false

var _is_mobile_cached: bool = false


func _ready() -> void:
	_recompute_platform_flags()


func is_android_runtime() -> bool:
	return OS.get_name() == "Android"


func is_mobile_ui_active() -> bool:
	_recompute_platform_flags()
	return _is_mobile_cached


func is_desktop_ui_active() -> bool:
	return not is_mobile_ui_active()


func set_force_mobile_ui(enabled: bool) -> void:
	force_mobile_ui = enabled
	_recompute_platform_flags()


func get_platform_profile_name() -> String:
	if is_mobile_ui_active():
		return "android"
	return "desktop"


func _recompute_platform_flags() -> void:
	var env_value: String = OS.get_environment(ENV_FORCE_MOBILE).strip_edges().to_lower()
	var env_forces_mobile: bool = env_value in ["1", "true", "yes", "android", "mobile"]
	_is_mobile_cached = is_android_runtime() or force_mobile_ui or env_forces_mobile