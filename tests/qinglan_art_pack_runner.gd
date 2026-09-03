extends SceneTree

const MAIN_SCENE := preload("res://src/main/main.tscn")
const EXPECTED_ASSET_COUNT := 14

var _failures := 0
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ArtPackRegistry.PACK_VERSION == "artpack-v0.4.0-player-polish", "Art Pack 版本必须固定")
	var asset_ids := ArtPackRegistry.asset_ids()
	_check(asset_ids.size() == EXPECTED_ASSET_COUNT, "应登记 14 个运行时资产")
	for asset_id in asset_ids:
		_check(ArtPackRegistry.has_asset(asset_id), "运行时资产可解析：%s" % asset_id)
		var instance := ArtPackRegistry.instantiate_asset(asset_id, "ContractProbe")
		_check(instance != null, "运行时资产可实例化：%s" % asset_id)
		if instance != null:
			_check(ArtPackRegistry.mesh_count(instance) > 0, "运行时资产至少包含一个网格：%s" % asset_id)
			_check(instance.get_meta("art_asset_id", "") == String(asset_id), "实例记录资产 ID：%s" % asset_id)
			instance.free()

	var demo := MAIN_SCENE.instantiate() as MortalPathMain
	root.add_child(demo)
	current_scene = demo
	await _frames(4)
	var bootstrap := root.get_node_or_null("QinglanArtBootstrap")
	_check(bootstrap != null, "青岚谷美术运行时已注册为 Autoload")
	_check(bootstrap != null and bootstrap.call("bound_scene_for_test") == demo, "美术运行时绑定当前 Demo")
	_check(bootstrap != null and bootstrap.call("environment_instance_count_for_test") == 10, "场景挂载 1 组道路、5 组岩体与 4 组竹蕨")
	var player := demo.get_node("Player") as PlayerController
	var portal := demo.get_node("EscapePortal") as EscapePortal
	_check(_asset_id(player) == "chr_player_qi_refining_polished_v0_4", "玩家挂载精修炼气角色资产")
	_check(player.get_node_or_null("PlayerArtMotionBridge") != null, "玩家挂载动作与飞剑同步桥")
	_check(_asset_id(portal) == "prop_escape_portal_qinglan_a", "遁光阵挂载运行时资产")
	_check(not (player.get_node("RealmLabel") as Label3D).visible, "正式人物接入后隐藏玩家世界空间调试标签")
	_check(not (portal.get_node("Label3D") as Label3D).visible, "正式遁光阵接入后隐藏世界空间说明标签")

	demo.start_demo_for_test()
	await _frames(5)
	var enemies := _alive_nodes("combat_enemies")
	_check(enemies.size() == 3, "首波仍生成三名炼气敌人")
	var melee_count := 0
	var talisman_count := 0
	for enemy in enemies:
		var id := _asset_id(enemy)
		melee_count += 1 if id == "chr_enemy_melee_qi_a" else 0
		talisman_count += 1 if id == "chr_enemy_talisman_qi_a" else 0
		_check(not (enemy.get_node("RealmLabel") as Label3D).visible, "正式敌人接入后隐藏世界空间调试标签")
	_check(melee_count == 2, "两名近战敌人共享近战散修视觉")
	_check(talisman_count == 1, "符箓邪修使用独立视觉")

	demo.force_complete_phase_for_test()
	await _frames(6)
	_check(demo.phase_name_for_test() == "escape", "清理首波后进入破阵阶段")
	_check(demo.remaining_anchor_count_for_test() == 3, "破阵阶段仍有三处阵眼")
	for anchor in _alive_nodes("demo_objectives"):
		_check(_asset_id(anchor) == "prop_formation_anchor_qinglan_a", "阵眼挂载运行时资产")
		_check(not (anchor.get_node("RealmLabel") as Label3D).visible, "正式阵眼接入后隐藏 HP 调试标签")
	var guardian := demo.get("_guardian") as TrainingEnemy
	_check(guardian != null and _asset_id(guardian) == "chr_guardian_foundation_a", "筑基守阵修士使用独立视觉")
	_check(guardian != null and is_equal_approx(guardian.incoming_damage_multiplier, 0.32), "美术接入不改变筑基护体数值")
	_check(guardian != null and not (guardian.get_node("RealmLabel") as Label3D).visible, "筑基守阵修士不显示重叠调试标签")

	demo.force_complete_phase_for_test()
	await _frames(5)
	_check(demo.escape_portal_active_for_test(), "全部阵眼破坏后遁光阵仍可开启")
	portal.escaped.emit(player)
	await _frames(2)
	_check(demo.phase_name_for_test() == "victory", "接入正式 GLB 后 Demo 仍可完成")

	demo.queue_free()
	await process_frame
	print("Qinglan Art Pack checks: %d; failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _asset_id(node: Node) -> String:
	var visual := node.get_node_or_null("ArtVisual")
	return String(visual.get_meta("art_asset_id", "")) if visual != null else ""


func _alive_nodes(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_nodes_in_group(group_name):
		if node is CombatActor and (node as CombatActor).is_dead:
			continue
		result.append(node)
	return result


func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
