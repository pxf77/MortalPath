extends SceneTree

const MAIN_SCENE := preload("res://src/main/main.tscn")
const EXPECTED_ASSETS := {
	TrainingEnemy.CombatStyle.MELEE: &"chr_enemy_melee_qi_refined_v0_6",
	TrainingEnemy.CombatStyle.RANGED: &"chr_enemy_talisman_qi_refined_v0_6",
	TrainingEnemy.CombatStyle.GUARDIAN: &"chr_guardian_foundation_refined_v0_6",
}
const EXPECTED_ROLES := {
	TrainingEnemy.CombatStyle.MELEE: &"melee",
	TrainingEnemy.CombatStyle.RANGED: &"talisman",
	TrainingEnemy.CombatStyle.GUARDIAN: &"guardian",
}

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for style in EXPECTED_ASSETS:
		var asset_id: StringName = EXPECTED_ASSETS[style]
		var contract := EnemyArtMotionContract.load_contract(asset_id, true)
		_check(not contract.is_empty(), "敌方动作 Manifest 必须可加载：%s" % asset_id)
		_check(EnemyArtMotionContract.load_error(asset_id).is_empty(), "敌方动作 Manifest 不得报告加载错误：%s" % asset_id)
		_check(EnemyArtMotionContract.version(asset_id) == "enemy_motion_refinement_v0_6", "动作契约版本必须固定为 v0.6：%s" % asset_id)
		_check(EnemyArtMotionContract.role(asset_id) == EXPECTED_ROLES[style], "动作契约角色必须匹配战斗类型：%s" % asset_id)
		_check(EnemyArtMotionContract.required_clips(asset_id).size() >= 12, "每个敌方角色至少提供 12 项动作：%s" % asset_id)
		_check(is_equal_approx(EnemyArtMotionContract.heavy_hit_ratio(asset_id), 0.18), "重受击阈值必须来自 Manifest：%s" % asset_id)

	var demo := MAIN_SCENE.instantiate() as MortalPathMain
	root.add_child(demo)
	current_scene = demo
	await _frames(6)
	demo.start_demo_for_test()
	await _frames(6)

	var melee := _enemy_for_style(TrainingEnemy.CombatStyle.MELEE)
	var talisman := _enemy_for_style(TrainingEnemy.CombatStyle.RANGED)
	_check(melee != null, "首波必须生成近战敌人")
	_check(talisman != null, "首波必须生成符箓敌人")
	if melee == null or talisman == null:
		await _finish(demo)
		return

	await _check_actor_contract(melee)
	await _check_actor_contract(talisman)
	_check(is_equal_approx(melee.attack_windup, 0.62), "近战敌人的既有 0.62 秒逻辑前摇保持不变")
	_check(is_equal_approx(talisman.attack_windup, 0.62), "符箓敌人的既有 0.62 秒逻辑前摇保持不变")

	var melee_bridge := melee.get_node("EnemyArtMotionBridge") as EnemyArtMotionBridge
	var talisman_bridge := talisman.get_node("EnemyArtMotionBridge") as EnemyArtMotionBridge
	_check_locomotion(melee, melee_bridge)
	_check_attack(melee, melee_bridge, TrainingEnemy.AttackKind.MELEE, &"melee", &"attack_melee")
	_check_attack(talisman, talisman_bridge, TrainingEnemy.AttackKind.RANGED, &"ranged", &"cast_talisman")
	await _check_hit_reactions(melee, melee_bridge)

	melee.force_defeat()
	await _frames(2)
	_check(melee.visible, "敌人死亡后保留表现节点以播放死亡动作")
	_check(melee_bridge.last_played_clip_for_test() == EnemyArtMotionContract.death_clip(EXPECTED_ASSETS[TrainingEnemy.CombatStyle.MELEE]), "死亡信号驱动 v0.6 死亡动画")
	_check(melee.collision_layer == 0 and melee.collision_mask == 0, "恢复死亡表现可见性不得恢复碰撞")

	demo.force_complete_phase_for_test()
	await _frames(7)
	var guardian := demo.get("_guardian") as TrainingEnemy
	_check(guardian != null, "破阵阶段必须生成筑基守关者")
	if guardian != null:
		await _check_actor_contract(guardian)
		var guardian_bridge := guardian.get_node("EnemyArtMotionBridge") as EnemyArtMotionBridge
		_clear_transient(guardian_bridge)
		guardian_bridge.call("_process", 0.016)
		_check(guardian_bridge.guarded_for_test(), "筑基减伤状态驱动护体姿态")
		_check(guardian_bridge.last_played_clip_for_test() == &"guard_stance", "筑基守关者静止时播放护体循环")
		_check(is_equal_approx(guardian.attack_windup, 0.72), "筑基守关者既有 0.72 秒逻辑前摇保持不变")
		_check_attack(guardian, guardian_bridge, TrainingEnemy.AttackKind.MELEE, &"melee", &"attack_melee")
		_check_attack(guardian, guardian_bridge, TrainingEnemy.AttackKind.RANGED, &"ranged", &"cast_guardian")

	await _finish(demo)


func _check_actor_contract(enemy: TrainingEnemy) -> void:
	enemy.set_ai_enabled(false)
	await physics_frame
	var asset_id: StringName = EXPECTED_ASSETS[enemy.combat_style]
	var visual := enemy.get_node_or_null("ArtVisual") as Node3D
	var bridge := enemy.get_node_or_null("EnemyArtMotionBridge") as EnemyArtMotionBridge
	_check(visual != null, "敌方角色必须挂载 ArtVisual：%s" % asset_id)
	_check(visual != null and visual.get_meta("art_asset_id", "") == String(asset_id), "敌方角色必须使用对应 v0.6 资产：%s" % asset_id)
	_check(visual != null and visual.get_meta("art_pack_version", "") == ArtPackRegistry.ENEMY_MOTION_PACK_VERSION, "敌方实例必须记录真实 v0.6 来源：%s" % asset_id)
	_check(bridge != null and bridge.is_ready_for_test(), "敌方动作桥与 AnimationPlayer 必须就绪：%s" % asset_id)
	if visual == null or bridge == null:
		return

	var animation_player := bridge.animation_player_for_test()
	for clip in EnemyArtMotionContract.required_clips(asset_id):
		_check(bridge.resolve_clip_for_test(clip) != &"", "Godot 可解析敌方动作：%s/%s" % [asset_id, clip])
	for loop_clip in [EnemyArtMotionContract.idle_clip(asset_id), EnemyArtMotionContract.locomotion_clip(asset_id), EnemyArtMotionContract.guard_clip(asset_id)]:
		if loop_clip == &"":
			continue
		var resolved := bridge.resolve_clip_for_test(loop_clip)
		var animation := animation_player.get_animation(resolved) if resolved != &"" else null
		_check(animation != null and animation.loop_mode == Animation.LOOP_LINEAR, "待机、移动与护体动作必须显式循环：%s/%s" % [asset_id, loop_clip])

	var skeleton := _find_skeleton(visual)
	_check(skeleton != null and skeleton.get_bone_count() == 20, "敌方 v0.6 必须导入 humanoid_v1 的 20 根骨骼：%s" % asset_id)
	var manifest := EnemyArtMotionContract.load_contract(asset_id)
	var material_contract = manifest.get("material_contract", {})
	var required_materials = material_contract.get("materials", {}) if material_contract is Dictionary else {}
	var imported_materials := _materials_by_name(visual)
	for material_name in required_materials:
		_check(imported_materials.has(material_name), "Godot 必须导入敌方 PBR 材质：%s/%s" % [asset_id, material_name])
	var motion = manifest.get("enemy_motion_contract", {})
	var presentation_nodes = motion.get("presentation_nodes", []) if motion is Dictionary else []
	for node_name in presentation_nodes:
		_check(_find_named(visual, StringName(node_name)) != null, "角色化表现节点必须保留：%s/%s" % [asset_id, node_name])


func _check_locomotion(enemy: TrainingEnemy, bridge: EnemyArtMotionBridge) -> void:
	_clear_transient(bridge)
	enemy.velocity = Vector3(2.0, 0.0, 0.0)
	bridge.call("_process", 0.016)
	_check(bridge.last_played_clip_for_test() == &"locomotion", "敌人移动速度驱动移动循环")
	enemy.velocity = Vector3.ZERO
	bridge.call("_process", 0.016)
	_check(bridge.last_played_clip_for_test() == &"idle", "敌人静止后回到待机")


func _check_attack(
	enemy: TrainingEnemy,
	bridge: EnemyArtMotionBridge,
	kind: int,
	action: StringName,
	expected_clip: StringName
) -> void:
	_clear_transient(bridge)
	var asset_id: StringName = EXPECTED_ASSETS[enemy.combat_style]
	var expected_speed := EnemyArtMotionContract.attack_playback_speed(asset_id, action, enemy.attack_windup)
	enemy.attack_started.emit(kind, enemy.attack_windup)
	_check(bridge.last_played_clip_for_test() == expected_clip, "攻击开始信号驱动角色化动作：%s" % expected_clip)
	_check(is_equal_approx(bridge.current_playback_speed_for_test(), expected_speed), "敌方动画释放帧与逻辑前摇对齐：%s" % expected_clip)
	enemy.attack_released.emit(kind)
	_check(bridge.last_release_clip_for_test() == expected_clip, "攻击释放信号记录对应动作：%s" % expected_clip)
	_check(is_equal_approx(bridge.effective_playback_speed_for_test(), 1.0), "敌方攻击释放后恢复段回到作者 1 倍速：%s" % expected_clip)


func _check_hit_reactions(enemy: TrainingEnemy, bridge: EnemyArtMotionBridge) -> void:
	var source := Node3D.new()
	root.add_child(source)
	source.global_position = enemy.global_position - enemy.global_basis.z * 2.0
	enemy.damage_received.emit(enemy, enemy.max_health * 0.10, source)
	await process_frame
	_check(bridge.last_played_clip_for_test() == &"hit_light_front", "前方轻击触发前向轻受击")
	source.global_position = enemy.global_position + enemy.global_basis.x * 2.0
	enemy.damage_received.emit(enemy, enemy.max_health * 0.20, source)
	await process_frame
	_check(bridge.last_played_clip_for_test() == &"hit_heavy_right", "右侧重击触发右向重受击")
	source.queue_free()


func _clear_transient(bridge: EnemyArtMotionBridge) -> void:
	var current := bridge.transient_animation_for_test()
	if current != &"":
		bridge.call("_on_animation_finished", current)


func _enemy_for_style(style: int) -> TrainingEnemy:
	for node in get_nodes_in_group("combat_enemies"):
		var enemy := node as TrainingEnemy
		if enemy != null and not enemy.is_dead and enemy.combat_style == style:
			return enemy
	return null


func _materials_by_name(node: Node) -> Dictionary:
	var result := {}
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.mesh.surface_get_material(surface)
				if material != null and not material.resource_name.is_empty():
					result[material.resource_name] = material
	for child in node.get_children():
		result.merge(_materials_by_name(child), true)
	return result


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
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
	print("Enemy motion v0.6 checks: %d; failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
