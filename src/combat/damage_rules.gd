class_name DamageRules
extends RefCounted


static func realm_penetration(attacker_realm: int, defender_realm: int) -> float:
	var difference: int = attacker_realm - defender_realm

	match difference:
		-2:
			return 0.08
		-1:
			return 0.35
		0:
			return 1.00
		1:
			return 1.40
		2:
			return 1.80
		_:
			if difference < -2:
				return 0.02
			return 2.20


static func control_efficiency(attacker_realm: int, defender_realm: int) -> float:
	var difference: int = attacker_realm - defender_realm

	if difference <= -2:
		return 0.05
	if difference == -1:
		return 0.35
	if difference == 0:
		return 1.00
	if difference == 1:
		return 1.25
	return 1.50


static func calculate_damage(
	attacker_attack: float,
	defender_defense: float,
	skill_multiplier: float,
	attacker_realm: int,
	defender_realm: int
) -> float:
	var safe_attack: float = maxf(attacker_attack, 1.0)
	var safe_defense: float = maxf(defender_defense, 0.0)
	var defense_factor: float = safe_attack / (safe_attack + safe_defense)
	var raw_damage: float = safe_attack * maxf(skill_multiplier, 0.0) * defense_factor
	var final_damage: float = raw_damage * realm_penetration(attacker_realm, defender_realm)
	var rounded_damage: float = snappedf(final_damage, 0.1)
	return maxf(1.0, rounded_damage)
