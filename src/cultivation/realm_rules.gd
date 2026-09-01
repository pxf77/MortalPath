class_name RealmRules
extends RefCounted

enum MajorRealm {
	MORTAL,
	QI_REFINING,
	FOUNDATION_ESTABLISHMENT,
	CORE_FORMATION,
	NASCENT_SOUL,
	SOUL_TRANSFORMATION,
}

const REALM_NAMES := [
	"凡俗",
	"炼气",
	"筑基",
	"结丹",
	"元婴",
	"化神",
]

# 每跨越一个大境界，基础威胁指数提高 8 倍。
# 它是战斗能力的综合指标，而不是直接显示给玩家的“战力值”。
const BASE_THREAT := [
	1.0,
	8.0,
	64.0,
	512.0,
	4096.0,
	32768.0,
]

const MORTAL_STAGE_NAMES := ["锻体", "通脉", "先天"]
const FOUR_STAGE_NAMES := ["初期", "中期", "后期", "圆满"]
const FOUR_STAGE_MULTIPLIERS := [1.0, 1.25, 1.60, 2.0]


static func realm_name(major_realm: int) -> String:
	var safe_realm := clampi(major_realm, MajorRealm.MORTAL, MajorRealm.SOUL_TRANSFORMATION)
	return REALM_NAMES[safe_realm]


static func max_minor_stage(major_realm: int) -> int:
	match major_realm:
		MajorRealm.MORTAL:
			return 3
		MajorRealm.QI_REFINING:
			return 9
		_:
			return 4


static func clamp_minor_stage(major_realm: int, minor_stage: int) -> int:
	return clampi(minor_stage, 1, max_minor_stage(major_realm))


static func stage_name(major_realm: int, minor_stage: int) -> String:
	var safe_stage := clamp_minor_stage(major_realm, minor_stage)

	match major_realm:
		MajorRealm.MORTAL:
			return MORTAL_STAGE_NAMES[safe_stage - 1]
		MajorRealm.QI_REFINING:
			return "%d层" % safe_stage
		_:
			return FOUR_STAGE_NAMES[safe_stage - 1]


static func realm_label(major_realm: int, minor_stage: int) -> String:
	if major_realm == MajorRealm.MORTAL:
		return "%s·%s" % [realm_name(major_realm), stage_name(major_realm, minor_stage)]
	return "%s%s" % [realm_name(major_realm), stage_name(major_realm, minor_stage)]


static func stage_multiplier(major_realm: int, minor_stage: int) -> float:
	var safe_stage := clamp_minor_stage(major_realm, minor_stage)

	match major_realm:
		MajorRealm.MORTAL:
			return [1.0, 1.4, 2.0][safe_stage - 1]
		MajorRealm.QI_REFINING:
			var progress := float(safe_stage - 1) / 8.0
			return lerpf(1.0, 2.0, progress)
		_:
			return FOUR_STAGE_MULTIPLIERS[safe_stage - 1]


static func threat_index(major_realm: int, minor_stage: int) -> float:
	var safe_realm := clampi(major_realm, MajorRealm.MORTAL, MajorRealm.SOUL_TRANSFORMATION)
	return BASE_THREAT[safe_realm] * stage_multiplier(safe_realm, minor_stage)


static func stat_scale(major_realm: int, minor_stage: int) -> float:
	# 炼气初期为 1.0；威胁指数用于综合关系，基础属性采用平方根缩放，
	# 再由境界穿透、控制抗性与能力质变共同形成实战差距。
	return sqrt(maxf(threat_index(major_realm, minor_stage) / BASE_THREAT[MajorRealm.QI_REFINING], 0.01))


static func threat_assessment(observer_threat: float, target_threat: float) -> String:
	var ratio := target_threat / maxf(observer_threat, 0.001)

	if ratio <= 0.55:
		return "压倒性优势"
	if ratio <= 1.40:
		return "可敌"
	if ratio <= 3.0:
		return "棘手"
	if ratio <= 8.0:
		return "凶险"
	if ratio <= 32.0:
		return "九死一生"
	return "深不可测"


static func next_major_realm(current_realm: int) -> int:
	return clampi(current_realm + 1, MajorRealm.MORTAL, MajorRealm.SOUL_TRANSFORMATION)
