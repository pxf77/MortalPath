class_name EnemyCombatVfxContract
extends RefCounted

const MANIFEST_ROOT := "res://assets/artpacks/enemy_combat_vfx_v0_7/manifests/vfx"

static var _contracts: Dictionary = {}
static var _load_errors: Dictionary = {}


static func load_contract(asset_id: StringName, force_reload: bool = false) -> Dictionary:
	if not force_reload and _contracts.has(asset_id):
		return _contracts[asset_id] as Dictionary
	_contracts.erase(asset_id)
	_load_errors.erase(asset_id)
	var path := "%s/%s.json" % [MANIFEST_ROOT, asset_id]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_load_errors[asset_id] = "cannot open enemy VFX manifest: %s" % path
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_load_errors[asset_id] = "enemy VFX manifest is not a JSON object: %s" % path
		return {}
	_contracts[asset_id] = parsed as Dictionary
	return _contracts[asset_id] as Dictionary


static func load_error(asset_id: StringName) -> String:
	load_contract(asset_id)
	return String(_load_errors.get(asset_id, ""))


static func version(asset_id: StringName) -> String:
	return String(_vfx(asset_id).get("version", ""))


static func purpose(asset_id: StringName) -> StringName:
	return StringName(String(_vfx(asset_id).get("purpose", "")))


static func role(asset_id: StringName) -> StringName:
	return StringName(String(_vfx(asset_id).get("role", "")))


static func logic_binding(asset_id: StringName) -> StringName:
	return StringName(String(_vfx(asset_id).get("logic_binding", "")))


static func presentation_nodes(asset_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var names = _vfx(asset_id).get("presentation_nodes", [])
	if not names is Array:
		return result
	for node_name in names:
		if node_name is String:
			result.append(StringName(node_name))
	return result


static func pulse_min(asset_id: StringName) -> float:
	return float(_pulse(asset_id).get("min", 1.0))


static func pulse_max(asset_id: StringName) -> float:
	return float(_pulse(asset_id).get("max", 1.0))


static func rotation_speed(asset_id: StringName) -> float:
	return float(_vfx(asset_id).get("rotation_degrees_per_second", 0.0))


static func duration(asset_id: StringName) -> float:
	return maxf(0.01, float(_vfx(asset_id).get("duration_seconds", 0.2)))


static func impact_scale_start(asset_id: StringName) -> float:
	return float(_impact_scale(asset_id).get("start", 1.0))


static func impact_scale_end(asset_id: StringName) -> float:
	return float(_impact_scale(asset_id).get("end", 1.0))


static func impact_rise(asset_id: StringName) -> float:
	return float(_vfx(asset_id).get("rise_m", 0.0))


static func _vfx(asset_id: StringName) -> Dictionary:
	var value = load_contract(asset_id).get("enemy_vfx_contract", {})
	return value as Dictionary if value is Dictionary else {}


static func _pulse(asset_id: StringName) -> Dictionary:
	var value = _vfx(asset_id).get("pulse_scale", {})
	return value as Dictionary if value is Dictionary else {}


static func _impact_scale(asset_id: StringName) -> Dictionary:
	var value = _vfx(asset_id).get("scale", {})
	return value as Dictionary if value is Dictionary else {}
