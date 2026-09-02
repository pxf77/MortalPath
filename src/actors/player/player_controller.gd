class_name PlayerController
extends CombatActor

signal combat_message(message: String)
signal spirit_changed(current_spirit: float, max_spirit: float)
signal action_started(action: StringName, combo_step: int)
signal action_released(action: StringName, combo_step: int)
signal attack_finished(action: StringName, combo_step: int, hit_count: int)

@export_group("Movement")
@export var move_speed: float = 6.2
@export var dodge_speed: float = 13.5
@export var dodge_duration: float = 0.20
@export var dodge_cooldown: float = 0.70
@export var arena_half_extent: float = 12.5

@export_group("Basic Attack")
@export var attack_range: float = 2.45
@export var attack_arc_degrees: float = 112.0
@export var combo_window: float = 0.72
@export var third_hit_spirit_restore: float = 9.0

@export_group("Spirit")
@export var max_spirit: float = 100.0
@export var spirit_regeneration_per_second: float = 10.0

@export_group("Sword Art")
@export var sword_art_cost: float = 30.0
@export var sword_art_cooldown: float = 2.1
@export var sword_art_range: float = 7.4
@export var sword_art_arc_degrees: float = 34.0
@export var sword_art_multiplier: float = 2.15

@export_group("Spirit Guard")
@export var guard_cost: float = 25.0
@export var guard_duration: float = 2.5
@export var guard_cooldown: float = 5.0
@export var guard_incoming_multiplier: float = 0.45

@onready var _attack_indicator: MeshInstance3D = $AttackIndicator
@onready var _sword_art_indicator: MeshInstance3D = $SwordArtIndicator
@onready var _guard_visual: MeshInstance3D = $GuardVisual
@onready var _realm_label: Label3D = $RealmLabel

var current_spirit: float = 100.0
var input_enabled: bool = true

var _facing := Vector3(0.0, 0.0, -1.0)
var _attack_cooldown_left: float = 0.0
var _combo_window_left: float = 0.0
var _combo_step: int = 0
var _attack_buffered: bool = false
var _attack_visual_left: float = 0.0
var _sword_art_cooldown_left: float = 0.0
var _sword_art_visual_left: float = 0.0
var _guard_cooldown_left: float = 0.0
var _guard_time_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _dodge_time_left: float = 0.0
var _pending_attack: StringName = &""
var _windup_left: float = 0.0
var _queued_actions: Dictionary = {}
const INPUT_BUFFER_SECONDS := 0.24


func _ready() -> void:
	super._ready()
	add_to_group("player")
	_attack_indicator.visible = false
	_sword_art_indicator.visible = false
	_guard_visual.visible = false
	_configure_attack_sector(_attack_indicator, attack_range, attack_arc_degrees)
	_configure_attack_sector(_sword_art_indicator, sword_art_range, sword_art_arc_degrees)
	current_spirit = max_spirit
	realm_changed.connect(_on_realm_changed)
	_update_realm_label()
	spirit_changed.emit(current_spirit, max_spirit)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	for action in _queued_actions.keys():
		_queued_actions[action] -= delta
		if _queued_actions[action] <= 0.0:
			_queued_actions.erase(action)
	if advance_hit_pause(delta):
		return

	_update_timers(delta)
	_regenerate_spirit(delta)
	_update_visuals(delta)

	if not input_enabled:
		velocity = Vector3.ZERO
		return

	if _dodge_cooldown_left <= 0.0 and _consume_action(&"dodge"):
		var dodge_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_start_dodge(_screen_move_direction(dodge_input))
	if _guard_cooldown_left <= 0.0 and _consume_action(&"spirit_guard"):
		_try_spirit_guard()

	if _dodge_time_left > 0.0:
		_dodge_time_left = maxf(0.0, _dodge_time_left - delta)
		velocity = _facing * dodge_speed
		if _dodge_time_left <= 0.0:
			invulnerable = false
		move_with_impact(delta)
		_clamp_to_arena()
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_direction := _screen_move_direction(input_vector)

	if move_direction.length_squared() > 0.001:
		move_direction = move_direction.normalized()
		if _pending_attack == &"":
			_facing = move_direction
			_face_direction(_facing)
		velocity = move_direction * move_speed
	else:
		velocity = Vector3.ZERO

	_update_attack_windup(delta)
	if _pending_attack == &"" and _consume_action(&"attack"):
		_request_combo_attack()

	if _pending_attack == &"" and _attack_cooldown_left <= 0.0 and _consume_action(&"sword_art"):
		_try_sword_art()

	if _attack_buffered and _pending_attack == &"" and _attack_cooldown_left <= 0.0 and _combo_window_left > 0.0:
		_attack_buffered = false
		_perform_combo_attack()

	move_with_impact(delta)
	_clamp_to_arena()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or is_dead or event.is_echo():
		return
	for action in [&"attack", &"sword_art", &"spirit_guard", &"dodge"]:
		if event.is_action_pressed(action):
			_queued_actions[action] = INPUT_BUFFER_SECONDS
			get_viewport().set_input_as_handled()
			return


func _consume_action(action: StringName) -> bool:
	if not _queued_actions.has(action):
		return false
	_queued_actions.erase(action)
	return true


func _screen_move_direction(input_vector: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y)
	var right := camera.global_basis.x
	var down := camera.global_basis.z
	right.y = 0.0
	down.y = 0.0
	return right.normalized() * input_vector.x + down.normalized() * input_vector.y


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO
		_attack_buffered = false
		_queued_actions.clear()
		_cancel_attack()
		_dodge_time_left = 0.0
		invulnerable = false
		clear_impact_motion()


func recover_between_phases() -> void:
	restore_health(max_health * 0.35)
	_restore_spirit(45.0)
	combat_message.emit("短暂调息：恢复部分气血与灵力。")


func sword_art_cooldown_left() -> float:
	return _sword_art_cooldown_left


func guard_cooldown_left() -> float:
	return _guard_cooldown_left


func dodge_cooldown_left() -> float:
	return _dodge_cooldown_left


func is_guard_active() -> bool:
	return _guard_time_left > 0.0


func _request_combo_attack() -> void:
	if _dodge_time_left > 0.0:
		return
	if _attack_cooldown_left <= 0.0:
		_perform_combo_attack()
	elif _combo_window_left > 0.0:
		_attack_buffered = true


func _perform_combo_attack() -> void:
	if is_dead or not input_enabled or _pending_attack != &"":
		return
	_combo_step = (_combo_step % 3) + 1
	_attack_buffered = false
	_attack_cooldown_left = DemoRules.combo_cooldown(_combo_step)
	_combo_window_left = combo_window
	_pending_attack = &"attack"
	_windup_left = 0.06 + float(_combo_step) * 0.025
	_attack_visual_left = _windup_left + 0.12
	_attack_indicator.visible = true
	_attack_indicator.scale = Vector3.ONE
	action_started.emit(&"attack", _combo_step)


func _resolve_combo_attack() -> void:

	var hit_all := _combo_step == 3
	var targets := _find_targets(attack_range, attack_arc_degrees, hit_all)
	var multiplier := DemoRules.combo_multiplier(_combo_step)
	var hit_count := 0

	if targets.is_empty():
		combat_message.emit("御剑第 %d 式落空。" % _combo_step)
	else:
		var total_damage := 0.0
		for target in targets:
			var damage := target.receive_attack(self, multiplier)
			total_damage += damage
			if damage > 0.0:
				hit_count += 1
		combat_message.emit(
			"御剑第 %d 式命中 %d 个目标，造成 %.1f 总伤害。"
			% [_combo_step, targets.size(), total_damage]
		)

	if _combo_step == 3 and hit_count > 0:
		_restore_spirit(third_hit_spirit_restore)
	attack_finished.emit(&"attack", _combo_step, hit_count)


func _try_sword_art() -> void:
	if is_dead or not input_enabled or _pending_attack != &"" or _dodge_time_left > 0.0 or _sword_art_cooldown_left > 0.0:
		return
	if not _spend_spirit(sword_art_cost):
		combat_message.emit("灵力不足，无法施展青锋剑诀。")
		return

	_sword_art_cooldown_left = sword_art_cooldown
	_pending_attack = &"sword_art"
	_windup_left = 0.16
	_sword_art_visual_left = _windup_left + 0.18
	_sword_art_indicator.visible = true
	action_started.emit(&"sword_art", 0)


func _resolve_sword_art() -> void:
	var targets := _find_targets(sword_art_range, sword_art_arc_degrees, true)
	var total_damage := 0.0
	var hit_count := 0
	for target in targets:
		var damage := target.receive_attack(self, sword_art_multiplier)
		total_damage += damage
		if damage > 0.0:
			hit_count += 1

	if targets.is_empty():
		combat_message.emit("青锋剑诀掠过山谷，未能锁定目标。")
	else:
		combat_message.emit(
			"青锋剑诀贯穿 %d 个目标，造成 %.1f 总伤害。"
			% [targets.size(), total_damage]
		)
	attack_finished.emit(&"sword_art", 0, hit_count)


func _update_attack_windup(delta: float) -> void:
	if _pending_attack == &"":
		return
	_windup_left = maxf(0.0, _windup_left - delta)
	if _windup_left > 0.0:
		return
	var action := _pending_attack
	_pending_attack = &""
	action_released.emit(action, _combo_step if action == &"attack" else 0)
	if action == &"attack":
		_resolve_combo_attack()
	else:
		_resolve_sword_art()


func _cancel_attack() -> void:
	_pending_attack = &""
	_windup_left = 0.0
	_attack_visual_left = 0.0
	_sword_art_visual_left = 0.0
	_attack_indicator.visible = false
	_sword_art_indicator.visible = false


func _try_spirit_guard() -> void:
	if is_dead or not input_enabled or _guard_time_left > 0.0 or _guard_cooldown_left > 0.0:
		return
	if not _spend_spirit(guard_cost):
		combat_message.emit("灵力不足，无法凝聚护体灵光。")
		return

	_guard_time_left = guard_duration
	_guard_cooldown_left = guard_cooldown
	set_incoming_damage_multiplier(guard_incoming_multiplier)
	_guard_visual.visible = true
	action_started.emit(&"guard_cast", 0)
	combat_message.emit("护体灵光展开：所受伤害暂时降低。")


func _end_spirit_guard() -> void:
	_guard_time_left = 0.0
	set_incoming_damage_multiplier(1.0)
	_guard_visual.visible = false
	combat_message.emit("护体灵光消散。")


func _find_targets(max_range: float, arc_degrees: float, hit_all: bool) -> Array[CombatActor]:
	var matches: Array[CombatActor] = []
	var best_target: CombatActor = null
	var best_distance := INF
	var minimum_dot := cos(deg_to_rad(arc_degrees * 0.5))

	for node in get_tree().get_nodes_in_group("combat_targets"):
		var target := node as CombatActor
		if target == null or not target.can_be_targeted():
			continue

		var offset := target.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > max_range or distance <= 0.001:
			continue
		if _facing.dot(offset.normalized()) < minimum_dot:
			continue

		if hit_all:
			matches.append(target)
		elif distance < best_distance:
			best_target = target
			best_distance = distance

	if not hit_all and best_target != null:
		matches.append(best_target)
	return matches


func _start_dodge(move_direction: Vector3) -> void:
	_cancel_attack()
	_attack_buffered = false
	if move_direction.length_squared() > 0.001:
		_facing = move_direction.normalized()
		_face_direction(_facing)

	_dodge_time_left = dodge_duration
	_dodge_cooldown_left = dodge_cooldown
	invulnerable = true
	velocity = _facing * dodge_speed
	action_started.emit(&"dodge", 0)
	combat_message.emit("施展身法：短暂避开来袭术法。")


func _update_timers(delta: float) -> void:
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_sword_art_cooldown_left = maxf(0.0, _sword_art_cooldown_left - delta)
	_guard_cooldown_left = maxf(0.0, _guard_cooldown_left - delta)
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)

	if _combo_window_left > 0.0:
		_combo_window_left = maxf(0.0, _combo_window_left - delta)
		if _combo_window_left <= 0.0:
			_combo_step = 0
			_attack_buffered = false

	if _guard_time_left > 0.0:
		_guard_time_left = maxf(0.0, _guard_time_left - delta)
		if _guard_time_left <= 0.0:
			_end_spirit_guard()


func _regenerate_spirit(delta: float) -> void:
	if current_spirit >= max_spirit:
		return
	_restore_spirit(spirit_regeneration_per_second * delta)


func _spend_spirit(cost: float) -> bool:
	if not DemoRules.can_spend_spirit(current_spirit, cost):
		return false
	current_spirit = DemoRules.spirit_after_spend(current_spirit, cost)
	spirit_changed.emit(current_spirit, max_spirit)
	return true


func _restore_spirit(amount: float) -> void:
	if amount <= 0.0:
		return
	var previous := current_spirit
	current_spirit = minf(max_spirit, current_spirit + amount)
	if not is_equal_approx(previous, current_spirit):
		spirit_changed.emit(current_spirit, max_spirit)


func _update_visuals(delta: float) -> void:
	for indicator in [_attack_indicator, _sword_art_indicator]:
		var material := indicator.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color.a = 0.13 if _pending_attack != &"" else 0.32
	if _attack_visual_left > 0.0:
		_attack_visual_left = maxf(0.0, _attack_visual_left - delta)
		if _attack_visual_left <= 0.0:
			_attack_indicator.visible = false

	if _sword_art_visual_left > 0.0:
		_sword_art_visual_left = maxf(0.0, _sword_art_visual_left - delta)
		if _sword_art_visual_left <= 0.0:
			_sword_art_indicator.visible = false

	if _guard_visual.visible:
		_guard_visual.rotation.y += delta * 1.7
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.05
		_guard_visual.scale = Vector3.ONE * pulse


func _face_direction(direction: Vector3) -> void:
	rotation.y = atan2(-direction.x, -direction.z)


func _configure_attack_sector(indicator: MeshInstance3D, radius: float, arc: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# The floor preview uses the exact same cone as _find_targets, including range.
	var material := indicator.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	indicator.material_override = material
	var vertices := PackedVector3Array()
	for segment in range(24):
		var first := deg_to_rad(-arc * 0.5 + arc * float(segment) / 24.0)
		var second := deg_to_rad(-arc * 0.5 + arc * float(segment + 1) / 24.0)
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(sin(first), 0.0, -cos(first)) * radius)
		vertices.append(Vector3(sin(second), 0.0, -cos(second)) * radius)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	indicator.mesh = mesh
	indicator.position.z = 0.0


func _clamp_to_arena() -> void:
	global_position.x = clampf(global_position.x, -arena_half_extent, arena_half_extent)
	global_position.z = clampf(global_position.z, -arena_half_extent, arena_half_extent)


func _on_realm_changed(_actor) -> void:
	_update_realm_label()


func _update_realm_label() -> void:
	if is_instance_valid(_realm_label):
		_realm_label.text = "%s\n%s" % [actor_name, realm_label()]
