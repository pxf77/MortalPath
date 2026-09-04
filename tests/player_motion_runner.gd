extends SceneTree

const MAIN_SCENE := preload("res://src/main/main.tscn")
const REQUIRED_MATERIALS := {
	"mat_player_cloth_moss": true,
	"mat_player_cloth_ink": true,
	"mat_player_leather_earth": true,
	"mat_player_iron_brushed": true,
	"mat_player_skin_warm": true,
	"mat_player_hair_ink": true,
	"mat_player_jade_muted": true,
}
const AUXILIARY_BONES := [
	"robe_front_l",
	"robe_front_r",
	"robe_back_l",
	"robe_back_r",
	"sleeve_l",
	"sleeve_r",
	"hair_01",
	"hair_02",
]
const DIRECTION_CASES := {
	Vector2(0.0, -1.0): &"locomotion_n",
	Vector2(1.0, -1.0): &"locomotion_ne",
	Vector2(1.0, 0.0): &"locomotion_e",
	Vector2(1.0, 1.0): &"locomotion_se",
	Vector2(0.0, 1.0): &"locomotion_s",
	Vector2(-1.0, 1.0): &"locomotion_sw",
	Vector2(-1.0, 0.0): &"locomotion_w",
	Vector2(-1.0, -1.0): &"locomotion_nw",
}

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := PlayerArtMotionContract.load_contract(true)
	_check(not contract.is_empty(), "主角 v0.5 Manifest 必须可加载：%s" % PlayerArtMotionContract.load_error())
	_check(PlayerArtMotionContract.version() == "player_motion_refinement_v0_5", "动作契约版本必须固定为 v0.5")
	_check(PlayerArtMotionContract.required_clips().size() == 30, "v0.5 必须提供 30 项动作")
	_check(is_equal_approx(PlayerArtMotionContract.heavy_hit_ratio(), 0.18), "重受击阈值必须来自 Manifest")

	for direction in DIRECTION_CASES:
		_check(
			PlayerArtMotionContract.locomotion_clip_for_screen_vector(direction) == DIRECTION_CASES[direction],
			"屏幕方向必须映射到独立移动动作：%s" % direction
		)

	var demo := MAIN_SCENE.instantiate() as MortalPathMain
	root.add_child(demo)
	current_scene = demo
	await _frames(6)
	var player := demo.get_node("Player") as PlayerController
	var visual := player.get_node_or_null("ArtVisual") as Node3D
	var bridge := player.get_node_or_null("PlayerArtMotionBridge") as PlayerArtMotionBridge
	_check(visual != null, "玩家必须挂载 ArtVisual")
	_check(
		visual != null and visual.get_meta("art_asset_id", "") == "chr_player_qi_refining_refined_v0_5",
		"玩家必须使用 v0.5 动作精修资产"
	)
	_check(
		visual != null
		and visual.get_meta("art_pack_version", "") == ArtPackRegistry.PLAYER_MOTION_PACK_VERSION,
		"主角实例必须记录真实 v0.5 来源版本"
	)
	_check(bridge != null and bridge.is_ready_for_test(), "动作桥、AnimationPlayer、飞剑节点与 Trail 必须就绪")
	if bridge == null:
		await _finish(demo)
		return

	var animation_player := bridge.animation_player_for_test()
	_check(animation_player != null, "v0.5 资产必须导入 AnimationPlayer")
	if animation_player != null:
		for clip in PlayerArtMotionContract.required_clips():
			_check(bridge.resolve_clip_for_test(clip) != &"", "Godot 可解析动作：%s" % clip)
		var loop_clips := {PlayerArtMotionContract.idle_clip(): true}
		for direction in DIRECTION_CASES:
			loop_clips[DIRECTION_CASES[direction]] = true
		for loop_clip in loop_clips:
			var resolved := bridge.resolve_clip_for_test(loop_clip)
			var animation := animation_player.get_animation(resolved) if resolved != &"" else null
			_check(animation != null and animation.loop_mode == Animation.LOOP_LINEAR, "待机和八方向移动动作必须显式循环：%s" % loop_clip)

	var skeleton := _find_skeleton(visual)
	_check(skeleton != null and skeleton.get_bone_count() == 28, "v0.5 必须导入 28 根骨骼")
	if skeleton != null:
		for bone_name in AUXILIARY_BONES:
			_check(skeleton.find_bone(bone_name) >= 0, "必须保留辅助骨骼：%s" % bone_name)

	var sword_tip := _find_named(visual, PlayerArtMotionContract.sword_tip_node())
	var sword_root := bridge.sword_root_for_test()
	_check(sword_tip is Node3D, "导入角色必须保留飞剑剑尖采样节点")
	_check(sword_root != null, "导入角色必须保留飞剑根节点")
	var materials := _materials_by_name(visual)
	for material_name in REQUIRED_MATERIALS:
		_check(materials.has(material_name), "Godot 必须导入 PBR 材质：%s" % material_name)
	for material_name in ["mat_player_cloth_moss", "mat_player_cloth_ink"]:
		var material = materials.get(material_name)
		_check(material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null, "绘画化布料材质必须绑定内嵌贴图：%s" % material_name)

	player.set_input_enabled(true)
	var north_velocity := _world_velocity_for_screen(player, Vector2(0.0, -1.0))
	player.velocity = north_velocity
	bridge.call("_process", 0.016)
	_check(bridge.last_played_clip_for_test() == PlayerArtMotionContract.locomotion_start_clip(), "静止转移动先播放起步动作")
	_check(bridge.visual_screen_locked_for_test(), "屏幕方向移动期间角色表现保持屏幕坐标基准")
	_finish_current_transition(bridge)
	_check(bridge.last_played_clip_for_test() == &"locomotion_n", "起步后进入北向移动循环")

	player.velocity = -north_velocity
	bridge.call("_process", 0.016)
	_check(bridge.last_played_clip_for_test() == PlayerArtMotionContract.locomotion_turn_clip(), "反向移动触发 180 度急转动作")
	_finish_current_transition(bridge)
	_check(bridge.last_played_clip_for_test() == &"locomotion_s", "急转后进入南向移动循环")

	player.velocity = Vector3.ZERO
	bridge.call("_process", 0.016)
	_check(bridge.last_played_clip_for_test() == PlayerArtMotionContract.locomotion_stop_clip(), "移动转静止播放停止动作")
	_finish_current_transition(bridge)
	_check(bridge.last_played_clip_for_test() == PlayerArtMotionContract.idle_clip(), "停止后回到待机")
	_check(not bridge.visual_screen_locked_for_test(), "停止完成后恢复战斗朝向")

	_check(is_equal_approx(player.action_windup_seconds(&"attack", 1), 0.085), "第一式前摇由玩家控制器统一提供")
	_check(is_equal_approx(player.action_windup_seconds(&"attack", 3), 0.135), "第三式前摇由玩家控制器统一提供")
	_check(is_equal_approx(player.action_windup_seconds(&"sword_art"), 0.16), "剑诀前摇由玩家控制器统一提供")

	var expected_speed := PlayerArtMotionContract.playback_speed_for(
		&"attack", 1, player.action_windup_seconds(&"attack", 1)
	)
	_check(expected_speed > 1.0 and expected_speed < 2.0, "第一式前摇应按释放帧计算有限加速")
	player.action_started.emit(&"attack", 1)
	await process_frame
	_check(bridge.last_played_clip_for_test() == &"attack_light_1", "第一式信号驱动第一式动画")
	_check(is_equal_approx(bridge.current_playback_speed_for_test(), expected_speed), "动画前摇速度与释放帧对齐")

	var trail := bridge.trail_for_test()
	var started_before := trail.started_count_for_test() if trail != null else -1
	player.action_released.emit(&"attack", 1)
	await process_frame
	_check(bridge.last_release_clip_for_test() == &"attack_light_1", "伤害释放信号记录第一式")
	_check(trail != null and trail.started_count_for_test() == started_before + 1, "释放事件启动飞剑轨迹")
	_check(is_equal_approx(bridge.effective_playback_speed_for_test(), 1.0), "释放后恢复段回到作者 1 倍速")
	if trail != null:
		var rule := trail.last_rule_for_test()
		_check(is_equal_approx(float(rule.get("trail_duration_seconds", 0.0)), 0.16), "第一式轨迹持续时间来自 Manifest")
		_check(is_equal_approx(float(rule.get("trail_width_m", 0.0)), 0.085), "第一式轨迹宽度来自 Manifest")
		_check(trail.sample_count_for_test() >= 1, "释放时至少采样一个剑尖位置")

	var source := Node3D.new()
	root.add_child(source)
	source.global_position = player.global_position - player.global_basis.z * 2.0
	player.damage_received.emit(player, player.max_health * 0.10, source)
	await process_frame
	_check(bridge.last_played_clip_for_test() == &"hit_light_front", "前方轻击触发前向轻受击")
	source.global_position = player.global_position + player.global_basis.x * 2.0
	player.damage_received.emit(player, player.max_health * 0.20, source)
	await process_frame
	_check(bridge.last_played_clip_for_test() == &"hit_heavy_right", "右侧重击触发右向重受击")
	source.queue_free()

	player.action_started.emit(&"dodge", 0)
	await process_frame
	_check(bridge.last_played_clip_for_test() == &"dodge", "身法信号驱动闪避动画")
	_check(bridge.current_playback_speed_for_test() > 2.0, "闪避动作按 0.20 秒逻辑窗口加速")
	await _frames(18)
	_check(bridge.transient_animation_for_test() == &"", "闪避逻辑结束后不继续锁定闪避姿态")

	var feedback := demo.get_node_or_null("CombatFeedback") as CombatFeedback
	var flash_target := feedback.flash_target_for_test(player) if feedback != null else null
	_check(visual != null and flash_target != null and (flash_target == visual or visual.is_ancestor_of(flash_target)), "命中闪白必须作用于真实 ArtVisual 网格")

	player.force_defeat()
	await _frames(2)
	_check(player.visible, "玩家死亡后保持表现节点可见以播放死亡动作")
	_check(bridge.last_played_clip_for_test() == PlayerArtMotionContract.death_clip(), "死亡信号驱动 v0.5 死亡动画")
	_check(bridge.transient_animation_for_test() == bridge.resolve_clip_for_test(PlayerArtMotionContract.death_clip()), "死亡动作不会被立即切回待机")
	await _frames(70)
	if sword_root != null:
		var sword_height := sword_root.global_position.y - player.global_position.y
		_check(sword_height <= PlayerArtMotionContract.death_sword_height_max_m() + 0.05, "死亡动作结束后飞剑必须坠落到约定高度")

	await _finish(demo)


func _finish_current_transition(bridge: PlayerArtMotionBridge) -> void:
	var current := bridge.transient_animation_for_test()
	if current != &"":
		bridge.call("_on_animation_finished", current)


func _world_velocity_for_screen(player: PlayerController, screen_direction: Vector2) -> Vector3:
	var camera := player.get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(screen_direction.x, 0.0, screen_direction.y) * player.move_speed
	var right := camera.global_basis.x
	var down := camera.global_basis.z
	right.y = 0.0
	down.y = 0.0
	return (right.normalized() * screen_direction.x + down.normalized() * screen_direction.y).normalized() * player.move_speed


func _finish(demo: Node) -> void:
	demo.queue_free()
	await process_frame
	print("Player motion v0.5 checks: %d; failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


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


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
