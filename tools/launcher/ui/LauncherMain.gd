extends Control

const LauncherUpdaterScript = preload("res://core/LauncherUpdater.gd")

var _updater: Node = null
var _bold_font: SystemFont = null
var _last_snap: Dictionary = {}
var _emblem_tex: Texture2D = null
var _banner_tex: Texture2D = null

var _lbl_installed_ver: Label
var _lbl_remote_ver: Label
var _lbl_status: Label
var _notes_text: RichTextLabel
var _prog_wrap: VBoxContainer
var _progress_bar: ProgressBar
var _progress_lbl: Label

var _btn_primary: Button
var _btn_secondary: Button
var _btn_apk: Button
var _btn_check: Button
var _btn_open_dir: Button

func _ready() -> void:
	_bold_font = SystemFont.new()
	_bold_font.font_names = PackedStringArray(["Segoe UI Semibold", "Arial", "sans-serif"])
	_emblem_tex = _load_tex_safe("res://assets/brand/magnata_emblem.png")
	_banner_tex = _load_tex_safe("res://assets/brand/magnata_banner.jpg")

	_updater = LauncherUpdaterScript.new()
	_updater.name = "LauncherUpdater"
	add_child(_updater)
	_updater.version_info_updated.connect(_on_version_info_updated)
	_updater.download_progress_changed.connect(_on_download_progress_changed)
	_updater.update_finished.connect(_on_update_finished)

	_build_ui()
	_updater.call("check_for_updates")

func _load_tex_safe(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			return res as Texture2D
	var abs_p: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_p):
		var img: Image = Image.load_from_file(abs_p)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

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

	if _banner_tex != null:
		var banner_bg: TextureRect = TextureRect.new()
		banner_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		banner_bg.texture = _banner_tex
		banner_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		banner_bg.modulate = Color(1.0, 1.0, 1.0, 0.34)
		banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(banner_bg)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.035, 0.065, 0.048, 0.80)
	add_child(bg)

	var outer: MarginContainer = MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 20)
	outer.add_theme_constant_override("margin_right", 20)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 18)
	add_child(outer)

	var root_card: PanelContainer = PanelContainer.new()
	root_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root_style: StyleBoxFlat = _make_panel_style("#0F1914", "#D4AF37", 16, 2)
	root_style.bg_color = Color(0.06, 0.10, 0.08, 0.94)
	root_style.shadow_size = 20
	root_style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	root_card.add_theme_stylebox_override("panel", root_style)
	outer.add_child(root_card)

	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 24)
	card_margin.add_theme_constant_override("margin_right", 24)
	card_margin.add_theme_constant_override("margin_top", 20)
	card_margin.add_theme_constant_override("margin_bottom", 20)
	root_card.add_child(card_margin)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card_margin.add_child(vb)

	# --- Header com Brasao Oficial ---
	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 14)
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hdr)

	if _emblem_tex != null:
		var emb_rect: TextureRect = TextureRect.new()
		emb_rect.texture = _emblem_tex
		emb_rect.custom_minimum_size = Vector2(56.0, 56.0)
		emb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hdr.add_child(emb_rect)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	hdr.add_child(title_box)

	var title_lbl: Label = Label.new()
	title_lbl.text = "MAGNATA DO PAMPA"
	if _bold_font != null:
		title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color("#F5D06F"))
	title_box.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "MODO CLÁSSICO  •  CENTRAL DE ATUALIZAÇÃO"
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color("#9BB8A8"))
	title_box.add_child(sub_lbl)

	_btn_check = Button.new()
	_btn_check.text = "Verificar"
	_btn_check.tooltip_text = "Verificar novamente no GitHub Releases"
	_style_btn(_btn_check, "#172A20", "#223D2F", "#101E17", "#52B788", Color("#E6FFF1"), 13, Vector2(114.0, 38.0), 10)
	_btn_check.pressed.connect(func() -> void: _updater.call("check_for_updates"))
	hdr.add_child(_btn_check)

	# --- Cards Compactos de Versao ---
	var ver_row: HBoxContainer = HBoxContainer.new()
	ver_row.add_theme_constant_override("separation", 12)
	vb.add_child(ver_row)

	var local_card: PanelContainer = PanelContainer.new()
	local_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local_card.add_theme_stylebox_override("panel", _make_panel_style("#13211A", "#325242", 10, 1))
	ver_row.add_child(local_card)
	var lm: MarginContainer = MarginContainer.new()
	lm.add_theme_constant_override("margin_left", 14)
	lm.add_theme_constant_override("margin_right", 14)
	lm.add_theme_constant_override("margin_top", 9)
	lm.add_theme_constant_override("margin_bottom", 9)
	local_card.add_child(lm)
	var lvb: VBoxContainer = VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 2)
	lm.add_child(lvb)
	var l_hdr: Label = Label.new()
	l_hdr.text = "VERSÃO INSTALADA"
	l_hdr.add_theme_font_size_override("font_size", 10)
	l_hdr.add_theme_color_override("font_color", Color("#8EAD9C"))
	lvb.add_child(l_hdr)
	_lbl_installed_ver = Label.new()
	_lbl_installed_ver.text = "-"
	if _bold_font != null:
		_lbl_installed_ver.add_theme_font_override("font", _bold_font)
	_lbl_installed_ver.add_theme_font_size_override("font_size", 17)
	_lbl_installed_ver.add_theme_color_override("font_color", Color("#F2F7F4"))
	lvb.add_child(_lbl_installed_ver)

	var remote_card: PanelContainer = PanelContainer.new()
	remote_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remote_card.add_theme_stylebox_override("panel", _make_panel_style("#13211A", "#325242", 10, 1))
	ver_row.add_child(remote_card)
	var rm: MarginContainer = MarginContainer.new()
	rm.add_theme_constant_override("margin_left", 14)
	rm.add_theme_constant_override("margin_right", 14)
	rm.add_theme_constant_override("margin_top", 9)
	rm.add_theme_constant_override("margin_bottom", 9)
	remote_card.add_child(rm)
	var rvb: VBoxContainer = VBoxContainer.new()
	rvb.add_theme_constant_override("separation", 2)
	rm.add_child(rvb)
	var r_hdr: Label = Label.new()
	r_hdr.text = "ÚLTIMA RELEASE"
	r_hdr.add_theme_font_size_override("font_size", 10)
	r_hdr.add_theme_color_override("font_color", Color("#8EAD9C"))
	rvb.add_child(r_hdr)
	_lbl_remote_ver = Label.new()
	_lbl_remote_ver.text = "-"
	if _bold_font != null:
		_lbl_remote_ver.add_theme_font_override("font", _bold_font)
	_lbl_remote_ver.add_theme_font_size_override("font_size", 17)
	_lbl_remote_ver.add_theme_color_override("font_color", Color("#F5D06F"))
	rvb.add_child(_lbl_remote_ver)

	# --- Notas da Release ---
	var notes_panel: PanelContainer = PanelContainer.new()
	notes_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_panel.add_theme_stylebox_override("panel", _make_panel_style("#0B140F", "#253B2F", 10, 1))
	vb.add_child(notes_panel)

	var nm: MarginContainer = MarginContainer.new()
	nm.add_theme_constant_override("margin_left", 14)
	nm.add_theme_constant_override("margin_right", 14)
	nm.add_theme_constant_override("margin_top", 10)
	nm.add_theme_constant_override("margin_bottom", 10)
	notes_panel.add_child(nm)

	var notes_vb: VBoxContainer = VBoxContainer.new()
	notes_vb.add_theme_constant_override("separation", 6)
	nm.add_child(notes_vb)

	var notes_hdr: Label = Label.new()
	notes_hdr.text = "NOVIDADES DESTA VERSÃO"
	if _bold_font != null:
		notes_hdr.add_theme_font_override("font", _bold_font)
	notes_hdr.add_theme_font_size_override("font_size", 11)
	notes_hdr.add_theme_color_override("font_color", Color("#C9A227"))
	notes_vb.add_child(notes_hdr)

	_notes_text = RichTextLabel.new()
	_notes_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes_text.fit_content = false
	_notes_text.scroll_active = true
	_notes_text.add_theme_font_size_override("normal_font_size", 13)
	_notes_text.add_theme_color_override("default_color", Color("#D7E7DD"))
	notes_vb.add_child(_notes_text)

	# --- Barra de Progresso (visivel apenas em download/instalacao) ---
	_prog_wrap = VBoxContainer.new()
	_prog_wrap.visible = false
	_prog_wrap.add_theme_constant_override("separation", 5)
	vb.add_child(_prog_wrap)

	var prog_top: HBoxContainer = HBoxContainer.new()
	_prog_wrap.add_child(prog_top)

	var prog_title: Label = Label.new()
	prog_title.text = "Transferindo atualização..."
	prog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_title.add_theme_font_size_override("font_size", 12)
	prog_title.add_theme_color_override("font_color", Color("#CFE5D8"))
	prog_top.add_child(prog_title)

	_progress_lbl = Label.new()
	_progress_lbl.text = ""
	_progress_lbl.add_theme_font_size_override("font_size", 12)
	_progress_lbl.add_theme_color_override("font_color", Color("#F5D06F"))
	prog_top.add_child(_progress_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_progress_bar.add_theme_stylebox_override("background", _make_panel_style("#0A120E", "#284033", 5, 1))
	_progress_bar.add_theme_stylebox_override("fill", _make_panel_style("#22C55E", "#86EFAC", 5, 0))
	_prog_wrap.add_child(_progress_bar)

	# --- Rodape Limpo e CTA ---
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 10)
	vb.add_child(footer)

	var left_foot: VBoxContainer = VBoxContainer.new()
	left_foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_foot.add_theme_constant_override("separation", 6)
	footer.add_child(left_foot)

	_lbl_status = Label.new()
	_lbl_status.text = ""
	_lbl_status.clip_text = true
	_lbl_status.add_theme_font_size_override("font_size", 13)
	_lbl_status.add_theme_color_override("font_color", Color("#CFE6D8"))
	left_foot.add_child(_lbl_status)

	var util_row: HBoxContainer = HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 8)
	left_foot.add_child(util_row)

	_btn_open_dir = Button.new()
	_btn_open_dir.text = "Pasta do Jogo"
	_style_btn(_btn_open_dir, "#15221B", "#20342A", "#0E1712", "#416151", Color("#CFE3D8"), 12, Vector2(114.0, 30.0), 8)
	_btn_open_dir.pressed.connect(_on_open_dir_pressed)
	util_row.add_child(_btn_open_dir)

	_btn_apk = Button.new()
	_btn_apk.text = "APK Android"
	_btn_apk.visible = false
	_style_btn(_btn_apk, "#172B3B", "#213E54", "#101E29", "#4DA6D6", Color("#DDF2FF"), 12, Vector2(112.0, 30.0), 8)
	_btn_apk.pressed.connect(_on_apk_pressed)
	util_row.add_child(_btn_apk)

	_btn_secondary = Button.new()
	_btn_secondary.text = "Só Atualizar"
	_btn_secondary.visible = false
	_style_btn(_btn_secondary, "#1B3328", "#264738", "#12241C", "#52B788", Color("#E4FFF0"), 14, Vector2(138.0, 48.0), 11)
	_btn_secondary.pressed.connect(func() -> void: _updater.call("start_one_click_update", false))
	footer.add_child(_btn_secondary)

	_btn_primary = Button.new()
	_btn_primary.text = "JOGAR"
	_style_btn(_btn_primary, "#E5BE52", "#F6D472", "#CCA53A", "#FFF2C6", Color("#101713"), 17, Vector2(246.0, 48.0), 11)
	_btn_primary.pressed.connect(_on_primary_pressed)
	footer.add_child(_btn_primary)

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
		_lbl_remote_ver.text = "Verificando..." if st_key == "CHECKING" else "Indisponível"
	elif rem_build > 0:
		_lbl_remote_ver.text = "v%s (build %d)" % [rem_ver, rem_build]
	else:
		_lbl_remote_ver.text = "v%s" % rem_ver

	_lbl_status.text = str(snap.get("status_text", ""))

	var notes: String = str(snap.get("release_notes", ""))
	_notes_text.text = notes if notes != "" else "Modo Clássico completo. Clique em JOGAR para iniciar a partida."

	var apk_url: String = str(snap.get("apk_url", ""))
	_btn_apk.visible = apk_url != ""

	var is_busy: bool = (st_key == "CHECKING" or st_key == "DOWNLOADING" or st_key == "INSTALLING")
	_btn_check.disabled = is_busy
	_prog_wrap.visible = (st_key == "DOWNLOADING" or st_key == "INSTALLING")

	if st_key == "DOWNLOADING":
		_btn_primary.text = "BAIXANDO..."
		_btn_primary.disabled = true
		_btn_secondary.visible = false
	elif st_key == "INSTALLING":
		_btn_primary.text = "INSTALANDO..."
		_btn_primary.disabled = true
		_btn_secondary.visible = false
		_progress_bar.value = 100.0
		_progress_lbl.text = "Finalizando..."
	elif st_key == "UPDATE_AVAILABLE":
		_btn_primary.text = "ATUALIZAR E JOGAR"
		_btn_primary.disabled = false
		_btn_secondary.visible = true
		_btn_secondary.disabled = false
	elif st_key == "NOT_INSTALLED":
		_btn_primary.text = "BAIXAR E INSTALAR"
		_btn_primary.disabled = (rem_ver == "")
		_btn_secondary.visible = false
	else:
		_btn_primary.text = "JOGAR"
		_btn_primary.disabled = is_busy or (not exe_exists)
		_btn_secondary.visible = false

func _on_download_progress_changed(downloaded_bytes: int, total_bytes: int, ratio: float) -> void:
	_prog_wrap.visible = true
	_progress_bar.value = ratio * 100.0
	var dl_mb: float = float(downloaded_bytes) / 1048576.0
	if total_bytes > 0:
		var tot_mb: float = float(total_bytes) / 1048576.0
		_progress_lbl.text = "%.1f / %.1f MB (%d%%)" % [dl_mb, tot_mb, roundi(ratio * 100.0)]
	else:
		_progress_lbl.text = "%.1f MB" % dl_mb

func _on_update_finished(success: bool, _message: String) -> void:
	if success:
		_prog_wrap.visible = false

func _on_primary_pressed() -> void:
	var st_key: String = str(_last_snap.get("state_key", "IDLE"))
	if st_key == "UPDATE_AVAILABLE":
		_updater.call("start_one_click_update", true)
	elif st_key == "NOT_INSTALLED":
		_updater.call("start_one_click_update", false)
	elif bool(_last_snap.get("exe_exists", false)):
		var launched: bool = bool(_updater.call("launch_game"))
		if launched and DisplayServer.get_name() != "headless":
			get_tree().quit()

func _on_open_dir_pressed() -> void:
	var dir_path: String = str(_last_snap.get("install_dir", ""))
	if dir_path != "":
		OS.shell_open(dir_path)

func _on_apk_pressed() -> void:
	var apk_url: String = str(_last_snap.get("apk_url", ""))
	if apk_url != "":
		OS.shell_open(apk_url)
