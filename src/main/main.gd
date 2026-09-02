class_name MortalPathMain
extends Node3D

enum DemoPhase {
	INTRO,
	COMBAT,
	ESCAPE,
	VICTORY,
	DEFEAT,
}

const ENEMY_SCENE := preload("res://src/actors/enemies/training_enemy.tscn")
const ANCHOR_SCENE := preload("res://src/world/formation_anchor.tscn")

@export var camera_offset := Vector3(10.8, 14.2, 10.8)
@export var camera_follow_speed: float = 7.0

@onready var _player: PlayerController = $Player
@onready var _actors: Node3D = $Actors
@onready var _portal: EscapePortal = $EscapePortal
@onready var _camera: Camera3D = $Camera3D
@onready var _player_status: Label = $HUD/PlayerPanel/Margin/VBox/PlayerStatus
@onready var _health_bar: ProgressBar = $HUD/PlayerPanel/Margin/VBox/HealthBar
@onready var _spirit_bar: ProgressBar = $HUD/PlayerPanel/Margin/VBox/SpiritBar
@onready var _skill_status: Label = $HUD/PlayerPanel/Margin/VBox/SkillStatus
@onready var _objective_label: Label = $HUD/ObjectivePanel/Margin/VBox/Objective
@onready var _threat_label: Label = $HUD/ObjectivePanel/Margin/VBox/Threat
@onready var _message_label: Label = $HUD/MessagePanel/Margin/Message
@onready var _overlay: Control = $HUD/Overlay
@onready var _overlay_title: Label = $HUD/Overlay/Panel/Margin/VBox/Title
@onready var _overlay_body: Label = $HUD/Overlay/Panel/Margin/VBox/Body
@onready var _overlay_prompt: Label = $HUD/Overlay/Panel/Margin/VBox/Prompt

var _phase: int = DemoPhase.INTRO
var _objective_text := "等待进入青岚谷"
var _last_message := "先击退炼气邪修，再设法从筑基修士的锁灵阵中脱身。"
var _guardian: TrainingEnemy = null
var _feedback: CombatFeedback


func _ready() -> void:
	_feedback = CombatFeedback.new()
	_feedback.name = "CombatFeedback"
	add_child(_feedback)
	_feedback.observe(_player)
	_player.combat_message.connect(_on_combat_message)
	_player.damage_received.connect(_on_player_damage_received)
	_player.died.connect(_on_player_died)
	_portal.escaped.connect(_on_portal_escaped)
	_player.set_input_enabled(false)
	_portal.set_active(false)
	_show_overlay(
		"青岚谷脱身",
		"无名修士为寻找筑基灵材进入青岚谷。击退谷口邪修后，一名筑基修士催动锁灵阵封住退路。\n\n同境界以操作取胜；面对高一大境界的对手，破阵与撤离才是正确目标。",
		"按 Enter 开始"
	)
	_refresh_hud()


func _process(delta: float) -> void:
	if is_instance_valid(_player):
		var target_position := _player.global_position + camera_offset
		var weight := minf(1.0, delta * camera_follow_speed)
		_camera.global_position = _camera.global_position.lerp(target_position, weight)
		_camera.look_at(_player.global_position + Vector3(0.0, 0.55, 0.0), Vector3.UP)
		var shake := _feedback.camera_offset()
		_camera.h_offset = shake.x
		_camera.v_offset = shake.y
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("toggle_feedback_motion"):
		_feedback.set_reduced_motion(not _feedback.reduced_motion)
		return
	if event.is_action_pressed("toggle_sound"):
		_feedback.audio.set_muted(not _feedback.audio.muted)
		return
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return

	if event.is_action_pressed("start_demo"):
		if _phase == DemoPhase.INTRO:
			_start_demo()
		elif _phase == DemoPhase.VICTORY or _phase == DemoPhase.DEFEAT:
			get_tree().reload_current_scene()


func start_demo_for_test() -> void:
	if _phase == DemoPhase.INTRO:
		_start_demo()


func force_complete_phase_for_test() -> void:
	if _phase == DemoPhase.COMBAT:
		for node in get_tree().get_nodes_in_group("combat_enemies"):
			var enemy := node as CombatActor
			if enemy != null and not enemy.is_dead:
				enemy.force_defeat()
	elif _phase == DemoPhase.ESCAPE:
		for node in get_tree().get_nodes_in_group("demo_objectives"):
			var anchor := node as CombatActor
			if anchor != null and not anchor.is_dead:
				anchor.force_defeat()


func phase_name_for_test() -> String:
	match _phase:
		DemoPhase.INTRO:
			return "intro"
		DemoPhase.COMBAT:
			return "combat"
		DemoPhase.ESCAPE:
			return "escape"
		DemoPhase.VICTORY:
			return "victory"
		DemoPhase.DEFEAT:
			return "defeat"
	return "unknown"


func escape_portal_active_for_test() -> bool:
	return _portal.is_active()


func alive_enemy_count_for_test() -> int:
	return _alive_enemy_count()


func remaining_anchor_count_for_test() -> int:
	return _remaining_anchor_count()


func _start_demo() -> void:
	_phase = DemoPhase.COMBAT
	_overlay.visible = false
	_player.set_input_enabled(true)
	_objective_text = "击退谷口炼气邪修"
	_last_message = "战斗开始：连续按 J/左键衔接三段御剑，Q 释放剑诀，E 展开护体。"
	_spawn_first_wave()


func _spawn_first_wave() -> void:
	_spawn_enemy(
		"持刀散修",
		RealmRules.MajorRealm.QI_REFINING,
		5,
		TrainingEnemy.CombatStyle.MELEE,
		Vector3(-5.2, 0.0, -1.2),
		Color(0.66, 0.25, 0.20, 1.0),
		92.0,
		17.0,
		6.0,
		2.9,
		1.0
	)
	_spawn_enemy(
		"御器散修",
		RealmRules.MajorRealm.QI_REFINING,
		6,
		TrainingEnemy.CombatStyle.MELEE,
		Vector3(4.8, 0.0, -0.8),
		Color(0.59, 0.30, 0.22, 1.0),
		102.0,
		18.0,
		7.0,
		3.1,
		1.05
	)
	var talisman_enemy := _spawn_enemy(
		"符箓邪修",
		RealmRules.MajorRealm.QI_REFINING,
		7,
		TrainingEnemy.CombatStyle.RANGED,
		Vector3(0.0, 0.0, -6.8),
		Color(0.64, 0.19, 0.31, 1.0),
		88.0,
		19.0,
		5.0,
		2.55,
		0.82
	)
	talisman_enemy.ranged_audio_cue = &"talisman_cast"


func _begin_escape_phase() -> void:
	if _phase != DemoPhase.COMBAT:
		return

	_phase = DemoPhase.ESCAPE
	_player.recover_between_phases()
	_spawn_anchor(Vector3(-6.1, 0.0, -2.2))
	_spawn_anchor(Vector3(0.0, 0.0, -7.2))
	_spawn_anchor(Vector3(6.1, 0.0, -2.2))

	_guardian = _spawn_enemy(
		"筑基守阵修士",
		RealmRules.MajorRealm.FOUNDATION_ESTABLISHMENT,
		1,
		TrainingEnemy.CombatStyle.GUARDIAN,
		Vector3(0.0, 0.0, -3.8),
		Color(0.42, 0.30, 0.52, 1.0),
		260.0,
		24.0,
		13.0,
		3.0,
		1.12
	)
	_guardian.attack_windup = 0.72
	_guardian.attack_cooldown = 1.25
	_guardian.projectile_speed = 10.0
	_guardian.ranged_max_distance = 8.5
	_guardian.detection_range = 30.0
	_guardian.set_incoming_damage_multiplier(0.32)

	_portal.set_active(false)
	_objective_text = DemoRules.escape_objective(_remaining_anchor_count(), false)
	_last_message = "筑基修士现身：普通攻击难以破防。不要恋战，先毁阵眼。"


func _spawn_enemy(
	name: String,
	realm: int,
	stage: int,
	style: int,
	spawn_position: Vector3,
	tint: Color,
	health: float,
	attack: float,
	base_defense_value: float,
	speed: float,
	multiplier: float
) -> TrainingEnemy:
	var enemy := ENEMY_SCENE.instantiate() as TrainingEnemy
	enemy.actor_name = name
	enemy.major_realm = realm
	enemy.minor_stage = stage
	enemy.combat_style = style
	enemy.position = spawn_position
	enemy.body_tint = tint
	enemy.base_max_health = health
	enemy.base_attack = attack
	enemy.base_defense = base_defense_value
	enemy.move_speed = speed
	enemy.attack_multiplier = multiplier
	_actors.add_child(enemy)
	_feedback.observe(enemy)
	enemy.died.connect(_on_enemy_died)
	return enemy


func _spawn_anchor(spawn_position: Vector3) -> FormationAnchor:
	var anchor := ANCHOR_SCENE.instantiate() as FormationAnchor
	anchor.position = spawn_position
	_actors.add_child(anchor)
	_feedback.observe(anchor)
	anchor.anchor_broken.connect(_on_anchor_broken)
	return anchor


func _on_combat_message(message: String) -> void:
	_last_message = message


func _on_player_damage_received(_actor, amount: float, source) -> void:
	var source_name := "未知术法"
	if source is CombatActor:
		source_name = source.actor_name
	var guard_note := "（护体灵光已减伤）" if _player.is_guard_active() else ""
	_last_message = "%s 对你造成 %.1f 伤害%s。" % [source_name, amount, guard_note]


func _on_player_died(_actor) -> void:
	if _phase == DemoPhase.VICTORY:
		return
	_phase = DemoPhase.DEFEAT
	_stop_combat()
	_show_overlay(
		"道途暂断",
		"你在青岚谷中陨落。观察敌人前摇，保留灵力用于护体，并在筑基修士出现后优先破坏阵眼。",
		"按 Enter 或 R 重新开始"
	)
	_last_message = "本次试炼失败。"


func _on_enemy_died(actor) -> void:
	if actor is CombatActor:
		_last_message = "已击败 %s（%s）。" % [actor.actor_name, actor.realm_label()]
	if _phase == DemoPhase.COMBAT:
		call_deferred("_check_combat_phase_complete")


func _check_combat_phase_complete() -> void:
	if _phase == DemoPhase.COMBAT and _alive_enemy_count() == 0:
		_begin_escape_phase()


func _on_anchor_broken(_anchor) -> void:
	call_deferred("_check_anchor_progress")


func _check_anchor_progress() -> void:
	if _phase != DemoPhase.ESCAPE:
		return
	var remaining := _remaining_anchor_count()
	if remaining == 0:
		_portal.set_active(true)
		_objective_text = DemoRules.escape_objective(0, true)
		_last_message = "锁灵阵崩解，南侧遁光阵已经恢复。立即撤离。"
	else:
		_objective_text = DemoRules.escape_objective(remaining, false)
		_last_message = "阵眼破碎，剩余 %d 处。" % remaining


func _on_portal_escaped(_actor) -> void:
	if _phase != DemoPhase.ESCAPE or not _portal.is_active():
		return
	_phase = DemoPhase.VICTORY
	_stop_combat()
	_show_overlay(
		"脱身成功",
		"你没有与筑基修士死战，而是破坏阵眼并借遁光阵离开青岚谷。\n\nDemo 完成：同境界战斗、灵力管理、远程预警、境界压制与撤离目标均已走通。",
		"按 Enter 或 R 再次挑战"
	)
	_last_message = "青岚谷初版 Demo 已完成。"


func _stop_combat() -> void:
	_player.set_input_enabled(false)
	_player.invulnerable = true
	_set_enemy_ai_enabled(false)
	for projectile in get_tree().get_nodes_in_group("combat_projectiles"):
		projectile.queue_free()


func _set_enemy_ai_enabled(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("combat_enemies"):
		var enemy := node as TrainingEnemy
		if enemy != null and not enemy.is_dead:
			enemy.set_ai_enabled(enabled)


func _alive_enemy_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("combat_enemies"):
		var enemy := node as CombatActor
		if enemy != null and not enemy.is_dead:
			count += 1
	return count


func _remaining_anchor_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("demo_objectives"):
		var anchor := node as CombatActor
		if anchor != null and not anchor.is_dead:
			count += 1
	return count


func _refresh_hud() -> void:
	if not is_instance_valid(_player):
		return

	_player_status.text = "%s · %s" % [_player.actor_name, _player.realm_label()]
	_health_bar.max_value = _player.max_health
	_health_bar.value = _player.current_health
	_health_bar.tooltip_text = "气血 %.0f / %.0f" % [_player.current_health, _player.max_health]
	_spirit_bar.max_value = _player.max_spirit
	_spirit_bar.value = _player.current_spirit
	_spirit_bar.tooltip_text = "灵力 %.0f / %.0f" % [_player.current_spirit, _player.max_spirit]

	_skill_status.text = "J 三段御剑  |  Q 青锋剑诀 %s  |  E 护体灵光 %s  |  Space 身法 %s" % [
		_cooldown_text(_player.sword_art_cooldown_left()),
		_cooldown_text(_player.guard_cooldown_left()),
		_cooldown_text(_player.dodge_cooldown_left()),
	]
	_skill_status.text += "\nF6 减弱动态：%s  |  M 音效：%s" % [
		"开" if _feedback.reduced_motion else "关",
		"关" if _feedback.audio.muted else "开",
	]
	_objective_label.text = "当前目标：%s" % _objective_text
	_threat_label.text = _build_threat_text()
	_message_label.text = _last_message


func _build_threat_text() -> String:
	if _phase == DemoPhase.COMBAT:
		return "炼气敌人剩余：%d" % _alive_enemy_count()
	if _phase == DemoPhase.ESCAPE:
		var assessment := "九死一生"
		if is_instance_valid(_guardian) and not _guardian.is_dead:
			assessment = RealmRules.threat_assessment(
				_player.threat_index(),
				_guardian.threat_index()
			)
		return "阵眼剩余：%d  |  筑基威胁：%s" % [_remaining_anchor_count(), assessment]
	if _phase == DemoPhase.VICTORY:
		return "结果：成功撤离"
	if _phase == DemoPhase.DEFEAT:
		return "结果：试炼失败"
	return "阶段：战前准备"


func _cooldown_text(value: float) -> String:
	if value <= 0.05:
		return "可用"
	return "%.1fs" % value


func _show_overlay(title: String, body: String, prompt: String) -> void:
	_overlay.visible = true
	_overlay_title.text = title
	_overlay_body.text = body
	_overlay_prompt.text = prompt
