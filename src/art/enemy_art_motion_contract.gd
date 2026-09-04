class_name EnemyArtMotionContract
extends RefCounted

const MANIFEST_ROOT := "res://assets/artpacks/enemy_motion_v0_6/manifests/characters"

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
		_load_errors[asset_id] = "cannot open enemy motion manifest: %s" % path
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_load_errors[asset_id] = "enemy motion manifest is not a JSON object: %s" % path
		return {}
	_contracts[asset_id] = parsed as Dictionary
	return _contracts[asset_id] as Dictionary


static func load_error(asset_id: StringName) -> String:
	load_contract(asset_id)
	return String(_load_errors.get(asset_id, ""))


static func is_loaded(asset_id: StringName) -> bool:
	return not load_contract(asset_id).is_empty()


static func version(asset_id: StringName) -> String:
	return String(_motion(asset_id).get("version", ""))


static func role(asset_id: StringName) -> StringName:
	return StringName(String(_motion(asset_id).get("role", "")))


static func fps(asset_id: StringName) -> float:
	return maxf(1.0, float(_motion(asset_id).get("fps", 30.0)))


static func idle_clip(asset_id: StringName) -> StringName:
	return StringName(String(_motion(asset_id).get("idle_clip", "idle")))


static func locomotion_clip(asset_id: StringName) -> StringName:
	return StringName(String(_motion(asset_id).get("locomotion_clip", "locomotion")))


static func guard_clip(asset_id: StringName) -> StringName:
	return StringName(String(_motion(asset_id).get("guard_clip", "")))


static func death_clip(asset_id: StringName) -> StringName:
	return StringName(String(_motion(asset_id).get("death_clip", "death")))


static func blend_seconds(asset_id: StringName) -> float:
	return clampf(float(_motion(asset_id).get("blend_seconds", 0.08)), 0.0, 0.25)


static func heavy_hit_ratio(asset_id: StringName) -> float:
	return clampf(float(_motion(asset_id).get("heavy_health_ratio", 0.18)), 0.0, 1.0)


static func attack_clip(asset_id: StringName, attack_kind: StringName) -> StringName:
	var rule := _action_rule(asset_id, attack_kind)
	return StringName(String(rule.get("clip", "")))


static func attack_release_time_seconds(
	asset_id: StringName,
	attack_kind: StringName
) -> float:
	var rule := _action_rule(asset_id, attack_kind)
	if rule.is_empty():
		return 0.0
	var release_frame := maxi(1, int(rule.get("release_frame", 1)))
	return float(release_frame - 1) / fps(asset_id)


static func attack_playback_speed(
	asset_id: StringName,
	attack_kind: StringName,
	logic_windup_seconds: float
) -> float:
	if logic_windup_seconds <= 0.001:
		return 1.0
	var release_seconds := attack_release_time_seconds(asset_id, attack_kind)
	if release_seconds <= 0.001:
		return 1.0
	return clampf(release_seconds / logic_windup_seconds, 0.35, 2.5)


static func hit_clip(
	asset_id: StringName,
	weight: StringName,
	direction: StringName
) -> StringName:
	var hits = _motion(asset_id).get("hit_reactions", {})
	if not hits is Dictionary:
		return StringName("hit_%s" % weight)
	var weight_rules = (hits as Dictionary).get(String(weight), {})
	if not weight_rules is Dictionary:
		return StringName("hit_%s" % weight)
	return StringName(String(
		(weight_rules as Dictionary).get(
			String(direction),
			"hit_%s_%s" % [weight, direction]
		)
	))


static func required_clips(asset_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var animation = load_contract(asset_id).get("animation_contract", {})
	if not animation is Dictionary:
		return result
	var clips = (animation as Dictionary).get("required_clips", [])
	if not clips is Array:
		return result
	for clip in clips:
		if clip is String:
			result.append(StringName(clip))
	return result


static func _action_rule(
	asset_id: StringName,
	attack_kind: StringName
) -> Dictionary:
	var actions = _motion(asset_id).get("actions", {})
	if not actions is Dictionary:
		return {}
	var rule = (actions as Dictionary).get(String(attack_kind), {})
	return rule as Dictionary if rule is Dictionary else {}


static func _motion(asset_id: StringName) -> Dictionary:
	var value = load_contract(asset_id).get("enemy_motion_contract", {})
	return value as Dictionary if value is Dictionary else {}
