extends SceneTree

const RealmRulesScript = preload("res://src/cultivation/realm_rules.gd")
const DamageRulesScript = preload("res://src/combat/damage_rules.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_realm_threat_progression()
	_test_realm_penetration()
	_test_cross_realm_damage()
	_test_realm_labels()

	if _failures == 0:
		print("MortalPath rule tests passed.")
	else:
		push_error("MortalPath rule tests failed: %d failure(s)." % _failures)

	quit(_failures)


func _test_realm_threat_progression() -> void:
	var qi_early := RealmRulesScript.threat_index(
		RealmRulesScript.MajorRealm.QI_REFINING,
		1
	)
	var foundation_early := RealmRulesScript.threat_index(
		RealmRulesScript.MajorRealm.FOUNDATION_ESTABLISHMENT,
		1
	)
	var core_early := RealmRulesScript.threat_index(
		RealmRulesScript.MajorRealm.CORE_FORMATION,
		1
	)

	_assert_approx(foundation_early / qi_early, 8.0, "筑基初期威胁指数应为炼气初期的 8 倍")
	_assert_approx(core_early / foundation_early, 8.0, "结丹初期威胁指数应为筑基初期的 8 倍")


func _test_realm_penetration() -> void:
	_assert_approx(
		DamageRulesScript.realm_penetration(1, 1),
		1.0,
		"同境界穿透应为 100%"
	)
	_assert_approx(
		DamageRulesScript.realm_penetration(1, 2),
		0.35,
		"低一个大境界穿透应为 35%"
	)
	_assert_approx(
		DamageRulesScript.realm_penetration(1, 3),
		0.08,
		"低两个大境界穿透应为 8%"
	)
	_assert_approx(
		DamageRulesScript.realm_penetration(2, 1),
		1.40,
		"高一个大境界穿透应为 140%"
	)


func _test_cross_realm_damage() -> void:
	var equal_realm_damage := DamageRulesScript.calculate_damage(20.0, 8.0, 1.0, 1, 1)
	var lower_realm_damage := DamageRulesScript.calculate_damage(20.0, 8.0, 1.0, 1, 2)
	var higher_realm_damage := DamageRulesScript.calculate_damage(20.0, 8.0, 1.0, 2, 1)

	_assert_true(
		lower_realm_damage < equal_realm_damage * 0.5,
		"低大境界攻击应受到明显压制"
	)
	_assert_true(
		higher_realm_damage > equal_realm_damage,
		"高大境界攻击应获得压制优势"
	)


func _test_realm_labels() -> void:
	_assert_equal(
		RealmRulesScript.realm_label(RealmRulesScript.MajorRealm.QI_REFINING, 4),
		"炼气4层",
		"炼气层级标签"
	)
	_assert_equal(
		RealmRulesScript.realm_label(RealmRulesScript.MajorRealm.FOUNDATION_ESTABLISHMENT, 1),
		"筑基初期",
		"筑基阶段标签"
	)


func _assert_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures += 1
		push_error("%s：expected %.4f, got %.4f" % [message, expected, actual])


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("%s：expected %s, got %s" % [message, str(expected), str(actual)])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
