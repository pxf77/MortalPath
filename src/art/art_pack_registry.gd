class_name ArtPackRegistry
extends RefCounted

const PACK_VERSION := "artpack-v0.2.0-qinglan-valley"
const PACK_ROOT := "res://assets/artpacks/qinglan_v0_2/runtime"

const ASSET_PATHS: Dictionary = {
	&"chr_player_qi_refining_a": PACK_ROOT + "/characters/chr_player_qi_refining_a.glb",
	&"chr_enemy_melee_qi_a": PACK_ROOT + "/characters/chr_enemy_melee_qi_a.glb",
	&"chr_enemy_talisman_qi_a": PACK_ROOT + "/characters/chr_enemy_talisman_qi_a.glb",
	&"chr_guardian_foundation_a": PACK_ROOT + "/characters/chr_guardian_foundation_a.glb",
	&"env_qinglan_path_set_a": PACK_ROOT + "/environments/env_qinglan_path_set_a.glb",
	&"env_qinglan_cliff_set_a": PACK_ROOT + "/environments/env_qinglan_cliff_set_a.glb",
	&"env_qinglan_bamboo_set_a": PACK_ROOT + "/environments/env_qinglan_bamboo_set_a.glb",
	&"prop_formation_anchor_qinglan_a": PACK_ROOT + "/props/prop_formation_anchor_qinglan_a.glb",
	&"prop_escape_portal_qinglan_a": PACK_ROOT + "/props/prop_escape_portal_qinglan_a.glb",
	&"wpn_flying_sword_qi_a": PACK_ROOT + "/weapons/wpn_flying_sword_qi_a.glb",
	&"vfx_sword_arc_qi_a": PACK_ROOT + "/vfx/vfx_sword_arc_qi_a.glb",
	&"vfx_qingfeng_blade_a": PACK_ROOT + "/vfx/vfx_qingfeng_blade_a.glb",
	&"vfx_guard_ripple_a": PACK_ROOT + "/vfx/vfx_guard_ripple_a.glb",
}

static var _scene_cache: Dictionary = {}


static func asset_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in ASSET_PATHS.keys():
		result.append(key as StringName)
	result.sort()
	return result


static func path_for(asset_id: StringName) -> String:
	return String(ASSET_PATHS.get(asset_id, ""))


static func has_asset(asset_id: StringName) -> bool:
	var path := path_for(asset_id)
	return not path.is_empty() and ResourceLoader.exists(path, "PackedScene")


static func load_scene(asset_id: StringName) -> PackedScene:
	if _scene_cache.has(asset_id):
		return _scene_cache[asset_id] as PackedScene
	var path := path_for(asset_id)
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return null
	var scene := load(path) as PackedScene
	if scene != null:
		_scene_cache[asset_id] = scene
	return scene


static func instantiate_asset(asset_id: StringName, node_name: String = "ArtVisual") -> Node3D:
	var scene := load_scene(asset_id)
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return null
	instance.name = node_name
	instance.set_meta("art_pack_version", PACK_VERSION)
	instance.set_meta("art_asset_id", String(asset_id))
	return instance


static func attach_asset(
	parent: Node3D,
	asset_id: StringName,
	node_name: String = "ArtVisual",
	local_transform: Transform3D = Transform3D.IDENTITY
) -> Node3D:
	var instance := instantiate_asset(asset_id, node_name)
	if instance == null:
		return null
	parent.add_child(instance)
	instance.transform = local_transform
	return instance


static func mesh_count(root: Node) -> int:
	var count := 1 if root is MeshInstance3D else 0
	for child in root.get_children():
		count += ArtPackRegistry.mesh_count(child)
	return count
