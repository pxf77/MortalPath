"""Render a deterministic square review preview from the currently opened scene.

The preview uses Cycles on CPU so GitHub-hosted runners do not need EGL, a GPU,
or a virtual display server. This is slower than Workbench but reproducible and
appropriate for review thumbnails rather than final marketing renders.
"""
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


def add_area_light(
    scene: bpy.types.Scene,
    *,
    name: str,
    location: Vector,
    target: Vector,
    energy: float,
    size: float,
    color: tuple[float, float, float],
) -> None:
    light_data = bpy.data.lights.new(name=name, type="AREA")
    light_data.energy = energy
    light_data.shape = "DISK"
    light_data.size = size
    light_data.color = color
    light = bpy.data.objects.new(name, light_data)
    scene.collection.objects.link(light)
    light.location = location
    look_at(light, target)


def configure_world(scene: bpy.types.Scene) -> None:
    if scene.world is None:
        scene.world = bpy.data.worlds.new("review_world")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    if background is None:
        raise RuntimeError("review world has no Background shader")
    background.inputs["Color"].default_value = (0.055, 0.065, 0.060, 1.0)
    background.inputs["Strength"].default_value = 0.28


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    repo_root = args.manifest.resolve().parents[3]
    output_path = repo_root / manifest["preview"]["path"]
    output_path.parent.mkdir(parents=True, exist_ok=True)

    minimum, maximum = mesh_bounds()
    center = (minimum + maximum) * 0.5
    extent = maximum - minimum
    radius = max(extent.x, extent.y, extent.z) * 0.9

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(output_path)
    scene.render.film_transparent = False
    configure_world(scene)

    camera_data = bpy.data.cameras.new("review_camera")
    camera = bpy.data.objects.new("review_camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = center + Vector((radius * 2.8, -radius * 3.4, radius * 2.4))
    look_at(camera, center)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(1.8, max(extent.x, extent.z) * 1.65)
    scene.camera = camera

    add_area_light(
        scene,
        name="review_key",
        location=center + Vector((radius * 3.2, -radius * 3.0, radius * 4.0)),
        target=center,
        energy=900.0,
        size=max(2.5, radius * 2.0),
        color=(0.95, 0.88, 0.74),
    )
    add_area_light(
        scene,
        name="review_fill",
        location=center + Vector((-radius * 3.0, -radius * 1.5, radius * 2.0)),
        target=center,
        energy=420.0,
        size=max(2.0, radius * 1.7),
        color=(0.58, 0.72, 0.68),
    )
    add_area_light(
        scene,
        name="review_rim",
        location=center + Vector((radius * 0.5, radius * 3.5, radius * 3.0)),
        target=center,
        energy=650.0,
        size=max(1.8, radius * 1.4),
        color=(0.67, 0.75, 0.82),
    )

    bpy.ops.render.render(write_still=True)
    if not output_path.is_file() or output_path.stat().st_size == 0:
        raise RuntimeError(f"Blender did not render {output_path}")
    print(f"rendered preview: {output_path}")


if __name__ == "__main__":
    main()
