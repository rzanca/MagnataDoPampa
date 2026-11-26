extends "res://ui/GameHUD.gd"

const AndroidProfileScript = preload("res://ui/shared/PlatformProfileAdapter.gd")

var _bound_core_signals: bool = false
var _last_core_state: int = 0
var _last_core_round: int = 1

func _resolve_platform_profile() -> RefCounted:
	return AndroidProfileScript.create_android_profile()

func get_ui_profile_id() -> String:
	return "android"

func bind_core_signals(core_manager: Node) -> void:
	if _bound_core_signals or core_manager == null:
		return
	if core_manager.has_signal("turn_state_changed"):
		core_manager.connect("turn_state_changed", Callable(self, "_on_core_turn_state_changed"))
	if core_manager.has_signal("property_purchased"):
		core_manager.connect("property_purchased", Callable(self, "_on_core_property_purchased"))
	if core_manager.has_signal("match_finished"):
		core_manager.connect("match_finished", Callable(self, "_on_core_match_finished"))
	_bound_core_signals = true

func _on_core_turn_state_changed(state: int, _player_id: int, round_number: int) -> void:
	_last_core_state = state
	_last_core_round = round_number

func _on_core_property_purchased(_player_id: int, _tile_index: int, _price: int) -> void:
	if _btn_deeds_jump != null:
		_btn_deeds_jump.tooltip_text = "Toque para gerenciar escrituras, casas e hipotecas"

func _on_core_match_finished(_victory_info: Dictionary) -> void:
	if _btn_roll != null:
		_btn_roll.disabled = true
