class_name PlayerController
extends CombatActor

signal combat_message(message: String)

@export_group("Movement")
@export var move_speed: float = 6.0
@export var dodge_speed: float = 13.0
@export var dodge_duration: float = 0.18
@export var dodge_cooldown: float = 0.65
@export var arena_half_extent: float = 12.5

@export_group("Attack")
@export var attack_range: float = 2.2
@export var attack_arc_degrees: float = 105.0
@export var attack_cooldown: float = 0.42
@export var attack_multiplier: float = 1.0

@onready var _attack_indicator: MeshInstance3D = $AttackIndicator
@onready var _realm_label: Label3D = $RealmLabel

var _facing := Vector3(0.0, 0.0, -1.0)
var _attack_cooldown_left: float = 0.0
var _attack_flash_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _dodge_time_left: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("player")
	_attack_indicator.visible = false
	realm_changed.connect(_on_realm_changed)
	_update_realm_label()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	_update_attack_flash(delta)

	if Input.is_action_just_pressed("debug_breakthrough"):
		_debug_breakthrough()

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
		_try_attack()

	move_and_slide()
	_clamp_to_arena()


func _try_attack() -> void:
	if _attack_cooldown_left > 0.0 or _dodge_time_left > 0.0:
		return

	_attack_cooldown_left = attack_cooldown
	_attack_flash_left = 0.11
	_attack_indicator.visible = true

	var target := _find_attack_target()
	if target == null:
		combat_message.emit("御剑斩击落空。")
		return

	var damage := target.receive_attack(self, attack_multiplier)
	var penetration := DamageRules.realm_penetration(major_realm, target.major_realm)
	combat_message.emit(
		"命中 %s，造成 %.1f 伤害；境界穿透 %.0f%%。"
		% [target.actor_name, damage, penetration * 100.0]
	)


func _find_attack_target() -> CombatActor:
	var best_target: CombatActor = null
	var best_distance := INF
	var minimum_dot := cos(deg_to_rad(attack_arc_degrees * 0.5))

	for node in get_tree().get_nodes_in_group("combat_enemies"):
		var enemy := node as CombatActor
		if enemy == null or enemy.is_dead:
			continue

		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > attack_range or distance <= 0.001:
			continue
		if _facing.dot(offset.normalized()) < minimum_dot:
			continue
		if distance < best_distance:
			best_target = enemy
			best_distance = distance

	return best_target


func _start_dodge(move_direction: Vector3) -> void:
	if move_direction.length_squared() > 0.001:
		_facing = move_direction.normalized()
		_face_direction(_facing)

	_dodge_time_left = dodge_duration
	_dodge_cooldown_left = dodge_cooldown
	invulnerable = true
	velocity = _facing * dodge_speed
	combat_message.emit("施展身法：闪避期间免疫伤害。")


func _debug_breakthrough() -> void:
	if major_realm >= RealmRules.MajorRealm.CORE_FORMATION:
		combat_message.emit("Combat Lab 的调试境界上限为结丹初期。")
		return

	breakthrough_to(major_realm + 1, 1)
	combat_message.emit("调试突破完成：当前境界为 %s。" % realm_label())


func _update_attack_flash(delta: float) -> void:
	if _attack_flash_left <= 0.0:
		return

	_attack_flash_left = maxf(0.0, _attack_flash_left - delta)
	if _attack_flash_left <= 0.0:
		_attack_indicator.visible = false


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
