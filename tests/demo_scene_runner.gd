extends SceneTree

const MAIN_SCENE := preload("res://src/main/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var demo := MAIN_SCENE.instantiate() as MortalPathMain
	root.add_child(demo)
	current_scene = demo
	await process_frame

	_assert_equal(demo.phase_name_for_test(), "intro", "Demo 初始阶段")
	demo.start_demo_for_test()
	await process_frame
	_assert_equal(demo.phase_name_for_test(), "combat", "开始后进入同境界战斗")
	_assert_equal(demo.alive_enemy_count_for_test(), 3, "首波应生成三个炼气敌人")

	demo.force_complete_phase_for_test()
	await process_frame
	await process_frame
	_assert_equal(demo.phase_name_for_test(), "escape", "清理首波后进入破阵撤离阶段")
	_assert_equal(demo.remaining_anchor_count_for_test(), 3, "撤离阶段应生成三个阵眼")
	_assert_true(not demo.escape_portal_active_for_test(), "阵眼未破时遁光阵不可用")

	demo.force_complete_phase_for_test()
	await process_frame
	await process_frame
	_assert_equal(demo.remaining_anchor_count_for_test(), 0, "测试应能清除全部阵眼")
	_assert_true(demo.escape_portal_active_for_test(), "阵眼全部破坏后遁光阵应开启")

	var portal := demo.get_node("EscapePortal") as EscapePortal
	var player := demo.get_node("Player") as PlayerController
	_assert_true(portal != null and player != null, "Demo 应存在遁光阵和玩家")
	if portal != null and player != null:
		portal.escaped.emit(player)
		await process_frame
		_assert_equal(demo.phase_name_for_test(), "victory", "进入遁光阵后应完成 Demo")

	demo.queue_free()
	await process_frame
	if _failures == 0:
		print("MortalPath demo scene flow test passed.")
	else:
		push_error("MortalPath demo scene flow test failed: %d failure(s)." % _failures)
	quit(_failures)


func _assert_equal(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("%s：expected %s, got %s" % [message, str(expected), str(actual)])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
