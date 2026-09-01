class_name MortalPathMain
extends Node3D

@export var camera_offset := Vector3(10.5, 14.0, 10.5)

@onready var _player: PlayerController = $Player
@onready var _camera: Camera3D = $Camera3D
@onready var _player_status: Label = $HUD/Panel/Margin/VBox/PlayerStatus
@onready var _enemy_status: Label = $HUD/Panel/Margin/VBox/EnemyStatus
@onready var _message_label: Label = $HUD/Panel/Margin/VBox/Message

var _last_message := "先挑战炼气敌人，再接近筑基敌人；按 B 可调试突破。"


func _ready() -> void:
	_player.combat_message.connect(_on_combat_message)
	_player.damage_received.connect(_on_player_damage_received)
	_player.died.connect(_on_player_died)

	for node in get_tree().get_nodes_in_group("combat_enemies"):
		var enemy := node as CombatActor
		if enemy != null:
			enemy.died.connect(_on_enemy_died)

	_refresh_hud()


func _process(_delta: float) -> void:
	if is_instance_valid(_player):
		_camera.global_position = _player.global_position + camera_offset
		_camera.look_at(_player.global_position + Vector3(0.0, 0.6, 0.0), Vector3.UP)

	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _refresh_hud() -> void:
	if not is_instance_valid(_player):
		return

	var player_state := "已陨落" if _player.is_dead else "存活"
	_player_status.text = (
		"玩家：%s | %s | HP %.0f / %.0f | 威胁指数 %.1f"
		% [
			_player.actor_name,
			_player.realm_label(),
			_player.current_health,
			_player.max_health,
			_player.threat_index(),
		]
	)
	if _player.is_dead:
		_player_status.text += " | %s，按 R 重置" % player_state

	var enemy_lines: Array[String] = []
	for node in get_tree().get_nodes_in_group("combat_enemies"):
		var enemy := node as CombatActor
		if enemy == null:
			continue

		if enemy.is_dead:
			enemy_lines.append("%s：已击败" % enemy.actor_name)
			continue

		var assessment := RealmRules.threat_assessment(
			_player.threat_index(),
			enemy.threat_index()
		)
		enemy_lines.append(
			"%s | %s | HP %.0f / %.0f | 神识判断：%s"
			% [
				enemy.actor_name,
				enemy.realm_label(),
				enemy.current_health,
				enemy.max_health,
				assessment,
			]
		)

	_enemy_status.text = "\n".join(enemy_lines)
	_message_label.text = "战斗记录：%s" % _last_message


func _on_combat_message(message: String) -> void:
	_last_message = message


func _on_player_damage_received(_actor, amount: float, source) -> void:
	var source_name := "未知敌人"
	if source is CombatActor:
		source_name = source.actor_name
	_last_message = "%s 对你造成 %.1f 伤害。" % [source_name, amount]


func _on_player_died(_actor) -> void:
	_last_message = "你已陨落。高境界敌人不应被视为普通血条，按 R 重置。"


func _on_enemy_died(actor) -> void:
	if actor is CombatActor:
		_last_message = "已击败 %s（%s）。" % [actor.actor_name, actor.realm_label()]
