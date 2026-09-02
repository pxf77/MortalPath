class_name CombatProjectile
extends Area3D

@export var speed: float = 8.5
@export var lifetime: float = 4.0
@export var attack_multiplier: float = 0.85

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var source_actor: CombatActor = null
var direction := Vector3.ZERO
var target_group: StringName = &"player"
var _time_left: float = 4.0


func _ready() -> void:
	_time_left = lifetime
	body_entered.connect(_on_body_entered)


func configure(
	new_source: CombatActor,
	travel_direction: Vector3,
	new_multiplier: float,
	new_speed: float,
	tint: Color
) -> void:
	source_actor = new_source
	direction = travel_direction.normalized()
	attack_multiplier = new_multiplier
	speed = new_speed
	_time_left = lifetime

	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.0
	material.roughness = 0.35
	_mesh.material_override = material


func _physics_process(delta: float) -> void:
	if direction.length_squared() <= 0.001:
		queue_free()
		return

	global_position += direction * speed * delta
	rotation.y += delta * 6.0
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return
	if body == source_actor or not body.is_in_group(target_group):
		return

	var target := body as CombatActor
	if target != null and not target.is_dead:
		target.receive_attack(source_actor, attack_multiplier)
	queue_free()
