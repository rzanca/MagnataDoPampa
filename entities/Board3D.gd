extends Node2D

signal tile_clicked(tile_index: int)

@export var viewport_position: Vector2 = Vector2(18.0, 18.0)
@export var viewport_size: Vector2 = Vector2(1426.0, 1044.0)

# Casas mais profundas radialmente (2.75 vs 2.0 anterior) e centro proporcionalmente mais compacto
const CORNER_SIZE: float = 2.75
const STEP_SIZE: float = 1.0
const BOARD_TOTAL_SIZE: float = CORNER_SIZE * 2.0 + STEP_SIZE * 9.0 # 14.5
const BOARD_HALF: float = BOARD_TOTAL_SIZE * 0.5 # 7.25
const TILE_GAP: float = 0.11
const TILE_HEIGHT: float = 0.20
const TILE_TOP_Y: float = 0.10
const STRIPE_THICK: float = 0.22
const JAIL_TILE_INDEX: int = 10
const JAIL_CELL_LOCAL_OFFSET: Vector3 = Vector3(0.36, 0.0, -0.34)

const ISO_CAM_POS: Vector3 = Vector3(8.4, 15.8, 12.8)
const ISO_CAM_TARGET: Vector3 = Vector3(0.0, -0.15, 0.15)
const ISO_CAM_OFFSET: Vector3 = ISO_CAM_POS - ISO_CAM_TARGET
const ISO_CAM_SIZE: float = 16.4
const TOP_CAM_POS: Vector3 = Vector3(0.0, 20.0, 0.001)
const TOP_CAM_SIZE: float = 15.35

const TILE_DEFAULT_BG: Color = Color("#151F1A")
const TILE_HOVER_BG: Color = Color("#25392E")
const TILE_MORTGAGED_BG: Color = Color("#241B1C")
const TILE_SPECIAL_BG: Color = Color("#18211C")
const TILE_COMPANY_BG: Color = Color("#13232C")
const TILE_ART_NORMAL_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const TILE_ART_HOVER_TINT: Color = Color(1.18, 1.18, 1.10, 1.0)
const TILE_ART_MORTGAGED_TINT: Color = Color(0.46, 0.43, 0.40, 1.0)

const TOKEN_COLORS: Array[Color] = [
	Color("#FF3B4E"),
	Color("#1FC8A9"),
	Color("#FFCA3A"),
	Color("#3A9BFF"),
	Color("#A45CFF"),
	Color("#FF7A38")
]

var _frame_panel: PanelContainer
var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D
var _board_root: Node3D
var _tokens_root: Node3D
var _center_root: Node3D
var _fx_root: Node3D

var _tiles_cache: Array[Dictionary] = []
var _tile_bounds_xz: Array[Rect2] = []
var _tile_centers_3d: Array[Vector3] = []
var _tile_base_materials: Array[StandardMaterial3D] = []
var _tile_art_materials: Dictionary[int, StandardMaterial3D] = {}
var _tile_default_colors: Array[Color] = []
var _owner_overlays: Dictionary[int, Node3D] = {}
var _building_overlays: Dictionary[int, Node3D] = {}
var _last_building_levels: Dictionary[int, int] = {}
var _mortgaged_cache: Dictionary[int, bool] = {}

var _player_colors: Dictionary[int, Color] = {}
var _token_nodes: Dictionary[int, Node3D] = {}
var _token_medallions: Dictionary[int, Node3D] = {}
var _token_stems: Dictionary[int, MeshInstance3D] = {}
var _token_halos: Dictionary[int, MeshInstance3D] = {}
var _token_jail_rings: Dictionary[int, MeshInstance3D] = {}
var _jailed_player_ids: Array[int] = []
var _active_player_id: int = -1
var _halo_tween: Tween = null
var _total_players_count: int = 0

var _flag_segments: Array[Node3D] = []
var _jail_beacon_mat: StandardMaterial3D = null
var _go_jail_spinner: Node3D = null
var _ambient_time: float = 0.0

var _dice_nodes: Array[Node3D] = []
var _deck_root: Node3D
var _anim_card_node: Node3D
var _anim_card_label: Label3D

var _is_2d_view: bool = false
var _camera_follow_enabled: bool = true
var _hovered_tile: int = -1
var _anim_token: int = 0
var _camera_tween: Tween = null
var _camera_return_tween: Tween = null
var _token_pose_tweens: Array[Tween] = []
var _active_tweens: Array[Tween] = []
var _bold_font: SystemFont = null

func _ready() -> void:
	_bold_font = SystemFont.new()
	_bold_font.font_names = PackedStringArray(["Segoe UI", "Arial", "Liberation Sans", "sans-serif"])
	_bold_font.font_weight = 800
	_build_viewport_shell()
	_setup_scene_lighting_and_camera()

func _process(delta: float) -> void:
	_ambient_time += delta
	# Ondulação suave da Bandeira do Rio Grande do Sul na casa 20 de Setembro
	for i: int in range(_flag_segments.size()):
		var seg: Node3D = _flag_segments[i]
		if seg == null or not is_instance_valid(seg):
			continue
		var phase: float = _ambient_time * 3.1 - float(i) * 0.85
		var amp: float = 4.2 + float(i) * 2.2
		seg.rotation_degrees.y = sin(phase) * amp
		seg.rotation_degrees.z = cos(phase * 0.7) * (1.2 + float(i) * 0.5)

	# Giroflex sutil no canto Vá pro Xadrez
	if _go_jail_spinner != null and is_instance_valid(_go_jail_spinner):
		_go_jail_spinner.rotation_degrees.y = fmod(_ambient_time * 135.0, 360.0)

	# Destaque pulsante no sinalizador da cela e nos peões presos no Xadrez
	var has_jailed: bool = not _jailed_player_ids.is_empty()
	var pulse_01: float = 0.5 + 0.5 * sin(_ambient_time * 4.4)
	if _jail_beacon_mat != null:
		_jail_beacon_mat.emission_energy_multiplier = (0.35 + pulse_01 * 1.15) if has_jailed else 0.08
	if has_jailed:
		var ring_scale_xz: float = 0.96 + pulse_01 * 0.12
		for pid: int in _jailed_player_ids:
			var j_ring: MeshInstance3D = _token_jail_rings.get(pid, null)
			if j_ring != null and is_instance_valid(j_ring) and j_ring.visible:
				j_ring.scale = Vector3(ring_scale_xz, 0.30, ring_scale_xz)

func _build_viewport_shell() -> void:
	_frame_panel = PanelContainer.new()
	_frame_panel.position = viewport_position
	_frame_panel.size = viewport_size

	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color("#0F1813")
	frame_style.border_color = Color("#D4AF37")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(12)
	_frame_panel.add_theme_stylebox_override("panel", frame_style)
	add_child(_frame_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_frame_panel.add_child(margin)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_viewport_container.gui_input.connect(_on_viewport_gui_input)
	_viewport_container.mouse_exited.connect(_on_viewport_mouse_exited)
	margin.add_child(_viewport_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(maxi(320, roundi(viewport_size.x - 8.0)), maxi(240, roundi(viewport_size.y - 8.0)))
	_sub_viewport.own_world_3d = true
	_sub_viewport.handle_input_locally = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport_container.add_child(_sub_viewport)

	_world_root = Node3D.new()
	_world_root.name = "WorldRoot"
	_sub_viewport.add_child(_world_root)

	_board_root = Node3D.new()
	_board_root.name = "BoardTiles"
	_world_root.add_child(_board_root)

	_center_root = Node3D.new()
	_center_root.name = "CenterPieces"
	_world_root.add_child(_center_root)

	_tokens_root = Node3D.new()
	_tokens_root.name = "Tokens"
	_world_root.add_child(_tokens_root)

	_fx_root = Node3D.new()
	_fx_root.name = "BoardFX"
	_world_root.add_child(_fx_root)

func _setup_scene_lighting_and_camera() -> void:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0D1510")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#DCE6DF")
	env.ambient_light_energy = 0.74
	env_node.environment = env
	_world_root.add_child(env_node)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 1.05
	sun.light_color = Color("#FFF7E6")
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-54.0, 34.0, 0.0)
	_world_root.add_child(sun)

	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.light_energy = 0.35
	fill_light.light_color = Color("#B7E4C7")
	fill_light.shadow_enabled = false
	fill_light.rotation_degrees = Vector3(-35.0, -135.0, 0.0)
	_world_root.add_child(fill_light)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.5
	_camera.far = 90.0
	_camera.current = true
	_world_root.add_child(_camera)
	_apply_camera_pose_immediate(false)

func _get_iso_quaternion() -> Quaternion:
	var t: Transform3D = Transform3D(Basis.IDENTITY, ISO_CAM_POS).looking_at(ISO_CAM_TARGET, Vector3.UP)
	return t.basis.get_rotation_quaternion()

func _get_top_quaternion() -> Quaternion:
	return Quaternion.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))

func _get_medallion_iso_quaternion() -> Quaternion:
	var q_yaw: Quaternion = Quaternion(Vector3.UP, deg_to_rad(33.5))
	var q_tilt: Quaternion = Quaternion(Vector3.RIGHT, deg_to_rad(42.0))
	return q_yaw * q_tilt

func _kill_token_pose_tweens() -> void:
	for tw: Tween in _token_pose_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_token_pose_tweens.clear()

func _sync_token_medallions_to_camera(to_2d: bool, animate: bool) -> void:
	_kill_token_pose_tweens()
	var target_pos: Vector3 = Vector3(0.0, 0.115, 0.0) if to_2d else Vector3(0.0, 0.39, 0.0)
	var target_quat: Quaternion = Quaternion.IDENTITY if to_2d else _get_medallion_iso_quaternion()
	var target_scale: Vector3 = Vector3(0.95, 0.95, 0.95) if to_2d else Vector3(1.06, 1.06, 1.06)
	var target_stem_scale: Vector3 = Vector3(0.01, 0.01, 0.01) if to_2d else Vector3.ONE

	for pid: int in _token_medallions.keys():
		var med: Node3D = _token_medallions[pid]
		var stem: MeshInstance3D = _token_stems.get(pid, null)
		if med == null or not is_instance_valid(med):
			continue
		if not animate or not is_inside_tree():
			med.position = target_pos
			med.quaternion = target_quat
			med.scale = target_scale
			if stem != null and is_instance_valid(stem):
				stem.scale = target_stem_scale
				stem.visible = not to_2d
		else:
			if stem != null and is_instance_valid(stem) and not to_2d:
				stem.visible = true
			var tw: Tween = create_tween()
			_token_pose_tweens.append(tw)
			tw.set_parallel(true)
			tw.set_trans(Tween.TRANS_CUBIC)
			tw.set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(med, "position", target_pos, 0.42)
			tw.tween_property(med, "quaternion", target_quat, 0.42)
			tw.tween_property(med, "scale", target_scale, 0.42)
			if stem != null and is_instance_valid(stem):
				tw.tween_property(stem, "scale", target_stem_scale, 0.36)

func set_viewport_rect(rect: Rect2) -> void:
	viewport_position = rect.position
	viewport_size = Vector2(maxf(320.0, rect.size.x), maxf(240.0, rect.size.y))
	if _frame_panel != null:
		_frame_panel.position = viewport_position
		_frame_panel.size = viewport_size
	if _sub_viewport != null and (_viewport_container == null or not _viewport_container.stretch):
		var target_w: int = maxi(320, roundi(viewport_size.x - 8.0))
		var target_h: int = maxi(240, roundi(viewport_size.y - 8.0))
		if _sub_viewport.size.x != target_w or _sub_viewport.size.y != target_h:
			_sub_viewport.size = Vector2i(target_w, target_h)
	if _camera != null and (_camera_tween == null or not _camera_tween.is_valid()):
		_camera.size = _get_effective_cam_size(_is_2d_view)

func _get_effective_cam_size(to_2d: bool) -> float:
	var aspect: float = 1.36
	if viewport_size.y > 0.0:
		aspect = maxf(320.0, viewport_size.x - 8.0) / maxf(240.0, viewport_size.y - 8.0)
	elif _sub_viewport != null and _sub_viewport.size.y > 0:
		aspect = float(_sub_viewport.size.x) / float(_sub_viewport.size.y)
	if to_2d:
		return maxf(TOP_CAM_SIZE, 15.6 / maxf(0.5, aspect))
	return maxf(ISO_CAM_SIZE, 20.8 / maxf(0.5, aspect))

func _apply_camera_pose_immediate(to_2d: bool) -> void:
	_is_2d_view = to_2d
	if _camera == null:
		return
	if to_2d:
		_camera.position = TOP_CAM_POS
		_camera.quaternion = _get_top_quaternion()
		_camera.size = _get_effective_cam_size(true)
	else:
		_camera.position = ISO_CAM_POS
		_camera.quaternion = _get_iso_quaternion()
		_camera.size = _get_effective_cam_size(false)
	_sync_token_medallions_to_camera(to_2d, false)

func is_2d_camera_active() -> bool:
	return _is_2d_view

func _kill_camera_tweens() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null
	if _camera_return_tween != null and _camera_return_tween.is_valid():
		_camera_return_tween.kill()
	_camera_return_tween = null

func is_camera_follow_enabled() -> bool:
	return _camera_follow_enabled

func set_camera_follow_enabled(enabled: bool) -> void:
	_camera_follow_enabled = enabled
	if not _camera_follow_enabled:
		reset_camera_framing(true)

func toggle_camera_follow() -> bool:
	set_camera_follow_enabled(not _camera_follow_enabled)
	return _camera_follow_enabled

func reset_camera_framing(animate: bool = true) -> void:
	set_camera_2d_mode(_is_2d_view, animate)

func _focus_camera_on_world_pos(world_pos: Vector3, zoom_factor: float = 0.74, duration: float = 0.22) -> void:
	if _is_2d_view or not _camera_follow_enabled or _camera == null or not is_inside_tree():
		return
	_kill_camera_tweens()
	# Foco amortecido mantendo boa leitura do entorno sem sair da mesa
	var damped_x: float = clampf(world_pos.x * 0.56, -3.6, 3.6)
	var damped_z: float = clampf(world_pos.z * 0.56, -3.6, 3.6)
	var focus_target: Vector3 = Vector3(damped_x, ISO_CAM_TARGET.y, damped_z + 0.15)
	var cam_dest: Vector3 = focus_target + ISO_CAM_OFFSET
	var cam_size: float = _get_effective_cam_size(false) * clampf(zoom_factor, 0.62, 1.0)

	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(_camera, "position", cam_dest, duration)
	_camera_tween.tween_property(_camera, "size", cam_size, duration)

func _schedule_camera_overview_return(delay_sec: float = 0.55) -> void:
	if _is_2d_view or _camera == null or not is_inside_tree():
		return
	if _camera_return_tween != null and _camera_return_tween.is_valid():
		_camera_return_tween.kill()
	var target_size: float = _get_effective_cam_size(false)
	_camera_return_tween = create_tween()
	_camera_return_tween.tween_interval(delay_sec)
	_camera_return_tween.tween_callback(func() -> void:
		if _is_2d_view or _camera == null or not is_inside_tree():
			return
		if _camera_tween != null and _camera_tween.is_valid():
			_camera_tween.kill()
		_camera_tween = create_tween()
		_camera_tween.set_parallel(true)
		_camera_tween.set_trans(Tween.TRANS_CUBIC)
		_camera_tween.set_ease(Tween.EASE_IN_OUT)
		_camera_tween.tween_property(_camera, "position", ISO_CAM_POS, 0.52)
		_camera_tween.tween_property(_camera, "size", target_size, 0.52)
	)

func set_camera_2d_mode(to_2d: bool, animate: bool = true) -> void:
	_is_2d_view = to_2d
	if _camera == null:
		return
	_kill_camera_tweens()
	if not animate:
		_apply_camera_pose_immediate(to_2d)
		return

	var target_pos: Vector3 = TOP_CAM_POS if to_2d else ISO_CAM_POS
	var target_quat: Quaternion = _get_top_quaternion() if to_2d else _get_iso_quaternion()
	var target_size: float = _get_effective_cam_size(to_2d)

	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera, "position", target_pos, 0.45)
	_camera_tween.tween_property(_camera, "quaternion", target_quat, 0.45)
	_camera_tween.tween_property(_camera, "size", target_size, 0.45)
	_sync_token_medallions_to_camera(to_2d, true)

func toggle_camera_view() -> bool:
	set_camera_2d_mode(not _is_2d_view, true)
	return _is_2d_view

func cancel_animations() -> void:
	_anim_token += 1
	_kill_camera_tweens()
	for tw: Tween in _active_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_active_tweens.clear()
	if _halo_tween != null and _halo_tween.is_valid():
		_halo_tween.kill()
	_halo_tween = null
	if _fx_root != null:
		for fx_child: Node in _fx_root.get_children():
			fx_child.queue_free()
	_apply_camera_pose_immediate(_is_2d_view)
	if _anim_card_node != null:
		_anim_card_node.visible = false

func _register_tween(tw: Tween) -> void:
	var alive: Array[Tween] = []
	for existing: Tween in _active_tweens:
		if existing != null and existing.is_valid():
			alive.append(existing)
	alive.append(tw)
	_active_tweens = alive

func _make_material(col: Color, roughness: float = 0.65, metallic: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	mat.roughness = roughness
	mat.metallic = metallic
	if alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _make_vivid_material(col: Color, roughness: float = 0.28, metallic: float = 0.12, emission_energy: float = 0.14) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emission_energy
	return mat

func _boost_vivid_color(col: Color) -> Color:
	return Color.from_hsv(col.h, minf(1.0, col.s * 1.18 + 0.06), minf(1.0, col.v * 1.08 + 0.05))

func build_board(tiles: Array[Dictionary]) -> void:
	cancel_animations()
	for child: Node in _board_root.get_children():
		child.queue_free()
	for child: Node in _center_root.get_children():
		child.queue_free()

	_tiles_cache = tiles.duplicate(true)
	_tile_bounds_xz.clear()
	_tile_centers_3d.clear()
	_tile_base_materials.clear()
	_tile_art_materials.clear()
	_tile_default_colors.clear()
	_owner_overlays.clear()
	_building_overlays.clear()
	_mortgaged_cache.clear()
	_flag_segments.clear()
	_jail_beacon_mat = null
	_go_jail_spinner = null
	_hovered_tile = -1

	# Moldura externa de madeira nobre escura
	var table_mesh: MeshInstance3D = MeshInstance3D.new()
	var table_box: BoxMesh = BoxMesh.new()
	table_box.size = Vector3(BOARD_TOTAL_SIZE + 0.55, 0.36, BOARD_TOTAL_SIZE + 0.55)
	table_mesh.mesh = table_box
	table_mesh.position = Vector3(0.0, -0.22, 0.0)
	table_mesh.material_override = _make_material(Color("#2B1F16"), 0.72, 0.05)
	_board_root.add_child(table_mesh)

	# Leito escuro sob as casas para ressaltar os frisos/gaps de separação entre blocos
	var groove_bed: MeshInstance3D = MeshInstance3D.new()
	var groove_box: BoxMesh = BoxMesh.new()
	groove_box.size = Vector3(BOARD_TOTAL_SIZE + 0.06, 0.08, BOARD_TOTAL_SIZE + 0.06)
	groove_bed.mesh = groove_box
	groove_bed.position = Vector3(0.0, -0.02, 0.0)
	groove_bed.material_override = _make_material(Color("#0F1512"), 0.85, 0.02)
	_board_root.add_child(groove_bed)

	# Feltro central proporcionalmente mais compacto (9.0 x 9.0 dentro de 14.5 x 14.5)
	var center_span: float = BOARD_TOTAL_SIZE - CORNER_SIZE * 2.0
	var felt_mesh: MeshInstance3D = MeshInstance3D.new()
	var felt_box: BoxMesh = BoxMesh.new()
	felt_box.size = Vector3(center_span - 0.16, 0.14, center_span - 0.16)
	felt_mesh.mesh = felt_box
	felt_mesh.position = Vector3(0.0, 0.0, 0.0)
	felt_mesh.material_override = _make_material(Color("#152A1E"), 0.85, 0.0)
	_board_root.add_child(felt_mesh)

	# Moldura dourada elegante contornando o centro reduzido
	_add_gold_center_frame(center_span - 0.50)

	# Título central harmonizado no espaço superior do feltro
	var center_title: Label3D = Label3D.new()
	center_title.text = "MAGNATA DO PAMPA\nMODO CLÁSSICO • RS"
	if _bold_font != null:
		center_title.font = _bold_font
	center_title.font_size = 54
	center_title.pixel_size = 0.0102
	center_title.modulate = Color("#F5D06F")
	center_title.outline_modulate = Color("#09110D")
	center_title.outline_size = 7
	center_title.position = Vector3(0.0, 0.088, -2.72)
	center_title.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_board_root.add_child(center_title)

	# 40 casas orientadas a dados
	for i: int in range(tiles.size()):
		var rect_xz: Rect2 = _get_tile_rect_xz(i)
		_tile_bounds_xz.append(rect_xz)
		var cx: float = rect_xz.position.x + rect_xz.size.x * 0.5
		var cz: float = rect_xz.position.y + rect_xz.size.y * 0.5
		_tile_centers_3d.append(Vector3(cx, TILE_TOP_Y, cz))

		var tile_node: Node3D = _create_tile_3d(i, rect_xz, tiles[i])
		_board_root.add_child(tile_node)

	_build_center_dice()
	_build_center_chance_deck()

func _add_gold_center_frame(span: float) -> void:
	var half_s: float = span * 0.5
	var thickness: float = 0.08
	var gold_mat: StandardMaterial3D = _make_material(Color("#D4AF37"), 0.35, 0.45)
	var bars: Array[Dictionary] = [
		{ "pos": Vector3(0.0, 0.08, -half_s), "size": Vector3(span, 0.03, thickness) },
		{ "pos": Vector3(0.0, 0.08, half_s), "size": Vector3(span, 0.03, thickness) },
		{ "pos": Vector3(-half_s, 0.08, 0.0), "size": Vector3(thickness, 0.03, span) },
		{ "pos": Vector3(half_s, 0.08, 0.0), "size": Vector3(thickness, 0.03, span) }
	]
	for b: Dictionary in bars:
		var m: MeshInstance3D = MeshInstance3D.new()
		var bx: BoxMesh = BoxMesh.new()
		bx.size = b["size"]
		m.mesh = bx
		m.position = b["pos"]
		m.material_override = gold_mat
		_board_root.add_child(m)

func _get_tile_rect_xz(index: int) -> Rect2:
	if index == 0:
		return Rect2(BOARD_HALF - CORNER_SIZE, BOARD_HALF - CORNER_SIZE, CORNER_SIZE, CORNER_SIZE)
	elif index < 10:
		var k: float = float(index)
		var x: float = BOARD_HALF - CORNER_SIZE - k * STEP_SIZE
		return Rect2(x, BOARD_HALF - CORNER_SIZE, STEP_SIZE, CORNER_SIZE)
	elif index == 10:
		return Rect2(-BOARD_HALF, BOARD_HALF - CORNER_SIZE, CORNER_SIZE, CORNER_SIZE)
	elif index < 20:
		var k: float = float(index - 10)
		var z: float = BOARD_HALF - CORNER_SIZE - k * STEP_SIZE
		return Rect2(-BOARD_HALF, z, CORNER_SIZE, STEP_SIZE)
	elif index == 20:
		return Rect2(-BOARD_HALF, -BOARD_HALF, CORNER_SIZE, CORNER_SIZE)
	elif index < 30:
		var k: float = float(index - 20)
		var x: float = -BOARD_HALF + CORNER_SIZE + (k - 1.0) * STEP_SIZE
		return Rect2(x, -BOARD_HALF, STEP_SIZE, CORNER_SIZE)
	elif index == 30:
		return Rect2(BOARD_HALF - CORNER_SIZE, -BOARD_HALF, CORNER_SIZE, CORNER_SIZE)
	else:
		var k: float = float(index - 30)
		var z: float = -BOARD_HALF + CORNER_SIZE + (k - 1.0) * STEP_SIZE
		return Rect2(BOARD_HALF - CORNER_SIZE, z, CORNER_SIZE, STEP_SIZE)

func _try_load_tile_art(art_id: String) -> Texture2D:
	if art_id == "":
		return null
	var extensions: Array[String] = ["png", "webp", "svg"]
	for ext: String in extensions:
		var path: String = "res://assets/tiles/%s.%s" % [art_id, ext]
		if ResourceLoader.exists(path):
			var loaded: Resource = ResourceLoader.load(path)
			if loaded is Texture2D:
				return loaded as Texture2D
		var abs_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return null

func _short_board_name(tile_data: Dictionary) -> String:
	var art_id: String = str(tile_data.get("art_id", ""))
	match art_id:
		"tile_galpao_central":
			return "PARTIDA"
		"tile_xadrez":
			return "XADREZ"
		"tile_feriadao_20_setembro":
			return "20 DE SETEMBRO"
		"tile_va_para_xadrez":
			return "VÁ PRO XADREZ"
		"tile_sorte_ou_azar":
			return "Sorte / Azar"
		"tile_imposto_erva_mate":
			return "Imp. Erva-Mate"
		"tile_taxa_churrasco":
			return "Taxa Churrasco"
		"comp_usina_jacui":
			return "Usina Jacuí"
		"comp_viacao_fandangueira":
			return "V. Fandangueira"
		"comp_estaleiro_rio_grande":
			return "Estaleiro RG"
		"comp_cooperativa_agricola":
			return "Coop. Agrícola"
		"comp_aeroporto_salgado_filho":
			return "Aeroporto POA"
		"prop_beco_do_chimarrao":
			return "Beco Chimarrão"
		"prop_vila_da_bombacha":
			return "Vila Bombacha"
		"prop_passo_do_quero_quero":
			return "Quero-Quero"
		"prop_rincao_da_coxilha":
			return "Rincão Coxilha"
		"prop_estancia_do_guapo":
			return "Estância Guapo"
		"prop_vale_dos_vinhedos":
			return "Vale Vinhedos"
		"prop_canion_itaimbezinho":
			return "Itaimbezinho"
		"prop_missoes_jesuiticas":
			return "Missões"
		"prop_fronteira_da_paz":
			return "Fronteira Paz"
		"prop_parque_da_redencao":
			return "Redenção"
		"prop_cascata_do_caracol":
			return "Cascata Caracol"
		"prop_praia_do_cassino":
			return "Praia Cassino"
		"prop_guarita_de_torres":
			return "Guarita Torres"
		"prop_cais_embarcadero":
			return "Embarcadero"
		"prop_moinhos_de_vento":
			return "Moinhos Vento"
		"prop_estancia_real_do_pampa":
			return "Estância Real"
		_:
			return str(tile_data.get("name", ""))

func _compute_tile_art_and_label_layout(tile_idx: int, has_stripe: bool, tile_w: float, tile_d: float) -> Dictionary:
	# Layout full-bleed sem distorção de proporção: arte de corpo inteiro, friso fino de grupo e tipografia ampla em alto contraste
	if tile_idx == 0 or tile_idx == 10 or tile_idx == 20 or tile_idx == 30:
		return {
			"is_corner": true,
			"art_size": Vector2(tile_w, tile_d),
			"art_pos": Vector3(0.0, TILE_TOP_Y + 0.005, 0.0),
			"name_pos": Vector3(0.0, TILE_TOP_Y + 0.022, tile_d * 0.5 - 0.27),
			"price_pos": Vector3(0.0, TILE_TOP_Y + 0.022, tile_d * 0.5 - 0.14),
			"lbl_width": tile_w - 0.16,
			"name_font_size": 38,
			"name_pixel_size": 0.0056,
			"price_font_size": 34,
			"price_pixel_size": 0.0056
		}
	if tile_idx < 10:
		# Base (0.89 x 2.64): faixa fina [-1.32..-1.10], arte full-bleed [-1.10..+0.20], rodapé escuro [+0.20..+1.32]
		var art_h: float = 1.30 if has_stripe else 1.44
		var art_z: float = (-tile_d * 0.5 + STRIPE_THICK + art_h * 0.5) if has_stripe else (-tile_d * 0.5 + art_h * 0.5)
		return {
			"is_corner": false,
			"art_size": Vector2(tile_w, art_h),
			"art_pos": Vector3(0.0, TILE_TOP_Y + 0.005, art_z),
			"name_pos": Vector3(0.0, TILE_TOP_Y + 0.020, 0.46 if has_stripe else 0.42),
			"price_pos": Vector3(0.0, TILE_TOP_Y + 0.020, 0.92 if has_stripe else 0.90),
			"lbl_width": tile_w - 0.05,
			"name_font_size": 27,
			"name_pixel_size": 0.0052,
			"price_font_size": 35,
			"price_pixel_size": 0.0056
		}
	if tile_idx < 20:
		# Esquerda (2.64 x 0.89): arte full-bleed à esquerda, painel escuro amplo de texto e faixa fina à direita
		var art_w: float = 1.18 if has_stripe else 1.26
		var art_x: float = -tile_w * 0.5 + art_w * 0.5
		return {
			"is_corner": false,
			"art_size": Vector2(art_w, tile_d),
			"art_pos": Vector3(art_x, TILE_TOP_Y + 0.005, 0.0),
			"name_pos": Vector3(0.48 if has_stripe else 0.63, TILE_TOP_Y + 0.020, -0.19),
			"price_pos": Vector3(0.48 if has_stripe else 0.63, TILE_TOP_Y + 0.020, 0.23),
			"lbl_width": 1.16 if has_stripe else 1.28,
			"name_font_size": 28,
			"name_pixel_size": 0.0053,
			"price_font_size": 36,
			"price_pixel_size": 0.0056
		}
	if tile_idx < 30:
		# Topo (0.89 x 2.64): arte full-bleed no topo [-1.32..-0.08], rodapé escuro [-0.08..+1.10], faixa fina [+1.10..+1.32]
		var art_h: float = 1.24 if has_stripe else 1.38
		var art_z: float = -tile_d * 0.5 + art_h * 0.5
		return {
			"is_corner": false,
			"art_size": Vector2(tile_w, art_h),
			"art_pos": Vector3(0.0, TILE_TOP_Y + 0.005, art_z),
			"name_pos": Vector3(0.0, TILE_TOP_Y + 0.020, 0.26 if has_stripe else 0.42),
			"price_pos": Vector3(0.0, TILE_TOP_Y + 0.020, 0.76 if has_stripe else 0.92),
			"lbl_width": tile_w - 0.05,
			"name_font_size": 27,
			"name_pixel_size": 0.0052,
			"price_font_size": 35,
			"price_pixel_size": 0.0056
		}
	# Direita (2.64 x 0.89): faixa fina à esquerda, painel escuro amplo de texto e arte full-bleed à direita
	var art_w_r: float = 1.18 if has_stripe else 1.26
	var art_x_r: float = tile_w * 0.5 - art_w_r * 0.5
	return {
		"is_corner": false,
		"art_size": Vector2(art_w_r, tile_d),
		"art_pos": Vector3(art_x_r, TILE_TOP_Y + 0.005, 0.0),
		"name_pos": Vector3(-0.48 if has_stripe else -0.63, TILE_TOP_Y + 0.020, -0.19),
		"price_pos": Vector3(-0.48 if has_stripe else -0.63, TILE_TOP_Y + 0.020, 0.23),
		"lbl_width": 1.16 if has_stripe else 1.28,
		"name_font_size": 28,
		"name_pixel_size": 0.0053,
		"price_font_size": 36,
		"price_pixel_size": 0.0056
	}

func _create_tile_3d(tile_idx: int, rect_xz: Rect2, tile_data: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	var cx: float = rect_xz.position.x + rect_xz.size.x * 0.5
	var cz: float = rect_xz.position.y + rect_xz.size.y * 0.5
	root.position = Vector3(cx, 0.0, cz)

	var tile_type: String = str(tile_data.get("type", ""))
	var is_corner: bool = (tile_idx == 0 or tile_idx == 10 or tile_idx == 20 or tile_idx == 30)
	var base_color: Color = TILE_DEFAULT_BG
	if tile_type == "COMPANY":
		base_color = TILE_COMPANY_BG
	elif tile_type != "PROPERTY":
		base_color = TILE_SPECIAL_BG

	var base_mat: StandardMaterial3D = _make_material(base_color, 0.72, 0.04)
	_tile_base_materials.append(base_mat)
	_tile_default_colors.append(base_color)

	# Gap visual nítido entre casas adjacentes (TILE_GAP = 0.11)
	var tile_w: float = maxf(0.2, rect_xz.size.x - TILE_GAP)
	var tile_d: float = maxf(0.2, rect_xz.size.y - TILE_GAP)

	# Plinto inferior escuro discreto (nos cantos fica rente ao bloco para zero borda branca/clara)
	var bevel: MeshInstance3D = MeshInstance3D.new()
	var bevel_box: BoxMesh = BoxMesh.new()
	var bevel_expand: float = 0.0 if is_corner else 0.02
	bevel_box.size = Vector3(tile_w + bevel_expand, TILE_HEIGHT * 0.55, tile_d + bevel_expand)
	bevel.mesh = bevel_box
	bevel.position = Vector3(0.0, -TILE_HEIGHT * 0.22, 0.0)
	bevel.material_override = _make_material(Color("#0E1511"), 0.82, 0.05)
	root.add_child(bevel)

	var slab: MeshInstance3D = MeshInstance3D.new()
	var slab_box: BoxMesh = BoxMesh.new()
	slab_box.size = Vector3(tile_w, TILE_HEIGHT, tile_d)
	slab.mesh = slab_box
	slab.position = Vector3(0.0, 0.0, 0.0)
	slab.material_override = base_mat
	root.add_child(slab)

	var color_hex: String = str(tile_data.get("color", ""))
	var has_stripe: bool = (color_hex != "")
	var layout: Dictionary = _compute_tile_art_and_label_layout(tile_idx, has_stripe, tile_w, tile_d)

	# Arte temática full-bleed com recorte central proporcional (sem esticar/distorcer a textura 1:1)
	var art_tex: Texture2D = _try_load_tile_art(str(tile_data.get("art_id", "")))
	if art_tex != null:
		var art_size: Vector2 = layout["art_size"]
		var art_plane: MeshInstance3D = MeshInstance3D.new()
		var quad: PlaneMesh = PlaneMesh.new()
		quad.size = art_size
		art_plane.mesh = quad
		art_plane.position = layout["art_pos"]
		art_plane.rotation = Vector3.ZERO
		var art_mat: StandardMaterial3D = StandardMaterial3D.new()
		art_mat.albedo_texture = art_tex
		art_mat.albedo_color = TILE_ART_NORMAL_TINT
		art_mat.roughness = 0.66
		art_mat.metallic = 0.02
		art_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if art_size.x < art_size.y:
			var u_scale: float = art_size.x / art_size.y
			art_mat.uv1_scale = Vector3(u_scale, 1.0, 1.0)
			art_mat.uv1_offset = Vector3((1.0 - u_scale) * 0.5, 0.0, 0.0)
		elif art_size.y < art_size.x:
			var v_scale: float = art_size.y / art_size.x
			art_mat.uv1_scale = Vector3(1.0, v_scale, 1.0)
			art_mat.uv1_offset = Vector3(0.0, (1.0 - v_scale) * 0.5, 0.0)
		art_plane.material_override = art_mat
		_tile_art_materials[tile_idx] = art_mat
		root.add_child(art_plane)

	# Nos 4 cantos: faixa escura translúcida elegante na base com filete dourado, sem nenhuma borda branca
	if is_corner:
		var ribbon_h: float = 0.52
		var ribbon_z: float = tile_d * 0.5 - ribbon_h * 0.5
		var corner_ribbon: MeshInstance3D = MeshInstance3D.new()
		var ribbon_quad: PlaneMesh = PlaneMesh.new()
		ribbon_quad.size = Vector2(tile_w, ribbon_h)
		corner_ribbon.mesh = ribbon_quad
		corner_ribbon.position = Vector3(0.0, TILE_TOP_Y + 0.011, ribbon_z)
		corner_ribbon.material_override = _make_material(Color("#08100C"), 0.80, 0.05, 0.86)
		root.add_child(corner_ribbon)

		var corner_hairline: MeshInstance3D = MeshInstance3D.new()
		var hairline_box: BoxMesh = BoxMesh.new()
		hairline_box.size = Vector3(tile_w, 0.010, 0.028)
		corner_hairline.mesh = hairline_box
		corner_hairline.position = Vector3(0.0, TILE_TOP_Y + 0.013, tile_d * 0.5 - ribbon_h)
		corner_hairline.material_override = _make_material(Color("#D4AF37"), 0.35, 0.45)
		root.add_child(corner_hairline)

	# Friso fino e elegante da cor do grupo na borda interna (com espaço garantido para casas/hotéis 3D)
	if has_stripe:
		var stripe: MeshInstance3D = MeshInstance3D.new()
		var stripe_box: BoxMesh = BoxMesh.new()
		if tile_idx > 0 and tile_idx < 10:
			stripe_box.size = Vector3(tile_w, 0.026, STRIPE_THICK)
			stripe.position = Vector3(0.0, TILE_TOP_Y + 0.013, -tile_d * 0.5 + STRIPE_THICK * 0.5)
		elif tile_idx > 10 and tile_idx < 20:
			stripe_box.size = Vector3(STRIPE_THICK, 0.026, tile_d)
			stripe.position = Vector3(tile_w * 0.5 - STRIPE_THICK * 0.5, TILE_TOP_Y + 0.013, 0.0)
		elif tile_idx > 20 and tile_idx < 30:
			stripe_box.size = Vector3(tile_w, 0.026, STRIPE_THICK)
			stripe.position = Vector3(0.0, TILE_TOP_Y + 0.013, tile_d * 0.5 - STRIPE_THICK * 0.5)
		elif tile_idx > 30:
			stripe_box.size = Vector3(STRIPE_THICK, 0.026, tile_d)
			stripe.position = Vector3(-tile_w * 0.5 + STRIPE_THICK * 0.5, TILE_TOP_Y + 0.013, 0.0)
		stripe.mesh = stripe_box
		stripe.material_override = _make_material(Color(color_hex), 0.42, 0.10)
		root.add_child(stripe)

	# Nome em fonte maior e preço de alto destaque sobre rodapé escuro de alto contraste
	var has_price_line: bool = (tile_type == "PROPERTY" or tile_type == "COMPANY" or tile_type == "TAX")
	var name_lbl: Label3D = Label3D.new()
	name_lbl.text = _short_board_name(tile_data)
	if _bold_font != null:
		name_lbl.font = _bold_font
	name_lbl.font_size = int(layout["name_font_size"])
	name_lbl.pixel_size = float(layout["name_pixel_size"])
	name_lbl.width = float(layout["lbl_width"]) / name_lbl.pixel_size
	name_lbl.line_spacing = -4.0
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.modulate = Color("#F8D568") if is_corner else Color("#FFFDF8")
	name_lbl.outline_modulate = Color("#080E0B")
	name_lbl.outline_size = 8 if is_corner else 7
	name_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var name_pos: Vector3 = layout["name_pos"]
	if not has_price_line and not is_corner:
		if tile_idx < 10 or (tile_idx > 20 and tile_idx < 30):
			name_pos.z += 0.22
		else:
			name_pos.z = 0.0
	name_lbl.position = name_pos
	root.add_child(name_lbl)

	if has_price_line:
		var price_lbl: Label3D = Label3D.new()
		if tile_type == "TAX":
			price_lbl.text = "-R$%d" % int(tile_data.get("amount", 0))
			price_lbl.modulate = Color("#FF7B7B")
		else:
			price_lbl.text = "R$%d" % int(tile_data.get("price", 0))
			price_lbl.modulate = Color("#F8D568")
		if _bold_font != null:
			price_lbl.font = _bold_font
		price_lbl.font_size = int(layout["price_font_size"])
		price_lbl.pixel_size = float(layout["price_pixel_size"])
		price_lbl.outline_modulate = Color("#080E0B")
		price_lbl.outline_size = 8
		price_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		price_lbl.position = layout["price_pos"]
		root.add_child(price_lbl)

	var owner_holder: Node3D = Node3D.new()
	owner_holder.name = "OwnerOverlay"
	root.add_child(owner_holder)
	_owner_overlays[tile_idx] = owner_holder

	var build_holder: Node3D = Node3D.new()
	build_holder.name = "BuildingOverlay"
	root.add_child(build_holder)
	_building_overlays[tile_idx] = build_holder

	_add_tile_landmark_3d(root, tile_idx, tile_data, tile_w, tile_d)

	return root

func _add_tile_landmark_3d(root: Node3D, tile_idx: int, tile_data: Dictionary, tile_w: float, tile_d: float) -> void:
	# Marcos 3D estilizados e leves posicionados apenas na periferia segura (zero colisão com peões ou cliques)
	var tile_type: String = str(tile_data.get("type", ""))
	var art_id: String = str(tile_data.get("art_id", ""))
	var gold_mat: StandardMaterial3D = _make_vivid_material(Color("#F6C958"), 0.24, 0.72, 0.14)
	var steel_mat: StandardMaterial3D = _make_vivid_material(Color("#DCE7F0"), 0.18, 0.82, 0.08)
	var wood_mat: StandardMaterial3D = _make_vivid_material(Color("#8A4B24"), 0.48, 0.06, 0.06)
	var dark_mat: StandardMaterial3D = _make_vivid_material(Color("#1A221E"), 0.42, 0.20, 0.02)

	if tile_idx == 0:
		# Galpão Central / Partida: pórtico crioulo imponente com lanterna e seta dourada de saída
		var lm: Node3D = Node3D.new()
		lm.position = Vector3(-0.36, TILE_TOP_Y, -0.78)
		root.add_child(lm)
		var stone_mat: StandardMaterial3D = _make_vivid_material(Color("#5C5A52"), 0.65, 0.08, 0.04)
		var roof_mat: StandardMaterial3D = _make_vivid_material(Color("#C24D27"), 0.38, 0.08, 0.14)
		var lantern_mat: StandardMaterial3D = _make_vivid_material(Color("#FFE58A"), 0.16, 0.05, 0.90)

		var plinth: BoxMesh = BoxMesh.new()
		plinth.size = Vector3(1.06, 0.07, 0.42)
		_add_mesh_part(lm, plinth, Vector3(0.0, 0.035, 0.0), stone_mat)

		var pillar: BoxMesh = BoxMesh.new()
		pillar.size = Vector3(0.11, 0.52, 0.11)
		_add_mesh_part(lm, pillar, Vector3(-0.36, 0.32, 0.0), wood_mat)
		_add_mesh_part(lm, pillar, Vector3(0.36, 0.32, 0.0), wood_mat)

		var beam: BoxMesh = BoxMesh.new()
		beam.size = Vector3(0.96, 0.09, 0.15)
		_add_mesh_part(lm, beam, Vector3(0.0, 0.56, 0.0), wood_mat)

		var roof: PrismMesh = PrismMesh.new()
		roof.size = Vector3(1.14, 0.30, 0.44)
		_add_mesh_part(lm, roof, Vector3(0.0, 0.74, 0.0), roof_mat)

		var crest: BoxMesh = BoxMesh.new()
		crest.size = Vector3(0.16, 0.16, 0.07)
		_add_mesh_part(lm, crest, Vector3(0.0, 0.56, 0.08), gold_mat, Vector3(0.0, 0.0, 45.0))

		var lantern: SphereMesh = SphereMesh.new()
		lantern.radius = 0.058
		lantern.height = 0.116
		_add_mesh_part(lm, lantern, Vector3(0.0, 0.45, 0.0), lantern_mat)

		# Seta dourada de direção de partida no quadrante superior direito
		var arrow_root: Node3D = Node3D.new()
		arrow_root.position = Vector3(0.68, TILE_TOP_Y + 0.016, -0.78)
		root.add_child(arrow_root)
		var shaft: BoxMesh = BoxMesh.new()
		shaft.size = Vector3(0.36, 0.022, 0.10)
		_add_mesh_part(arrow_root, shaft, Vector3(0.08, 0.011, 0.0), gold_mat)
		var head: PrismMesh = PrismMesh.new()
		head.size = Vector3(0.24, 0.24, 0.022)
		_add_mesh_part(arrow_root, head, Vector3(-0.18, 0.011, 0.0), gold_mat, Vector3(-90.0, 0.0, 90.0))
		return

	if tile_idx == JAIL_TILE_INDEX:
		# Xadrez: cela 3D espaçosa aberta por cima para acomodar peões presos visivelmente atrás das grades
		var lm: Node3D = Node3D.new()
		lm.position = Vector3(JAIL_CELL_LOCAL_OFFSET.x, TILE_TOP_Y, JAIL_CELL_LOCAL_OFFSET.z)
		root.add_child(lm)
		var cell_w: float = 1.38
		var cell_d: float = 1.18
		var cell_h: float = 0.66
		var iron_dark_mat: StandardMaterial3D = _make_vivid_material(Color("#2D3A42"), 0.34, 0.55, 0.05)
		var floor_mat: StandardMaterial3D = _make_vivid_material(Color("#1A2024"), 0.72, 0.14, 0.03)
		var caution_mat: StandardMaterial3D = _make_vivid_material(Color("#F4A261"), 0.36, 0.10, 0.22)

		var cell_floor: BoxMesh = BoxMesh.new()
		cell_floor.size = Vector3(cell_w, 0.036, cell_d)
		_add_mesh_part(lm, cell_floor, Vector3(0.0, 0.018, 0.0), floor_mat)

		# Filete âmbar demarcando a área interna da cela
		var curb_front: BoxMesh = BoxMesh.new()
		curb_front.size = Vector3(cell_w + 0.04, 0.042, 0.045)
		_add_mesh_part(lm, curb_front, Vector3(0.0, 0.021, cell_d * 0.5), caution_mat)
		var curb_left: BoxMesh = BoxMesh.new()
		curb_left.size = Vector3(0.045, 0.042, cell_d + 0.04)
		_add_mesh_part(lm, curb_left, Vector3(-cell_w * 0.5, 0.021, 0.0), caution_mat)

		# 4 pilares estruturais nos cantos da cela
		var post_m: BoxMesh = BoxMesh.new()
		post_m.size = Vector3(0.085, cell_h, 0.085)
		var hx: float = cell_w * 0.5 - 0.04
		var hz: float = cell_d * 0.5 - 0.04
		_add_mesh_part(lm, post_m, Vector3(-hx, cell_h * 0.5, -hz), iron_dark_mat)
		_add_mesh_part(lm, post_m, Vector3(hx, cell_h * 0.5, -hz), iron_dark_mat)
		_add_mesh_part(lm, post_m, Vector3(-hx, cell_h * 0.5, hz), iron_dark_mat)
		_add_mesh_part(lm, post_m, Vector3(hx, cell_h * 0.5, hz), iron_dark_mat)

		# Grades metálicas nas 4 laterais (espaçadas para boa leitura do medalhão do peão preso)
		var bar_m: CylinderMesh = CylinderMesh.new()
		bar_m.top_radius = 0.017
		bar_m.bottom_radius = 0.017
		bar_m.height = cell_h - 0.06
		bar_m.radial_segments = 10
		for bx: float in [-0.42, -0.21, 0.0, 0.21, 0.42]:
			_add_mesh_part(lm, bar_m, Vector3(bx, cell_h * 0.5, hz), steel_mat)
			_add_mesh_part(lm, bar_m, Vector3(bx, cell_h * 0.5, -hz), steel_mat)
		for bz: float in [-0.36, -0.12, 0.12, 0.36]:
			_add_mesh_part(lm, bar_m, Vector3(-hx, cell_h * 0.5, bz), steel_mat)
			_add_mesh_part(lm, bar_m, Vector3(hx, cell_h * 0.5, bz), steel_mat)

		# Aro superior aberto (moldura de ferro sem teto fechado para não cobrir peões no 2D/3D)
		var rail_x: BoxMesh = BoxMesh.new()
		rail_x.size = Vector3(cell_w, 0.055, 0.065)
		_add_mesh_part(lm, rail_x, Vector3(0.0, cell_h, hz), iron_dark_mat)
		_add_mesh_part(lm, rail_x, Vector3(0.0, cell_h, -hz), iron_dark_mat)
		var rail_z: BoxMesh = BoxMesh.new()
		rail_z.size = Vector3(0.065, 0.055, cell_d)
		_add_mesh_part(lm, rail_z, Vector3(-hx, cell_h, 0.0), iron_dark_mat)
		_add_mesh_part(lm, rail_z, Vector3(hx, cell_h, 0.0), iron_dark_mat)

		# Sinalizador âmbar no pilar frontal esquerdo da cela (pulsa quando há jogador preso)
		_jail_beacon_mat = _make_vivid_material(Color("#FF9F1C"), 0.18, 0.12, 0.08)
		var beacon_s: SphereMesh = SphereMesh.new()
		beacon_s.radius = 0.072
		beacon_s.height = 0.144
		_add_mesh_part(lm, beacon_s, Vector3(-hx, cell_h + 0.075, hz), _jail_beacon_mat)
		return

	if tile_idx == 20:
		# Feriadão 20 de Setembro: monumento com pedestal e Bandeira do RS imponente com ondulação suave
		var lm: Node3D = Node3D.new()
		lm.position = Vector3(-0.78, TILE_TOP_Y, -0.76)
		root.add_child(lm)
		var stone_mat: StandardMaterial3D = _make_vivid_material(Color("#4E5852"), 0.55, 0.12, 0.04)
		var bronze_mat: StandardMaterial3D = _make_vivid_material(Color("#B8892D"), 0.28, 0.62, 0.12)

		var base_step1: CylinderMesh = CylinderMesh.new()
		base_step1.top_radius = 0.30
		base_step1.bottom_radius = 0.35
		base_step1.height = 0.09
		base_step1.radial_segments = 8
		_add_mesh_part(lm, base_step1, Vector3(0.0, 0.045, 0.0), stone_mat)

		var base_step2: CylinderMesh = CylinderMesh.new()
		base_step2.top_radius = 0.19
		base_step2.bottom_radius = 0.24
		base_step2.height = 0.09
		base_step2.radial_segments = 8
		_add_mesh_part(lm, base_step2, Vector3(0.0, 0.13, 0.0), bronze_mat)

		var pole: CylinderMesh = CylinderMesh.new()
		pole.top_radius = 0.028
		pole.bottom_radius = 0.040
		pole.height = 1.46
		pole.radial_segments = 16
		_add_mesh_part(lm, pole, Vector3(0.0, 0.85, 0.0), steel_mat)

		var finial_ring: TorusMesh = TorusMesh.new()
		finial_ring.inner_radius = 0.032
		finial_ring.outer_radius = 0.056
		_add_mesh_part(lm, finial_ring, Vector3(0.0, 1.56, 0.0), gold_mat)

		var finial: SphereMesh = SphereMesh.new()
		finial.radius = 0.072
		finial.height = 0.144
		_add_mesh_part(lm, finial, Vector3(0.0, 1.63, 0.0), gold_mat)

		# Bandeira tricolor articulada em 4 segmentos (estendida para +X dentro da própria casa 20)
		var green_mat: StandardMaterial3D = _make_vivid_material(Color("#24A148"), 0.34, 0.05, 0.22)
		var red_mat: StandardMaterial3D = _make_vivid_material(Color("#E63946"), 0.34, 0.05, 0.24)
		var yellow_mat: StandardMaterial3D = _make_vivid_material(Color("#FFCA3A"), 0.34, 0.05, 0.22)
		var crest_white_mat: StandardMaterial3D = _make_vivid_material(Color("#FAF9F2"), 0.30, 0.06, 0.18)

		var flag_anchor: Node3D = Node3D.new()
		flag_anchor.position = Vector3(0.03, 1.24, 0.0)
		lm.add_child(flag_anchor)

		var seg_w: float = 0.265
		var seg_h: float = 0.195
		var seg_t: float = 0.034
		var parent_seg: Node3D = flag_anchor
		for seg_i: int in range(4):
			var seg_pivot: Node3D = Node3D.new()
			seg_pivot.position = Vector3(0.0 if seg_i == 0 else seg_w, 0.0, 0.0)
			parent_seg.add_child(seg_pivot)
			_flag_segments.append(seg_pivot)

			var strip_mesh: BoxMesh = BoxMesh.new()
			strip_mesh.size = Vector3(seg_w + 0.012, seg_h, seg_t)
			_add_mesh_part(seg_pivot, strip_mesh, Vector3(seg_w * 0.5, seg_h, 0.0), green_mat)
			_add_mesh_part(seg_pivot, strip_mesh, Vector3(seg_w * 0.5, 0.0, 0.0), red_mat)
			_add_mesh_part(seg_pivot, strip_mesh, Vector3(seg_w * 0.5, -seg_h, 0.0), yellow_mat)

			# Escudo central farroupilha no miolo da bandeira
			if seg_i == 1:
				var shield: BoxMesh = BoxMesh.new()
				shield.size = Vector3(0.16, 0.16, seg_t + 0.018)
				_add_mesh_part(seg_pivot, shield, Vector3(seg_w * 0.72, 0.0, 0.0), crest_white_mat, Vector3(0.0, 0.0, 45.0))
				var shield_core: BoxMesh = BoxMesh.new()
				shield_core.size = Vector3(0.085, 0.085, seg_t + 0.026)
				_add_mesh_part(seg_pivot, shield_core, Vector3(seg_w * 0.72, 0.0, 0.0), gold_mat, Vector3(0.0, 0.0, 45.0))

			parent_seg = seg_pivot
		return

	if tile_idx == 30:
		# Vá pro Xadrez: torre sinalizadora imponente com giroflex rotativo e barreira de advertência
		var lm: Node3D = Node3D.new()
		lm.position = Vector3(0.62, TILE_TOP_Y, -0.66)
		root.add_child(lm)
		var siren_red_mat: StandardMaterial3D = _make_vivid_material(Color("#FF3347"), 0.16, 0.12, 0.72)
		var warn_yellow_mat: StandardMaterial3D = _make_vivid_material(Color("#FFCA3A"), 0.34, 0.10, 0.24)

		var ped1: CylinderMesh = CylinderMesh.new()
		ped1.top_radius = 0.28
		ped1.bottom_radius = 0.34
		ped1.height = 0.16
		ped1.radial_segments = 24
		_add_mesh_part(lm, ped1, Vector3(0.0, 0.08, 0.0), dark_mat)

		var ped2: CylinderMesh = CylinderMesh.new()
		ped2.top_radius = 0.18
		ped2.bottom_radius = 0.22
		ped2.height = 0.26
		ped2.radial_segments = 24
		_add_mesh_part(lm, ped2, Vector3(0.0, 0.28, 0.0), steel_mat)

		var collar: TorusMesh = TorusMesh.new()
		collar.inner_radius = 0.20
		collar.outer_radius = 0.255
		_add_mesh_part(lm, collar, Vector3(0.0, 0.41, 0.0), gold_mat, Vector3.ZERO, Vector3(1.0, 0.55, 1.0))

		var dome: SphereMesh = SphereMesh.new()
		dome.radius = 0.20
		dome.height = 0.38
		_add_mesh_part(lm, dome, Vector3(0.0, 0.56, 0.0), siren_red_mat)

		_go_jail_spinner = Node3D.new()
		_go_jail_spinner.position = Vector3(0.0, 0.56, 0.0)
		lm.add_child(_go_jail_spinner)
		var beam_bar: BoxMesh = BoxMesh.new()
		beam_bar.size = Vector3(0.50, 0.07, 0.08)
		_add_mesh_part(_go_jail_spinner, beam_bar, Vector3.ZERO, warn_yellow_mat)

		# Barreira zebrada discreta no quadrante superior esquerdo da casa 30
		var barrier: Node3D = Node3D.new()
		barrier.position = Vector3(-0.36, TILE_TOP_Y, -0.82)
		root.add_child(barrier)
		var leg_b: BoxMesh = BoxMesh.new()
		leg_b.size = Vector3(0.06, 0.28, 0.06)
		_add_mesh_part(barrier, leg_b, Vector3(-0.30, 0.14, 0.0), dark_mat)
		_add_mesh_part(barrier, leg_b, Vector3(0.30, 0.14, 0.0), dark_mat)
		var plank_b: BoxMesh = BoxMesh.new()
		plank_b.size = Vector3(0.76, 0.12, 0.05)
		_add_mesh_part(barrier, plank_b, Vector3(0.0, 0.24, 0.0), warn_yellow_mat)
		var stripe_b: BoxMesh = BoxMesh.new()
		stripe_b.size = Vector3(0.14, 0.125, 0.056)
		_add_mesh_part(barrier, stripe_b, Vector3(-0.18, 0.24, 0.0), dark_mat)
		_add_mesh_part(barrier, stripe_b, Vector3(0.18, 0.24, 0.0), dark_mat)
		return

	# Companhias e Impostos: miniaturas elegantes na borda interna (onde terrenos têm o friso de casas)
	if tile_type != "COMPANY" and tile_type != "TAX":
		return

	var edge_anchor: Vector3 = Vector3.ZERO
	var edge_yaw: float = 0.0
	if tile_idx > 0 and tile_idx < 10:
		edge_anchor = Vector3(0.0, TILE_TOP_Y, -tile_d * 0.5 + 0.15)
		edge_yaw = 0.0
	elif tile_idx > 10 and tile_idx < 20:
		edge_anchor = Vector3(tile_w * 0.5 - 0.15, TILE_TOP_Y, 0.0)
		edge_yaw = -90.0
	elif tile_idx > 20 and tile_idx < 30:
		edge_anchor = Vector3(0.0, TILE_TOP_Y, tile_d * 0.5 - 0.15)
		edge_yaw = 180.0
	else:
		edge_anchor = Vector3(-tile_w * 0.5 + 0.15, TILE_TOP_Y, 0.0)
		edge_yaw = 90.0

	var prop_root: Node3D = Node3D.new()
	prop_root.position = edge_anchor
	prop_root.rotation_degrees = Vector3(0.0, edge_yaw, 0.0)
	root.add_child(prop_root)

	if tile_type == "TAX":
		# Pilha de moedas douradas com faixa rubi de imposto
		var coin_c: CylinderMesh = CylinderMesh.new()
		coin_c.top_radius = 0.11
		coin_c.bottom_radius = 0.11
		coin_c.height = 0.045
		_add_mesh_part(prop_root, coin_c, Vector3(-0.08, 0.025, 0.0), gold_mat)
		_add_mesh_part(prop_root, coin_c, Vector3(-0.07, 0.075, 0.0), gold_mat)
		_add_mesh_part(prop_root, coin_c, Vector3(0.09, 0.025, 0.0), gold_mat)
		var seal: CylinderMesh = CylinderMesh.new()
		seal.top_radius = 0.07
		seal.bottom_radius = 0.07
		seal.height = 0.05
		_add_mesh_part(prop_root, seal, Vector3(-0.07, 0.12, 0.0), _make_vivid_material(Color("#E63946"), 0.28, 0.12, 0.24))
		return

	match art_id:
		"comp_usina_jacui":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.10
			cyl.bottom_radius = 0.13
			cyl.height = 0.28
			_add_mesh_part(prop_root, cyl, Vector3(0.0, 0.14, 0.0), steel_mat)
			var glow_r: TorusMesh = TorusMesh.new()
			glow_r.inner_radius = 0.10
			glow_r.outer_radius = 0.14
			_add_mesh_part(prop_root, glow_r, Vector3(0.0, 0.22, 0.0), _make_vivid_material(Color("#4CC9F0"), 0.20, 0.10, 0.55))
		"comp_viacao_fandangueira":
			var bus: BoxMesh = BoxMesh.new()
			bus.size = Vector3(0.38, 0.17, 0.16)
			_add_mesh_part(prop_root, bus, Vector3(0.0, 0.10, 0.0), _make_vivid_material(Color("#2A9D8F"), 0.30, 0.18, 0.16))
			var roof_b: BoxMesh = BoxMesh.new()
			roof_b.size = Vector3(0.34, 0.04, 0.14)
			_add_mesh_part(prop_root, roof_b, Vector3(0.0, 0.20, 0.0), _make_vivid_material(Color("#F6F4EC"), 0.30, 0.05, 0.10))
		"comp_estaleiro_rio_grande":
			var hull: BoxMesh = BoxMesh.new()
			hull.size = Vector3(0.42, 0.10, 0.16)
			_add_mesh_part(prop_root, hull, Vector3(0.0, 0.05, 0.0), _make_vivid_material(Color("#1D3557"), 0.35, 0.15, 0.12))
			var cabin: BoxMesh = BoxMesh.new()
			cabin.size = Vector3(0.20, 0.12, 0.13)
			_add_mesh_part(prop_root, cabin, Vector3(-0.04, 0.15, 0.0), _make_vivid_material(Color("#F8F9FA"), 0.30, 0.05, 0.10))
			var funnel: CylinderMesh = CylinderMesh.new()
			funnel.top_radius = 0.032
			funnel.bottom_radius = 0.036
			funnel.height = 0.14
			_add_mesh_part(prop_root, funnel, Vector3(0.08, 0.18, 0.0), _make_vivid_material(Color("#E63946"), 0.30, 0.08, 0.18))
		"comp_cooperativa_agricola":
			var silo: CylinderMesh = CylinderMesh.new()
			silo.top_radius = 0.10
			silo.bottom_radius = 0.10
			silo.height = 0.26
			_add_mesh_part(prop_root, silo, Vector3(-0.08, 0.13, 0.0), steel_mat)
			_add_mesh_part(prop_root, silo, Vector3(0.11, 0.11, 0.0), steel_mat, Vector3.ZERO, Vector3(0.85, 0.85, 0.85))
			var dome_s: SphereMesh = SphereMesh.new()
			dome_s.radius = 0.10
			dome_s.height = 0.12
			_add_mesh_part(prop_root, dome_s, Vector3(-0.08, 0.27, 0.0), gold_mat)
		_:
			# Aeroporto Salgado Filho: torre de controle moderna
			var stem_t: CylinderMesh = CylinderMesh.new()
			stem_t.top_radius = 0.055
			stem_t.bottom_radius = 0.085
			stem_t.height = 0.26
			_add_mesh_part(prop_root, stem_t, Vector3(0.0, 0.13, 0.0), steel_mat)
			var cab: CylinderMesh = CylinderMesh.new()
			cab.top_radius = 0.12
			cab.bottom_radius = 0.08
			cab.height = 0.10
			_add_mesh_part(prop_root, cab, Vector3(0.0, 0.30, 0.0), _make_vivid_material(Color("#4CC9F0"), 0.18, 0.20, 0.35))
			var cap_t: CylinderMesh = CylinderMesh.new()
			cap_t.top_radius = 0.13
			cap_t.bottom_radius = 0.13
			cap_t.height = 0.03
			_add_mesh_part(prop_root, cap_t, Vector3(0.0, 0.36, 0.0), gold_mat)

func _on_viewport_gui_input(event: InputEvent) -> void:
	if _camera == null or _tile_bounds_xz.is_empty():
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		var hit_idx: int = _raycast_tile_at_screen_pos(mm.position)
		_set_hovered_tile(hit_idx)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit_idx: int = _raycast_tile_at_screen_pos(mb.position)
			if hit_idx >= 0:
				tile_clicked.emit(hit_idx)

func _on_viewport_mouse_exited() -> void:
	_set_hovered_tile(-1)

func _raycast_tile_at_screen_pos(local_pos: Vector2) -> int:
	if _camera == null or _sub_viewport == null or _viewport_container == null:
		return -1
	var c_size: Vector2 = _viewport_container.size
	var vp_pos: Vector2 = local_pos
	if c_size.x > 1.0 and c_size.y > 1.0:
		vp_pos = Vector2(
			local_pos.x * float(_sub_viewport.size.x) / c_size.x,
			local_pos.y * float(_sub_viewport.size.y) / c_size.y
		)
	var origin: Vector3 = _camera.project_ray_origin(vp_pos)
	var dir: Vector3 = _camera.project_ray_normal(vp_pos)
	var board_plane: Plane = Plane(Vector3.UP, TILE_TOP_Y)
	var hit: Variant = board_plane.intersects_ray(origin, dir)
	if not (hit is Vector3):
		return -1
	var hit_vec: Vector3 = hit
	var pt_xz: Vector2 = Vector2(hit_vec.x, hit_vec.z)
	for i: int in range(_tile_bounds_xz.size()):
		if _tile_bounds_xz[i].has_point(pt_xz):
			return i
	return -1

func _set_hovered_tile(new_idx: int) -> void:
	if new_idx == _hovered_tile:
		return
	if _hovered_tile >= 0 and _hovered_tile < _tile_base_materials.size():
		var was_mortgaged: bool = _mortgaged_cache.get(_hovered_tile, false)
		_tile_base_materials[_hovered_tile].albedo_color = TILE_MORTGAGED_BG if was_mortgaged else _tile_default_colors[_hovered_tile]
		if _tile_art_materials.has(_hovered_tile):
			_tile_art_materials[_hovered_tile].albedo_color = TILE_ART_MORTGAGED_TINT if was_mortgaged else TILE_ART_NORMAL_TINT
	_hovered_tile = new_idx
	if _hovered_tile >= 0 and _hovered_tile < _tile_base_materials.size():
		_tile_base_materials[_hovered_tile].albedo_color = TILE_HOVER_BG
		if _tile_art_materials.has(_hovered_tile):
			_tile_art_materials[_hovered_tile].albedo_color = TILE_ART_HOVER_TINT

func get_player_color(player_id: int) -> Color:
	if _player_colors.has(player_id):
		return _player_colors[player_id]
	var safe_idx: int = absi(player_id) % TOKEN_COLORS.size()
	return TOKEN_COLORS[safe_idx]

func _compute_monopoly_tiles(owners_map: Dictionary[int, int]) -> Dictionary[int, bool]:
	var mono_tiles: Dictionary[int, bool] = {}
	if _tiles_cache.is_empty():
		return mono_tiles
	var group_indices: Dictionary[String, Array] = {}
	for i: int in range(_tiles_cache.size()):
		var t: Dictionary = _tiles_cache[i]
		if str(t.get("type", "")) != "PROPERTY":
			continue
		var g: String = str(t.get("group", ""))
		if g == "":
			continue
		if not group_indices.has(g):
			group_indices[g] = []
		group_indices[g].append(i)

	for g: String in group_indices.keys():
		var list: Array = group_indices[g]
		if list.is_empty():
			continue
		var first_tid: int = int(list[0])
		if not owners_map.has(first_tid):
			continue
		var expected_owner: int = owners_map[first_tid]
		var all_same: bool = true
		for idx_var: Variant in list:
			var tid: int = int(idx_var)
			if owners_map.get(tid, -1) != expected_owner:
				all_same = false
				break
		if all_same:
			for idx_var: Variant in list:
				mono_tiles[int(idx_var)] = true
	return mono_tiles

func update_ownership(owners_map: Dictionary[int, int], mortgaged_map: Dictionary[int, bool]) -> void:
	_mortgaged_cache.clear()
	var mono_tiles: Dictionary[int, bool] = _compute_monopoly_tiles(owners_map)
	var mono_gold_mat: StandardMaterial3D = _make_vivid_material(Color("#FFD166"), 0.22, 0.70, 0.36)

	for tile_idx: int in _owner_overlays.keys():
		var overlay: Node3D = _owner_overlays[tile_idx]
		for child: Node in overlay.get_children():
			child.queue_free()

		if tile_idx < 0 or tile_idx >= _tile_bounds_xz.size():
			continue

		if not owners_map.has(tile_idx):
			if tile_idx < _tile_base_materials.size() and tile_idx != _hovered_tile:
				_tile_base_materials[tile_idx].albedo_color = _tile_default_colors[tile_idx]
			if _tile_art_materials.has(tile_idx) and tile_idx != _hovered_tile:
				_tile_art_materials[tile_idx].albedo_color = TILE_ART_NORMAL_TINT
			continue

		var owner_id: int = owners_map[tile_idx]
		var is_mortgaged: bool = mortgaged_map.get(tile_idx, false)
		var is_monopoly: bool = mono_tiles.get(tile_idx, false) and not is_mortgaged
		_mortgaged_cache[tile_idx] = is_mortgaged

		if tile_idx < _tile_base_materials.size() and tile_idx != _hovered_tile:
			_tile_base_materials[tile_idx].albedo_color = TILE_MORTGAGED_BG if is_mortgaged else _tile_default_colors[tile_idx]
		if _tile_art_materials.has(tile_idx) and tile_idx != _hovered_tile:
			_tile_art_materials[tile_idx].albedo_color = TILE_ART_MORTGAGED_TINT if is_mortgaged else TILE_ART_NORMAL_TINT

		var rect_xz: Rect2 = _tile_bounds_xz[tile_idx]
		var tile_w: float = rect_xz.size.x - TILE_GAP
		var tile_d: float = rect_xz.size.y - TILE_GAP
		var owner_color: Color = get_player_color(owner_id)
		var bar_alpha: float = 0.45 if is_mortgaged else 1.0

		var bar: MeshInstance3D = MeshInstance3D.new()
		var bar_box: BoxMesh = BoxMesh.new()
		var bar_t: float = 0.14
		var bar_pos: Vector3 = Vector3.ZERO
		if tile_idx > 0 and tile_idx < 10:
			bar_box.size = Vector3(tile_w, 0.044, bar_t)
			bar_pos = Vector3(0.0, TILE_TOP_Y + 0.022, tile_d * 0.5 - bar_t * 0.5)
		elif tile_idx > 10 and tile_idx < 20:
			bar_box.size = Vector3(bar_t, 0.044, tile_d)
			bar_pos = Vector3(-tile_w * 0.5 + bar_t * 0.5, TILE_TOP_Y + 0.022, 0.0)
		elif tile_idx > 20 and tile_idx < 30:
			bar_box.size = Vector3(tile_w, 0.044, bar_t)
			bar_pos = Vector3(0.0, TILE_TOP_Y + 0.022, -tile_d * 0.5 + bar_t * 0.5)
		else:
			bar_box.size = Vector3(bar_t, 0.044, tile_d)
			bar_pos = Vector3(tile_w * 0.5 - bar_t * 0.5, TILE_TOP_Y + 0.022, 0.0)
		bar.position = bar_pos
		bar.mesh = bar_box
		bar.material_override = _make_material(owner_color, 0.38, 0.10, bar_alpha)
		overlay.add_child(bar)

		# Indicador visual claro de Monopólio / Grupo Completo (filete dourado luminoso + emblema estrela)
		if is_monopoly:
			var is_h: bool = (tile_idx > 0 and tile_idx < 10) or (tile_idx > 20 and tile_idx < 30)
			var gold_trim: BoxMesh = BoxMesh.new()
			gold_trim.size = Vector3(tile_w, 0.024, 0.042) if is_h else Vector3(0.042, 0.024, tile_d)
			var trim_shift: Vector3 = Vector3.ZERO
			if tile_idx > 0 and tile_idx < 10:
				trim_shift = Vector3(0.0, 0.026, -bar_t * 0.5 - 0.015)
			elif tile_idx > 10 and tile_idx < 20:
				trim_shift = Vector3(bar_t * 0.5 + 0.015, 0.026, 0.0)
			elif tile_idx > 20 and tile_idx < 30:
				trim_shift = Vector3(0.0, 0.026, bar_t * 0.5 + 0.015)
			else:
				trim_shift = Vector3(-bar_t * 0.5 - 0.015, 0.026, 0.0)
			_add_mesh_part(overlay, gold_trim, bar_pos + trim_shift, mono_gold_mat)

			var star_gem: BoxMesh = BoxMesh.new()
			star_gem.size = Vector3(0.095, 0.040, 0.095)
			_add_mesh_part(overlay, star_gem, bar_pos + Vector3(0.0, 0.036, 0.0), mono_gold_mat, Vector3(0.0, 45.0, 0.0))

		if is_mortgaged:
			var hip_lbl: Label3D = Label3D.new()
			hip_lbl.text = "HIP"
			if _bold_font != null:
				hip_lbl.font = _bold_font
			hip_lbl.font_size = 32
			hip_lbl.pixel_size = 0.0058
			hip_lbl.modulate = Color("#FF595E")
			hip_lbl.outline_modulate = Color("#080E0B")
			hip_lbl.outline_size = 8
			hip_lbl.position = Vector3(0.0, TILE_TOP_Y + 0.045, 0.0)
			hip_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			overlay.add_child(hip_lbl)

func update_buildings(buildings_map: Dictionary[int, int]) -> void:
	var base_mat: StandardMaterial3D = _make_vivid_material(Color("#F0E9D6"), 0.46, 0.05, 0.08)
	var house_mat: StandardMaterial3D = _make_vivid_material(Color("#22B573"), 0.30, 0.08, 0.18)
	var door_mat: StandardMaterial3D = _make_vivid_material(Color("#2D1D14"), 0.52, 0.05, 0.02)
	var roof_mat: StandardMaterial3D = _make_vivid_material(Color("#C8552E"), 0.38, 0.06, 0.14)
	var window_mat: StandardMaterial3D = _make_vivid_material(Color("#FFF0A6"), 0.16, 0.05, 0.65)
	var hotel_mat: StandardMaterial3D = _make_vivid_material(Color("#D61F33"), 0.26, 0.14, 0.22)
	var hotel_trim_mat: StandardMaterial3D = _make_vivid_material(Color("#FFF8E8"), 0.30, 0.08, 0.12)
	var hotel_roof_mat: StandardMaterial3D = _make_vivid_material(Color("#FFD166"), 0.20, 0.72, 0.24)

	for tile_idx: int in _building_overlays.keys():
		var overlay: Node3D = _building_overlays[tile_idx]
		for child: Node in overlay.get_children():
			child.queue_free()

		var prev_level: int = _last_building_levels.get(tile_idx, 0)
		var level: int = buildings_map.get(tile_idx, 0)
		_last_building_levels[tile_idx] = level
		if level <= 0 or tile_idx < 0 or tile_idx >= _tile_bounds_xz.size():
			continue

		var should_pop: bool = (level > prev_level) and is_inside_tree()
		var rect_xz: Rect2 = _tile_bounds_xz[tile_idx]
		var tile_w: float = rect_xz.size.x - TILE_GAP
		var tile_d: float = rect_xz.size.y - TILE_GAP
		var is_horiz_stripe: bool = (tile_idx > 0 and tile_idx < 10) or (tile_idx > 20 and tile_idx < 30)
		var stripe_center_offset: float = STRIPE_THICK * 0.5

		var anchor_pos: Vector3 = Vector3.ZERO
		if tile_idx > 0 and tile_idx < 10:
			anchor_pos = Vector3(0.0, TILE_TOP_Y + 0.026, -tile_d * 0.5 + stripe_center_offset)
		elif tile_idx > 10 and tile_idx < 20:
			anchor_pos = Vector3(tile_w * 0.5 - stripe_center_offset, TILE_TOP_Y + 0.026, 0.0)
		elif tile_idx > 20 and tile_idx < 30:
			anchor_pos = Vector3(0.0, TILE_TOP_Y + 0.026, tile_d * 0.5 - stripe_center_offset)
		else:
			anchor_pos = Vector3(-tile_w * 0.5 + stripe_center_offset, TILE_TOP_Y + 0.026, 0.0)

		if level >= 5:
			# Hotel 3D imponente em dois pavimentos + torre central dourada (claramente distinto das casas)
			var hotel_node: Node3D = Node3D.new()
			hotel_node.position = anchor_pos

			var plinth: BoxMesh = BoxMesh.new()
			plinth.size = Vector3(0.62, 0.055, 0.25) if is_horiz_stripe else Vector3(0.25, 0.055, 0.62)
			_add_mesh_part(hotel_node, plinth, Vector3(0.0, 0.028, 0.0), hotel_trim_mat)

			var main_body: BoxMesh = BoxMesh.new()
			main_body.size = Vector3(0.56, 0.42, 0.22) if is_horiz_stripe else Vector3(0.22, 0.42, 0.56)
			_add_mesh_part(hotel_node, main_body, Vector3(0.0, 0.26, 0.0), hotel_mat)

			var win_band: BoxMesh = BoxMesh.new()
			win_band.size = Vector3(0.575, 0.06, 0.17) if is_horiz_stripe else Vector3(0.17, 0.06, 0.575)
			_add_mesh_part(hotel_node, win_band, Vector3(0.0, 0.36, 0.0), window_mat)
			_add_mesh_part(hotel_node, win_band, Vector3(0.0, 0.24, 0.0), window_mat)
			_add_mesh_part(hotel_node, win_band, Vector3(0.0, 0.12, 0.0), window_mat)

			var cornice: BoxMesh = BoxMesh.new()
			cornice.size = Vector3(0.60, 0.048, 0.25) if is_horiz_stripe else Vector3(0.25, 0.048, 0.60)
			_add_mesh_part(hotel_node, cornice, Vector3(0.0, 0.485, 0.0), hotel_trim_mat)

			var upper_tower: BoxMesh = BoxMesh.new()
			upper_tower.size = Vector3(0.32, 0.16, 0.21) if is_horiz_stripe else Vector3(0.21, 0.16, 0.32)
			_add_mesh_part(hotel_node, upper_tower, Vector3(0.0, 0.585, 0.0), hotel_mat)

			var roof: PrismMesh = PrismMesh.new()
			roof.size = Vector3(0.36, 0.16, 0.23) if is_horiz_stripe else Vector3(0.23, 0.16, 0.36)
			_add_mesh_part(hotel_node, roof, Vector3(0.0, 0.72, 0.0), hotel_roof_mat)

			var crown_gem: SphereMesh = SphereMesh.new()
			crown_gem.radius = 0.045
			crown_gem.height = 0.09
			_add_mesh_part(hotel_node, crown_gem, Vector3(0.0, 0.81, 0.0), hotel_roof_mat)

			overlay.add_child(hotel_node)
			if should_pop:
				_animate_building_pop(hotel_node, anchor_pos, true)
		else:
			# 1 a 4 casas esmeralda nítidas sobre o friso fino (sem sobrepor os peões)
			var spacing: float = 0.21
			for h: int in range(level):
				var offset_val: float = (float(h) - float(level - 1) * 0.5) * spacing
				var house_node: Node3D = Node3D.new()
				var shift: Vector3 = Vector3(offset_val, 0.0, 0.0) if is_horiz_stripe else Vector3(0.0, 0.0, offset_val)
				var final_pos: Vector3 = anchor_pos + shift
				house_node.position = final_pos

				var h_base: BoxMesh = BoxMesh.new()
				h_base.size = Vector3(0.175, 0.036, 0.175)
				_add_mesh_part(house_node, h_base, Vector3(0.0, 0.018, 0.0), base_mat)

				var h_body: BoxMesh = BoxMesh.new()
				h_body.size = Vector3(0.16, 0.21, 0.16)
				_add_mesh_part(house_node, h_body, Vector3(0.0, 0.135, 0.0), house_mat)

				var h_door: BoxMesh = BoxMesh.new()
				h_door.size = Vector3(0.048, 0.09, 0.168) if is_horiz_stripe else Vector3(0.168, 0.09, 0.048)
				_add_mesh_part(house_node, h_door, Vector3(0.0, 0.08, 0.0), door_mat)

				var h_win: BoxMesh = BoxMesh.new()
				h_win.size = Vector3(0.168, 0.046, 0.075) if is_horiz_stripe else Vector3(0.075, 0.046, 0.168)
				_add_mesh_part(house_node, h_win, Vector3(0.0, 0.165, 0.0), window_mat)

				var h_roof: PrismMesh = PrismMesh.new()
				h_roof.size = Vector3(0.20, 0.135, 0.20)
				_add_mesh_part(house_node, h_roof, Vector3(0.0, 0.305, 0.0), roof_mat)

				var h_chimney: BoxMesh = BoxMesh.new()
				h_chimney.size = Vector3(0.036, 0.085, 0.036)
				_add_mesh_part(house_node, h_chimney, Vector3(0.055, 0.34, 0.03), base_mat)

				overlay.add_child(house_node)
				if should_pop and h == level - 1:
					_animate_building_pop(house_node, final_pos, false)

func _animate_building_pop(node: Node3D, final_pos: Vector3, is_hotel: bool = false) -> void:
	node.scale = Vector3(0.10, 0.10, 0.10)
	node.position = final_pos + Vector3(0.0, 0.36 if is_hotel else 0.28, 0.0)
	var tw: Tween = create_tween()
	_register_tween(tw)
	tw.set_parallel(true)
	tw.tween_property(node, "position", final_pos, 0.34 if is_hotel else 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector3.ONE, 0.32 if is_hotel else 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Pequeno anel dourado de assentamento no piso da construção
	var parent_node: Node = node.get_parent()
	if parent_node is Node3D:
		var ring_inst: MeshInstance3D = MeshInstance3D.new()
		var ring_m: TorusMesh = TorusMesh.new()
		ring_m.inner_radius = 0.14 if is_hotel else 0.08
		ring_m.outer_radius = 0.20 if is_hotel else 0.12
		ring_inst.mesh = ring_m
		ring_inst.position = final_pos + Vector3(0.0, 0.015, 0.0)
		ring_inst.scale = Vector3(0.45, 0.25, 0.45)
		var r_mat: StandardMaterial3D = StandardMaterial3D.new()
		r_mat.albedo_color = Color("#FFD166") if is_hotel else Color("#A8FF78")
		r_mat.albedo_color.a = 0.85
		r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r_mat.emission_enabled = true
		r_mat.emission = r_mat.albedo_color
		r_mat.emission_energy_multiplier = 1.0
		r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_inst.material_override = r_mat
		(parent_node as Node3D).add_child(ring_inst)

		var r_tw: Tween = create_tween()
		_register_tween(r_tw)
		r_tw.set_parallel(true)
		r_tw.tween_property(ring_inst, "scale", Vector3(1.65, 0.25, 1.65), 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		r_tw.tween_property(r_mat, "albedo_color:a", 0.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		r_tw.chain().tween_callback(func() -> void:
			if is_instance_valid(ring_inst):
				ring_inst.queue_free()
		)

func play_tile_pulse(tile_idx: int, pulse_color: Color, floating_text: String = "") -> void:
	if _fx_root == null or not is_inside_tree():
		return
	if tile_idx < 0 or tile_idx >= _tile_bounds_xz.size():
		return

	var rect_xz: Rect2 = _tile_bounds_xz[tile_idx]
	var center: Vector3 = _tile_centers_3d[tile_idx]
	var pw: float = maxf(0.4, rect_xz.size.x - TILE_GAP + 0.04)
	var pd: float = maxf(0.4, rect_xz.size.y - TILE_GAP + 0.04)

	var pulse_mesh: MeshInstance3D = MeshInstance3D.new()
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2(pw, pd)
	pulse_mesh.mesh = quad
	pulse_mesh.position = Vector3(center.x, TILE_TOP_Y + 0.032, center.z)
	var p_mat: StandardMaterial3D = StandardMaterial3D.new()
	p_mat.albedo_color = Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.58)
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.emission_enabled = true
	p_mat.emission = pulse_color
	p_mat.emission_energy_multiplier = 1.15
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse_mesh.material_override = p_mat
	_fx_root.add_child(pulse_mesh)

	var tw: Tween = create_tween()
	_register_tween(tw)
	tw.set_parallel(true)
	tw.tween_property(pulse_mesh, "scale", Vector3(1.12, 1.0, 1.12), 0.58).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(p_mat, "albedo_color:a", 0.0, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(pulse_mesh):
			pulse_mesh.queue_free()
	)

	if floating_text != "":
		var pop_lbl: Label3D = Label3D.new()
		pop_lbl.text = floating_text
		if _bold_font != null:
			pop_lbl.font = _bold_font
		pop_lbl.font_size = 42
		pop_lbl.pixel_size = 0.0082
		pop_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pop_lbl.no_depth_test = true
		pop_lbl.modulate = Color(pulse_color.lightened(0.32).r, pulse_color.lightened(0.32).g, pulse_color.lightened(0.32).b, 1.0)
		pop_lbl.outline_modulate = Color(0.03, 0.05, 0.04, 1.0)
		pop_lbl.outline_size = 10
		pop_lbl.position = Vector3(center.x, TILE_TOP_Y + 0.82, center.z)
		pop_lbl.scale = Vector3(0.45, 0.45, 0.45)
		_fx_root.add_child(pop_lbl)

		var l_tw: Tween = create_tween()
		_register_tween(l_tw)
		l_tw.set_parallel(true)
		l_tw.tween_property(pop_lbl, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		l_tw.tween_property(pop_lbl, "position:y", TILE_TOP_Y + 1.85, 0.96).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		l_tw.tween_property(pop_lbl, "modulate:a", 0.0, 0.36).set_delay(0.60)
		l_tw.tween_property(pop_lbl, "outline_modulate:a", 0.0, 0.36).set_delay(0.60)
		l_tw.chain().tween_callback(func() -> void:
			if is_instance_valid(pop_lbl):
				pop_lbl.queue_free()
		)

# --- Peões 3D: Medalhões / Totens Temáticos Gaúchos Ilustrados ---

func _normalize_pawn_art_id(pawn_id: String) -> String:
	var key: String = pawn_id.strip_edges().to_upper()
	match key:
		"CUIA", "CHIMARRAO":
			return "cuia"
		"QUERO_QUERO":
			return "quero_quero"
		"ESPETO", "CHURRASCO":
			return "espeto"
		"CAVALO":
			return "cavalo"
		"CHAPEU":
			return "chapeu"
		"FACAO":
			return "facao"
		_:
			return "cuia"

func _try_load_pawn_art(pawn_id: String) -> Texture2D:
	var canonical: String = _normalize_pawn_art_id(pawn_id)
	var extensions: Array[String] = ["png", "webp", "svg"]
	for ext: String in extensions:
		var path: String = "res://assets/pawns/%s.%s" % [canonical, ext]
		if ResourceLoader.exists(path):
			var loaded: Resource = ResourceLoader.load(path)
			if loaded is Texture2D:
				return loaded as Texture2D
		var abs_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return null

func setup_tokens(players: Array[Dictionary]) -> void:
	_kill_token_pose_tweens()
	_kill_camera_tweens()
	_last_building_levels.clear()
	if _halo_tween != null and _halo_tween.is_valid():
		_halo_tween.kill()
	_halo_tween = null
	for child: Node in _tokens_root.get_children():
		child.queue_free()
	_token_nodes.clear()
	_token_medallions.clear()
	_token_stems.clear()
	_token_halos.clear()
	_token_jail_rings.clear()
	_jailed_player_ids.clear()
	_player_colors.clear()
	_active_player_id = -1
	_total_players_count = players.size()

	for i: int in range(players.size()):
		var player: Dictionary = players[i]
		var pid: int = int(player.get("id", i))
		var custom_hex: String = str(player.get("color_hex", ""))
		var token_color: Color = Color(custom_hex) if custom_hex != "" else TOKEN_COLORS[i % TOKEN_COLORS.size()]
		_player_colors[pid] = token_color

		var pawn_id: String = str(player.get("pawn_id", "cuia"))
		var pawn_code: String = str(player.get("pawn_code", "P%d" % (i + 1)))
		var pawn_node: Node3D = _build_gaucho_pawn_3d(pid, pawn_id, pawn_code, token_color)
		_tokens_root.add_child(pawn_node)
		_token_nodes[pid] = pawn_node

	_sync_token_medallions_to_camera(_is_2d_view, false)
	update_token_positions(players)

func set_active_player(player_id: int) -> void:
	_active_player_id = player_id
	if _halo_tween != null and _halo_tween.is_valid():
		_halo_tween.kill()
	_halo_tween = null

	for pid: int in _token_halos.keys():
		var halo: MeshInstance3D = _token_halos[pid]
		if halo == null or not is_instance_valid(halo):
			continue
		var token_node: Node3D = _token_nodes.get(pid, null)
		var show_halo: bool = (pid == player_id) and (token_node != null and token_node.visible)
		halo.visible = show_halo
		halo.scale = Vector3(1.0, 0.25, 1.0)
		if show_halo and is_inside_tree():
			_halo_tween = create_tween()
			_halo_tween.set_loops()
			_halo_tween.set_trans(Tween.TRANS_SINE)
			_halo_tween.set_ease(Tween.EASE_IN_OUT)
			_halo_tween.tween_property(halo, "scale", Vector3(1.12, 0.25, 1.12), 0.78)
			_halo_tween.tween_property(halo, "scale", Vector3(0.96, 0.25, 0.96), 0.78)

func _add_mesh_part(
	parent: Node3D,
	mesh: Mesh,
	pos: Vector3,
	mat: Material,
	rot_deg: Vector3 = Vector3.ZERO,
	scl: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.scale = scl
	inst.material_override = mat
	parent.add_child(inst)
	return inst

func _build_gaucho_pawn_3d(player_id: int, pawn_id: String, pawn_code: String, player_color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	var vivid_col: Color = _boost_vivid_color(player_color)
	var player_mat: StandardMaterial3D = _make_vivid_material(vivid_col, 0.22, 0.16, 0.20)
	var player_rim_mat: StandardMaterial3D = _make_vivid_material(vivid_col.lightened(0.24), 0.18, 0.22, 0.22)
	var obsidian_mat: StandardMaterial3D = _make_vivid_material(Color("#121916"), 0.36, 0.22, 0.02)
	var gold_mat: StandardMaterial3D = _make_vivid_material(Color("#FFD166"), 0.22, 0.72, 0.14)

	# 1. Base pesada elegante com borda escura contrastante e corpo na cor saturada do jogador
	var halo_torus: TorusMesh = TorusMesh.new()
	halo_torus.inner_radius = 0.305
	halo_torus.outer_radius = 0.375
	halo_torus.rings = 36
	halo_torus.ring_segments = 12
	var halo_col: Color = Color("#FFE28A").lerp(vivid_col, 0.28)
	var halo_mat: StandardMaterial3D = StandardMaterial3D.new()
	halo_mat.albedo_color = Color(halo_col.r, halo_col.g, halo_col.b, 0.90)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.roughness = 0.22
	halo_mat.metallic = 0.10
	halo_mat.emission_enabled = true
	halo_mat.emission = halo_col
	halo_mat.emission_energy_multiplier = 0.95
	var halo_inst: MeshInstance3D = _add_mesh_part(root, halo_torus, Vector3(0.0, 0.016, 0.0), halo_mat, Vector3.ZERO, Vector3(1.0, 0.25, 1.0))
	halo_inst.visible = false
	_token_halos[player_id] = halo_inst

	# Anel âmbar-alaranjado sutil sob a base quando o jogador está preso no Xadrez
	var jail_torus: TorusMesh = TorusMesh.new()
	jail_torus.inner_radius = 0.265
	jail_torus.outer_radius = 0.340
	jail_torus.rings = 32
	jail_torus.ring_segments = 10
	var jail_ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	jail_ring_mat.albedo_color = Color(1.0, 0.56, 0.14, 0.88)
	jail_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jail_ring_mat.roughness = 0.22
	jail_ring_mat.emission_enabled = true
	jail_ring_mat.emission = Color("#FF8C1A")
	jail_ring_mat.emission_energy_multiplier = 1.10
	var jail_ring_inst: MeshInstance3D = _add_mesh_part(root, jail_torus, Vector3(0.0, 0.022, 0.0), jail_ring_mat, Vector3.ZERO, Vector3(1.0, 0.30, 1.0))
	jail_ring_inst.visible = false
	_token_jail_rings[player_id] = jail_ring_inst

	var base_shadow: CylinderMesh = CylinderMesh.new()
	base_shadow.top_radius = 0.255
	base_shadow.bottom_radius = 0.275
	base_shadow.height = 0.042
	base_shadow.radial_segments = 32
	_add_mesh_part(root, base_shadow, Vector3(0.0, 0.021, 0.0), obsidian_mat)

	var base_disc: CylinderMesh = CylinderMesh.new()
	base_disc.top_radius = 0.232
	base_disc.bottom_radius = 0.245
	base_disc.height = 0.048
	base_disc.radial_segments = 32
	_add_mesh_part(root, base_disc, Vector3(0.0, 0.058, 0.0), player_mat)

	# Haste dourada discreta que sustenta o medalhão na vista 3D isométrica (retrai automaticamente no 2D)
	var stem_cyl: CylinderMesh = CylinderMesh.new()
	stem_cyl.top_radius = 0.055
	stem_cyl.bottom_radius = 0.088
	stem_cyl.height = 0.18
	stem_cyl.radial_segments = 20
	var stem_inst: MeshInstance3D = _add_mesh_part(root, stem_cyl, Vector3(0.0, 0.155, 0.0), gold_mat)
	_token_stems[player_id] = stem_inst

	# 2. Medalhão / Totem circular 3D com a cor do jogador, aro contrastante e ilustração 256x256 nítida
	var medallion: Node3D = Node3D.new()
	medallion.name = "Medallion"
	root.add_child(medallion)
	_token_medallions[player_id] = medallion

	var coin_body: CylinderMesh = CylinderMesh.new()
	coin_body.top_radius = 0.335
	coin_body.bottom_radius = 0.335
	coin_body.height = 0.072
	coin_body.radial_segments = 36
	_add_mesh_part(medallion, coin_body, Vector3.ZERO, player_mat)

	var outer_bevel: TorusMesh = TorusMesh.new()
	outer_bevel.inner_radius = 0.312
	outer_bevel.outer_radius = 0.360
	outer_bevel.rings = 36
	outer_bevel.ring_segments = 14
	_add_mesh_part(medallion, outer_bevel, Vector3(0.0, 0.014, 0.0), player_rim_mat, Vector3.ZERO, Vector3(1.0, 0.72, 1.0))

	var dark_edge: TorusMesh = TorusMesh.new()
	dark_edge.inner_radius = 0.345
	dark_edge.outer_radius = 0.370
	dark_edge.rings = 36
	dark_edge.ring_segments = 12
	_add_mesh_part(medallion, dark_edge, Vector3(0.0, -0.012, 0.0), obsidian_mat, Vector3.ZERO, Vector3(1.0, 0.78, 1.0))

	var pawn_tex: Texture2D = _try_load_pawn_art(pawn_id)
	if pawn_tex != null:
		var emblem_quad: PlaneMesh = PlaneMesh.new()
		emblem_quad.size = Vector2(0.58, 0.58)
		var emblem_mat: StandardMaterial3D = StandardMaterial3D.new()
		emblem_mat.albedo_texture = pawn_tex
		emblem_mat.albedo_color = Color.WHITE
		emblem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		emblem_mat.roughness = 0.32
		emblem_mat.metallic = 0.06
		emblem_mat.emission_enabled = true
		emblem_mat.emission_texture = pawn_tex
		emblem_mat.emission_energy_multiplier = 0.22
		emblem_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_add_mesh_part(medallion, emblem_quad, Vector3(0.0, 0.041, 0.0), emblem_mat)
	else:
		var fallback_lbl: Label3D = Label3D.new()
		fallback_lbl.text = pawn_code
		if _bold_font != null:
			fallback_lbl.font = _bold_font
		fallback_lbl.font_size = 44
		fallback_lbl.pixel_size = 0.0055
		fallback_lbl.modulate = Color("#FFFDF8")
		fallback_lbl.outline_modulate = Color("#0D1511")
		fallback_lbl.outline_size = 8
		fallback_lbl.position = Vector3(0.0, 0.044, 0.0)
		fallback_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		medallion.add_child(fallback_lbl)

	# Verso acabado do medalhão com anel dourado
	var back_ring: TorusMesh = TorusMesh.new()
	back_ring.inner_radius = 0.22
	back_ring.outer_radius = 0.26
	back_ring.rings = 28
	back_ring.ring_segments = 10
	_add_mesh_part(medallion, back_ring, Vector3(0.0, -0.036, 0.0), gold_mat, Vector3.ZERO, Vector3(1.0, 0.45, 1.0))

	return root

func _get_jail_cell_slot_world_pos(slot_idx: int, occupants_count: int) -> Vector3:
	if _tile_centers_3d.size() <= JAIL_TILE_INDEX:
		return Vector3(0.0, TILE_TOP_Y + 0.038, 0.0)
	var center: Vector3 = _tile_centers_3d[JAIL_TILE_INDEX] + JAIL_CELL_LOCAL_OFFSET
	var total: int = maxi(1, occupants_count)
	var clamped: int = clampi(slot_idx, 0, total - 1)
	var cols: int = mini(3, total) if total <= 3 else (2 if total <= 4 else 3)
	var row: int = floori(float(clamped) / float(cols))
	var col: int = clamped % cols
	var rows_total: int = ceili(float(total) / float(cols))
	var cols_in_row: int = mini(cols, total - row * cols)
	var ox: float = (float(col) - float(cols_in_row - 1) * 0.5) * 0.38
	var oz: float = (float(row) - float(rows_total - 1) * 0.5) * 0.42
	return Vector3(center.x + ox, TILE_TOP_Y + 0.038, center.z + oz)

func _get_jail_visit_slot_world_pos(slot_idx: int, occupants_count: int) -> Vector3:
	if _tile_centers_3d.size() <= JAIL_TILE_INDEX:
		return Vector3(0.0, TILE_TOP_Y, 0.0)
	var center: Vector3 = _tile_centers_3d[JAIL_TILE_INDEX]
	# Corredor externo de "Só de Visita" fora das grades (esquerda e frente da cela)
	var visit_slots: Array[Vector2] = [
		Vector2(-0.84, 0.44),
		Vector2(-0.84, -0.16),
		Vector2(-0.22, 0.54),
		Vector2(0.42, 0.54),
		Vector2(-0.84, -0.74),
		Vector2(0.92, 0.54)
	]
	var safe_idx: int = clampi(slot_idx, 0, visit_slots.size() - 1)
	if occupants_count == 1:
		safe_idx = 0
	var off: Vector2 = visit_slots[safe_idx]
	return Vector3(center.x + off.x, TILE_TOP_Y, center.z + off.y)

func _get_token_slot_world_pos(slot_idx: int, tile_idx: int, occupants_count: int = -1) -> Vector3:
	if _tile_centers_3d.is_empty():
		return Vector3(0.0, TILE_TOP_Y, 0.0)
	var safe_tile: int = posmod(tile_idx, _tile_centers_3d.size())
	if safe_tile == JAIL_TILE_INDEX:
		return _get_jail_visit_slot_world_pos(slot_idx, maxi(1, occupants_count))
	var center: Vector3 = _tile_centers_3d[safe_tile]
	var total: int = maxi(1, occupants_count if occupants_count > 0 else _total_players_count)
	var clamped_slot: int = clampi(slot_idx, 0, total - 1)

	# Cantos 0, 20 e 30 (2.64 x 2.64): zona frontal limpa abaixo dos marcos 3D e acima da faixa de título
	if safe_tile == 0 or safe_tile == 20 or safe_tile == 30:
		var c_col: int = clamped_slot % 3
		var c_row: int = floori(float(clamped_slot) / 3.0)
		var c_cols_in_row: int = mini(3, total - c_row * 3)
		var c_rows: int = 2 if total > 3 else 1
		var c_ox: float = (float(c_col) - float(c_cols_in_row - 1) * 0.5) * 0.72
		var c_oz: float = (float(c_row) - float(c_rows - 1) * 0.5) * 0.50 + 0.24
		return Vector3(center.x + c_ox, TILE_TOP_Y, center.z + c_oz)

	# Casas superior/inferior (0.89 largura x 2.64 profundidade): grade 2x3 ao longo da profundidade radial
	if safe_tile < 10 or (safe_tile > 20 and safe_tile < 30):
		var col: int = clamped_slot % 2
		var row: int = floori(float(clamped_slot) / 2.0)
		var cols_in_row: int = mini(2, total - row * 2)
		var rows_total: int = ceili(float(total) / 2.0)
		var ox: float = (float(col) - float(cols_in_row - 1) * 0.5) * 0.42
		var radial_bias: float = 0.34 if safe_tile < 10 else -0.22
		var oz: float = radial_bias + (float(row) - float(rows_total - 1) * 0.5) * 0.56
		return Vector3(center.x + ox, TILE_TOP_Y, center.z + oz)

	# Casas esquerda/direita (2.64 largura x 0.89 profundidade): grade 3x2 ao longo da largura radial
	var s_col: int = clamped_slot % 3
	var s_row: int = floori(float(clamped_slot) / 3.0)
	var s_cols_in_row: int = mini(3, total - s_row * 3)
	var s_rows_total: int = 2 if total > 3 else 1
	var side_bias: float = -0.26 if safe_tile < 20 else 0.26
	var s_ox: float = side_bias + (float(s_col) - float(s_cols_in_row - 1) * 0.5) * 0.56
	var s_oz: float = (float(s_row) - float(s_rows_total - 1) * 0.5) * 0.42
	return Vector3(center.x + s_ox, TILE_TOP_Y, center.z + s_oz)

func update_token_positions(players: Array[Dictionary]) -> void:
	if _tile_centers_3d.is_empty():
		return
	_total_players_count = players.size()
	_jailed_player_ids.clear()
	var tile_groups: Dictionary[int, Array] = {}
	var jail_inmates: Array[int] = []
	var jail_visitors: Array[int] = []

	for i: int in range(players.size()):
		var player: Dictionary = players[i]
		var pid: int = int(player.get("id", i))
		if not _token_nodes.has(pid):
			continue
		var token: Node3D = _token_nodes[pid]
		var j_ring: MeshInstance3D = _token_jail_rings.get(pid, null)
		if bool(player.get("bankrupt", false)):
			token.visible = false
			if j_ring != null and is_instance_valid(j_ring):
				j_ring.visible = false
			continue
		token.visible = true
		var pos_idx: int = posmod(int(player.get("position", 0)), _tile_centers_3d.size())
		var is_jailed: bool = (pos_idx == JAIL_TILE_INDEX) and bool(player.get("in_jail", false))
		if j_ring != null and is_instance_valid(j_ring):
			j_ring.visible = is_jailed
			j_ring.scale = Vector3(1.0, 0.30, 1.0)
		if pos_idx == JAIL_TILE_INDEX:
			if is_jailed:
				jail_inmates.append(pid)
				_jailed_player_ids.append(pid)
			else:
				jail_visitors.append(pid)
		else:
			if not tile_groups.has(pos_idx):
				tile_groups[pos_idx] = []
			tile_groups[pos_idx].append(pid)

	for tile_idx: int in tile_groups.keys():
		var occupants: Array = tile_groups[tile_idx]
		var occ_count: int = occupants.size()
		for occ_i: int in range(occ_count):
			var pid: int = int(occupants[occ_i])
			var token: Node3D = _token_nodes[pid]
			token.position = _get_token_slot_world_pos(occ_i, tile_idx, occ_count)

	var inmate_count: int = jail_inmates.size()
	for in_i: int in range(inmate_count):
		var in_pid: int = jail_inmates[in_i]
		var in_token: Node3D = _token_nodes[in_pid]
		in_token.position = _get_jail_cell_slot_world_pos(in_i, inmate_count)

	var visit_count: int = jail_visitors.size()
	for v_i: int in range(visit_count):
		var v_pid: int = jail_visitors[v_i]
		var v_token: Node3D = _token_nodes[v_pid]
		v_token.position = _get_jail_visit_slot_world_pos(v_i, visit_count)

func animate_token_move(player_id: int, from_pos: int, steps: int, players: Array[Dictionary]) -> bool:
	if not _token_nodes.has(player_id) or _tile_centers_3d.is_empty():
		update_token_positions(players)
		return true

	var expected_token: int = _anim_token
	var token: Node3D = _token_nodes[player_id]
	var board_len: int = _tile_centers_3d.size()
	var step_dir: int = 1 if steps >= 0 else -1
	var total_hops: int = absi(steps)

	var current_tile: int = from_pos
	for hop_idx: int in range(total_hops):
		if expected_token != _anim_token or not is_inside_tree():
			return false
		current_tile = posmod(current_tile + step_dir, board_len)
		var target_pos: Vector3 = _get_token_slot_world_pos(0, current_tile, 1)
		var start_pos: Vector3 = token.position
		var mid_pos: Vector3 = start_pos.lerp(target_pos, 0.5)
		mid_pos.y = TILE_TOP_Y + 0.56

		# Câmera dinâmica acompanha suavemente o peão na Vista Isométrica (nunca interfere na Conferência 2D)
		if not _is_2d_view and _camera_follow_enabled:
			var is_last_hop: bool = (hop_idx == total_hops - 1)
			_focus_camera_on_world_pos(target_pos, 0.72 if is_last_hop else 0.78, 0.20 if is_last_hop else 0.16)

		var tw: Tween = create_tween()
		_register_tween(tw)
		tw.tween_property(token, "position", mid_pos, 0.065).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(token, "position", target_pos, 0.065).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw.finished
		if expected_token != _anim_token or not is_inside_tree():
			return false

	update_token_positions(players)
	if not _is_2d_view and _camera_follow_enabled:
		_schedule_camera_overview_return(0.55)
	return true

# --- Dados 3D no Centro do Tabuleiro ---

func _build_center_dice() -> void:
	_dice_nodes.clear()
	var rest_positions: Array[Vector3] = [
		Vector3(-2.35, 0.41, 0.85),
		Vector3(-1.30, 0.41, 1.45)
	]
	for i: int in range(2):
		var die: Node3D = _create_single_die_3d()
		die.position = rest_positions[i]
		die.quaternion = _get_die_face_quaternion(i + 1, float(i) * 0.35 - 0.15)
		_center_root.add_child(die)
		_dice_nodes.append(die)

func _create_single_die_3d() -> Node3D:
	var root: Node3D = Node3D.new()
	var die_size: float = 0.66
	var half: float = die_size * 0.5

	var cube: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(die_size, die_size, die_size)
	cube.mesh = box
	cube.material_override = _make_material(Color("#FAF6EE"), 0.30, 0.05)
	root.add_child(cube)

	var dark_pip: StandardMaterial3D = _make_material(Color("#1A201C"), 0.4, 0.05)
	var red_pip: StandardMaterial3D = _make_material(Color("#C1121F"), 0.35, 0.05)
	var off: float = 0.17

	# Face 1 (+Y)
	_add_pip(root, Vector3(0.0, half + 0.008, 0.0), Vector3.ZERO, red_pip)
	# Face 6 (-Y)
	for sx: float in [-off, off]:
		for sz: float in [-off, 0.0, off]:
			_add_pip(root, Vector3(sx, -half - 0.008, sz), Vector3(PI, 0.0, 0.0), dark_pip)
	# Face 2 (+Z)
	_add_pip(root, Vector3(-off, off, half + 0.008), Vector3(PI * 0.5, 0.0, 0.0), dark_pip)
	_add_pip(root, Vector3(off, -off, half + 0.008), Vector3(PI * 0.5, 0.0, 0.0), dark_pip)
	# Face 5 (-Z)
	_add_pip(root, Vector3(0.0, 0.0, -half - 0.008), Vector3(-PI * 0.5, 0.0, 0.0), dark_pip)
	for sx: float in [-off, off]:
		for sy: float in [-off, off]:
			_add_pip(root, Vector3(sx, sy, -half - 0.008), Vector3(-PI * 0.5, 0.0, 0.0), dark_pip)
	# Face 3 (+X)
	_add_pip(root, Vector3(half + 0.008, 0.0, 0.0), Vector3(0.0, 0.0, -PI * 0.5), dark_pip)
	_add_pip(root, Vector3(half + 0.008, off, -off), Vector3(0.0, 0.0, -PI * 0.5), dark_pip)
	_add_pip(root, Vector3(half + 0.008, -off, off), Vector3(0.0, 0.0, -PI * 0.5), dark_pip)
	# Face 4 (-X)
	for sy: float in [-off, off]:
		for sz: float in [-off, off]:
			_add_pip(root, Vector3(-half - 0.008, sy, sz), Vector3(0.0, 0.0, PI * 0.5), dark_pip)

	return root

func _add_pip(parent: Node3D, pos: Vector3, rot_rad: Vector3, mat: StandardMaterial3D) -> void:
	var pip: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.056
	cyl.bottom_radius = 0.056
	cyl.height = 0.018
	pip.mesh = cyl
	pip.position = pos
	pip.rotation = rot_rad
	pip.material_override = mat
	parent.add_child(pip)

func _get_die_face_quaternion(face_value: int, yaw_rad: float) -> Quaternion:
	var face_euler: Vector3 = Vector3.ZERO
	match face_value:
		1:
			face_euler = Vector3(0.0, 0.0, 0.0)
		2:
			face_euler = Vector3(-PI * 0.5, 0.0, 0.0)
		3:
			face_euler = Vector3(0.0, 0.0, PI * 0.5)
		4:
			face_euler = Vector3(0.0, 0.0, -PI * 0.5)
		5:
			face_euler = Vector3(PI * 0.5, 0.0, 0.0)
		_:
			face_euler = Vector3(PI, 0.0, 0.0)
	var face_basis: Basis = Basis.from_euler(face_euler)
	var yaw_basis: Basis = Basis(Vector3.UP, yaw_rad)
	return (yaw_basis * face_basis).get_rotation_quaternion()

func play_dice_roll(d1: int, d2: int) -> bool:
	if _dice_nodes.size() < 2 or not is_inside_tree():
		return true

	var expected_token: int = _anim_token
	var values: Array[int] = [d1, d2]
	var rest_y: float = 0.41
	var targets: Array[Vector3] = [
		Vector3(randf_range(-2.65, -1.90), rest_y, randf_range(0.45, 1.90)),
		Vector3(randf_range(-1.45, -0.75), rest_y, randf_range(0.60, 2.15))
	]

	var finish_tween: Tween = null
	for i: int in range(2):
		var die: Node3D = _dice_nodes[i]
		var target_pos: Vector3 = targets[i]
		var start_pos: Vector3 = target_pos + Vector3(randf_range(-0.95, 0.95), 2.30, randf_range(-0.85, 0.85))
		var mid_bounce_1: Vector3 = target_pos.lerp(start_pos, 0.22)
		mid_bounce_1.y = rest_y + 0.72
		var mid_bounce_2: Vector3 = target_pos.lerp(start_pos, 0.07)
		mid_bounce_2.y = rest_y + 0.24

		die.position = start_pos
		die.rotation = Vector3(randf_range(0.0, TAU), randf_range(0.0, TAU), randf_range(0.0, TAU))

		var final_quat: Quaternion = _get_die_face_quaternion(values[i], randf_range(-0.42, 0.42))
		var spin_mid_quat: Quaternion = Quaternion.from_euler(Vector3(randf_range(2.5, 5.5), randf_range(2.5, 5.5), randf_range(2.5, 5.5)))

		var pos_tw: Tween = create_tween()
		_register_tween(pos_tw)
		pos_tw.tween_property(die, "position", Vector3(mid_bounce_1.x, rest_y, mid_bounce_1.z), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pos_tw.tween_property(die, "position", mid_bounce_1, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pos_tw.tween_property(die, "position", Vector3(mid_bounce_2.x, rest_y, mid_bounce_2.z), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pos_tw.tween_property(die, "position", mid_bounce_2, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pos_tw.tween_property(die, "position", target_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		var rot_tw: Tween = create_tween()
		_register_tween(rot_tw)
		rot_tw.tween_property(die, "quaternion", spin_mid_quat, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		rot_tw.tween_property(die, "quaternion", final_quat, 0.43).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		finish_tween = pos_tw

	if finish_tween != null:
		await finish_tween.finished

	return expected_token == _anim_token and is_inside_tree()

# --- Pilha Animada de Cartas 'Sorte ou Azar, Tchê!' ---

func _build_center_chance_deck() -> void:
	_deck_root = Node3D.new()
	_deck_root.position = Vector3(1.52, 0.08, 0.90)
	_deck_root.rotation_degrees = Vector3(0.0, -9.0, 0.0)
	_center_root.add_child(_deck_root)

	var gold_mat: StandardMaterial3D = _make_material(Color("#D4AF37"), 0.34, 0.48)
	var pad: MeshInstance3D = MeshInstance3D.new()
	var pad_box: BoxMesh = BoxMesh.new()
	pad_box.size = Vector3(3.16, 0.024, 2.08)
	pad.mesh = pad_box
	pad.material_override = gold_mat
	_deck_root.add_child(pad)

	var card_back_mat: StandardMaterial3D = _make_material(Color("#1A4737"), 0.44, 0.14)
	var card_edge_mat: StandardMaterial3D = _make_material(Color("#F4EFE4"), 0.65, 0.0)
	var stack_layers: int = 7
	for layer_i: int in range(stack_layers):
		var c: MeshInstance3D = MeshInstance3D.new()
		var c_box: BoxMesh = BoxMesh.new()
		c_box.size = Vector3(2.94, 0.038, 1.88)
		c.mesh = c_box
		c.position = Vector3(0.0, 0.032 + float(layer_i) * 0.042, 0.0)
		c.material_override = card_back_mat if layer_i == stack_layers - 1 else card_edge_mat
		_deck_root.add_child(c)

	# Moldura dourada fina gravada no topo do baralho
	var top_y: float = 0.032 + float(stack_layers - 1) * 0.042 + 0.022
	var trim_w: float = 2.66
	var trim_d: float = 1.60
	var trim_bars: Array[Dictionary] = [
		{ "pos": Vector3(0.0, top_y, -trim_d * 0.5), "size": Vector3(trim_w, 0.012, 0.045) },
		{ "pos": Vector3(0.0, top_y, trim_d * 0.5), "size": Vector3(trim_w, 0.012, 0.045) },
		{ "pos": Vector3(-trim_w * 0.5, top_y, 0.0), "size": Vector3(0.045, 0.012, trim_d) },
		{ "pos": Vector3(trim_w * 0.5, top_y, 0.0), "size": Vector3(0.045, 0.012, trim_d) }
	]
	for tb: Dictionary in trim_bars:
		var t_mesh: MeshInstance3D = MeshInstance3D.new()
		var t_box: BoxMesh = BoxMesh.new()
		t_box.size = tb["size"]
		t_mesh.mesh = t_box
		t_mesh.position = tb["pos"]
		t_mesh.material_override = gold_mat
		_deck_root.add_child(t_mesh)

	var deck_lbl: Label3D = Label3D.new()
	deck_lbl.text = "SORTE OU AZAR\nTCHÊ!"
	if _bold_font != null:
		deck_lbl.font = _bold_font
	deck_lbl.font_size = 38
	deck_lbl.pixel_size = 0.0074
	deck_lbl.modulate = Color("#F8D568")
	deck_lbl.outline_modulate = Color("#08120D")
	deck_lbl.outline_size = 6
	deck_lbl.position = Vector3(0.0, top_y + 0.014, 0.0)
	deck_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_deck_root.add_child(deck_lbl)

	# Carta animada elegante que descola do topo da pilha sem sobrepor o título central
	_anim_card_node = Node3D.new()
	_anim_card_node.visible = false
	_center_root.add_child(_anim_card_node)

	var anim_mesh: MeshInstance3D = MeshInstance3D.new()
	var anim_box: BoxMesh = BoxMesh.new()
	anim_box.size = Vector3(2.94, 0.042, 1.88)
	anim_mesh.mesh = anim_box
	anim_mesh.material_override = _make_material(Color("#FAF6EE"), 0.36, 0.06)
	_anim_card_node.add_child(anim_mesh)

	var trim_mesh: MeshInstance3D = MeshInstance3D.new()
	var trim_box: BoxMesh = BoxMesh.new()
	trim_box.size = Vector3(3.06, 0.028, 2.00)
	trim_mesh.mesh = trim_box
	trim_mesh.position = Vector3(0.0, -0.008, 0.0)
	trim_mesh.material_override = gold_mat
	_anim_card_node.add_child(trim_mesh)

	var header_strip: MeshInstance3D = MeshInstance3D.new()
	var header_box: BoxMesh = BoxMesh.new()
	header_box.size = Vector3(2.94, 0.012, 0.42)
	header_strip.mesh = header_box
	header_strip.position = Vector3(0.0, 0.024, -0.73)
	header_strip.material_override = _make_material(Color("#1A4737"), 0.44, 0.08)
	_anim_card_node.add_child(header_strip)

	var header_lbl: Label3D = Label3D.new()
	header_lbl.text = "SORTE OU AZAR, TCHÊ!"
	if _bold_font != null:
		header_lbl.font = _bold_font
	header_lbl.font_size = 24
	header_lbl.pixel_size = 0.0052
	header_lbl.modulate = Color("#F8D568")
	header_lbl.outline_modulate = Color("#08120D")
	header_lbl.outline_size = 5
	header_lbl.position = Vector3(0.0, 0.035, -0.73)
	header_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_anim_card_node.add_child(header_lbl)

	_anim_card_label = Label3D.new()
	_anim_card_label.text = ""
	if _bold_font != null:
		_anim_card_label.font = _bold_font
	_anim_card_label.font_size = 24
	_anim_card_label.pixel_size = 0.0052
	_anim_card_label.width = 480.0
	_anim_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anim_card_label.modulate = Color("#16211B")
	_anim_card_label.outline_size = 0
	_anim_card_label.position = Vector3(0.0, 0.035, 0.14)
	_anim_card_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_anim_card_node.add_child(_anim_card_label)

func play_chance_card_animation(card_text: String, hold_sec: float = 0.22) -> bool:
	if _anim_card_node == null or _deck_root == null or not is_inside_tree():
		return true

	var expected_token: int = _anim_token
	var trimmed_text: String = card_text if card_text.length() <= 72 else (card_text.substr(0, 69) + "...")
	_anim_card_label.text = trimmed_text

	# Saque limpo no próprio quadrante da pilha (sem invadir o título central nem textos flutuantes)
	var deck_top_pos: Vector3 = _deck_root.position + Vector3(0.0, 0.34, 0.0)
	var deck_rot: Vector3 = _deck_root.rotation_degrees
	var lift_pos: Vector3 = _deck_root.position + Vector3(0.28, 1.05, 0.32)
	var lift_rot: Vector3 = Vector3(0.0, deck_rot.y, 0.0) if _is_2d_view else Vector3(12.0, deck_rot.y + 8.0, -4.0)

	_anim_card_node.position = deck_top_pos
	_anim_card_node.rotation_degrees = deck_rot
	_anim_card_node.scale = Vector3(0.96, 0.96, 0.96)
	_anim_card_node.visible = true

	var lift_tw: Tween = create_tween()
	_register_tween(lift_tw)
	lift_tw.set_parallel(true)
	lift_tw.set_trans(Tween.TRANS_CUBIC)
	lift_tw.set_ease(Tween.EASE_OUT)
	lift_tw.tween_property(_anim_card_node, "position", lift_pos, 0.28)
	lift_tw.tween_property(_anim_card_node, "rotation_degrees", lift_rot, 0.28)
	lift_tw.tween_property(_anim_card_node, "scale", Vector3(1.08, 1.08, 1.08), 0.28)
	await lift_tw.finished
	if expected_token != _anim_token or not is_inside_tree():
		return false

	var safe_hold: float = clampf(hold_sec, 0.08, 0.40)
	await get_tree().create_timer(safe_hold).timeout
	if expected_token != _anim_token or not is_inside_tree():
		return false

	var return_tw: Tween = create_tween()
	_register_tween(return_tw)
	return_tw.set_parallel(true)
	return_tw.set_trans(Tween.TRANS_CUBIC)
	return_tw.set_ease(Tween.EASE_IN_OUT)
	return_tw.tween_property(_anim_card_node, "position", deck_top_pos, 0.22)
	return_tw.tween_property(_anim_card_node, "rotation_degrees", deck_rot, 0.22)
	return_tw.tween_property(_anim_card_node, "scale", Vector3(0.94, 0.94, 0.94), 0.22)
	await return_tw.finished
	if expected_token != _anim_token or not is_inside_tree():
		return false

	_anim_card_node.visible = false
	return true
