class_name TrainingEnemy
extends CombatActor

@export_group("AI")
@export var move_speed: float = 2.8
@export var detection_range: float = 7.0
@export var attack_range: float = 1.55
@export var attack_windup: float = 0.55
@export var attack_cooldown: float = 1.20
@export var attack_multiplier: float = 1.05
@export var arena_half_extent: float = 12.5

@export_group("Presentation")
@export var body_tint: Color = Color(0.76, 0.24, 0.22, 1.0)

@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _realm_label: Label3D = $RealmLabel

var _target: CombatActor = null
var _attack_cooldown_left: float = 0.0
var _windup_left: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("combat_enemies")
	_apply_unique_tint()
	realm_changed.connect(_on_realm_changed)
	_update_realm_label()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_acquire_target()
	if _target == null or _target.is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	var offset := _target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()

	if _windup_left > 0.0:
		velocity = Vector3.ZERO
		_windup_left = maxf(0.0, _windup_left - delta)
		_update_windup_visual()
		if _windup_left <= 0.0:
			_resolve_attack()
	elif distance > detection_range:
		velocity = Vector3.ZERO
	elif distance > attack_range:
		_move_toward_target(offset)
	elif _attack_cooldown_left <= 0.0:
		_begin_attack()
	else:
		velocity = Vector3.ZERO

	move_and_slide()
	_clamp_to_arena()


func _acquire_target() -> void:
	if is_instance_valid(_target) and not _target.is_dead:
		return

	for node in get_tree().get_nodes_in_group("player"):
		var candidate := node as CombatActor
		if candidate != null:
			_target = candidate
			return

	_target = null


func _move_toward_target(offset: Vector3) -> void:
	if offset.length_squared() <= 0.001:
		velocity = Vector3.ZERO
		return

	var direction := offset.normalized()
	velocity = direction * move_speed
	rotation.y = atan2(-direction.x, -direction.z)


func _begin_attack() -> void:
	velocity = Vector3.ZERO
	_windup_left = attack_windup


func _resolve_attack() -> void:
	_body_mesh.scale = Vector3.ONE
	_attack_cooldown_left = attack_cooldown

	if _target == null or _target.is_dead:
		return

	var distance := Vector2(
		_target.global_position.x - global_position.x,
		_target.global_position.z - global_position.z
	).length()

	if distance <= attack_range + 0.35:
		_target.receive_attack(self, attack_multiplier)


func _update_windup_visual() -> void:
	var progress := 1.0 - (_windup_left / maxf(attack_windup, 0.001))
	var pulse := 1.0 + sin(progress * PI) * 0.12
	_body_mesh.scale = Vector3.ONE * pulse


func _apply_unique_tint() -> void:
	var material := _body_mesh.get_active_material(0)
	if material is StandardMaterial3D:
		var unique_material := material.duplicate() as StandardMaterial3D
		unique_material.albedo_color = body_tint
		_body_mesh.material_override = unique_material


func _clamp_to_arena() -> void:
	global_position.x = clampf(global_position.x, -arena_half_extent, arena_half_extent)
	global_position.z = clampf(global_position.z, -arena_half_extent, arena_half_extent)


func _on_realm_changed(_actor) -> void:
	_update_realm_label()


func _update_realm_label() -> void:
	if is_instance_valid(_realm_label):
		_realm_label.text = "%s\n%s" % [actor_name, realm_label()]
