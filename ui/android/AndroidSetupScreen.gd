extends "res://ui/SetupScreen.gd"

const AndroidProfileScript = preload("res://ui/shared/PlatformProfileAdapter.gd")

func _resolve_platform_profile() -> RefCounted:
	return AndroidProfileScript.create_android_profile()

func get_ui_profile_id() -> String:
	return "android"
