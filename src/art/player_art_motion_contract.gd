class_name PlayerArtMotionContract
extends RefCounted

const MANIFEST_PATH := "res://assets/artpacks/player_motion_v0_5/manifests/characters/chr_player_qi_refining_refined_v0_5.json"

static var _contract: Dictionary = {}
static var _load_error := ""


static func load_contract(force_reload: bool = false) -> Dictionary:
	if not force_reload and not _contract.is_empty():
		return _contract
	_contract = {}
	_load_error = ""
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_load_error = "cannot open player motion manifest: %s" % MANIFEST_PATH
		return _contract
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_load_error = "player motion manifest is not a JSON object"
		return _contract
	_contract = parsed as Dictionary
	return _contract


static func load_error() -> String:
	load_contract()
	return _load_error


static func is_loaded() -> bool:
	return not load_contract().is_empty()


static func version() -> String:
	var motion := _motion_contract()
	return String(motion.get("version", ""))


static func fps() -> float:
	var motion := _motion_contract()
	return float(motion.get("fps", 30.0))


static func idle_clip() -> StringName:
	var motion := _motion_contract()
	return StringName(String(motion.get("idle_clip", "idle")))


static func locomotion_clip() -> StringName:
	var motion := _motion_contract()
	return StringName(String(motion.get("locomotion_clip", "locomotion_8_direction")))


static func locomotion_clip_for_screen_vector(direction: Vector2) -> StringName:
	if direction.length_squared() <= 0.0001:
		return idle_clip()
	var normalized := direction.normalized()
	var best_clip := locomotion_clip()
	var best_dot := -INF
	for value in _locomotion_directions().values():
		if not value is Dictionary:
			continue
		var rule := value as Dictionary
		var point = rule.get("blend_position", [])
		if not point is Array or (point as Array).size() != 2:
			continue
		var candidate := Vector2(float(point[0]), float(point[1])).normalized()
		var score := normalized.dot(candidate)
		if score > best_dot:
			best_dot = score
			best_clip = StringName(String(rule.get("clip", best_clip)))
	return best_clip


static func locomotion_start_clip() -> StringName:
	return StringName(String(_locomotion_contract().get("start_clip", "locomotion_start")))


static func locomotion_stop_clip() -> StringName:
	return StringName(String(_locomotion_contract().get("stop_clip", "locomotion_stop")))


static func locomotion_turn_clip() -> StringName:
	return StringName(String(_locomotion_contract().get("turn_clip", "turn_180")))


static func locomotion_blend_seconds() -> float:
	return maxf(0.0, float(_locomotion_contract().get("blend_seconds", 0.10)))


static func locomotion_turn_threshold_dot() -> float:
	return clampf(float(_locomotion_contract().get("turn_threshold_dot", -0.45)), -1.0, 1.0)


static func sword_root_node() -> StringName:
	var motion := _motion_contract()
	return StringName(String(motion.get("sword_root_node", "presentation_flying_sword")))


static func sword_tip_node() -> StringName:
	var motion := _motion_contract()
	return StringName(String(motion.get("sword_tip_node", "presentation_flying_sword_tip")))


static func heavy_hit_ratio() -> float:
	return clampf(float(_hit_reaction_contract().get("heavy_health_ratio", 0.18)), 0.0, 1.0)


static func hit_clip(weight: StringName, direction: StringName) -> StringName:
	var weight_rules = _hit_reaction_contract().get(String(weight), {})
	if not weight_rules is Dictionary:
		return StringName("hit_%s" % weight)
	return StringName(String((weight_rules as Dictionary).get(String(direction), "hit_%s" % weight)))


static func death_clip() -> StringName:
	return StringName(String(_death_contract().get("clip", "death")))


static func death_sword_height_max_m() -> float:
	return float(_death_contract().get("runtime_sword_height_max_m", 0.25))


static func clip_for_action(action: StringName, combo_step: int = 0) -> StringName:
	match action:
		&"attack":
			return StringName("attack_light_%d" % clampi(combo_step, 1, 3))
		&"sword_art":
			return &"cast_sword_art"
		&"guard_cast":
			return &"cast_guard"
		&"dodge":
			return &"dodge"
	return &""


static func rule_for_action(action: StringName, combo_step: int = 0) -> Dictionary:
	var clip := clip_for_action(action, combo_step)
	if clip == &"":
		return {}
	var actions := _actions()
	var value = actions.get(String(clip), {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func release_time_seconds(action: StringName, combo_step: int = 0) -> float:
	var rule := rule_for_action(action, combo_step)
	if rule.is_empty():
		return 0.0
	var release_frame := maxi(1, int(rule.get("release_frame", 1)))
	return float(release_frame - 1) / maxf(fps(), 1.0)


static func playback_speed_for(
	action: StringName,
	combo_step: int,
	logic_windup_seconds: float
) -> float:
	if logic_windup_seconds <= 0.001:
		return 1.0
	var release_seconds := release_time_seconds(action, combo_step)
	if release_seconds <= 0.001:
		return 1.0
	return clampf(release_seconds / logic_windup_seconds, 0.35, 2.5)


static func required_clips() -> Array[StringName]:
	var result: Array[StringName] = []
	var animation = load_contract().get("animation_contract", {})
	if not animation is Dictionary:
		return result
	var clips = (animation as Dictionary).get("required_clips", [])
	if not clips is Array:
		return result
	for clip in clips:
		if clip is String:
			result.append(StringName(clip))
	return result


static func _motion_contract() -> Dictionary:
	var value = load_contract().get("motion_contract", {})
	if value is Dictionary:
		return value as Dictionary
	return {}


static func _locomotion_contract() -> Dictionary:
	var value = load_contract().get("locomotion_contract", {})
	if value is Dictionary:
		return value as Dictionary
	return {}


static func _locomotion_directions() -> Dictionary:
	var value = _locomotion_contract().get("directions", {})
	if value is Dictionary:
		return value as Dictionary
	return {}


static func _hit_reaction_contract() -> Dictionary:
	var value = load_contract().get("hit_reaction_contract", {})
	if value is Dictionary:
		return value as Dictionary
	return {}


static func _death_contract() -> Dictionary:
	var value = load_contract().get("death_contract", {})
	if value is Dictionary:
		return value as Dictionary
	return {}


static func _actions() -> Dictionary:
	var value = _motion_contract().get("actions", {})
	if value is Dictionary:
		return value as Dictionary
	return {}
