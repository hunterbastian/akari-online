#!/usr/bin/env python3
"""Rebuild Akari's low-poly glTF assets.

Run from the repo root:

    blender -b --python tools/blender/build_assets.py

Meshes are flat-shaded geometric forms in a small warm/cool palette.
Blender +Y is the nose; the glTF exporter maps that to Three.js -Z.
Props sit on local Z = 0, which becomes Y = 0 after export.
"""

import json
import math
import os
import random
import subprocess

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT_DIR = os.path.join(ROOT, 'public', 'models')
META_PATH = os.path.join(ROOT, 'src', 'components', 'flight', 'modelMeta.json')

os.makedirs(OUT_DIR, exist_ok=True)


def hex_rgba(value, alpha=1.0):
    value = value.lstrip('#')
    rgb = tuple(int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return (*rgb, alpha)


def make_material(name, color, roughness=0.84, metallic=0.0, emission=None, strength=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = hex_rgba(color)
    bsdf = material.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = hex_rgba(color)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    if emission:
        bsdf.inputs['Emission Color'].default_value = hex_rgba(emission)
        bsdf.inputs['Emission Strength'].default_value = strength
    return material


MAT = {}


def ensure_materials():
    MAT['Hull'] = make_material('Hull', '#d9d3c8', 0.78, 0.04)
    MAT['Accent'] = make_material('Accent', '#e6b089', 0.62, 0.08)
    MAT['Dark'] = make_material('Dark', '#1a1028', 0.5, 0.12)
    MAT['Canopy'] = make_material('Canopy', '#243044', 0.22, 0.18)
    MAT['Engine'] = make_material('Engine', '#e07a48', 0.4, 0.0, '#e07a48', 2.4)
    MAT['Glow'] = make_material('Glow', '#f2c394', 0.35, 0.0, '#f2c394', 1.6)
    MAT['Rock'] = make_material('Rock', '#9a9186', 0.94, 0.0)
    MAT['Plant'] = make_material('Plant', '#4e7a52', 0.88, 0.0)
    MAT['Crystal'] = make_material('Crystal', '#d5e4ea', 0.28, 0.04, '#d5e4ea', 0.35)
    MAT['Metal'] = make_material('Metal', '#c4beb4', 0.55, 0.22)
    MAT['Ice'] = make_material('Ice', '#d7eef8', 0.24, 0.02, '#e7f6ff', 0.25)
    MAT['Sand'] = make_material('Sand', '#e0c39a', 0.9, 0.0)


def assign(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)


def shade_flat(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = False


def link_new(mesh, name):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def select_only(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def apply_scale(obj):
    select_only([obj])
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def primitive(kind, name, location, scale=(1, 1, 1), rotation=(0, 0, 0), material=None, **kwargs):
    add = {
        'cube': bpy.ops.mesh.primitive_cube_add,
        'cylinder': bpy.ops.mesh.primitive_cylinder_add,
        'cone': bpy.ops.mesh.primitive_cone_add,
        'uv': bpy.ops.mesh.primitive_uv_sphere_add,
        'ico': bpy.ops.mesh.primitive_ico_sphere_add,
        'octa': lambda **kw: bpy.ops.mesh.primitive_circle_add(**kw),  # placeholder, unused
        'torus': bpy.ops.mesh.primitive_torus_add,
    }[kind]
    add(location=location, rotation=rotation, **kwargs)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    apply_scale(obj)
    shade_flat(obj)
    if material:
        assign(obj, material)
    return obj


def box(name, location, size, material, rotation=(0, 0, 0)):
    obj = primitive('cube', name, location, scale=size, rotation=rotation, material=material, size=1)
    return obj


def join(objects, name):
    select_only(objects)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    shade_flat(obj)
    return obj


def shift_vertices(obj, offset):
    for vert in obj.data.vertices:
        vert.co += Vector(offset)


def center_ship(obj):
    bpy.context.view_layer.update()
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    offset = (
        -((min(xs) + max(xs)) / 2),
        -((min(ys) + max(ys)) / 2),
        -((min(zs) + max(zs)) / 2),
    )
    shift_vertices(obj, offset)
    obj.location = (0, 0, 0)
    return offset


def sit_on_floor(obj):
    bpy.context.view_layer.update()
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    shift_vertices(obj, (
        -((min(xs) + max(xs)) / 2),
        -((min(ys) + max(ys)) / 2),
        -min(zs),
    ))
    obj.location = (0, 0, 0)


def to_gltf(x, y, z):
    return [round(x, 4), round(z, 4), round(-y, 4)]


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for collection in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)


def export_glb(objects, filename):
    path = os.path.join(OUT_DIR, filename)
    select_only(objects)
    common = dict(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_texcoords=False,
        export_normals=True,
        export_materials='EXPORT',
        export_animations=False,
    )
    # The exporter flag is present, but Debian's Blender omits libextern_draco.so
    # and silently writes an uncompressed file. compress.mjs does the real pass.
    try:
        bpy.ops.export_scene.gltf(
            **common,
            export_draco_mesh_compression_enable=True,
            export_draco_mesh_compression_level=6,
            export_draco_position_quantization=14,
            export_draco_normal_quantization=10,
            export_draco_texcoord_quantization=10,
        )
    except Exception as error:  # noqa: BLE001 - still emit a mesh if the flag is rejected
        print('Draco flag rejected, writing plain GLB:', error)
        bpy.ops.export_scene.gltf(**common)
    print(f'exported {filename} ({os.path.getsize(path)} bytes, draco={glb_has_draco(path)})')
    return path


def glb_has_draco(path):
    with open(path, 'rb') as handle:
        blob = handle.read()
    return b'KHR_draco_mesh_compression' in blob


def hull_mesh():
    """Wedge fuselage. Nose is +Y."""
    mesh = bpy.data.meshes.new('hull')
    sections = [
        (2.72, 0.06, 0.07),
        (1.55, 0.30, 0.15),
        (0.25, 0.46, 0.20),
        (-0.85, 0.34, 0.16),
        (-1.95, 0.18, 0.09),
    ]
    verts = []
    rings = []
    for y, half_w, half_h in sections:
        ring = []
        points = [
            (0, y, half_h * 0.95),
            (half_w * 0.78, y, half_h * 0.42),
            (half_w, y, -half_h * 0.05),
            (half_w * 0.48, y, -half_h),
            (-half_w * 0.48, y, -half_h),
            (-half_w, y, -half_h * 0.05),
            (-half_w * 0.78, y, half_h * 0.42),
        ]
        for point in points:
            ring.append(len(verts))
            verts.append(point)
        rings.append(ring)

    faces = [rings[0]]
    for ring_a, ring_b in zip(rings, rings[1:]):
        count = len(ring_a)
        for i in range(count):
            j = (i + 1) % count
            faces.append((ring_a[i], ring_a[j], ring_b[j], ring_b[i]))
    faces.append(tuple(reversed(rings[-1])))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = link_new(mesh, 'Hull')
    assign(obj, MAT['Hull'])
    shade_flat(obj)
    return obj


def wing(sign):
    mesh = bpy.data.meshes.new('wing')
    s = sign
    top = [
        (s * 0.28, 0.72, 0.02),
        (s * 0.22, -0.95, 0.0),
        (s * 2.05, -1.28, 0.05),
        (s * 1.62, 0.18, 0.08),
    ]
    bottom = [(x, y, z - 0.045) for x, y, z in top]
    verts = top + bottom
    faces = [
        (0, 1, 2, 3),
        (4, 7, 6, 5),
        (0, 3, 7, 4),
        (3, 2, 6, 7),
        (2, 1, 5, 6),
        (1, 0, 4, 5),
    ]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = link_new(mesh, f'Wing{sign}')
    assign(obj, MAT['Hull'])
    shade_flat(obj)
    return obj


def build_ship():
    parts = [hull_mesh(), wing(1), wing(-1)]
    parts.append(box('Canopy', (0, 0.85, 0.28), (0.34, 0.72, 0.16), MAT['Canopy']))
    parts.append(box('Stripe', (0, 0.15, 0.22), (0.06, 2.3, 0.025), MAT['Accent']))
    parts.append(box('Fin', (0, -1.35, 0.38), (0.045, 0.55, 0.42), MAT['Hull']))
    parts.append(box('FinTip', (0, -1.5, 0.62), (0.03, 0.22, 0.08), MAT['Accent']))
    for side in (1, -1):
        parts.append(primitive(
            'cylinder', f'Engine{side}',
            (side * 0.34, -1.72, -0.02),
            scale=(1, 1, 1),
            rotation=(math.pi / 2, 0, 0),
            material=MAT['Dark'],
            vertices=8, radius=0.16, depth=0.62,
        ))
        parts.append(primitive(
            'cylinder', f'Nozzle{side}',
            (side * 0.34, -2.02, -0.02),
            scale=(1, 1, 1),
            rotation=(math.pi / 2, 0, 0),
            material=MAT['Engine'],
            vertices=8, radius=0.09, depth=0.08,
        ))
    ship = join(parts, 'Ship')
    center_ship(ship)
    engines = []
    for side in (1, -1):
        # Nozzles were joined; record the designed rear point in the centered mesh.
        engines.append(None)
    # Measure actual rear-most vertices near each side for trail anchors.
    left = []
    right = []
    for vert in ship.data.vertices:
        if vert.co.y < -1.3:
            (right if vert.co.x > 0 else left).append(vert.co)
    def anchor(group):
        if not group:
            return (0, -1.6, 0)
        x = sum(v.x for v in group) / len(group)
        y = min(v.y for v in group)
        z = sum(v.z for v in group) / len(group)
        return (x, y - 0.05, z)
    meta = {
        'engines': [to_gltf(*anchor(right)), to_gltf(*anchor(left))],
    }
    export_glb([ship], 'ship.glb')
    clear_scene()
    return meta


def build_hauler():
    parts = []
    parts.append(box('Body', (0, 0, 0.15), (1.15, 3.4, 0.72), MAT['Hull']))
    parts.append(box('Nose', (0, 2.05, 0.08), (0.62, 0.9, 0.42), MAT['Hull']))
    parts.append(box('Canopy', (0, 1.15, 0.58), (0.46, 0.55, 0.22), MAT['Canopy']))
    parts.append(box('CargoL', (-0.78, -0.15, 0.28), (0.42, 1.7, 0.55), MAT['Accent']))
    parts.append(box('CargoR', (0.78, -0.15, 0.28), (0.42, 1.7, 0.55), MAT['Accent']))
    parts.append(box('Stripe', (0, 0.2, 0.52), (0.08, 2.6, 0.03), MAT['Dark']))
    parts.append(primitive(
        'cylinder', 'Engine',
        (0, -1.85, 0.05),
        rotation=(math.pi / 2, 0, 0),
        material=MAT['Dark'],
        vertices=8, radius=0.28, depth=0.55,
    ))
    parts.append(primitive(
        'cylinder', 'Nozzle',
        (0, -2.16, 0.05),
        rotation=(math.pi / 2, 0, 0),
        material=MAT['Engine'],
        vertices=8, radius=0.16, depth=0.08,
    ))
    ship = join(parts, 'Hauler')
    center_ship(ship)
    rear = [v.co for v in ship.data.vertices if v.co.y < -1.2]
    y = min(v.y for v in rear) - 0.04
    x = sum(v.x for v in rear) / len(rear)
    z = sum(v.z for v in rear) / len(rear)
    meta = {'engines': [to_gltf(x, y, z)]}
    export_glb([ship], 'hauler.glb')
    clear_scene()
    return meta


def build_freighter():
    parts = []
    parts.append(box('Spine', (0, 0, 0), (1.1, 14.5, 0.7), MAT['Metal']))
    parts.append(box('Bridge', (0, 6.4, 0.85), (0.9, 1.6, 0.7), MAT['Hull']))
    parts.append(box('Glass', (0, 7.05, 1.05), (0.7, 0.35, 0.28), MAT['Canopy']))
    for i, y in enumerate((-3.6, -1.2, 1.2, 3.4)):
        tone = MAT['Hull'] if i % 2 == 0 else MAT['Accent']
        parts.append(box(f'Pod{i}', (0, y, 0.15), (1.7, 1.7, 1.15), tone))
    for side in (1, -1):
        parts.append(primitive(
            'cylinder', f'Engine{side}',
            (side * 0.42, -7.5, 0),
            rotation=(math.pi / 2, 0, 0),
            material=MAT['Dark'],
            vertices=8, radius=0.32, depth=0.9,
        ))
        parts.append(primitive(
            'cylinder', f'Glow{side}',
            (side * 0.42, -8.0, 0),
            rotation=(math.pi / 2, 0, 0),
            material=MAT['Engine'],
            vertices=8, radius=0.18, depth=0.1,
        ))
    ship = join(parts, 'Freighter')
    center_ship(ship)
    export_glb([ship], 'freighter.glb')
    clear_scene()


def build_station():
    parts = []
    parts.append(primitive(
        'cylinder', 'Hub', (0, 0, 0),
        material=MAT['Hull'],
        vertices=8, radius=1.35, depth=3.4,
    ))
    parts.append(primitive(
        'torus', 'Ring', (0, 0, 0.2),
        material=MAT['Accent'],
        major_radius=5.6, minor_radius=0.16,
        major_segments=8, minor_segments=6,
    ))
    for i in range(4):
        angle = i * math.pi / 2
        x = math.cos(angle) * 5.6
        y = math.sin(angle) * 5.6
        parts.append(box(f'Pylon{i}', (x, y, -0.9), (0.28, 0.28, 2.2), MAT['Metal']))
        parts.append(primitive(
            'cylinder', f'Light{i}', (x, y, 0.55),
            material=MAT['Glow'],
            vertices=6, radius=0.12, depth=0.12,
        ))
    parts.append(box('Arm', (0, 3.2, -0.15), (0.55, 3.6, 0.28), MAT['Metal']))
    parts.append(box('Dock', (0, 5.15, -0.15), (1.5, 0.7, 0.18), MAT['Hull']))
    parts.append(primitive(
        'cylinder', 'Dish', (0, -1.6, 2.15),
        scale=(1.1, 1.1, 0.18),
        rotation=(0.5, 0, 0.4),
        material=MAT['Dark'],
        vertices=8, radius=0.7, depth=0.12,
    ))
    station = join(parts, 'Station')
    station.location = (0, 0, 0)
    export_glb([station], 'station.glb')
    clear_scene()


def build_gate():
    parts = []
    parts.append(primitive(
        'torus', 'Ring', (0, 0, 0),
        rotation=(math.pi / 2, 0, 0),
        material=MAT['Metal'],
        major_radius=6.0, minor_radius=0.11,
        major_segments=12, minor_segments=6,
    ))
    for i in range(4):
        angle = i * math.pi / 2 + 0.4
        x = math.cos(angle) * 6.0
        z = math.sin(angle) * 6.0
        parts.append(box(f'Lamp{i}', (x, 0, z), (0.28, 0.28, 0.28), MAT['Glow']))
    gate = join(parts, 'Gate')
    export_glb([gate], 'gate.glb')
    clear_scene()


def build_pilot():
    parts = []
    parts.append(primitive(
        'uv', 'Head', (0, 0, 1.58),
        material=MAT['Hull'],
        segments=8, ring_count=6, radius=0.16,
    ))
    parts.append(box('Visor', (0, 0.12, 1.6), (0.18, 0.06, 0.08), MAT['Canopy']))
    parts.append(box('Torso', (0, 0, 1.12), (0.36, 0.2, 0.48), MAT['Hull']))
    parts.append(box('Chest', (0, 0.08, 1.16), (0.16, 0.06, 0.22), MAT['Accent']))
    parts.append(box('Hip', (0, 0, 0.78), (0.32, 0.18, 0.16), MAT['Dark']))
    for side in (1, -1):
        parts.append(box(f'Leg{side}', (side * 0.09, 0, 0.36), (0.1, 0.12, 0.7), MAT['Dark']))
        parts.append(box(f'Arm{side}', (side * 0.28, 0, 1.12), (0.08, 0.1, 0.42), MAT['Hull']))
    pilot = join(parts, 'Pilot')
    sit_on_floor(pilot)
    export_glb([pilot], 'pilot.glb')
    clear_scene()


def build_rock(name, seed, scale=1.0):
    rng = random.Random(seed)
    parts = []
    for i in range(4):
        parts.append(box(
            f'{name}{i}',
            (
                rng.uniform(-0.22, 0.22) * scale,
                rng.uniform(-0.22, 0.22) * scale,
                rng.uniform(0.2, 0.55) * scale,
            ),
            (
                rng.uniform(0.35, 0.85) * scale,
                rng.uniform(0.3, 0.75) * scale,
                rng.uniform(0.28, 0.6) * scale,
            ),
            MAT['Rock'],
            rotation=(rng.uniform(-0.5, 0.5), rng.uniform(-0.4, 0.4), rng.uniform(0, math.pi)),
        ))
    rock = join(parts, name)
    sit_on_floor(rock)
    export_glb([rock], f'{name}.glb')
    clear_scene()


def build_crystal():
    parts = []
    for i, (x, y, height, radius) in enumerate((
        (0, 0, 1.15, 0.22),
        (0.18, 0.08, 0.72, 0.12),
        (-0.14, -0.1, 0.55, 0.1),
    )):
        parts.append(primitive(
            'cone', f'Crystal{i}',
            (x, y, height * 0.45),
            scale=(radius / 0.2, radius / 0.2, height),
            material=MAT['Crystal'],
            vertices=5, radius1=0.2, radius2=0.0, depth=1,
        ))
    obj = join(parts, 'Crystal')
    sit_on_floor(obj)
    export_glb([obj], 'crystal.glb')
    clear_scene()


def build_tree():
    parts = []
    parts.append(primitive(
        'cylinder', 'Trunk', (0, 0, 0.45),
        material=MAT['Rock'],
        vertices=6, radius=0.08, depth=0.9,
    ))
    parts.append(primitive(
        'cone', 'CanopyA', (0, 0, 1.15),
        material=MAT['Plant'],
        vertices=6, radius1=0.55, radius2=0.0, depth=0.85,
    ))
    parts.append(primitive(
        'cone', 'CanopyB', (0, 0, 1.55),
        material=MAT['Plant'],
        vertices=6, radius1=0.38, radius2=0.0, depth=0.6,
    ))
    obj = join(parts, 'Tree')
    sit_on_floor(obj)
    export_glb([obj], 'tree.glb')
    clear_scene()


def build_flora():
    parts = []
    parts.append(primitive(
        'cylinder', 'Stem', (0, 0, 0.35),
        material=MAT['Plant'],
        vertices=5, radius=0.035, depth=0.7,
    ))
    parts.append(primitive(
        'uv', 'Bulb', (0, 0, 0.82),
        scale=(1, 1, 1.15),
        material=MAT['Accent'],
        segments=8, ring_count=6, radius=0.2,
    ))
    obj = join(parts, 'Flora')
    sit_on_floor(obj)
    export_glb([obj], 'flora.glb')
    clear_scene()


def build_shard():
    parts = []
    parts.append(primitive(
        'cone', 'Shard', (0, 0, 0.7),
        scale=(0.7, 0.45, 1.5),
        rotation=(0.08, 0, 0.2),
        material=MAT['Ice'],
        vertices=4, radius1=0.28, radius2=0.0, depth=1,
    ))
    parts.append(primitive(
        'cone', 'ShardB', (0.16, -0.05, 0.4),
        scale=(0.4, 0.3, 0.8),
        material=MAT['Ice'],
        vertices=4, radius1=0.22, radius2=0.0, depth=1,
    ))
    obj = join(parts, 'Shard')
    sit_on_floor(obj)
    export_glb([obj], 'shard.glb')
    clear_scene()


def build_spire():
    parts = []
    parts.append(box('Base', (0, 0, 0.25), (0.7, 0.7, 0.5), MAT['Sand']))
    parts.append(box('Mid', (0, 0, 0.85), (0.42, 0.42, 0.8), MAT['Sand'], rotation=(0, 0, 0.2)))
    parts.append(box('Top', (0, 0, 1.45), (0.22, 0.22, 0.55), MAT['Accent']))
    obj = join(parts, 'Spire')
    sit_on_floor(obj)
    export_glb([obj], 'spire.glb')
    clear_scene()


def build_deposit():
    parts = []
    parts.append(box('Bed', (0, 0, 0.12), (0.7, 0.55, 0.22), MAT['Rock']))
    for i, (x, y, z) in enumerate(((0, 0.05, 0.45), (0.18, -0.08, 0.32), (-0.16, 0.02, 0.3))):
        parts.append(primitive(
            'cone', f'Gem{i}', (x, y, z),
            scale=(0.55, 0.55, 0.7 + i * 0.15),
            material=MAT['Accent'],
            vertices=5, radius1=0.16, radius2=0.0, depth=0.5,
        ))
    obj = join(parts, 'Deposit')
    sit_on_floor(obj)
    export_glb([obj], 'deposit.glb')
    clear_scene()


def build_arch():
    parts = []
    parts.append(box('Left', (-0.95, 0, 1.25), (0.48, 0.42, 2.5), MAT['Rock'], rotation=(0, 0, 0.14)))
    parts.append(box('Right', (0.95, 0, 1.25), (0.48, 0.42, 2.5), MAT['Rock'], rotation=(0, 0, -0.14)))
    parts.append(box('Lintel', (0, 0, 2.55), (2.35, 0.5, 0.42), MAT['Rock']))
    parts.append(box('Key', (0, 0.08, 2.28), (0.32, 0.22, 0.62), MAT['Accent']))
    obj = join(parts, 'Arch')
    sit_on_floor(obj)
    export_glb([obj], 'arch.glb')
    clear_scene()


def build_monolith():
    parts = []
    parts.append(box('Slab', (0, 0, 1.7), (1.15, 0.28, 3.4), MAT['Dark']))
    parts.append(box('Cap', (0, 0, 3.45), (1.28, 0.36, 0.12), MAT['Accent']))
    parts.append(box('Slit', (0, 0.15, 1.8), (0.08, 0.04, 1.5), MAT['Glow']))
    parts.append(box('Plinth', (0, 0, 0.12), (1.6, 0.7, 0.24), MAT['Metal']))
    obj = join(parts, 'Monolith')
    sit_on_floor(obj)
    export_glb([obj], 'monolith.glb')
    clear_scene()


def main():
    clear_scene()
    ensure_materials()
    meta = {
        'ship': build_ship(),
        'hauler': build_hauler(),
    }
    build_freighter()
    build_station()
    build_gate()
    build_pilot()
    build_rock('rock_a', 3, 1.0)
    build_rock('rock_b', 11, 0.72)
    build_crystal()
    build_tree()
    build_flora()
    build_shard()
    build_spire()
    build_arch()
    build_deposit()
    build_monolith()
    with open(META_PATH, 'w', encoding='utf-8') as handle:
        json.dump(meta, handle, indent=2)
        handle.write('\n')
    print('meta', meta)
    compress = os.path.join(os.path.dirname(__file__), 'compress.mjs')
    modules = os.path.join(os.path.dirname(__file__), 'node_modules')
    if os.path.isdir(modules):
        subprocess.check_call(['node', compress], cwd=ROOT)
    else:
        print('Skipping Draco compress. From tools/blender: npm install && node compress.mjs')


if __name__ == '__main__':
    main()
