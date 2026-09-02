class_name PlayerController
extends CombatActor

signal combat_message(message: String)
signal spirit_changed(current_spirit: float, max_spirit: float)

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


func _ready() -> void:
	super._ready()
	add_to_group("player")
	_attack_indicator.visible = false
	_sword_art_indicator.visible = false
	_guard_visual.visible = false
	current_spirit = max_spirit
	realm_changed.connect(_on_realm_changed)
	_update_realm_label()
	spirit_changed.emit(current_spirit, max_spirit)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)
	_regenerate_spirit(delta)
	_update_visuals(delta)

	if not input_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if _dodge_time_left > 0.0:
		_dodge_time_left = maxf(0.0, _dodge_time_left - delta)
		velocity = _facing * dodge_speed
		if _dodge_time_left <= 0.0:
			invulnerable = false
		move_and_slide()
		_clamp_to_arena()
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y)

	if move_direction.length_squared() > 0.001:
		move_direction = move_direction.normalized()
		_facing = move_direction
		_face_direction(_facing)
		velocity = move_direction * move_speed
	else:
		velocity = Vector3.ZERO

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_left <= 0.0:
		_start_dodge(move_direction)

	if Input.is_action_just_pressed("attack"):
		_request_combo_attack()

	if Input.is_action_just_pressed("sword_art"):
		_try_sword_art()

	if Input.is_action_just_pressed("spirit_guard"):
		_try_spirit_guard()

	if _attack_buffered and _attack_cooldown_left <= 0.0 and _combo_window_left > 0.0:
		_attack_buffered = false
		_perform_combo_attack()

	move_and_slide()
	_clamp_to_arena()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO
		_attack_buffered = false


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
	_combo_step = (_combo_step % 3) + 1
	_attack_cooldown_left = DemoRules.combo_cooldown(_combo_step)
	_combo_window_left = combo_window
	_attack_visual_left = 0.12
	_attack_indicator.visible = true
	_attack_indicator.scale = Vector3.ONE * (0.92 + float(_combo_step) * 0.08)

	var hit_all := _combo_step == 3
	var targets := _find_targets(attack_range, attack_arc_degrees, hit_all)
	var multiplier := DemoRules.combo_multiplier(_combo_step)

	if targets.is_empty():
		combat_message.emit("御剑第 %d 式落空。" % _combo_step)
	else:
		var total_damage := 0.0
		for target in targets:
			total_damage += target.receive_attack(self, multiplier)
		combat_message.emit(
			"御剑第 %d 式命中 %d 个目标，造成 %.1f 总伤害。"
			% [_combo_step, targets.size(), total_damage]
		)

	if _combo_step == 3:
		_restore_spirit(third_hit_spirit_restore)


func _try_sword_art() -> void:
	if _dodge_time_left > 0.0 or _sword_art_cooldown_left > 0.0:
		return
	if not _spend_spirit(sword_art_cost):
		combat_message.emit("灵力不足，无法施展青锋剑诀。")
		return

	_sword_art_cooldown_left = sword_art_cooldown
	_sword_art_visual_left = 0.18
	_sword_art_indicator.visible = true
	var targets := _find_targets(sword_art_range, sword_art_arc_degrees, true)
	var total_damage := 0.0
	for target in targets:
		total_damage += target.receive_attack(self, sword_art_multiplier)

	if targets.is_empty():
		combat_message.emit("青锋剑诀掠过山谷，未能锁定目标。")
	else:
		combat_message.emit(
			"青锋剑诀贯穿 %d 个目标，造成 %.1f 总伤害。"
			% [targets.size(), total_damage]
		)


func _try_spirit_guard() -> void:
	if _guard_time_left > 0.0 or _guard_cooldown_left > 0.0:
		return
	if not _spend_spirit(guard_cost):
		combat_message.emit("灵力不足，无法凝聚护体灵光。")
		return

	_guard_time_left = guard_duration
	_guard_cooldown_left = guard_cooldown
	set_incoming_damage_multiplier(guard_incoming_multiplier)
	_guard_visual.visible = true
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
	if move_direction.length_squared() > 0.001:
		_facing = move_direction.normalized()
		_face_direction(_facing)

	_dodge_time_left = dodge_duration
	_dodge_cooldown_left = dodge_cooldown
	invulnerable = true
	velocity = _facing * dodge_speed
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


func _clamp_to_arena() -> void:
	global_position.x = clampf(global_position.x, -arena_half_extent, arena_half_extent)
	global_position.z = clampf(global_position.z, -arena_half_extent, arena_half_extent)


func _on_realm_changed(_actor) -> void:
	_update_realm_label()


func _update_realm_label() -> void:
	if is_instance_valid(_realm_label):
		_realm_label.text = "%s\n%s" % [actor_name, realm_label()]
