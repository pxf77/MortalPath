"""Create the procedural Blender source used to prove the P0 pipeline.

This bootstrap object is intentionally simple. It validates units, material export,
GLB conversion, preview rendering, budget inspection and Godot import without
pretending to be a production game asset.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def material(name: str, color: tuple[float, float, float, float], roughness: float):
    value = bpy.data.materials.new(name=name)
    value.diffuse_color = color
    value.use_nodes = True
    principled = value.node_tree.nodes.get("Principled BSDF")
    if principled:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
    return value


def add_bevel(object_: bpy.types.Object, width: float, segments: int = 3) -> None:
    modifier = object_.modifiers.new(name="production_bevel", type="BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = object_
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def main() -> None:
    args = parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["mortalpath_asset_id"] = "prop_pipeline_marker"

    stone = material("mat_stone_gray", (0.28, 0.30, 0.28, 1.0), 0.88)
    dark_stone = material("mat_stone_dark", (0.12, 0.15, 0.14, 1.0), 0.93)
    jade = material("mat_jade_muted", (0.16, 0.38, 0.31, 1.0), 0.42)

    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.58, depth=0.16, location=(0, 0, 0.08))
    base = bpy.context.object
    base.name = "prop_pipeline_marker_base"
    base.data.materials.append(dark_stone)
    add_bevel(base, 0.035, 2)

    bpy.ops.mesh.primitive_cube_add(location=(0, 0, 0.73), scale=(0.34, 0.25, 0.62))
    body = bpy.context.object
    body.name = "prop_pipeline_marker_body"
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    body.data.materials.append(stone)
    add_bevel(body, 0.08, 4)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.23,
        minor_radius=0.035,
        major_segments=24,
        minor_segments=8,
        location=(0, -0.275, 0.78),
        rotation=(1.57079632679, 0, 0),
    )
    ring = bpy.context.object
    ring.name = "prop_pipeline_marker_jade_ring"
    ring.data.materials.append(jade)

    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.12, location=(0, -0.30, 0.78))
    core = bpy.context.object
    core.name = "prop_pipeline_marker_jade_core"
    core.data.materials.append(jade)

    for obj in bpy.context.scene.objects:
        obj.select_set(obj.type == "MESH")
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output))
    print(f"created bootstrap source: {args.output}")


if __name__ == "__main__":
    main()
