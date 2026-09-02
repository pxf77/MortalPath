class_name DemoRules
extends RefCounted

const COMBO_MULTIPLIERS := [0.85, 1.0, 1.35]
const COMBO_COOLDOWNS := [0.24, 0.28, 0.40]


static func combo_multiplier(step: int) -> float:
	return COMBO_MULTIPLIERS[clampi(step, 1, 3) - 1]


static func combo_cooldown(step: int) -> float:
	return COMBO_COOLDOWNS[clampi(step, 1, 3) - 1]


static func can_spend_spirit(current_spirit: float, cost: float) -> bool:
	return cost >= 0.0 and current_spirit + 0.001 >= cost


static func spirit_after_spend(current_spirit: float, cost: float) -> float:
	if not can_spend_spirit(current_spirit, cost):
		return current_spirit
	return maxf(0.0, current_spirit - cost)


static func escape_objective(remaining_anchors: int, portal_active: bool) -> String:
	if portal_active:
		return "阵眼已破：前往南侧遁光阵撤离"
	return "破坏锁灵阵眼（剩余 %d）" % maxi(remaining_anchors, 0)
