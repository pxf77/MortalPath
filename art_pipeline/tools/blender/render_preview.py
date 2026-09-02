"""Render a deterministic square review preview from the currently opened scene."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    return parser.parse_args(argv)


def look_at(object_: bpy.types.Object, target: Vector) -> None:
    direction = target - object_.location
    object_.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def mesh_bounds() -> tuple[Vector, Vector]:
    points: list[Vector] = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        raise RuntimeError("scene contains no mesh bounds")
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return minimum, maximum


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    repo_root = args.manifest.resolve().parents[3]
    output_path = repo_root / manifest["preview"]["path"]
    output_path.parent.mkdir(parents=True, exist_ok=True)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output_path)
    scene.render.film_transparent = False
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "WORLD"
    scene.display.shading.curvature_ridge_factor = 1.4
    scene.display.shading.curvature_valley_factor = 1.1
    scene.world.color = (0.055, 0.065, 0.06)

    minimum, maximum = mesh_bounds()
    center = (minimum + maximum) * 0.5
    extent = maximum - minimum
    radius = max(extent.x, extent.y, extent.z) * 0.9

    camera_data = bpy.data.cameras.new("review_camera")
    camera = bpy.data.objects.new("review_camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = center + Vector((radius * 2.8, -radius * 3.4, radius * 2.4))
    look_at(camera, center)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(1.8, max(extent.x, extent.z) * 1.65)
    scene.camera = camera

    bpy.ops.render.render(write_still=True)
    if not output_path.is_file() or output_path.stat().st_size == 0:
        raise RuntimeError(f"Blender did not render {output_path}")
    print(f"rendered preview: {output_path}")


if __name__ == "__main__":
    main()
