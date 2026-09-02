class_name CombatActor
extends CharacterBody3D

signal health_changed(actor, current_health: float, max_health: float)
signal realm_changed(actor)
signal damage_received(actor, amount: float, source)
signal damage_modifier_changed(actor, incoming_multiplier: float)
signal died(actor)

@export_group("Identity")
@export var actor_name: String = "修士"
@export_enum("凡俗", "炼气", "筑基", "结丹", "元婴", "化神") var major_realm: int = RealmRules.MajorRealm.QI_REFINING
@export_range(1, 9, 1) var minor_stage: int = 1

@export_group("Base Stats")
@export var base_max_health: float = 120.0
@export var base_attack: float = 18.0
@export var base_defense: float = 7.0

var max_health: float = 1.0
var current_health: float = 1.0
var attack_power: float = 1.0
var defense: float = 0.0
var invulnerable: bool = false
var is_dead: bool = false
var incoming_damage_multiplier: float = 1.0


func _ready() -> void:
	refresh_stats(true)


func refresh_stats(full_restore: bool = false) -> void:
	var previous_ratio := 1.0
	if max_health > 0.0:
		previous_ratio = current_health / max_health

	var scale := RealmRules.stat_scale(major_realm, minor_stage)
	max_health = maxf(1.0, base_max_health * scale)
	attack_power = maxf(1.0, base_attack * scale)
	defense = maxf(0.0, base_defense * scale)

	if full_restore:
		current_health = max_health
	else:
		current_health = clampf(max_health * previous_ratio, 1.0, max_health)

	health_changed.emit(self, current_health, max_health)
	realm_changed.emit(self)


func receive_attack(attacker: CombatActor, skill_multiplier: float = 1.0) -> float:
	if is_dead or invulnerable or not is_instance_valid(attacker):
		return 0.0

	var calculated_damage := DamageRules.calculate_damage(
		attacker.attack_power,
		defense,
		skill_multiplier,
		attacker.major_realm,
		major_realm
	)
	var damage := round(calculated_damage * incoming_damage_multiplier * 10.0) / 10.0
	damage = maxf(0.1, damage)

	current_health = maxf(0.0, current_health - damage)
	damage_received.emit(self, damage, attacker)
	health_changed.emit(self, current_health, max_health)

	if current_health <= 0.0:
		_die()

	return damage


func set_incoming_damage_multiplier(multiplier: float) -> void:
	incoming_damage_multiplier = clampf(multiplier, 0.05, 2.0)
	damage_modifier_changed.emit(self, incoming_damage_multiplier)


func restore_full() -> void:
	if is_dead:
		return
	current_health = max_health
	health_changed.emit(self, current_health, max_health)


func restore_health(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var before := current_health
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(self, current_health, max_health)
	return current_health - before


func breakthrough_to(new_major_realm: int, new_minor_stage: int = 1) -> void:
	if is_dead:
		return

	major_realm = clampi(
		new_major_realm,
		RealmRules.MajorRealm.MORTAL,
		RealmRules.MajorRealm.SOUL_TRANSFORMATION
	)
	minor_stage = RealmRules.clamp_minor_stage(major_realm, new_minor_stage)
	refresh_stats(true)


func set_minor_stage(new_minor_stage: int, full_restore: bool = true) -> void:
	if is_dead:
		return

	minor_stage = RealmRules.clamp_minor_stage(major_realm, new_minor_stage)
	refresh_stats(full_restore)


func realm_label() -> String:
	return RealmRules.realm_label(major_realm, minor_stage)


func threat_index() -> float:
	return RealmRules.threat_index(major_realm, minor_stage)


func health_ratio() -> float:
	return current_health / maxf(max_health, 0.001)


func can_be_targeted() -> bool:
	return not is_dead and visible


func force_defeat() -> void:
	if is_dead:
		return
	current_health = 0.0
	health_changed.emit(self, current_health, max_health)
	_die()


func _die() -> void:
	is_dead = true
	invulnerable = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	visible = false
	set_physics_process(false)
	died.emit(self)
