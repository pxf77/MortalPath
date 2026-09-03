extends SceneTree

const MAIN := preload("res://src/main/main.tscn")
var _failures := 0
var _checks := 0
var _completed: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var required_driver := OS.get_environment("GODOT_REQUIRE_AUDIO_DRIVER")
	if not required_driver.is_empty():
		print("Audio driver: %s; required: %s" % [AudioServer.get_driver_name(), required_driver])
		if AudioServer.get_driver_name() != required_driver:
			push_error("Graphical playback requires the requested audio driver, not a fallback.")
			quit(1)
			return
	await _test_windup_and_buffer()
	await _test_whiff_and_dodge()
	await _test_sword_and_guard()
	await _test_feedback_and_terminal_state()
	await _test_input_expiry_and_restart()
	await _test_audio()
	await _test_audio_event_timing()
	print("Combat feedback checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _new_demo() -> MortalPathMain:
	var demo := MAIN.instantiate() as MortalPathMain
	root.add_child(demo)
	current_scene = demo
	await process_frame
	demo.start_demo_for_test()
	var player := demo.get_node("Player") as PlayerController
	player.global_position = Vector3.ZERO
	player.spirit_regeneration_per_second = 0.0
	for enemy in get_nodes_in_group("combat_enemies"):
		enemy.set_ai_enabled(false)
		enemy.global_position = Vector3(10.0, 0.0, 10.0)
	await _frames(2)
	return demo


func _test_windup_and_buffer() -> void:
	var demo := await _new_demo()
	var player := demo.get_node("Player") as PlayerController
	var target := get_nodes_in_group("combat_enemies")[0] as TrainingEnemy
	target.global_position = Vector3(0.0, 0.0, -1.7)
	_completed.clear()
	player.attack_finished.connect(func(action, step, hits): _completed.append([action, step, hits]))
	var before := target.current_health
	_tap(&"attack")
	await _frames(2)
	_check(target.current_health == before, "普攻必须先前摇，不能按键当帧伤害")
	_check(player.get_node("AttackIndicator").visible, "前摇期间必须存在动作提示")
	_tap(&"attack")
	await _frames(30)
	_check(_completed.size() == 2, "前摇期间的提前输入应衔接第二段")
	if _completed.size() >= 2:
		_check(_completed[0][1] == 1 and _completed[1][1] == 2, "连击顺序为一、二段")
	_check(target.current_health < before, "前摇结束后才造成真实伤害")
	# Input while locally paused must still be delivered by _unhandled_input.
	player.current_spirit = 50.0
	target.global_position = Vector3(0.0, 0.0, -1.7)
	player.request_hit_pause(0.065)
	_tap(&"attack")
	await _frames(36)
	_check(_completed.size() == 3 and _completed.back()[1] == 3, "命中停顿期间输入不丢失")
	_check(player.current_spirit == 59.0, "第三段真实命中才回复 9 灵力")
	_check(Engine.time_scale == 1.0, "局部停顿不得修改全局时间倍率")
	await _dispose(demo)


func _test_input_expiry_and_restart() -> void:
	var demo := await _new_demo()
	var player := demo.get_node("Player") as PlayerController
	player.set("_attack_cooldown_left", 0.5)
	_tap(&"sword_art")
	await _frames(40)
	_check(player.current_spirit == player.max_spirit, "超过 240ms 的剑诀输入失效，不延迟误触")
	var direction: Vector3 = player.call("_screen_move_direction", Vector2.UP)
	var camera := player.get_viewport().get_camera_3d()
	var start := camera.unproject_position(player.global_position)
	var end := camera.unproject_position(player.global_position + direction)
	_check(end.y < start.y and absf(end.x - start.x) < 1.0, "W 对应屏幕向上而非世界斜向")
	_tap(&"attack")
	await _frames(2)
	_tap(&"restart")
	await _frames(4)
	demo = current_scene as MortalPathMain
	_check(demo != null and demo.phase_name_for_test() == "intro", "战斗前摇期间 R 可安全重开")
	player = demo.get_node("Player") as PlayerController
	_tap(&"attack")
	await _frames(12)
	_check(player.get("_pending_attack") == &"", "开场遮罩不允许战斗输入")
	_tap(&"start_demo")
	await _frames(4)
	_check(demo.phase_name_for_test() == "combat", "重开后 Enter 仍正常开始")
	player.force_defeat()
	await _frames(2)
	_tap(&"start_demo")
	await _frames(4)
	demo = current_scene as MortalPathMain
	_check(demo != null and demo.phase_name_for_test() == "intro", "失败结算后 Enter 可重开")
	await _dispose(demo)


func _test_whiff_and_dodge() -> void:
	var demo := await _new_demo()
	var player := demo.get_node("Player") as PlayerController
	player.current_spirit = 40.0
	for index in range(3):
		_tap(&"attack")
		await _frames(21)
	_check(player.current_spirit == 40.0, "空挥第三段不得回灵")
	await _frames(50)
	var target := get_nodes_in_group("combat_enemies")[0] as TrainingEnemy
	target.global_position = Vector3(0.0, 0.0, -1.7)
	var before := target.current_health
	_tap(&"attack")
	await _frames(2)
	_tap(&"dodge")
	await _frames(2)
	_check(player.invulnerable, "身法开启短暂无敌")
	_check(player.receive_attack(target) == 0.0, "无敌窗口内不受伤")
	await _frames(18)
	_check(target.current_health == before, "闪避取消前摇，不留下幽灵命中")
	_check(not player.invulnerable, "身法结束必须退出无敌")
	_check(player.receive_attack(target) > 0.0, "无敌结束后正常受伤")
	await _dispose(demo)


func _test_sword_and_guard() -> void:
	var demo := await _new_demo()
	var player := demo.get_node("Player") as PlayerController
	var enemies := get_nodes_in_group("combat_enemies")
	enemies[0].global_position = Vector3(0.0, 0.0, -4.0)
	enemies[1].global_position = Vector3(0.0, 0.0, -6.0)
	var first_hp: float = enemies[0].current_health
	var second_hp: float = enemies[1].current_health
	_tap(&"sword_art")
	await _frames(2)
	_check(enemies[0].current_health == first_hp, "剑诀也必须先前摇")
	_check(player.current_spirit == 70.0, "剑诀只扣一次灵力")
	await _frames(20)
	_check(enemies[0].current_health < first_hp and enemies[1].current_health < second_hp, "剑诀能贯穿普攻距离外的两个目标")
	var source := enemies[0] as CombatActor
	var raw := player.receive_attack(source)
	_tap(&"spirit_guard")
	await _frames(8)
	_check(player.is_guard_active(), "护体可经正常输入开启")
	_check(player.current_spirit == 45.0, "护体消耗 25 灵力")
	var guarded := player.receive_attack(source)
	_check(guarded < raw * 0.5, "护体有独立减伤价值")
	await _dispose(demo)


func _test_feedback_and_terminal_state() -> void:
	var demo := await _new_demo()
	var player := demo.get_node("Player") as PlayerController
	var feedback := demo.get_node("CombatFeedback") as CombatFeedback
	var enemy := get_nodes_in_group("combat_enemies")[0] as TrainingEnemy
	var untouched := get_nodes_in_group("combat_enemies")[1] as TrainingEnemy
	var enemy_flash_target := feedback.flash_target_for_test(enemy)
	var untouched_flash_target := feedback.flash_target_for_test(untouched)
	_check(enemy_flash_target != null, "受击对象必须具有可用的局部闪光目标")
	_check(untouched_flash_target != null, "未受击对象必须具有独立的局部闪光目标")
	enemy.receive_attack(player)
	_check(
		enemy_flash_target != null
		and feedback.get("_flashes").has(enemy_flash_target.get_instance_id()),
		"受击对象仅记录真实可见网格的局部闪光状态"
	)
	var fallback := enemy.get_node("BodyMesh") as MeshInstance3D
	if enemy_flash_target != null and fallback != enemy_flash_target:
		_check(
			not feedback.get("_flashes").has(fallback.get_instance_id()),
			"隐藏回退网格不得重复注册闪光状态"
		)
	if DisplayServer.get_name() != "headless":
		_check(enemy_flash_target != null and enemy_flash_target.material_overlay != null, "图形模式实际应用闪光材质")
	_check(untouched_flash_target != null and untouched_flash_target.material_overlay == null, "闪光不污染共享材质")
	feedback.set_reduced_motion(true)
	_check(feedback.camera_offset() == Vector2.ZERO, "减弱动态完全关闭震屏")
	_check(not player.advance_hit_pause(0.01), "减弱动态清理已有命中停顿")
	await _frames(16)
	_check(feedback.get("_flashes").is_empty(), "闪光计时结束必须清理状态")
	_check(enemy_flash_target == null or enemy_flash_target.material_overlay == null, "闪光结束恢复原覆盖材质")
	demo.force_complete_phase_for_test()
	await _frames(3)
	var guardian: CombatActor = demo.get("_guardian")
	guardian.receive_attack(player)
	_check(guardian.get("_knockback_velocity") == Vector3.ZERO, "炼气不能击退筑基")
	_check(guardian.incoming_damage_multiplier == 0.32, "反馈不得改变筑基护体规则")
	demo.force_complete_phase_for_test()
	await _frames(3)
	var projectile := preload("res://src/combat/combat_projectile.tscn").instantiate()
	demo.add_child(projectile)
	projectile.configure(guardian, Vector3.FORWARD, 1.0, 8.0, Color.WHITE)
	var portal := demo.get_node("EscapePortal") as EscapePortal
	portal.escaped.emit(player)
	var health := player.current_health
	_check(player.receive_attack(guardian) == 0.0, "胜利后不受残留伤害")
	await _frames(4)
	_check(get_nodes_in_group("combat_projectiles").is_empty(), "结算清理所有飞行物")
	_check(player.current_health == health and not player.is_dead, "结算后保持玩家可见存活")
	_check(demo.phase_name_for_test() == "victory", "胜利不能被残留攻击改为失败")
	await _dispose(demo)
	_check(Engine.time_scale == 1.0, "场景销毁后不残留全局时间状态")
	# A fresh scene must not inherit prior feedback or buffered inputs.
	demo = await _new_demo()
	player = demo.get_node("Player") as PlayerController
	_check(player.get("_pending_attack") == &"" and player.hit_pause_enabled, "新一轮无残留动作或停顿设置")
	player.force_defeat()
	await _frames(2)
	_check(demo.phase_name_for_test() == "defeat", "失败结算仍然有效")
	await _dispose(demo)


func _test_audio() -> void:
	for cue in CombatAudio.CUES:
		for variant in range(CombatAudio.CUES[cue].size()):
			var stream := CombatAudio.stream_for(cue, variant + 1)
			_check(stream != null and stream.resource_path.begins_with("res://assets/audio/cc0_m1/"), "%s 来自随游戏打包的下载加工素材" % cue)
			_check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 48000 and not stream.stereo, "%s 使用统一 PCM 规格" % cue)
			_check(stream.data.size() > 1000 and stream.get_length() < 1.1, "%s 是有内容的短战斗音效" % cue)
			_check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, "%s 两端淡化避免爆音" % cue)
	_check(CombatAudio.stream_for(&"attack", 1) != CombatAudio.stream_for(&"attack", 3), "御剑连击使用不同成品，不是重复同一声")
	_check(CombatAudio.stream_for(&"unknown") == null, "未知音效键安全忽略")
	_check(CombatAudio.stream_for(&"attack", 99) == CombatAudio.stream_for(&"attack", 3), "连击索引安全限制")
	var audio := CombatAudio.new()
	root.add_child(audio)
	await process_frame
	for index in range(32):
		audio.play_cue(&"attack", index % 3 + 1)
	_check(audio.get_child_count() == CombatAudio.VOICE_LIMIT, "连续触发不无限创建声部")
	for voice in audio.get_children():
		_check(voice.volume_db <= -14.0, "八声部保留混音余量")
		_check(voice.pitch_scale == 1.0, "不额外改变已制作成品的音高")
	audio.set_muted(true)
	audio.play_cue(&"sword_art")
	for voice in audio.get_children():
		_check(not voice.playing, "M 静音停止尾音且阻止新声音")
	var before: int = audio.get("_next_voice")
	audio.set_muted(false)
	audio.play_cue(&"unknown")
	_check(audio.get("_next_voice") == before, "未知音效不抢占声部")
	audio.play_cue(&"talisman_cast")
	var playing := false
	for voice in audio.get_children():
		playing = playing or voice.playing
	if DisplayServer.get_name() != "headless":
		_check(playing, "取消静音后可播放已入库的符箓资源")
	else:
		_check(not playing, "headless 验证资源选择，不向 Dummy 音频服务提交播放")
	await _dispose(audio)


func _test_audio_event_timing() -> void:
	var demo := await _new_demo()
	var feedback := demo.get_node("CombatFeedback") as CombatFeedback
	var heard: Array[StringName] = []
	feedback.cue_played.connect(func(cue: StringName): heard.append(cue))
	_tap(&"attack")
	await _frames(2)
	_check(not heard.has(&"attack"), "前摇尚未释放时不播放出剑声")
	_tap(&"dodge")
	await _frames(18)
	_check(not heard.has(&"attack") and heard.has(&"dodge"), "闪避取消攻击后没有幽灵出剑声")
	await _frames(30)
	heard.clear()
	_tap(&"attack")
	await _frames(16)
	_check(heard.has(&"attack") and not heard.has(&"hit"), "落空也有出剑声，但无虚假命中声")
	var enemy := get_nodes_in_group("combat_enemies")[0] as TrainingEnemy
	enemy.set("_target", demo.get_node("Player"))
	enemy.combat_style = TrainingEnemy.CombatStyle.RANGED
	enemy.call("_begin_attack", TrainingEnemy.AttackKind.RANGED)
	_check(not heard.has(&"enemy_spell"), "敌人前摇不提前播放灵弹释放声")
	enemy.call("_resolve_attack")
	_check(heard.has(&"enemy_spell"), "敌人真实生成灵弹时触发施法声")
	enemy.combat_style = TrainingEnemy.CombatStyle.GUARDIAN
	enemy.call("_begin_attack", TrainingEnemy.AttackKind.RANGED)
	enemy.call("_resolve_attack")
	_check(heard.has(&"guardian_spell"), "筑基守阵者使用独立厚度配方")
	var talisman_enemy := get_nodes_in_group("combat_enemies")[2] as TrainingEnemy
	_check(talisman_enemy.ranged_audio_cue == &"talisman_cast", "符箓邪修配置纸张与引燃音效")
	talisman_enemy.set("_target", demo.get_node("Player"))
	talisman_enemy.call("_begin_attack", TrainingEnemy.AttackKind.RANGED)
	talisman_enemy.call("_resolve_attack")
	_check(heard.has(&"talisman_cast"), "实际敌方符箓释放走独立声音映射")
	heard.clear()
	enemy.call("_begin_attack", TrainingEnemy.AttackKind.RANGED)
	enemy.set_ai_enabled(false)
	enemy.call("_resolve_attack")
	_check(heard.is_empty(), "取消敌方施法不产生释放声")
	await _dispose(demo)


func _tap(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func _dispose(demo: Node) -> void:
	demo.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
