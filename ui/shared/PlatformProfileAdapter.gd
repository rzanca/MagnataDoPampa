extends RefCounted

const PROFILE_DESKTOP: String = "desktop"
const PROFILE_ANDROID: String = "android"

var profile_name: String = PROFILE_DESKTOP
var is_mobile: bool = false
var show_keyboard_hints: bool = true

var font_scale: float = 1.0
var button_height_scale: float = 1.0
var viewport_padding: float = 18.0
var panel_gap: float = 16.0
var side_panel_ratio: float = 0.245
var side_panel_min_width: float = 430.0
var side_panel_max_width: float = 520.0
var toast_width_ratio: float = 0.27
var toast_min_width: float = 280.0
var toast_max_width: float = 380.0
var setup_font_scale: float = 1.0
var setup_column_breakpoint: float = 1080.0

static func resolve_is_mobile(tree: SceneTree) -> bool:
	if tree != null and tree.root != null:
		var platform_cfg: Node = tree.root.get_node_or_null("PlatformConfig")
		if platform_cfg != null and platform_cfg.has_method("is_mobile_ui_active"):
			return bool(platform_cfg.call("is_mobile_ui_active"))
	return OS.get_name() == "Android"

static func create_desktop_profile() -> RefCounted:
	var script_res: Script = load("res://ui/shared/PlatformProfileAdapter.gd")
	var adapter: RefCounted = script_res.new()
	adapter.set("profile_name", PROFILE_DESKTOP)
	adapter.set("is_mobile", false)
	adapter.set("show_keyboard_hints", true)
	adapter.set("font_scale", 1.0)
	adapter.set("button_height_scale", 1.0)
	adapter.set("viewport_padding", 18.0)
	adapter.set("panel_gap", 16.0)
	adapter.set("side_panel_ratio", 0.245)
	adapter.set("side_panel_min_width", 430.0)
	adapter.set("side_panel_max_width", 520.0)
	adapter.set("toast_width_ratio", 0.27)
	adapter.set("toast_min_width", 280.0)
	adapter.set("toast_max_width", 380.0)
	adapter.set("setup_font_scale", 1.0)
	adapter.set("setup_column_breakpoint", 1080.0)
	return adapter

static func create_android_profile() -> RefCounted:
	var script_res: Script = load("res://ui/shared/PlatformProfileAdapter.gd")
	var adapter: RefCounted = script_res.new()
	adapter.set("profile_name", PROFILE_ANDROID)
	adapter.set("is_mobile", true)
	adapter.set("show_keyboard_hints", false)
	adapter.set("font_scale", 1.22)
	adapter.set("button_height_scale", 1.28)
	adapter.set("viewport_padding", 14.0)
	adapter.set("panel_gap", 14.0)
	adapter.set("side_panel_ratio", 0.275)
	adapter.set("side_panel_min_width", 490.0)
	adapter.set("side_panel_max_width", 610.0)
	adapter.set("toast_width_ratio", 0.36)
	adapter.set("toast_min_width", 290.0)
	adapter.set("toast_max_width", 400.0)
	adapter.set("setup_font_scale", 1.18)
	adapter.set("setup_column_breakpoint", 1240.0)
	return adapter

static func create_for_mobile_flag(mobile_active: bool) -> RefCounted:
	if mobile_active:
		return create_android_profile()
	return create_desktop_profile()

func compute_side_panel_width(viewport_width: float) -> float:
	var raw_w: float = clampf(viewport_width * side_panel_ratio, side_panel_min_width, side_panel_max_width)
	return minf(raw_w, maxf(300.0, viewport_width * 0.42))

func compute_toast_width(board_width: float) -> float:
	return clampf(board_width * toast_width_ratio, toast_min_width, toast_max_width)

func compute_setup_columns(viewport_width: float) -> int:
	return 1 if viewport_width < setup_column_breakpoint else 2
