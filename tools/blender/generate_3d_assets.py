"""Gerador headless (Blender 5.3) de assets 3D .glb para Magnata do Pampa.

Execução:
  blender --background --python tools/blender/generate_3d_assets.py
"""

import math
import os
import bpy


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
OUT_DIR = os.path.join(REPO_ROOT, "assets", "models")


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if bpy.context.scene.world is None:
        bpy.context.scene.world = bpy.data.worlds.new("World")


def make_mat(
    name: str,
    rgba: tuple[float, float, float, float],
    roughness: float = 0.4,
    metallic: float = 0.0,
    emission_rgba: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        if "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = rgba
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        if emission_rgba is not None and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission_rgba
        if emission_strength > 0.0 and "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def assign_mat(obj: bpy.types.Object, mat: bpy.types.Material) -> None:
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def smooth_obj(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    for poly in obj.data.polygons:
        poly.use_smooth = True


def add_bevel(obj: bpy.types.Object, width: float = 0.012, segments: int = 2) -> None:
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(32.0)


def apply_and_ground(objs: list[bpy.types.Object], center_xyz: bool = False) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    # Compute world-space bounding box across all objects
    min_x = min(min(o.location.x + v[0] for v in o.bound_box) for o in objs)
    max_x = max(max(o.location.x + v[0] for v in o.bound_box) for o in objs)
    min_y = min(min(o.location.y + v[1] for v in o.bound_box) for o in objs)
    max_y = max(max(o.location.y + v[1] for v in o.bound_box) for o in objs)
    min_z = min(min(o.location.z + v[2] for v in o.bound_box) for o in objs)
    max_z = max(max(o.location.z + v[2] for v in o.bound_box) for o in objs)

    shift_x = -(min_x + max_x) * 0.5
    shift_y = -(min_y + max_y) * 0.5
    shift_z = -(min_z + max_z) * 0.5 if center_xyz else -min_z
    for o in objs:
        o.location.x += shift_x
        o.location.y += shift_y
        o.location.z += shift_z


def export_glb(filename: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    out_path = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    print(f"EXPORTED_GLB={out_path}")


def add_cylinder(
    name: str,
    loc: tuple[float, float, float],
    radius: float,
    depth: float,
    mat: bpy.types.Material,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
    verts: int = 28,
    smooth: bool = True,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    assign_mat(o, mat)
    if smooth:
        smooth_obj(o)
    return o


def add_cone(
    name: str,
    loc: tuple[float, float, float],
    r1: float,
    r2: float,
    depth: float,
    mat: bpy.types.Material,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
    verts: int = 28,
    smooth: bool = True,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    assign_mat(o, mat)
    if smooth:
        smooth_obj(o)
    return o


def add_box(
    name: str,
    loc: tuple[float, float, float],
    scale_xyz: tuple[float, float, float],
    mat: bpy.types.Material,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.008,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale_xyz
    assign_mat(o, mat)
    if bevel > 0.0:
        add_bevel(o, bevel, 2)
    return o


def add_sphere(
    name: str,
    loc: tuple[float, float, float],
    scale_xyz: tuple[float, float, float],
    mat: bpy.types.Material,
    segs: int = 24,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=16, radius=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale_xyz
    assign_mat(o, mat)
    smooth_obj(o)
    return o


def add_torus(
    name: str,
    loc: tuple[float, float, float],
    major_r: float,
    minor_r: float,
    mat: bpy.types.Material,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=32,
        minor_segments=14,
        major_radius=major_r,
        minor_radius=minor_r,
        location=loc,
        rotation=rot,
    )
    o = bpy.context.active_object
    o.name = name
    assign_mat(o, mat)
    smooth_obj(o)
    return o


def pawn_base_parts(primary_mat: bpy.types.Material, gold_mat: bpy.types.Material, dark_mat: bpy.types.Material) -> list[bpy.types.Object]:
    return [
        add_cylinder("PedestalObsidian", (0.0, 0.0, 0.025), 0.21, 0.05, dark_mat, verts=32),
        add_cone("PedestalColor", (0.0, 0.0, 0.075), 0.19, 0.16, 0.055, primary_mat, verts=32),
        add_torus("PedestalGoldTrim", (0.0, 0.0, 0.105), 0.155, 0.016, gold_mat),
    ]


def build_pawn_cuia() -> None:
    reset_scene()
    p_mat = make_mat("PlayerPrimary", (0.85, 0.24, 0.28, 1.0), roughness=0.28, metallic=0.12)
    gold = make_mat("GoldAccent", (0.94, 0.78, 0.30, 1.0), roughness=0.22, metallic=0.82)
    dark = make_mat("ObsidianAccent", (0.10, 0.13, 0.11, 1.0), roughness=0.45, metallic=0.15)
    erva = make_mat("ErvaMat", (0.16, 0.56, 0.24, 1.0), roughness=0.72)
    silver = make_mat("SilverAccent", (0.88, 0.92, 0.96, 1.0), roughness=0.18, metallic=0.88)

    objs = pawn_base_parts(p_mat, gold, dark)
    objs.append(add_cone("CuiaFoot", (0.0, 0.0, 0.155), 0.115, 0.068, 0.09, dark, verts=28))
    objs.append(add_sphere("CuiaBelly", (0.0, 0.0, 0.29), (0.175, 0.175, 0.145), p_mat))
    objs.append(add_torus("CuiaRim", (0.0, 0.0, 0.39), 0.148, 0.022, gold))
    objs.append(add_cylinder("ErvaTop", (0.0, 0.0, 0.392), 0.135, 0.018, erva, verts=28))
    # Bomba inclinada de prata + bico dourado
    objs.append(add_cylinder("BombaStem", (0.06, 0.0, 0.49), 0.016, 0.24, silver, rot=(0.0, math.radians(24.0), 0.0), verts=16))
    objs.append(add_sphere("BombaLip", (0.112, 0.0, 0.605), (0.026, 0.018, 0.014), gold))
    apply_and_ground(objs)
    export_glb("pawn_cuia.glb")


def build_pawn_quero_quero() -> None:
    reset_scene()
    p_mat = make_mat("PlayerPrimary", (0.85, 0.24, 0.28, 1.0), roughness=0.30, metallic=0.10)
    gold = make_mat("GoldAccent", (0.94, 0.78, 0.30, 1.0), roughness=0.22, metallic=0.82)
    dark = make_mat("ObsidianAccent", (0.10, 0.13, 0.11, 1.0), roughness=0.45, metallic=0.15)
    cream = make_mat("CreamAccent", (0.94, 0.92, 0.86, 1.0), roughness=0.36)

    objs = pawn_base_parts(p_mat, gold, dark)
    objs.append(add_cylinder("LegL", (-0.045, 0.0, 0.18), 0.015, 0.15, gold, verts=12))
    objs.append(add_cylinder("LegR", (0.045, 0.0, 0.18), 0.015, 0.15, gold, verts=12))
    objs.append(add_sphere("BirdBody", (0.0, -0.02, 0.30), (0.115, 0.155, 0.105), p_mat))
    objs.append(add_sphere("WingL", (-0.095, -0.02, 0.30), (0.032, 0.12, 0.065), dark))
    objs.append(add_sphere("WingR", (0.095, -0.02, 0.30), (0.032, 0.12, 0.065), dark))
    objs.append(add_cone("Tail", (0.0, -0.17, 0.28), 0.065, 0.015, 0.14, dark, rot=(math.radians(-68.0), 0.0, 0.0), verts=16))
    objs.append(add_sphere("Chest", (0.0, 0.09, 0.36), (0.075, 0.070, 0.080), cream))
    objs.append(add_sphere("Head", (0.0, 0.11, 0.46), (0.068, 0.072, 0.066), p_mat))
    objs.append(add_cone("Beak", (0.0, 0.20, 0.455), 0.022, 0.004, 0.085, gold, rot=(math.radians(-90.0), 0.0, 0.0), verts=14))
    objs.append(add_cone("Crest", (0.0, 0.05, 0.54), 0.018, 0.003, 0.11, dark, rot=(math.radians(38.0), 0.0, 0.0), verts=12))
    apply_and_ground(objs)
    export_glb("pawn_quero_quero.glb")


def build_pawn_espeto() -> None:
    reset_scene()
    p_mat = make_mat("PlayerPrimary", (0.85, 0.24, 0.28, 1.0), roughness=0.32, metallic=0.14)
    gold = make_mat("GoldAccent", (0.94, 0.78, 0.30, 1.0), roughness=0.22, metallic=0.82)
    dark = make_mat("ObsidianAccent", (0.10, 0.13, 0.11, 1.0), roughness=0.45, metallic=0.15)
    silver = make_mat("SilverAccent", (0.88, 0.92, 0.96, 1.0), roughness=0.18, metallic=0.88)
    wood = make_mat("WoodHandle", (0.48, 0.24, 0.11, 1.0), roughness=0.52)

    objs = pawn_base_parts(p_mat, gold, dark)
    objs.append(add_cylinder("WoodGrip", (0.0, 0.0, 0.16), 0.036, 0.11, wood, verts=18))
    objs.append(add_box("CrossGuard", (0.0, 0.0, 0.225), (0.18, 0.045, 0.026), gold, bevel=0.006))
    objs.append(add_cylinder("SteelBlade", (0.0, 0.0, 0.42), 0.016, 0.38, silver, verts=16))
    # Cortes estilizados no espeto (coloridos com aro dourado para identificação)
    objs.append(add_box("CutLow", (0.0, 0.0, 0.31), (0.17, 0.115, 0.075), p_mat, bevel=0.016))
    objs.append(add_box("CutMid", (0.0, 0.0, 0.41), (0.145, 0.105, 0.070), dark, rot=(0.0, 0.0, math.radians(18.0)), bevel=0.015))
    objs.append(add_box("CutTop", (0.0, 0.0, 0.50), (0.125, 0.095, 0.065), p_mat, rot=(0.0, 0.0, math.radians(-14.0)), bevel=0.014))
    objs.append(add_cone("TipCap", (0.0, 0.0, 0.625), 0.022, 0.002, 0.045, silver, verts=12))
    apply_and_ground(objs)
    export_glb("pawn_espeto.glb")


def build_pawn_cavalo() -> None:
    reset_scene()
    p_mat = make_mat("PlayerPrimary", (0.85, 0.24, 0.28, 1.0), roughness=0.28, metallic=0.14)
    gold = make_mat("GoldAccent", (0.94, 0.78, 0.30, 1.0), roughness=0.22, metallic=0.82)
    dark = make_mat("ObsidianAccent", (0.10, 0.13, 0.11, 1.0), roughness=0.45, metallic=0.15)

    objs = pawn_base_parts(p_mat, gold, dark)
    objs.append(add_cone("ChestBase", (0.0, 0.0, 0.17), 0.13, 0.10, 0.13, p_mat, verts=28))
    objs.append(add_box("NeckLower", (0.0, -0.01, 0.30), (0.115, 0.14, 0.19), p_mat, rot=(math.radians(-14.0), 0.0, 0.0), bevel=0.022))
    objs.append(add_box("HeadSkull", (0.0, 0.04, 0.44), (0.10, 0.14, 0.13), p_mat, rot=(math.radians(18.0), 0.0, 0.0), bevel=0.022))
    objs.append(add_box("Muzzle", (0.0, 0.14, 0.415), (0.075, 0.13, 0.078), p_mat, rot=(math.radians(24.0), 0.0, 0.0), bevel=0.018))
    objs.append(add_box("Mane", (0.0, -0.095, 0.35), (0.045, 0.075, 0.25), dark, rot=(math.radians(-12.0), 0.0, 0.0), bevel=0.012))
    objs.append(add_cone("EarL", (-0.036, 0.01, 0.535), 0.022, 0.004, 0.075, gold, verts=12))
    objs.append(add_cone("EarR", (0.036, 0.01, 0.535), 0.022, 0.004, 0.075, gold, verts=12))
    objs.append(add_torus("BridleRing", (0.0, 0.10, 0.425), 0.055, 0.010, gold, rot=(0.0, math.radians(90.0), 0.0)))
    apply_and_ground(objs)
    export_glb("pawn_cavalo.glb")


def build_pawn_chapeu() -> None:
    reset_scene()
    p_mat = make_mat("PlayerPrimary", (0.85, 0.24, 0.28, 1.0), roughness=0.36, metallic=0.10)
    gold = make_mat("GoldAccent", (0.94, 0.78, 0.30, 1.0), roughness=0.22, metallic=0.82)
    dark = make_mat("ObsidianAccent", (0.10, 0.13, 0.11, 1.0), roughness=0.45, metallic=0.15)

    objs = pawn_base_parts(p_mat, gold, dark)
    objs.append(add_cylinder("HatPillar", (0.0, 0.0, 0.165), 0.068, 0.12, dark, verts=24))
    # Aba larga estilizada levemente ovalada
    brim = add_cylinder("HatBrim", (0.0, 0.0, 0.24), 0.245, 0.026, p_mat, verts=36)
    brim.scale = (1.06, 0.96, 1.0)
    objs.append(brim)
    objs.append(add_torus("BrimRim", (0.0, 0.0, 0.242), 0.240, 0.012, dark))
    objs.append(add_cone("Crown", (0.0, 0.0, 0.33), 0.135, 0.105, 0.16, p_mat, verts=32))
    objs.append(add_cylinder("CrownBand", (0.0, 0.0, 0.268), 0.138, 0.032, gold, verts=32))
    objs.append(add_torus("CrownDimple", (0.0, 0.0, 0.41), 0.088, 0.020, p_mat))
    objs.append(add_box("BarbicachoCoin", (0.0, 0.14, 0.27), (0.048, 0.022, 0.048), gold, rot=(0.0, math.radians(45.0), 0.0), bevel=0.005))
    apply_and_ground(objs)
    export_glb("pawn_chapeu.glb")


def build_pawn_facao() -> None:
    reset_scene()
    p_mat = make_mat("PlayerPrimary", (0.85, 0.24, 0.28, 1.0), roughness=0.28, metallic=0.16)
    gold = make_mat("GoldAccent", (0.94, 0.78, 0.30, 1.0), roughness=0.22, metallic=0.82)
    dark = make_mat("ObsidianAccent", (0.10, 0.13, 0.11, 1.0), roughness=0.45, metallic=0.15)
    silver = make_mat("SilverAccent", (0.90, 0.93, 0.96, 1.0), roughness=0.16, metallic=0.90)

    objs = pawn_base_parts(p_mat, gold, dark)
    objs.append(add_cylinder("PommelHandle", (0.0, 0.0, 0.165), 0.038, 0.12, p_mat, verts=20))
    objs.append(add_torus("GripRing", (0.0, 0.0, 0.165), 0.042, 0.010, gold))
    objs.append(add_box("HiltGuard", (0.0, 0.0, 0.235), (0.19, 0.055, 0.032), gold, bevel=0.008))
    objs.append(add_box("BladeBase", (0.0, 0.0, 0.38), (0.072, 0.026, 0.26), silver, bevel=0.006))
    objs.append(add_box("BladeFuller", (0.0, 0.0, 0.37), (0.024, 0.032, 0.21), p_mat, bevel=0.003))
    objs.append(add_cone("BladeTip", (0.0, 0.0, 0.56), 0.042, 0.002, 0.11, silver, verts=4))
    apply_and_ground(objs)
    export_glb("pawn_facao.glb")


def build_casa_campeira() -> None:
    reset_scene()
    stone = make_mat("StonePlinth", (0.88, 0.85, 0.78, 1.0), roughness=0.65)
    wall = make_mat("CasaWall", (0.15, 0.66, 0.42, 1.0), roughness=0.38)
    roof = make_mat("TerracottaRoof", (0.78, 0.33, 0.17, 1.0), roughness=0.42)
    wood = make_mat("TimberTrim", (0.28, 0.16, 0.09, 1.0), roughness=0.55)
    win = make_mat("WarmWindow", (1.0, 0.90, 0.55, 1.0), roughness=0.20, emission_rgba=(1.0, 0.86, 0.42, 1.0), emission_strength=0.65)

    objs = [
        add_box("Base", (0.0, 0.0, 0.02), (0.185, 0.185, 0.04), stone, bevel=0.006),
        add_box("Walls", (0.0, 0.0, 0.105), (0.160, 0.155, 0.135), wall, bevel=0.006),
        add_box("Door", (0.0, 0.080, 0.082), (0.044, 0.012, 0.086), wood, bevel=0.003),
        add_box("WinL", (-0.052, 0.080, 0.112), (0.032, 0.012, 0.034), win, bevel=0.003),
        add_box("WinR", (0.052, 0.080, 0.112), (0.032, 0.012, 0.034), win, bevel=0.003),
        add_box("Chimney", (0.046, -0.042, 0.215), (0.028, 0.028, 0.075), stone, bevel=0.004),
    ]
    # Telhado em duas águas via cone piramidal / prisma
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.145, radius2=0.0, depth=0.10, location=(0.0, 0.0, 0.218), rotation=(0.0, 0.0, math.radians(45.0)))
    r_obj = bpy.context.active_object
    r_obj.name = "PitchedRoof"
    assign_mat(r_obj, roof)
    objs.append(r_obj)
    apply_and_ground(objs)
    export_glb("casa_campeira.glb")


def build_estancia_hotel() -> None:
    reset_scene()
    cream = make_mat("EstatePlaster", (0.96, 0.93, 0.86, 1.0), roughness=0.45)
    ruby = make_mat("EstanciaWall", (0.78, 0.14, 0.20, 1.0), roughness=0.34, metallic=0.08)
    gold = make_mat("GoldCupola", (0.95, 0.78, 0.30, 1.0), roughness=0.20, metallic=0.85)
    roof = make_mat("EstanciaRoof", (0.62, 0.22, 0.14, 1.0), roughness=0.40)
    win = make_mat("EstanciaWindow", (1.0, 0.92, 0.60, 1.0), roughness=0.18, emission_rgba=(1.0, 0.88, 0.45, 1.0), emission_strength=0.72)

    objs = [
        add_box("Plinth", (0.0, 0.0, 0.03), (0.58, 0.25, 0.06), cream, bevel=0.008),
        add_box("MainManor", (0.0, 0.0, 0.23), (0.52, 0.21, 0.34), ruby, bevel=0.010),
        add_box("WinBandLow", (0.0, 0.0, 0.14), (0.535, 0.165, 0.05), win, bevel=0.004),
        add_box("WinBandMid", (0.0, 0.0, 0.24), (0.535, 0.165, 0.05), win, bevel=0.004),
        add_box("WinBandTop", (0.0, 0.0, 0.34), (0.535, 0.165, 0.05), win, bevel=0.004),
        add_box("Cornice", (0.0, 0.0, 0.42), (0.56, 0.24, 0.048), cream, bevel=0.008),
        add_box("Tower", (0.0, 0.0, 0.51), (0.28, 0.19, 0.14), ruby, bevel=0.008),
    ]
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.22, radius2=0.0, depth=0.16, location=(0.0, 0.0, 0.65), rotation=(0.0, 0.0, math.radians(45.0)))
    roof_top = bpy.context.active_object
    roof_top.name = "ManorRoof"
    roof_top.scale = (1.15, 0.85, 1.0)
    assign_mat(roof_top, roof)
    objs.append(roof_top)
    objs.append(add_sphere("GoldSpire", (0.0, 0.0, 0.745), (0.042, 0.042, 0.042), gold))
    apply_and_ground(objs)
    export_glb("estancia_hotel.glb")


def build_dado_pampa() -> None:
    reset_scene()
    ivory = make_mat("DiceIvory", (0.97, 0.95, 0.90, 1.0), roughness=0.28, metallic=0.04)
    pip_dark = make_mat("PipObsidian", (0.10, 0.13, 0.11, 1.0), roughness=0.35)
    pip_red = make_mat("PipRuby", (0.78, 0.09, 0.14, 1.0), roughness=0.28)
    gold = make_mat("DiceGoldRim", (0.92, 0.75, 0.28, 1.0), roughness=0.24, metallic=0.80)

    s = 0.66
    h = s * 0.5
    off = 0.175
    objs = [add_box("DiceCube", (0.0, 0.0, 0.0), (s, s, s), ivory, bevel=0.055)]

    # Mapeamento export_yup=True: Blender +Z -> Godot +Y (Face 1), -Z -> -Y (6), -Y -> +Z (2), +Y -> -Z (5), +X -> +X (3), -X -> -X (4)
    # Face 1 (+Z)
    objs.append(add_torus("Pip1GoldRing", (0.0, 0.0, h + 0.003), 0.074, 0.010, gold))
    objs.append(add_cylinder("Pip1", (0.0, 0.0, h + 0.005), 0.062, 0.014, pip_red, verts=20))
    # Face 6 (-Z)
    for sx in (-off, off):
        for sy in (-off, 0.0, off):
            objs.append(add_cylinder(f"Pip6_{sx}_{sy}", (sx, sy, -h - 0.005), 0.052, 0.014, pip_dark, verts=18))
    # Face 2 (-Y in Blender -> +Z in Godot)
    objs.append(add_cylinder("Pip2a", (-off, -h - 0.005, off), 0.054, 0.014, pip_dark, rot=(math.radians(90.0), 0.0, 0.0), verts=18))
    objs.append(add_cylinder("Pip2b", (off, -h - 0.005, -off), 0.054, 0.014, pip_dark, rot=(math.radians(90.0), 0.0, 0.0), verts=18))
    # Face 5 (+Y in Blender -> -Z in Godot)
    objs.append(add_cylinder("Pip5c", (0.0, h + 0.005, 0.0), 0.052, 0.014, pip_dark, rot=(math.radians(90.0), 0.0, 0.0), verts=18))
    for sx in (-off, off):
        for sz in (-off, off):
            objs.append(add_cylinder(f"Pip5_{sx}_{sz}", (sx, h + 0.005, sz), 0.052, 0.014, pip_dark, rot=(math.radians(90.0), 0.0, 0.0), verts=18))
    # Face 3 (+X)
    objs.append(add_cylinder("Pip3a", (h + 0.005, 0.0, 0.0), 0.052, 0.014, pip_dark, rot=(0.0, math.radians(90.0), 0.0), verts=18))
    objs.append(add_cylinder("Pip3b", (h + 0.005, off, off), 0.052, 0.014, pip_dark, rot=(0.0, math.radians(90.0), 0.0), verts=18))
    objs.append(add_cylinder("Pip3c", (h + 0.005, -off, -off), 0.052, 0.014, pip_dark, rot=(0.0, math.radians(90.0), 0.0), verts=18))
    # Face 4 (-X)
    for sy in (-off, off):
        for sz in (-off, off):
            objs.append(add_cylinder(f"Pip4_{sy}_{sz}", (-h - 0.005, sy, sz), 0.052, 0.014, pip_dark, rot=(0.0, math.radians(90.0), 0.0), verts=18))

    apply_and_ground(objs, center_xyz=True)
    export_glb("dado_pampa.glb")


def build_prop_galpao() -> None:
    reset_scene()
    stone = make_mat("StonePlinth", (0.36, 0.35, 0.32, 1.0), roughness=0.68)
    wood = make_mat("TimberWood", (0.50, 0.27, 0.12, 1.0), roughness=0.52)
    roof = make_mat("GalpaoRoof", (0.76, 0.30, 0.15, 1.0), roughness=0.40)
    gold = make_mat("GoldCrest", (0.95, 0.78, 0.32, 1.0), roughness=0.24, metallic=0.78)
    lantern = make_mat("WarmLantern", (1.0, 0.90, 0.56, 1.0), roughness=0.18, emission_rgba=(1.0, 0.85, 0.42, 1.0), emission_strength=0.90)

    objs = [
        add_box("Plinth", (0.0, 0.0, 0.035), (1.06, 0.42, 0.07), stone, bevel=0.010),
        add_box("PillarL", (-0.36, 0.0, 0.31), (0.11, 0.11, 0.52), wood, bevel=0.008),
        add_box("PillarR", (0.36, 0.0, 0.31), (0.11, 0.11, 0.52), wood, bevel=0.008),
        add_box("Beam", (0.0, 0.0, 0.56), (0.96, 0.15, 0.09), wood, bevel=0.008),
        add_box("Crest", (0.0, 0.08, 0.56), (0.16, 0.06, 0.16), gold, rot=(0.0, math.radians(45.0), 0.0), bevel=0.006),
        add_sphere("Lantern", (0.0, 0.0, 0.445), (0.058, 0.058, 0.062), lantern),
    ]
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.66, radius2=0.0, depth=0.28, location=(0.0, 0.0, 0.72), rotation=(0.0, 0.0, math.radians(45.0)))
    g_roof = bpy.context.active_object
    g_roof.name = "GalpaoRoofMesh"
    g_roof.scale = (1.18, 0.48, 1.0)
    assign_mat(g_roof, roof)
    objs.append(g_roof)
    apply_and_ground(objs)
    export_glb("prop_galpao.glb")


def build_prop_20_setembro() -> None:
    reset_scene()
    stone = make_mat("PedestalStone", (0.30, 0.35, 0.32, 1.0), roughness=0.58)
    bronze = make_mat("PedestalBronze", (0.72, 0.54, 0.18, 1.0), roughness=0.30, metallic=0.68)
    steel = make_mat("PoleSteel", (0.86, 0.90, 0.94, 1.0), roughness=0.20, metallic=0.85)
    gold = make_mat("FinialGold", (0.96, 0.80, 0.32, 1.0), roughness=0.22, metallic=0.80)
    green = make_mat("RSGreen", (0.14, 0.62, 0.28, 1.0), roughness=0.36)
    red = make_mat("RSRed", (0.86, 0.20, 0.24, 1.0), roughness=0.36)
    yellow = make_mat("RSYellow", (0.98, 0.78, 0.20, 1.0), roughness=0.36)

    objs = [
        add_cylinder("Base1", (0.0, 0.0, 0.045), 0.32, 0.09, stone, verts=8, smooth=False),
        add_cylinder("Base2", (0.0, 0.0, 0.13), 0.21, 0.09, bronze, verts=8, smooth=False),
        add_cone("Pole", (0.0, 0.0, 0.84), 0.040, 0.026, 1.40, steel, verts=16),
        add_torus("FinialCollar", (0.0, 0.0, 1.54), 0.044, 0.012, gold),
        add_sphere("Finial", (0.0, 0.0, 1.60), (0.068, 0.068, 0.068), gold),
        add_box("FlagTopGreen", (0.36, 0.0, 1.38), (0.68, 0.036, 0.16), green, rot=(0.0, 0.0, math.radians(-5.0)), bevel=0.005),
        add_box("FlagMidRed", (0.36, 0.0, 1.22), (0.68, 0.036, 0.16), red, rot=(0.0, 0.0, math.radians(-5.0)), bevel=0.005),
        add_box("FlagBotYellow", (0.36, 0.0, 1.06), (0.68, 0.036, 0.16), yellow, rot=(0.0, 0.0, math.radians(-5.0)), bevel=0.005),
        add_box("ShieldCrest", (0.36, 0.0, 1.22), (0.14, 0.052, 0.14), gold, rot=(0.0, math.radians(45.0), math.radians(-5.0)), bevel=0.005),
    ]
    apply_and_ground(objs)
    export_glb("prop_20_setembro.glb")


def build_prop_imposto() -> None:
    reset_scene()
    gold = make_mat("CoinGold", (0.95, 0.78, 0.28, 1.0), roughness=0.22, metallic=0.85)
    ruby = make_mat("SealRuby", (0.86, 0.20, 0.24, 1.0), roughness=0.30, metallic=0.14)
    objs = [
        add_cylinder("CoinA1", (-0.08, 0.0, 0.024), 0.11, 0.046, gold, verts=24),
        add_cylinder("CoinA2", (-0.07, 0.0, 0.072), 0.11, 0.046, gold, verts=24),
        add_cylinder("CoinB1", (0.09, 0.0, 0.024), 0.11, 0.046, gold, verts=24),
        add_cylinder("WaxSeal", (-0.07, 0.0, 0.118), 0.075, 0.044, ruby, verts=24),
    ]
    apply_and_ground(objs)
    export_glb("prop_imposto.glb")


def build_prop_companhia() -> None:
    reset_scene()
    steel = make_mat("SiloSteel", (0.84, 0.89, 0.94, 1.0), roughness=0.22, metallic=0.80)
    gold = make_mat("SiloGold", (0.94, 0.76, 0.28, 1.0), roughness=0.24, metallic=0.75)
    emerald = make_mat("SiloBase", (0.14, 0.42, 0.30, 1.0), roughness=0.45)
    objs = [
        add_box("CompPad", (0.0, 0.0, 0.02), (0.36, 0.20, 0.04), emerald, bevel=0.006),
        add_cylinder("SiloMain", (-0.07, 0.0, 0.16), 0.095, 0.26, steel, verts=24),
        add_cylinder("SiloAux", (0.10, 0.0, 0.13), 0.075, 0.20, steel, verts=24),
        add_sphere("DomeMain", (-0.07, 0.0, 0.29), (0.095, 0.095, 0.055), gold),
        add_sphere("DomeAux", (0.10, 0.0, 0.23), (0.075, 0.075, 0.045), gold),
    ]
    apply_and_ground(objs)
    export_glb("prop_companhia.glb")


def build_prop_sorte_azar() -> None:
    reset_scene()
    emerald = make_mat("LuckyBase", (0.10, 0.32, 0.22, 1.0), roughness=0.42)
    gold = make_mat("LuckyGold", (0.96, 0.80, 0.30, 1.0), roughness=0.20, metallic=0.86, emission_rgba=(0.95, 0.76, 0.25, 1.0), emission_strength=0.25)
    objs = [
        add_cylinder("CharmPad", (0.0, 0.0, 0.02), 0.15, 0.036, emerald, verts=24),
        add_torus("Horseshoe", (0.0, 0.0, 0.15), 0.088, 0.024, gold, rot=(math.radians(82.0), 0.0, 0.0)),
        add_box("CenterGem", (0.0, 0.0, 0.15), (0.055, 0.032, 0.055), gold, rot=(0.0, math.radians(45.0), 0.0), bevel=0.004),
    ]
    apply_and_ground(objs)
    export_glb("prop_sorte_azar.glb")


def main() -> None:
    builders = [
        build_pawn_cuia,
        build_pawn_quero_quero,
        build_pawn_espeto,
        build_pawn_cavalo,
        build_pawn_chapeu,
        build_pawn_facao,
        build_casa_campeira,
        build_estancia_hotel,
        build_dado_pampa,
        build_prop_galpao,
        build_prop_20_setembro,
        build_prop_imposto,
        build_prop_companhia,
        build_prop_sorte_azar,
    ]
    for fn in builders:
        fn()
    print(f"BLENDER_PIPELINE_DONE total={len(builders)}")


if __name__ == "__main__":
    main()
