class_name TrainingEnemy
extends CombatActor

enum CombatStyle {
	MELEE,
	RANGED,
	GUARDIAN,
}

enum AttackKind {
	NONE,
	MELEE,
	RANGED,
}

const PROJECTILE_SCENE := preload("res://src/combat/combat_projectile.tscn")

@export_group("AI")
@export_enum("近战", "远程", "筑基守阵") var combat_style: int = CombatStyle.MELEE
@export var move_speed: float = 2.8
@export var detection_range: float = 10.0
@export var melee_range: float = 1.65
@export var ranged_min_distance: float = 3.6
@export var ranged_max_distance: float = 7.0
@export var attack_windup: float = 0.62
@export var attack_cooldown: float = 1.35
@export var attack_multiplier: float = 1.0
@export var projectile_speed: float = 8.5
@export var arena_half_extent: float = 12.5

@export_group("Presentation")
@export var body_tint: Color = Color(0.76, 0.24, 0.22, 1.0)

@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _telegraph: MeshInstance3D = $Telegraph
@onready var _projectile_origin: Node3D = $ProjectileOrigin
@onready var _realm_label: Label3D = $RealmLabel

var ai_enabled: bool = true
var _target: CombatActor = null
var _attack_cooldown_left: float = 0.0
var _windup_left: float = 0.0
var _attack_kind: int = AttackKind.NONE
var _damage_flash_left: float = 0.0
var _unique_material: StandardMaterial3D = null


func _ready() -> void:
	super._ready()
	add_to_group("combat_enemies")
	add_to_group("combat_targets")
	_telegraph.visible = false
	_apply_unique_tint()
	damage_received.connect(_on_damage_received)
	realm_changed.connect(_on_realm_changed)
	_update_realm_label()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_update_damage_flash(delta)
	_acquire_target()

	if not ai_enabled or _target == null or _target.is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var offset: Vector3 = _target.global_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()

	if _windup_left > 0.0:
		velocity = Vector3.ZERO
		_windup_left = maxf(0.0, _windup_left - delta)
		_update_windup_visual()
		if _windup_left <= 0.0:
			_resolve_attack()
	else:
		match combat_style:
			CombatStyle.RANGED:
				_tick_ranged(offset, distance)
			CombatStyle.GUARDIAN:
				_tick_guardian(offset, distance)
			_:
				_tick_melee(offset, distance)

	move_and_slide()
	_clamp_to_arena()


func set_ai_enabled(enabled: bool) -> void:
	ai_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO
		_windup_left = 0.0
		_attack_kind = AttackKind.NONE
		_telegraph.visible = false
		_body_mesh.scale = Vector3.ONE


func _tick_melee(offset: Vector3, distance: float) -> void:
	if distance > detection_range:
		velocity = Vector3.ZERO
	elif distance > melee_range:
		_move_in_direction(offset.normalized())
	elif _attack_cooldown_left <= 0.0:
		_begin_attack(AttackKind.MELEE)
	else:
		velocity = Vector3.ZERO


func _tick_ranged(offset: Vector3, distance: float) -> void:
	if distance > detection_range:
		velocity = Vector3.ZERO
	elif distance > ranged_max_distance:
		_move_in_direction(offset.normalized())
	elif distance < ranged_min_distance:
		_move_in_direction(-offset.normalized())
	elif _attack_cooldown_left <= 0.0:
		_face_direction(offset.normalized())
		_begin_attack(AttackKind.RANGED)
	else:
		velocity = Vector3.ZERO


func _tick_guardian(offset: Vector3, distance: float) -> void:
	if distance > detection_range:
		velocity = Vector3.ZERO
	elif distance > ranged_max_distance:
		_move_in_direction(offset.normalized())
	elif distance <= melee_range + 0.25 and _attack_cooldown_left <= 0.0:
		_face_direction(offset.normalized())
		_begin_attack(AttackKind.MELEE)
	elif _attack_cooldown_left <= 0.0:
		_face_direction(offset.normalized())
		_begin_attack(AttackKind.RANGED)
	else:
		velocity = Vector3.ZERO


func _acquire_target() -> void:
	if is_instance_valid(_target) and not _target.is_dead:
		return

	for node in get_tree().get_nodes_in_group("player"):
		var candidate := node as CombatActor
		if candidate != null:
			_target = candidate
			return
	_target = null


func _move_in_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.001:
		velocity = Vector3.ZERO
		return
	var normalized: Vector3 = direction.normalized()
	velocity = normalized * move_speed
	_face_direction(normalized)


func _face_direction(direction: Vector3) -> void:
	rotation.y = atan2(-direction.x, -direction.z)


func _begin_attack(kind: int) -> void:
	velocity = Vector3.ZERO
	_attack_kind = kind
	_windup_left = attack_windup
	_telegraph.visible = true
	if kind == AttackKind.MELEE:
		_telegraph.scale = Vector3.ONE
	else:
		_telegraph.scale = Vector3(0.68, 1.0, 0.68)


func _resolve_attack() -> void:
	_body_mesh.scale = Vector3.ONE
	_telegraph.visible = false
	_attack_cooldown_left = attack_cooldown

	if _target == null or _target.is_dead:
		_attack_kind = AttackKind.NONE
		return

	if _attack_kind == AttackKind.RANGED:
		_spawn_projectile()
	elif _attack_kind == AttackKind.MELEE:
		var planar_distance: float = Vector2(
			_target.global_position.x - global_position.x,
			_target.global_position.z - global_position.z
		).length()
		if planar_distance <= melee_range + 0.45:
			_target.receive_attack(self, attack_multiplier)
	_attack_kind = AttackKind.NONE


func _spawn_projectile() -> void:
	if _target == null or _target.is_dead:
		return
	var direction: Vector3 = _target.global_position + Vector3(0.0, 0.75, 0.0) - _projectile_origin.global_position
	direction = direction.normalized()
	var projectile := PROJECTILE_SCENE.instantiate() as CombatProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _projectile_origin.global_position
	projectile.configure(self, direction, attack_multiplier, projectile_speed, body_tint)


func _update_windup_visual() -> void:
	var progress: float = 1.0 - (_windup_left / maxf(attack_windup, 0.001))
	var pulse: float = 1.0 + sin(progress * PI) * 0.12
	_body_mesh.scale = Vector3.ONE * pulse
	_telegraph.rotation.y += 0.09


func _apply_unique_tint() -> void:
	if _body_mesh.mesh == null or _body_mesh.mesh.get_surface_count() == 0:
		return
	var source_material: Material = _body_mesh.mesh.surface_get_material(0)
	if source_material is StandardMaterial3D:
		_unique_material = source_material.duplicate() as StandardMaterial3D
		_unique_material.albedo_color = body_tint
		_body_mesh.material_override = _unique_material


func _on_damage_received(_actor, _amount: float, _source) -> void:
	_damage_flash_left = 0.09
	if _unique_material != null:
		_unique_material.albedo_color = Color(0.95, 0.90, 0.78, 1.0)


func _update_damage_flash(delta: float) -> void:
	if _damage_flash_left <= 0.0:
		return
	_damage_flash_left = maxf(0.0, _damage_flash_left - delta)
	if _damage_flash_left <= 0.0 and _unique_material != null:
		_unique_material.albedo_color = body_tint


func _clamp_to_arena() -> void:
	global_position.x = clampf(global_position.x, -arena_half_extent, arena_half_extent)
	global_position.z = clampf(global_position.z, -arena_half_extent, arena_half_extent)


func _on_realm_changed(_actor) -> void:
	_update_realm_label()


func _update_realm_label() -> void:
	if is_instance_valid(_realm_label):
		_realm_label.text = "%s\n%s" % [actor_name, realm_label()]
