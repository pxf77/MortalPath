PYTHON ?= python3
BLENDER ?= blender
MANIFEST := art_pipeline/manifests/props/prop_pipeline_marker.json
SOURCE_BLEND := art_pipeline/work/source/prop_pipeline_marker.blend

.PHONY: preflight bootstrap export preview catalog pack clean

preflight:
	$(PYTHON) -m unittest discover -s art_pipeline/tests -v
	$(PYTHON) art_pipeline/tools/validate_manifest.py

bootstrap:
	mkdir -p art_pipeline/work/source
	$(BLENDER) --background \
		--python art_pipeline/source/bootstrap/prop_pipeline_marker.py \
		-- --output $(SOURCE_BLEND)

export: bootstrap
	$(BLENDER) --background $(SOURCE_BLEND) \
		--python art_pipeline/tools/blender/export_asset.py \
		-- --manifest $(MANIFEST)
	$(PYTHON) art_pipeline/tools/validate_manifest.py --check-runtime
	$(PYTHON) art_pipeline/tools/inspect_glb.py \
		--manifest $(MANIFEST) \
		--output art_pipeline/reports/assets/prop_pipeline_marker.json

preview: bootstrap
	$(BLENDER) --background $(SOURCE_BLEND) \
		--python art_pipeline/tools/blender/render_preview.py \
		-- --manifest $(MANIFEST)

catalog:
	$(PYTHON) art_pipeline/tools/build_catalog.py

pack: catalog
	$(PYTHON) art_pipeline/tools/build_art_pack.py

clean:
	rm -rf art_pipeline/work art_pipeline/runtime/* art_pipeline/reports/* art_pipeline/dist/*
	touch art_pipeline/runtime/.gitkeep art_pipeline/reports/.gitkeep art_pipeline/dist/.gitkeep
