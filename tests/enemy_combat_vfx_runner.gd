extends SceneTree

const MAIN_SCENE := preload("res://src/main/main.tscn")
const PROJECTILE_SCENE := preload("res://src/combat/combat_projectile.tscn")
const EXPECTED := {
	&"vfx_enemy_melee_telegraph_v0_7": [&"telegraph", &"melee", &"attack_windup"],
	&"vfx_enemy_talisman_telegraph_v0_7": [&"telegraph", &"talisman", &"attack_windup"],
	&"vfx_guardian_telegraph_v0_7": [&"telegraph", &"guardian", &"attack_windup"],
	&"vfx_enemy_talisman_projectile_v0_7": [&"projectile", &"talisman", &"projectile_spawn"],
	&"vfx_guardian_projectile_v0_7": [&"projectile", &"guardian", &"projectile_spawn"],
	&"vfx_enemy_impact_qi_v0_7": [&"impact", &"qi_enemy", &"player_impact_resolved"],
	&"vfx_guardian_impact_v0_7": [&"impact", &"guardian", &"player_impact_resolved"],
}

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_contracts()
	var demo := MAIN_SCENE.instantiate() as MortalPathMain
	root.add_child(demo)
	current_scene = demo
	await _frames(6)
	var bootstrap := root.get_node_or_null("QinglanArtBootstrap")
	var bridge := (
		bootstrap.call("enemy_vfx_bridge_for_test") as EnemyCombatVfxBridge
		if bootstrap != null
		else null
	)
	_check(bridge != null, "敌方战斗 VFX 薄桥必须由美术运行时安装")
	if bridge == null:
		await _finish(demo)
		return

	demo.start_demo_for_test()
	await _frames(6)
	var melee := _enemy_for_style(TrainingEnemy.CombatStyle.MELEE)
	var talisman := _enemy_for_style(TrainingEnemy.CombatStyle.RANGED)
	_check(melee != null, "首波必须包含近战敌人")
	_check(talisman != null, "首波必须包含符修敌人")
	if melee == null or talisman == null:
		await _finish(demo)
		return

	melee.set_ai_enabled(false)
	talisman.set_ai_enabled(false)
	await _frames(2)
	_check_telegraph(melee, &"vfx_enemy_melee_telegraph_v0_7", TrainingEnemy.AttackKind.MELEE)
	_check_telegraph(talisman, &"vfx_enemy_talisman_telegraph_v0_7", TrainingEnemy.AttackKind.RANGED)
	await _check_projectile(talisman, &"vfx_enemy_talisman_projectile_v0_7")
	_check_impact(bridge, demo.get_node("Player") as PlayerController, melee, &"vfx_enemy_impact_qi_v0_7")
	bridge.call("_process", 0.30)
	_check(bridge.active_impact_count_for_test() == 0, "普通命中特效按 Manifest 寿命回收")

	demo.force_complete_phase_for_test()
	await _frames(7)
	var guardian := demo.get("_guardian") as TrainingEnemy
	_check(guardian != null, "破阵阶段必须生成筑基守关者")
	if guardian != null:
		guardian.set_ai_enabled(false)
		await _frames(2)
		_check_telegraph(guardian, &"vfx_guardian_telegraph_v0_7", TrainingEnemy.AttackKind.RANGED)
		await _check_projectile(guardian, &"vfx_guardian_projectile_v0_7")
		_check_impact(bridge, demo.get_node("Player") as PlayerController, guardian, &"vfx_guardian_impact_v0_7")
		bridge.call("_process", 0.38)
		_check(bridge.active_impact_count_for_test() == 0, "守关者命中特效按 Manifest 寿命回收")
		_check(is_equal_approx(guardian.attack_windup, 0.72), "VFX 接入不改变守关者既有前摇")

	await _finish(demo)


func _check_contracts() -> void:
	for asset_id in EXPECTED:
		var expected: Array = EXPECTED[asset_id]
		var manifest := EnemyCombatVfxContract.load_contract(asset_id, true)
		_check(not manifest.is_empty(), "敌方 VFX Manifest 必须可加载：%s" % asset_id)
		_check(EnemyCombatVfxContract.load_error(asset_id).is_empty(), "敌方 VFX Manifest 不得报告错误：%s" % asset_id)
		_check(EnemyCombatVfxContract.version(asset_id) == "enemy_combat_vfx_v0_7", "VFX 契约版本必须固定为 v0.7：%s" % asset_id)
		_check(EnemyCombatVfxContract.purpose(asset_id) == expected[0], "VFX 用途必须匹配：%s" % asset_id)
		_check(EnemyCombatVfxContract.role(asset_id) == expected[1], "VFX 角色必须匹配：%s" % asset_id)
		_check(EnemyCombatVfxContract.logic_binding(asset_id) == expected[2], "VFX 逻辑绑定必须匹配：%s" % asset_id)
		_check(ArtPackRegistry.pack_version_for(asset_id) == ArtPackRegistry.ENEMY_VFX_PACK_VERSION, "VFX 必须标记真实 v0.7 来源：%s" % asset_id)
		var instance := ArtPackRegistry.instantiate_asset(asset_id, "ContractProbe")
		_check(instance != null, "VFX GLB 必须可实例化：%s" % asset_id)
		if instance != null:
			for node_name in EnemyCombatVfxContract.presentation_nodes(asset_id):
				_check(_find_named(instance, node_name) != null, "Godot 必须保留 VFX 表现节点：%s/%s" % [asset_id, node_name])
			instance.free()


func _check_telegraph(enemy: TrainingEnemy, asset_id: StringName, attack_kind: int) -> void:
	var telegraph := enemy.get_node("Telegraph") as MeshInstance3D
	var visual := telegraph.get_node_or_null("EnemyTelegraphVisual") as Node3D
	_check(visual != null, "敌人必须挂载角色化蓄力警示：%s" % asset_id)
	_check(telegraph.mesh == null, "正式警示 GLB 必须替换原始占位网格：%s" % asset_id)
	_check(visual != null and visual.get_meta("art_asset_id", "") == String(asset_id), "敌人必须使用对应警示资产：%s" % asset_id)
	var original_windup := enemy.attack_windup
	enemy.call("_begin_attack", attack_kind)
	_check(telegraph.visible, "既有攻击前摇仍控制警示显隐：%s" % asset_id)
	_check(is_equal_approx(enemy.attack_windup, original_windup), "警示表现不得修改攻击前摇：%s" % asset_id)
	var before_rotation := visual.rotation.y if visual != null else 0.0
	var bridge := root.get_node("QinglanArtBootstrap").call("enemy_vfx_bridge_for_test") as EnemyCombatVfxBridge
	bridge.call("_process", 0.10)
	if visual != null:
		_check(visual.scale.x >= EnemyCombatVfxContract.pulse_min(asset_id), "警示脉冲下限来自 Manifest：%s" % asset_id)
		_check(visual.scale.x <= EnemyCombatVfxContract.pulse_max(asset_id), "警示脉冲上限来自 Manifest：%s" % asset_id)
		if not is_zero_approx(EnemyCombatVfxContract.rotation_speed(asset_id)):
			_check(not is_equal_approx(visual.rotation.y, before_rotation), "旋转警示速度来自 Manifest：%s" % asset_id)
	enemy.set_ai_enabled(false)


func _check_projectile(source: TrainingEnemy, asset_id: StringName) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as CombatProjectile
	current_scene.add_child(projectile)
	projectile.global_position = Vector3(40.0, 4.0, 40.0)
	projectile.configure(source, Vector3.RIGHT, 0.73, 9.25, Color.WHITE)
	await _frames(3)
	var visual := projectile.get_node_or_null("EnemyProjectileVisual") as Node3D
	var mesh := projectile.get_node("MeshInstance3D") as MeshInstance3D
	_check(visual != null, "敌方投射物必须挂载角色化资产：%s" % asset_id)
	_check(mesh.mesh == null, "正式投射物 GLB 必须替换原始占位网格：%s" % asset_id)
	_check(visual != null and visual.get_meta("art_asset_id", "") == String(asset_id), "投射物必须按施法者角色选资产：%s" % asset_id)
	_check(is_equal_approx(projectile.speed, 9.25), "投射物表现不得修改移动速度：%s" % asset_id)
	_check(is_equal_approx(projectile.attack_multiplier, 0.73), "投射物表现不得修改伤害倍率：%s" % asset_id)
	projectile.queue_free()
	await process_frame


func _check_impact(bridge: EnemyCombatVfxBridge, player: PlayerController, source: TrainingEnemy, asset_id: StringName) -> void:
	var health_before := player.current_health
	player.impact_resolved.emit(player, source, &"hit", 3.0)
	_check(bridge.last_impact_asset_for_test() == asset_id, "命中事件必须按攻击者层级选择特效：%s" % asset_id)
	_check(bridge.active_impact_count_for_test() == 1, "命中事件只生成一个表现实例：%s" % asset_id)
	_check(is_equal_approx(player.current_health, health_before), "表现桥不得二次结算伤害：%s" % asset_id)


func _enemy_for_style(style: int) -> TrainingEnemy:
	for node in get_nodes_in_group("combat_enemies"):
		var enemy := node as TrainingEnemy
		if enemy != null and not enemy.is_dead and enemy.combat_style == style:
			return enemy
	return null


func _find_named(node: Node, wanted: StringName) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null


func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _finish(demo: Node) -> void:
	demo.queue_free()
	await process_frame
	print("Enemy combat VFX v0.7 checks: %d; failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
