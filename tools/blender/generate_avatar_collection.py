"""Generate OneProyect's first continuous-body modular avatar set.

Run with:
    blender --background --python generate_avatar_collection.py -- /output/path

The script intentionally uses only Blender's bundled Python API. It creates
four game-ready GLB files from a common skeleton. Preview rendering is done by
Godot Compatibility so the result matches the game instead of Blender Eevee.
"""

from __future__ import annotations

import math
import os
import sys
from dataclasses import dataclass

import bpy
from mathutils import Vector


@dataclass(frozen=True)
class Archetype:
    file_id: str
    display_name: str
    feminine: bool
    semihuman: bool
    skin: tuple[float, float, float, float]
    outfit: tuple[float, float, float, float]


ARCHETYPES = (
    Archetype("human_male", "Humano masculino", False, False, (0.52, 0.25, 0.12, 1), (0.04, 0.25, 0.52, 1)),
    Archetype("human_female", "Humana femenina", True, False, (0.72, 0.40, 0.24, 1), (0.55, 0.05, 0.24, 1)),
    Archetype("lynx_male", "Lince masculino", False, True, (0.50, 0.24, 0.08, 1), (0.06, 0.34, 0.28, 1)),
    Archetype("lynx_female", "Lince femenina", True, True, (0.72, 0.38, 0.12, 1), (0.42, 0.08, 0.48, 1)),
)

FPS = 30
def clear_scene() -> None:
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.armatures, bpy.data.materials, bpy.data.actions):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(name: str, color: tuple[float, float, float, float], metallic=0.0, roughness=0.72):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return mat


def add_ellipsoid(name: str, location, scale, mat=None, segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=rings,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    return obj


def add_segment(name: str, start, end, radius: float, mat=None, vertices=12):
    start_v, end_v = Vector(start), Vector(end)
    direction = end_v - start_v
    midpoint = (start_v + end_v) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=direction.length,
        location=midpoint,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    return obj


def join_objects(objects, name: str):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    return result


def connected_components(mesh_obj):
    adjacency = [set() for _ in mesh_obj.data.vertices]
    for edge in mesh_obj.data.edges:
        first, second = edge.vertices
        adjacency[first].add(second)
        adjacency[second].add(first)
    remaining = set(range(len(adjacency)))
    components = []
    while remaining:
        component = {remaining.pop()}
        pending = list(component)
        while pending:
            current = pending.pop()
            for neighbor in adjacency[current]:
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    component.add(neighbor)
                    pending.append(neighbor)
        components.append(component)
    return components


def add_meta_ellipsoid(meta, location, scale, rotation=None, stiffness=2.0):
    element = meta.elements.new(type="ELLIPSOID")
    element.co = location
    element.radius = 1.0
    element.size_x, element.size_y, element.size_z = scale
    element.stiffness = stiffness
    if rotation is not None:
        element.rotation = rotation
    return element


def add_meta_segment(meta, start, end, radius: float):
    start_v, end_v = Vector(start), Vector(end)
    direction = end_v - start_v
    # Extend the volume beyond both joints. The overlap is what turns separate
    # limbs into a genuinely continuous surface after conversion.
    length = direction.length + radius * 1.35
    midpoint = (start_v + end_v) * 0.5
    rotation = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    return add_meta_ellipsoid(
        meta,
        midpoint,
        (radius, radius, length * 0.5),
        rotation,
        stiffness=2.25,
    )


def build_body(archetype: Archetype, skin_mat):
    female = archetype.feminine
    shoulder = 0.50 if female else 0.57
    hip = 0.38 if female else 0.33
    waist = 0.26 if female else 0.31
    chest = 0.40 if female else 0.46
    meta = bpy.data.metaballs.new("BodyOrganicVolume")
    meta.resolution = 0.045
    meta.render_resolution = 0.038
    meta.threshold = 0.72
    meta_obj = bpy.data.objects.new("BodyOrganicVolume", meta)
    bpy.context.collection.objects.link(meta_obj)
    volumes = [
        ((0, 0, 1.02), (hip, 0.27, 0.38)),
        ((0, 0, 1.34), (waist, 0.22, 0.36)),
        ((0, 0, 1.66), (chest, 0.27, 0.42)),
        ((0, 0, 2.00), (0.17, 0.17, 0.28)),
        ((0, -0.015, 2.30), (0.32, 0.30, 0.38)),
        ((0, -0.075, 2.14), (0.27, 0.25, 0.23)),
        ((0, -0.295, 2.27), (0.075, 0.11, 0.105)),
        ((0, -0.235, 2.27), (0.09, 0.13, 0.12)),
    ]
    for location, scale in volumes:
        add_meta_ellipsoid(meta, location, scale)
    if female:
        add_meta_ellipsoid(meta, (0.17, -0.19, 1.70), (0.21, 0.20, 0.21))
        add_meta_ellipsoid(meta, (-0.17, -0.19, 1.70), (0.21, 0.20, 0.21))
    for side in (-1, 1):
        sx = side * shoulder
        ex = side * 0.84
        wx = side * 0.93
        add_meta_segment(
            meta,
            (side * 0.20, 0, 1.76),
            (sx, 0, 1.76),
            0.22 if female else 0.245,
        )
        add_meta_ellipsoid(
            meta,
            (side * 0.37, 0.015, 1.64),
            (0.25, 0.235, 0.27),
            stiffness=2.3,
        )
        add_meta_ellipsoid(meta, (sx, 0, 1.76), (0.25, 0.25, 0.26))
        add_meta_segment(meta, (sx, 0, 1.76), (ex, 0, 1.34), 0.19 if female else 0.21)
        add_meta_ellipsoid(meta, (ex, 0, 1.34), (0.19, 0.18, 0.20))
        add_meta_segment(meta, (ex, 0, 1.34), (wx, -0.02, 0.96), 0.16 if female else 0.18)
        add_meta_ellipsoid(meta, (wx, -0.03, 0.86), (0.18, 0.14, 0.25))
        add_meta_ellipsoid(meta, (side * hip * 0.52, 0.17, 0.98), (hip * 0.64, 0.29, 0.31))
        add_meta_segment(meta, (side * 0.22, 0, 1.01), (side * 0.23, 0, 0.50), 0.24 if female else 0.26)
        add_meta_ellipsoid(meta, (side * 0.23, -0.02, 0.48), (0.22, 0.21, 0.23))
        add_meta_segment(meta, (side * 0.23, 0, 0.48), (side * 0.23, 0, 0.10), 0.19 if female else 0.21)
        add_meta_ellipsoid(meta, (side * 0.23, -0.16, 0.06), (0.21, 0.35, 0.15))
    if archetype.semihuman:
        add_meta_ellipsoid(meta, (0.22, 0, 2.70), (0.13, 0.11, 0.31))
        add_meta_ellipsoid(meta, (-0.22, 0, 2.70), (0.13, 0.11, 0.31))
        add_meta_ellipsoid(meta, (0.20, 0, 2.52), (0.16, 0.14, 0.18), stiffness=2.4)
        add_meta_ellipsoid(meta, (-0.20, 0, 2.52), (0.16, 0.14, 0.18), stiffness=2.4)
        add_meta_segment(meta, (0, 0.24, 1.02), (0, 0.50, 0.82), 0.13)
        add_meta_segment(meta, (0, 0.50, 0.82), (0.08, 0.68, 0.48), 0.115)
        add_meta_segment(meta, (0.08, 0.68, 0.48), (0.20, 0.68, 0.20), 0.09)
        add_meta_ellipsoid(meta, (0, 0.27, 1.00), (0.16, 0.16, 0.16), stiffness=2.4)
        add_meta_ellipsoid(meta, (0, 0.50, 0.82), (0.15, 0.15, 0.16), stiffness=2.4)
        add_meta_ellipsoid(meta, (0.08, 0.68, 0.48), (0.13, 0.13, 0.15), stiffness=2.4)
    bpy.context.view_layer.objects.active = meta_obj
    meta_obj.select_set(True)
    body = bpy.context.object
    bpy.ops.object.convert(target="MESH")
    body = bpy.context.object
    body.name = "BodyContinuous"
    decimate = body.modifiers.new("MobileDecimate", "DECIMATE")
    decimate.ratio = 0.82
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    for polygon in body.data.polygons:
        polygon.use_smooth = True
    body.data.materials.clear()
    body.data.materials.append(skin_mat)
    components = connected_components(body)
    if len(components) != 1:
        descriptions = []
        for component in components:
            points = [body.data.vertices[index].co for index in component]
            minimum = Vector((
                min(point.x for point in points),
                min(point.y for point in points),
                min(point.z for point in points),
            ))
            maximum = Vector((
                max(point.x for point in points),
                max(point.y for point in points),
                max(point.z for point in points),
            ))
            descriptions.append(
                f"{len(component)} verts at {tuple(round(v, 2) for v in minimum)}"
                f"..{tuple(round(v, 2) for v in maximum)}"
            )
        raise RuntimeError(
            f"{archetype.file_id} body is not continuous: "
            + "; ".join(descriptions)
        )
    return body


def build_outfit(body, archetype: Archetype, outfit_mat):
    """Copy fitted regions from the body to form a clipping-free shirt/shorts."""
    selected_faces = []
    selected_vertices = set()
    torso_limit = 0.38 if archetype.feminine else 0.43
    for polygon in body.data.polygons:
        center = polygon.center
        is_shirt = 1.32 <= center.z <= 1.94 and abs(center.x) <= torso_limit
        is_shorts = 0.82 <= center.z <= 1.24 and abs(center.x) <= 0.48
        if is_shirt or is_shorts:
            indices = list(polygon.vertices)
            selected_faces.append(indices)
            selected_vertices.update(indices)
    ordered = sorted(selected_vertices)
    remap = {old: new for new, old in enumerate(ordered)}
    vertices = [body.data.vertices[index].co.copy() for index in ordered]
    faces = [[remap[index] for index in face] for face in selected_faces]
    mesh = bpy.data.meshes.new("OutfitStreetMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(outfit_mat)
    outfit = bpy.data.objects.new("OutfitStreet", mesh)
    bpy.context.collection.objects.link(outfit)
    displace = outfit.modifiers.new("FabricClearance", "DISPLACE")
    displace.direction = "NORMAL"
    displace.strength = 0.028
    solidify = outfit.modifiers.new("FabricThickness", "SOLIDIFY")
    solidify.thickness = 0.018
    solidify.offset = 1.0
    for polygon in outfit.data.polygons:
        polygon.use_smooth = True
    return outfit


def build_face(archetype: Archetype):
    eye_mat = material("Eyes", (0.03, 0.035, 0.04, 1), metallic=0.05, roughness=0.25)
    accent = material("EyeAccent", (0.08, 0.70, 0.95, 1), metallic=0.15, roughness=0.2)
    pieces = []
    for side in (-1, 1):
        pieces.append(add_ellipsoid(f"Eye{side}", (side * 0.115, -0.395, 2.35), (0.082, 0.060, 0.098), eye_mat, 12, 8))
        pieces.append(add_ellipsoid(f"Iris{side}", (side * 0.115, -0.446, 2.35), (0.036, 0.018, 0.048), accent, 10, 6))
    pieces.append(
        add_ellipsoid("Mouth", (0, -0.397, 2.145), (0.105, 0.022, 0.026), eye_mat, 12, 6)
    )
    return join_objects(pieces, "FaceDetails")


def build_hair(archetype: Archetype):
    hair_color = (0.055, 0.025, 0.015, 1) if not archetype.semihuman else (0.18, 0.07, 0.025, 1)
    hair_mat = material("HairOrTuft", hair_color, roughness=0.9)
    pieces = [
        add_ellipsoid("HairCrown", (0, 0.035, 2.52), (0.325, 0.295, 0.245), hair_mat, 16, 10),
        add_ellipsoid("Fringe", (0, -0.270, 2.48), (0.27, 0.075, 0.13), hair_mat, 14, 8),
    ]
    if archetype.feminine:
        pieces += [
            add_ellipsoid("HairBack", (0, 0.205, 2.30), (0.28, 0.19, 0.34), hair_mat, 14, 9),
            add_ellipsoid("Ponytail", (0, 0.39, 2.14), (0.17, 0.16, 0.32), hair_mat, 12, 8),
        ]
    elif archetype.semihuman:
        pieces.append(
            add_ellipsoid("HeadTuft", (0, -0.025, 2.70), (0.15, 0.12, 0.20), hair_mat, 12, 8)
        )
    hair = join_objects(pieces, "HairAccessory")
    for polygon in hair.data.polygons:
        polygon.use_smooth = True
    return hair


def build_armature(archetype: Archetype):
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    armature = bpy.context.object
    armature.name = "AvatarRig"
    armature.data.name = "AvatarSkeleton"
    edit_bones = armature.data.edit_bones
    edit_bones.remove(edit_bones[0])

    specs = {
        "root": ((0, 0, 0), (0, 0, 0.25), None, False),
        "hips": ((0, 0, 0.88), (0, 0, 1.18), "root", True),
        "spine": ((0, 0, 1.18), (0, 0, 1.56), "hips", True),
        "chest": ((0, 0, 1.56), (0, 0, 1.92), "spine", True),
        "neck": ((0, 0, 1.92), (0, 0, 2.12), "chest", True),
        "head": ((0, 0, 2.12), (0, 0, 2.58), "neck", True),
    }
    shoulder = 0.53 if archetype.feminine else 0.62
    for side, suffix in ((1, ".L"), (-1, ".R")):
        specs[f"upper_arm{suffix}"] = ((side * 0.34, 0, 1.82), (side * 0.84, 0, 1.34), "chest", True)
        specs[f"forearm{suffix}"] = ((side * 0.84, 0, 1.34), (side * 0.93, 0, 0.96), f"upper_arm{suffix}", True)
        specs[f"hand{suffix}"] = ((side * 0.93, 0, 0.96), (side * 0.96, -0.02, 0.74), f"forearm{suffix}", True)
        specs[f"thigh{suffix}"] = ((side * 0.22, 0, 1.08), (side * 0.23, 0, 0.50), "hips", True)
        specs[f"shin{suffix}"] = ((side * 0.23, 0, 0.50), (side * 0.23, 0, 0.10), f"thigh{suffix}", True)
        specs[f"foot{suffix}"] = ((side * 0.23, 0, 0.10), (side * 0.23, -0.32, 0.04), f"shin{suffix}", True)
    if archetype.semihuman:
        specs["ear.L"] = ((0.22, 0, 2.52), (0.22, 0, 2.86), "head", True)
        specs["ear.R"] = ((-0.22, 0, 2.52), (-0.22, 0, 2.86), "head", True)
        specs["tail.01"] = ((0, 0.18, 1.02), (0, 0.50, 0.82), "hips", True)
        specs["tail.02"] = ((0, 0.50, 0.82), (0.08, 0.68, 0.48), "tail.01", True)
        specs["tail.03"] = ((0.08, 0.68, 0.48), (0.20, 0.68, 0.20), "tail.02", True)

    for name, (head, tail, parent, deform) in specs.items():
        bone = edit_bones.new(name)
        bone.head, bone.tail = head, tail
        bone.use_deform = deform
        if parent:
            bone.parent = edit_bones[parent]
    bpy.ops.object.mode_set(mode="POSE")
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "XYZ"
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def distance_to_segment(point: Vector, start: Vector, end: Vector) -> float:
    segment = end - start
    if segment.length_squared == 0:
        return (point - start).length
    ratio = max(0.0, min(1.0, (point - start).dot(segment) / segment.length_squared))
    return (point - (start + segment * ratio)).length


def bind_mesh(mesh_obj, armature):
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature
    candidates = [bone for bone in armature.data.bones if bone.use_deform]
    groups = {bone.name: mesh_obj.vertex_groups.new(name=bone.name) for bone in candidates}
    for vertex in mesh_obj.data.vertices:
        point = vertex.co
        ranked = sorted(
            (
                (1.0 / max(0.015, distance_to_segment(point, bone.head_local, bone.tail_local)) ** 2, bone.name)
                for bone in candidates
            ),
            reverse=True,
        )[:4]
        total = sum(weight for weight, _ in ranked)
        for weight, bone_name in ranked:
            groups[bone_name].add([vertex.index], weight / total, "REPLACE")
    mesh_obj.parent = armature


def key_pose(armature, frame: int, rotations=None, locations=None):
    rotations = rotations or {}
    locations = locations or {}
    for bone_name, rotation in rotations.items():
        bone = armature.pose.bones.get(bone_name)
        if bone:
            bone.rotation_euler = rotation
            bone.keyframe_insert("rotation_euler", frame=frame)
    for bone_name, location in locations.items():
        bone = armature.pose.bones.get(bone_name)
        if bone:
            bone.location = location
            bone.keyframe_insert("location", frame=frame)


def create_actions(armature, archetype: Archetype):
    feminine = archetype.feminine
    hip_sway = 0.09 if feminine else 0.025
    chest_sway = 0.045 if feminine else 0.015
    animal_a = {
        "ear.L": (0.03, 0.07, -0.055),
        "ear.R": (-0.03, -0.07, 0.055),
        "tail.01": (0.04, 0.10, 0.12),
        "tail.02": (-0.03, -0.08, 0.10),
        "tail.03": (0.02, 0.05, 0.08),
    }
    animal_b = {
        "ear.L": (-0.04, -0.09, 0.045),
        "ear.R": (0.04, 0.09, -0.045),
        "tail.01": (-0.05, -0.12, -0.14),
        "tail.02": (0.04, 0.09, -0.11),
        "tail.03": (-0.03, -0.06, -0.09),
    }
    clips = {
        "Idle": (30, [
            (1, {"spine": (0.02, 0, 0), "chest": (-0.02, 0, 0), **animal_a}, {}),
            (16, {"spine": (-0.025, 0, 0), "chest": (0.025, 0, 0), **animal_b}, {"hips": (0, 0, 0.015)}),
            (30, {"spine": (0.02, 0, 0), "chest": (-0.02, 0, 0), **animal_a}, {}),
        ]),
        "Walk": (30, [
            (1, {
                "hips": (0.015, 0, hip_sway),
                "chest": (-0.025, 0, -chest_sway),
                "head": (0.01, 0, chest_sway * 0.35),
                "upper_arm.L": (0, 0.42, 0),
                "upper_arm.R": (0, -0.42, 0),
                "forearm.L": (0, 0.16, 0),
                "forearm.R": (0, -0.28, 0),
                "thigh.L": (0, -0.48, 0),
                "thigh.R": (0, 0.48, 0),
                "shin.L": (0, 0.16, 0),
                "shin.R": (0, 0.48, 0),
                "foot.L": (0, 0.12, 0),
                "foot.R": (0, -0.22, 0),
                **animal_a,
            }, {}),
            (9, {
                "hips": (-0.025, 0, 0),
                "chest": (0.02, 0, 0),
                "head": (-0.01, 0, 0),
                "upper_arm.L": (0, 0, 0),
                "upper_arm.R": (0, 0, 0),
                "forearm.L": (0, 0.24, 0),
                "forearm.R": (0, -0.24, 0),
                "thigh.L": (0, 0, 0),
                "thigh.R": (0, 0, 0),
                "shin.L": (0, 0.08, 0),
                "shin.R": (0, 0.34, 0),
                "foot.L": (0, -0.06, 0),
                "foot.R": (0, 0.18, 0),
            }, {"hips": (0, 0, 0.045)}),
            (16, {
                "hips": (0.015, 0, -hip_sway),
                "chest": (-0.025, 0, chest_sway),
                "head": (0.01, 0, -chest_sway * 0.35),
                "upper_arm.L": (0, -0.42, 0),
                "upper_arm.R": (0, 0.42, 0),
                "forearm.L": (0, 0.28, 0),
                "forearm.R": (0, -0.16, 0),
                "thigh.L": (0, 0.48, 0),
                "thigh.R": (0, -0.48, 0),
                "shin.L": (0, 0.48, 0),
                "shin.R": (0, 0.16, 0),
                "foot.L": (0, -0.22, 0),
                "foot.R": (0, 0.12, 0),
                **animal_b,
            }, {}),
            (24, {
                "hips": (-0.025, 0, 0),
                "chest": (0.02, 0, 0),
                "head": (-0.01, 0, 0),
                "upper_arm.L": (0, 0, 0),
                "upper_arm.R": (0, 0, 0),
                "forearm.L": (0, 0.24, 0),
                "forearm.R": (0, -0.24, 0),
                "thigh.L": (0, 0, 0),
                "thigh.R": (0, 0, 0),
                "shin.L": (0, 0.34, 0),
                "shin.R": (0, 0.08, 0),
                "foot.L": (0, 0.18, 0),
                "foot.R": (0, -0.06, 0),
            }, {"hips": (0, 0, 0.045)}),
            (30, {
                "hips": (0.015, 0, hip_sway),
                "chest": (-0.025, 0, -chest_sway),
                "head": (0.01, 0, chest_sway * 0.35),
                "upper_arm.L": (0, 0.42, 0),
                "upper_arm.R": (0, -0.42, 0),
                "forearm.L": (0, 0.16, 0),
                "forearm.R": (0, -0.28, 0),
                "thigh.L": (0, -0.48, 0),
                "thigh.R": (0, 0.48, 0),
                "shin.L": (0, 0.16, 0),
                "shin.R": (0, 0.48, 0),
                "foot.L": (0, 0.12, 0),
                "foot.R": (0, -0.22, 0),
                **animal_a,
            }, {}),
        ]),
        "Crouch": (20, [
            (1, {}, {}),
            (20, {"spine": (0.22, 0, 0), "thigh.L": (0, -0.72, 0), "thigh.R": (0, -0.72, 0), "shin.L": (0, 0.85, 0), "shin.R": (0, 0.85, 0)}, {"hips": (0, 0, -0.38)}),
        ]),
        "Push": (18, [
            (1, {}, {}),
            (7, {"chest": (-0.28, 0, 0), "upper_arm.L": (0, -1.05, 0), "upper_arm.R": (0, 1.05, 0), "forearm.L": (0, -0.45, 0), "forearm.R": (0, 0.45, 0)}, {}),
            (18, {}, {}),
        ]),
        "Shoot": (12, [
            (1, {"upper_arm.R": (0, 0.90, 0), "forearm.R": (0, 0.45, 0), "upper_arm.L": (0, -0.55, 0)}, {}),
            (5, {"chest": (0.08, 0, 0), "upper_arm.R": (0, 0.78, 0), "forearm.R": (0, 0.35, 0)}, {}),
            (12, {"upper_arm.R": (0, 0.90, 0), "forearm.R": (0, 0.45, 0), "upper_arm.L": (0, -0.55, 0)}, {}),
        ]),
    }
    for action_name, (end_frame, poses) in clips.items():
        action = bpy.data.actions.new(action_name)
        armature.animation_data_create()
        armature.animation_data.action = action
        for frame, rotations, locations in poses:
            key_pose(armature, frame, rotations, locations)
        action.frame_start, action.frame_end = 1, end_frame
        track = armature.animation_data.nla_tracks.new()
        track.name = action_name
        strip = track.strips.new(action_name, 1, action)
        strip.action_frame_start, strip.action_frame_end = 1, end_frame
        track.mute = True
    armature.animation_data.action = None
    for track in armature.animation_data.nla_tracks:
        track.mute = False


def setup_preview(archetype: Archetype, output_path: str):
    ground_mat = material("PreviewGround", (0.025, 0.035, 0.055, 1), metallic=0.1, roughness=0.85)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=1.55, depth=0.10, location=(0, 0, -0.08))
    ground = bpy.context.object
    ground.name = "PreviewPedestal"
    ground.data.materials.append(ground_mat)
    bpy.ops.object.camera_add(location=(4.3, -6.5, 3.15))
    camera = bpy.context.object
    camera.data.lens = 58
    direction = Vector((0, 0, 1.35)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(3.5, -3.5, 5.4))
    key = bpy.context.object
    key.data.energy = 900
    key.data.shape = "DISK"
    key.data.size = 4.0
    bpy.ops.object.light_add(type="AREA", location=(-3.0, 0.5, 3.2))
    fill = bpy.context.object
    fill.data.energy = 520
    fill.data.color = (0.2, 0.5, 1.0)
    fill.data.size = 3.0
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 760
    scene.render.resolution_percentage = 100
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = os.path.join(output_path, f"{archetype.file_id}_preview.png")
    scene.world.color = (0.012, 0.018, 0.03)
    scene.render.film_transparent = False
    bpy.ops.render.render(write_still=True)
    for obj in (ground, camera, key, fill):
        bpy.data.objects.remove(obj, do_unlink=True)


def export_glb(archetype: Archetype, output_path: str):
    glb_path = os.path.join(output_path, f"{archetype.file_id}.glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_skins=True,
        export_morph=False,
        export_def_bones=True,
        export_all_influences=False,
        export_nla_strips=True,
        export_optimize_animation_size=True,
    )
    return glb_path


def build_archetype(archetype: Archetype, output_path: str):
    clear_scene()
    skin_mat = material("SkinOrFur", archetype.skin, roughness=0.82)
    outfit_mat = material("OutfitPrimary", archetype.outfit, metallic=0.08, roughness=0.68)
    body = build_body(archetype, skin_mat)
    outfit = build_outfit(body, archetype, outfit_mat)
    face = build_face(archetype)
    hair = build_hair(archetype)
    armature = build_armature(archetype)
    for mesh in (body, outfit, face, hair):
        bind_mesh(mesh, armature)
    create_actions(armature, archetype)
    for obj in (body, outfit, face, hair, armature):
        obj["oneproyect_archetype"] = archetype.file_id
        obj["oneproyect_display_name"] = archetype.display_name
    glb_path = export_glb(archetype, output_path)
    if os.environ.get("ONEPROYECT_RENDER_PREVIEWS") == "1":
        setup_preview(archetype, output_path)
    blend_path = os.path.join(output_path, f"{archetype.file_id}.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(
        f"ONEPROYECT_AVATAR_OK id={archetype.file_id} "
        f"vertices={len(body.data.vertices)} glb={glb_path}"
    )


def main():
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    output_path = os.path.abspath(arguments[0] if arguments else "./generated_avatars")
    os.makedirs(output_path, exist_ok=True)
    requested = {
        item.strip()
        for item in os.environ.get("ONEPROYECT_AVATAR_FILTER", "").split(",")
        if item.strip()
    }
    for archetype in ARCHETYPES:
        if requested and archetype.file_id not in requested:
            continue
        build_archetype(archetype, output_path)


if __name__ == "__main__":
    main()
