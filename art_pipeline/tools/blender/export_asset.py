"""Export the currently opened Blender scene according to one asset manifest."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    repo_root = args.manifest.resolve().parents[3]
    output_path = repo_root / manifest["runtime"]["path"]
    output_path.parent.mkdir(parents=True, exist_ok=True)

    mesh_count = 0
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
        if obj.type != "MESH":
            continue
        mesh_count += 1
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        obj.select_set(False)

    if mesh_count == 0:
        raise RuntimeError("scene contains no mesh objects")

    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=False,
        export_animations=True,
    )
    if not output_path.is_file() or output_path.stat().st_size == 0:
        raise RuntimeError(f"Blender did not create {output_path}")
    print(f"exported {manifest['id']} to {output_path}")


if __name__ == "__main__":
    main()
