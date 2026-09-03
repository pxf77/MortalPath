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

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := PlayerArtMotionContract.load_contract(true)
	_check(not contract.is_empty(), "主角精修 Manifest 必须可加载：%s" % PlayerArtMotionContract.load_error())
	_check(PlayerArtMotionContract.version() == "player_polish_v0_4", "动作契约版本必须固定")
	_check(PlayerArtMotionContract.required_clips().size() == 11, "必须保留十一项 humanoid_v1 动作")

	var demo := MAIN_SCENE.instantiate() as MortalPathMain
	root.add_child(demo)
	current_scene = demo
	await _frames(6)
	var player := demo.get_node("Player") as PlayerController
	var visual := player.get_node_or_null("ArtVisual") as Node3D
	var bridge := player.get_node_or_null("PlayerArtMotionBridge") as PlayerArtMotionBridge
	_check(visual != null, "玩家必须挂载 ArtVisual")
	_check(visual != null and visual.get_meta("art_asset_id", "") == "chr_player_qi_refining_polished_v0_4", "玩家必须使用 v0.4 精修资产")
	_check(
		visual != null
		and visual.get_meta("art_pack_version", "") == ArtPackRegistry.PLAYER_POLISH_PACK_VERSION,
		"精修主角实例必须记录真实 v0.4 来源版本"
	)
	_check(bridge != null and bridge.is_ready_for_test(), "动作桥、AnimationPlayer、剑尖与 Trail 必须就绪")
	if bridge == null:
		await _finish(demo)
		return

	var animation_player := bridge.animation_player_for_test()
	_check(animation_player != null, "精修资产必须导入 AnimationPlayer")
	if animation_player != null:
		for clip in PlayerArtMotionContract.required_clips():
			_check(bridge.resolve_clip_for_test(clip) != &"", "Godot 可解析动作：%s" % clip)
		for loop_clip in [PlayerArtMotionContract.idle_clip(), PlayerArtMotionContract.locomotion_clip()]:
			var resolved := bridge.resolve_clip_for_test(loop_clip)
			var animation := animation_player.get_animation(resolved) if resolved != &"" else null
			_check(animation != null and animation.loop_mode == Animation.LOOP_LINEAR, "待机和移动动作必须显式循环：%s" % loop_clip)

	var sword_tip := _find_named(visual, PlayerArtMotionContract.sword_tip_node())
	_check(sword_tip is Node3D, "导入角色必须保留飞剑剑尖采样节点")
	var material_names := _material_names(visual)
	for material_name in REQUIRED_MATERIALS:
		_check(material_names.has(material_name), "Godot 必须导入 PBR 材质：%s" % material_name)

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
	_check(bridge.last_played_clip_for_test() == &"death", "死亡信号驱动死亡动画")
	_check(bridge.transient_animation_for_test() == bridge.resolve_clip_for_test(&"death"), "死亡动作不会被立即切回待机")

	await _finish(demo)


func _finish(demo: Node) -> void:
	demo.queue_free()
	await process_frame
	print("Player polish checks: %d; failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _material_names(node: Node) -> Dictionary:
	var result := {}
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.mesh.surface_get_material(surface)
				if material != null and not material.resource_name.is_empty():
					result[material.resource_name] = true
	for child in node.get_children():
		result.merge(_material_names(child), true)
	return result


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
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
