extends Control

const LauncherUpdaterScript = preload("res://core/LauncherUpdater.gd")

var _updater: Node = null
var _bold_font: SystemFont = null
var _last_snap: Dictionary = {}

var _lbl_installed_ver: Label
var _lbl_remote_ver: Label
var _lbl_status: Label
var _lbl_dir: Label
var _notes_text: RichTextLabel
var _progress_bar: ProgressBar
var _progress_lbl: Label

var _btn_primary: Button
var _btn_secondary: Button
var _btn_apk: Button
var _btn_check: Button
var _btn_config: Button
var _btn_open_dir: Button

var _cfg_overlay: ColorRect
var _cfg_repo_edit: LineEdit
var _cfg_token_edit: LineEdit
var _cfg_dir_edit: LineEdit

func _ready() -> void:
	_bold_font = SystemFont.new()
	_bold_font.font_names = PackedStringArray(["Segoe UI Semibold", "Arial", "sans-serif"])

	_updater = LauncherUpdaterScript.new()
	_updater.name = "LauncherUpdater"
	add_child(_updater)
	_updater.version_info_updated.connect(_on_version_info_updated)
	_updater.download_progress_changed.connect(_on_download_progress_changed)
	_updater.update_finished.connect(_on_update_finished)

	_build_ui()
	_updater.call("check_for_updates")

func _make_panel_style(bg_hex: String, border_hex: String, radius: int = 12, border_w: int = 1) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(bg_hex)
	sb.border_color = Color(border_hex)
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

func _style_btn(
	btn: Button,
	bg_hex: String,
	hover_hex: String,
	pressed_hex: String,
	border_hex: String,
	fg_col: Color,
	font_sz: int,
	min_sz: Vector2,
	radius: int = 10
) -> void:
	btn.custom_minimum_size = min_sz
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _bold_font != null:
		btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", fg_col)
	btn.add_theme_color_override("font_hover_color", fg_col)
	btn.add_theme_color_override("font_pressed_color", fg_col)
	btn.add_theme_stylebox_override("normal", _make_panel_style(bg_hex, border_hex, radius, 1))
	btn.add_theme_stylebox_override("hover", _make_panel_style(hover_hex, "#FFE9A8", radius, 1))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(pressed_hex, "#FFF3C4", radius, 2))
	btn.add_theme_stylebox_override("disabled", _make_panel_style("#18211C", "#304037", radius, 1))

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#09110D")
	add_child(bg)

	var outer: MarginContainer = MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 24)
	outer.add_theme_constant_override("margin_right", 24)
	outer.add_theme_constant_override("margin_top", 22)
	outer.add_theme_constant_override("margin_bottom", 22)
	add_child(outer)

	var root_card: PanelContainer = PanelContainer.new()
	var root_style: StyleBoxFlat = _make_panel_style("#101A14", "#D4AF37", 16, 2)
	root_style.shadow_size = 22
	root_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	root_card.add_theme_stylebox_override("panel", root_style)
	outer.add_child(root_card)

	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 26)
	card_margin.add_theme_constant_override("margin_right", 26)
	card_margin.add_theme_constant_override("margin_top", 22)
	card_margin.add_theme_constant_override("margin_bottom", 22)
	root_card.add_child(card_margin)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	card_margin.add_child(vb)

	# --- Header ---
	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vb.add_child(hdr)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	hdr.add_child(title_box)

	var title_lbl: Label = Label.new()
	title_lbl.text = "MAGNATA DO PAMPA — LAUNCHER"
	if _bold_font != null:
		title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color("#F5D06F"))
	title_box.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "Verificação automática de build e atualização em 1 clique via GitHub Releases"
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color("#9BB8A8"))
	title_box.add_child(sub_lbl)

	_btn_check = Button.new()
	_btn_check.text = "Verificar"
	_style_btn(_btn_check, "#1A2E24", "#244032", "#12211A", "#52B788", Color("#E6FFF1"), 14, Vector2(118.0, 40.0), 10)
	_btn_check.pressed.connect(func() -> void: _updater.call("check_for_updates"))
	hdr.add_child(_btn_check)

	_btn_config = Button.new()
	_btn_config.text = "Configurar Repo"
	_style_btn(_btn_config, "#1C2923", "#283B32", "#141D19", "#C9A227", Color("#F8E5A8"), 14, Vector2(146.0, 40.0), 10)
	_btn_config.pressed.connect(_open_config_modal)
	hdr.add_child(_btn_config)

	# --- Cards de Versao Instalada vs Remota ---
	var ver_row: HBoxContainer = HBoxContainer.new()
	ver_row.add_theme_constant_override("separation", 14)
	vb.add_child(ver_row)

	var local_card: PanelContainer = PanelContainer.new()
	local_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local_card.add_theme_stylebox_override("panel", _make_panel_style("#15241C", "#335443", 12, 1))
	ver_row.add_child(local_card)
	var lm: MarginContainer = MarginContainer.new()
	lm.add_theme_constant_override("margin_left", 16)
	lm.add_theme_constant_override("margin_right", 16)
	lm.add_theme_constant_override("margin_top", 12)
	lm.add_theme_constant_override("margin_bottom", 12)
	local_card.add_child(lm)
	var lvb: VBoxContainer = VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 4)
	lm.add_child(lvb)
	var l_hdr: Label = Label.new()
	l_hdr.text = "VERSÃO INSTALADA"
	l_hdr.add_theme_font_size_override("font_size", 11)
	l_hdr.add_theme_color_override("font_color", Color("#8EAD9C"))
	lvb.add_child(l_hdr)
	_lbl_installed_ver = Label.new()
	_lbl_installed_ver.text = "-"
	if _bold_font != null:
		_lbl_installed_ver.add_theme_font_override("font", _bold_font)
	_lbl_installed_ver.add_theme_font_size_override("font_size", 20)
	_lbl_installed_ver.add_theme_color_override("font_color", Color("#F2F7F4"))
	lvb.add_child(_lbl_installed_ver)

	var remote_card: PanelContainer = PanelContainer.new()
	remote_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remote_card.add_theme_stylebox_override("panel", _make_panel_style("#15241C", "#335443", 12, 1))
	ver_row.add_child(remote_card)
	var rm: MarginContainer = MarginContainer.new()
	rm.add_theme_constant_override("margin_left", 16)
	rm.add_theme_constant_override("margin_right", 16)
	rm.add_theme_constant_override("margin_top", 12)
	rm.add_theme_constant_override("margin_bottom", 12)
	remote_card.add_child(rm)
	var rvb: VBoxContainer = VBoxContainer.new()
	rvb.add_theme_constant_override("separation", 4)
	rm.add_child(rvb)
	var r_hdr: Label = Label.new()
	r_hdr.text = "ÚLTIMA RELEASE (GITHUB)"
	r_hdr.add_theme_font_size_override("font_size", 11)
	r_hdr.add_theme_color_override("font_color", Color("#8EAD9C"))
	rvb.add_child(r_hdr)
	_lbl_remote_ver = Label.new()
	_lbl_remote_ver.text = "-"
	if _bold_font != null:
		_lbl_remote_ver.add_theme_font_override("font", _bold_font)
	_lbl_remote_ver.add_theme_font_size_override("font_size", 20)
	_lbl_remote_ver.add_theme_color_override("font_color", Color("#F5D06F"))
	rvb.add_child(_lbl_remote_ver)

	# --- Pasta de Instalacao + Status ---
	var dir_row: HBoxContainer = HBoxContainer.new()
	dir_row.add_theme_constant_override("separation", 10)
	vb.add_child(dir_row)

	_lbl_dir = Label.new()
	_lbl_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_dir.clip_text = true
	_lbl_dir.add_theme_font_size_override("font_size", 12)
	_lbl_dir.add_theme_color_override("font_color", Color("#8BA396"))
	dir_row.add_child(_lbl_dir)

	_btn_open_dir = Button.new()
	_btn_open_dir.text = "Abrir Pasta"
	_style_btn(_btn_open_dir, "#16241D", "#22362C", "#0F1914", "#466857", Color("#D8EAE0"), 12, Vector2(106.0, 30.0), 8)
	_btn_open_dir.pressed.connect(_on_open_dir_pressed)
	dir_row.add_child(_btn_open_dir)

	_btn_apk = Button.new()
	_btn_apk.text = "Baixar APK Android"
	_btn_apk.visible = false
	_style_btn(_btn_apk, "#182B3A", "#223E54", "#111F2A", "#4DA6D6", Color("#DDF2FF"), 12, Vector2(158.0, 30.0), 8)
	_btn_apk.pressed.connect(_on_apk_pressed)
	dir_row.add_child(_btn_apk)

	# --- Notas da Release ---
	var notes_panel: PanelContainer = PanelContainer.new()
	notes_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_panel.add_theme_stylebox_override("panel", _make_panel_style("#0C1510", "#263D31", 12, 1))
	vb.add_child(notes_panel)

	var nm: MarginContainer = MarginContainer.new()
	nm.add_theme_constant_override("margin_left", 14)
	nm.add_theme_constant_override("margin_right", 14)
	nm.add_theme_constant_override("margin_top", 12)
	nm.add_theme_constant_override("margin_bottom", 12)
	notes_panel.add_child(nm)

	_notes_text = RichTextLabel.new()
	_notes_text.fit_content = false
	_notes_text.scroll_active = true
	_notes_text.add_theme_font_size_override("normal_font_size", 14)
	_notes_text.add_theme_color_override("default_color", Color("#D7E7DD"))
	nm.add_child(_notes_text)

	# --- Progresso e Status ---
	var prog_box: VBoxContainer = VBoxContainer.new()
	prog_box.add_theme_constant_override("separation", 6)
	vb.add_child(prog_box)

	var st_row: HBoxContainer = HBoxContainer.new()
	prog_box.add_child(st_row)

	_lbl_status = Label.new()
	_lbl_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_status.add_theme_font_size_override("font_size", 14)
	_lbl_status.add_theme_color_override("font_color", Color("#DDF0E4"))
	st_row.add_child(_lbl_status)

	_progress_lbl = Label.new()
	_progress_lbl.text = ""
	_progress_lbl.add_theme_font_size_override("font_size", 13)
	_progress_lbl.add_theme_color_override("font_color", Color("#F5D06F"))
	st_row.add_child(_progress_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0.0, 14.0)
	_progress_bar.add_theme_stylebox_override("background", _make_panel_style("#0B130E", "#284033", 7, 1))
	_progress_bar.add_theme_stylebox_override("fill", _make_panel_style("#22C55E", "#86EFAC", 7, 0))
	prog_box.add_child(_progress_bar)

	# --- Acoes Principais ---
	var cta_row: HBoxContainer = HBoxContainer.new()
	cta_row.alignment = BoxContainer.ALIGNMENT_END
	cta_row.add_theme_constant_override("separation", 12)
	vb.add_child(cta_row)

	_btn_secondary = Button.new()
	_btn_secondary.text = "Só Atualizar"
	_btn_secondary.visible = false
	_style_btn(_btn_secondary, "#1B3328", "#264738", "#12241C", "#52B788", Color("#E4FFF0"), 15, Vector2(180.0, 52.0), 12)
	_btn_secondary.pressed.connect(func() -> void: _updater.call("start_one_click_update", false))
	cta_row.add_child(_btn_secondary)

	_btn_primary = Button.new()
	_btn_primary.text = "JOGAR"
	_style_btn(_btn_primary, "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), 18, Vector2(310.0, 52.0), 12)
	_btn_primary.pressed.connect(_on_primary_pressed)
	cta_row.add_child(_btn_primary)

	_build_config_modal()

func _build_config_modal() -> void:
	_cfg_overlay = ColorRect.new()
	_cfg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cfg_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	_cfg_overlay.visible = false
	add_child(_cfg_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cfg_overlay.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(540.0, 0.0)
	card.add_theme_stylebox_override("panel", _make_panel_style("#111D16", "#D4AF37", 16, 2))
	center.add_child(card)

	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	card.add_child(m)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	m.add_child(vb)

	var hdr: Label = Label.new()
	hdr.text = "CONFIGURAR ORIGEM NO GITHUB RELEASES"
	if _bold_font != null:
		hdr.add_theme_font_override("font", _bold_font)
	hdr.add_theme_font_size_override("font_size", 17)
	hdr.add_theme_color_override("font_color", Color("#F5D06F"))
	vb.add_child(hdr)

	var repo_lbl: Label = Label.new()
	repo_lbl.text = "Repositório GitHub (usuario/repositorio):"
	repo_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(repo_lbl)

	_cfg_repo_edit = LineEdit.new()
	_cfg_repo_edit.placeholder_text = "ex.: raizadev/magnata-do-pampa"
	_cfg_repo_edit.custom_minimum_size = Vector2(0.0, 38.0)
	vb.add_child(_cfg_repo_edit)

	var tok_lbl: Label = Label.new()
	tok_lbl.text = "Token GitHub PAT (opcional — apenas se o repositório for privado):"
	tok_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(tok_lbl)

	_cfg_token_edit = LineEdit.new()
	_cfg_token_edit.placeholder_text = "ghp_... (deixe vazio se o repositório for público)"
	_cfg_token_edit.secret = true
	_cfg_token_edit.custom_minimum_size = Vector2(0.0, 38.0)
	vb.add_child(_cfg_token_edit)

	var dir_lbl: Label = Label.new()
	dir_lbl.text = "Pasta personalizada do jogo (opcional):"
	dir_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(dir_lbl)

	_cfg_dir_edit = LineEdit.new()
	_cfg_dir_edit.placeholder_text = "Vazio = usar a mesma pasta do Launcher"
	_cfg_dir_edit.custom_minimum_size = Vector2(0.0, 38.0)
	vb.add_child(_cfg_dir_edit)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vb.add_child(btn_row)

	var btn_cancel: Button = Button.new()
	btn_cancel.text = "Cancelar"
	_style_btn(btn_cancel, "#212D26", "#2E3F35", "#161E19", "#556E60", Color("#DDEAE2"), 14, Vector2(120.0, 40.0), 10)
	btn_cancel.pressed.connect(func() -> void: _cfg_overlay.visible = false)
	btn_row.add_child(btn_cancel)

	var btn_save: Button = Button.new()
	btn_save.text = "Salvar e Verificar"
	_style_btn(btn_save, "#214F38", "#2B694A", "#173828", "#52B788", Color("#EAFFF3"), 14, Vector2(180.0, 40.0), 10)
	btn_save.pressed.connect(_on_save_config_pressed)
	btn_row.add_child(btn_save)

func _open_config_modal() -> void:
	var cfg: Dictionary = _updater.call("get_settings")
	_cfg_repo_edit.text = str(cfg.get("github_repo", ""))
	_cfg_token_edit.text = str(cfg.get("github_token", ""))
	_cfg_dir_edit.text = str(cfg.get("custom_install_dir", ""))
	_cfg_overlay.visible = true

func _on_save_config_pressed() -> void:
	_updater.call("save_settings", _cfg_repo_edit.text, _cfg_token_edit.text, _cfg_dir_edit.text)
	_cfg_overlay.visible = false
	_updater.call("check_for_updates")

func _on_version_info_updated(snap: Dictionary) -> void:
	_last_snap = snap
	var st_key: String = str(snap.get("state_key", "IDLE"))
	var exe_exists: bool = bool(snap.get("exe_exists", false))
	var inst_ver: String = str(snap.get("installed_version", ""))
	var inst_build: int = int(snap.get("installed_build", 0))
	var rem_ver: String = str(snap.get("remote_version", ""))
	var rem_build: int = int(snap.get("remote_build", 0))

	if not exe_exists:
		_lbl_installed_ver.text = "Não instalado"
	elif inst_build > 0:
		_lbl_installed_ver.text = "v%s (build %d)" % [inst_ver, inst_build]
	else:
		_lbl_installed_ver.text = "v%s" % inst_ver

	if rem_ver == "":
		_lbl_remote_ver.text = "Aguardando repositório" if st_key == "NO_REPO" else "Indisponível"
	elif rem_build > 0:
		_lbl_remote_ver.text = "v%s (build %d)" % [rem_ver, rem_build]
	else:
		_lbl_remote_ver.text = "v%s" % rem_ver

	_lbl_dir.text = "Pasta: %s" % str(snap.get("install_dir", ""))
	_lbl_status.text = str(snap.get("status_text", ""))

	var notes: String = str(snap.get("release_notes", ""))
	if notes != "":
		_notes_text.text = notes
	elif st_key == "NO_REPO":
		_notes_text.text = "Clique em 'Configurar Repo' acima e informe usuario/repositorio do GitHub para ativar a checagem automática e o update em 1 clique."
	else:
		_notes_text.text = "Nenhuma nota de lançamento informada para esta release."

	var apk_url: String = str(snap.get("apk_url", ""))
	_btn_apk.visible = apk_url != ""

	var is_busy: bool = (st_key == "CHECKING" or st_key == "DOWNLOADING" or st_key == "INSTALLING")
	_btn_check.disabled = is_busy
	_btn_config.disabled = is_busy

	if st_key == "DOWNLOADING":
		_btn_primary.text = "BAIXANDO..."
		_btn_primary.disabled = true
		_btn_secondary.visible = false
	elif st_key == "INSTALLING":
		_btn_primary.text = "INSTALANDO..."
		_btn_primary.disabled = true
		_btn_secondary.visible = false
	elif st_key == "UPDATE_AVAILABLE":
		_btn_primary.text = "ATUALIZAR E JOGAR (v%s)" % rem_ver
		_btn_primary.disabled = false
		_btn_secondary.visible = true
		_btn_secondary.text = "Só Atualizar"
		_btn_secondary.disabled = false
		_progress_bar.value = 0.0
		_progress_lbl.text = ""
	elif st_key == "NOT_INSTALLED":
		_btn_primary.text = "BAIXAR E INSTALAR (v%s)" % rem_ver
		_btn_primary.disabled = (rem_ver == "")
		_btn_secondary.visible = false
		_progress_bar.value = 0.0
		_progress_lbl.text = ""
	else:
		_btn_primary.text = "JOGAR MAGNATA DO PAMPA" if exe_exists else "CONFIGURAR REPO"
		_btn_primary.disabled = is_busy
		_btn_secondary.visible = false
		if st_key == "UP_TO_DATE":
			_progress_bar.value = 100.0
			_progress_lbl.text = "Pronto"
		elif st_key != "DOWNLOADING":
			_progress_bar.value = 0.0
			_progress_lbl.text = ""

func _on_download_progress_changed(downloaded_bytes: int, total_bytes: int, ratio: float) -> void:
	_progress_bar.value = ratio * 100.0
	var dl_mb: float = float(downloaded_bytes) / 1048576.0
	if total_bytes > 0:
		var tot_mb: float = float(total_bytes) / 1048576.0
		_progress_lbl.text = "%.1f / %.1f MB (%d%%)" % [dl_mb, tot_mb, roundi(ratio * 100.0)]
	else:
		_progress_lbl.text = "%.1f MB" % dl_mb

func _on_update_finished(success: bool, _message: String) -> void:
	if success:
		_progress_bar.value = 100.0
		_progress_lbl.text = "100%"

func _on_primary_pressed() -> void:
	var st_key: String = str(_last_snap.get("state_key", "IDLE"))
	if st_key == "UPDATE_AVAILABLE":
		_updater.call("start_one_click_update", true)
	elif st_key == "NOT_INSTALLED":
		_updater.call("start_one_click_update", false)
	elif bool(_last_snap.get("exe_exists", false)):
		_updater.call("launch_game")
	else:
		_open_config_modal()

func _on_open_dir_pressed() -> void:
	var dir_path: String = str(_last_snap.get("install_dir", ""))
	if dir_path != "":
		OS.shell_open(dir_path)

func _on_apk_pressed() -> void:
	var apk_url: String = str(_last_snap.get("apk_url", ""))
	if apk_url != "":
		OS.shell_open(apk_url)
