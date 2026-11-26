extends "res://ui/SetupScreen.gd"

const DesktopProfileScript = preload("res://ui/shared/PlatformProfileAdapter.gd")

func _resolve_platform_profile() -> RefCounted:
	return DesktopProfileScript.create_desktop_profile()

func get_ui_profile_id() -> String:
	return "desktop"
