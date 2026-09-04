class_name EnemyArtMotionBridge
extends Node
## Presentation-only adapter from existing enemy signals to a versioned Art Pack.
## AI decisions, movement, collision, damage and attack resolution stay game-owned.

const MIN_PLAYBACK_SPEED := 0.01

var _enemy: TrainingEnemy = null
var _visual: Node3D = null
var _asset_id: StringName = &""
var _animation_player: AnimationPlayer = null
var _transient_animation: StringName = &""
var _loop_clip: StringName = &""
var _last_played_clip: StringName = &""
var _last_release_clip: StringName = &""
var _active_custom_speed := 1.0
var _guarded := false
var _dead := false


func configure(
	enemy: TrainingEnemy,
	visual: Node3D,
	asset_id: StringName
) -> void:
	_enemy = enemy
	_visual = visual
	_asset_id = asset_id
	_animation_player = _find_animation_player(visual)
	if _animation_player == null:
		push_warning("enemy art asset has no AnimationPlayer: %s" % asset_id)
		return
	_configure_loop(EnemyArtMotionContract.idle_clip(_asset_id))
	_configure_loop(EnemyArtMotionContract.locomotion_clip(_asset_id))
	_configure_loop(EnemyArtMotionContract.guard_clip(_asset_id))
	_guarded = _enemy.incoming_damage_multiplier < 0.99
	_connect_enemy_signals()
	_play_loop(_rest_clip())


func _process(_delta: float) -> void:
	if not is_instance_valid(_enemy) or _animation_player == null or _dead:
		return
	if _transient_animation != &"":
		if _animation_player.is_playing():
			return
		_finish_transient()
	_play_loop(
		EnemyArtMotionContract.locomotion_clip(_asset_id)
		if _enemy.velocity.length_squared() > 0.04
		else _rest_clip()
	)


func _connect_enemy_signals() -> void:
	if not _enemy.attack_started.is_connected(_on_attack_started):
		_enemy.attack_started.connect(_on_attack_started)
	if not _enemy.attack_released.is_connected(_on_attack_released):
		_enemy.attack_released.connect(_on_attack_released)
	if not _enemy.damage_received.is_connected(_on_damage_received):
		_enemy.damage_received.connect(_on_damage_received)
	if not _enemy.damage_modifier_changed.is_connected(_on_damage_modifier_changed):
		_enemy.damage_modifier_changed.connect(_on_damage_modifier_changed)
	if not _enemy.died.is_connected(_on_died):
		_enemy.died.connect(_on_died)
	if not _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.connect(_on_animation_finished)


func _on_attack_started(kind: int, windup_seconds: float) -> void:
	if _dead:
		return
	var attack_kind := _attack_kind_name(kind)
	var clip := EnemyArtMotionContract.attack_clip(_asset_id, attack_kind)
	if clip == &"":
		return
	var speed := EnemyArtMotionContract.attack_playback_speed(
		_asset_id,
		attack_kind,
		windup_seconds
	)
	_play_transient(clip, speed)


func _on_attack_released(kind: int) -> void:
	if _dead:
		return
	var clip := EnemyArtMotionContract.attack_clip(
		_asset_id,
		_attack_kind_name(kind)
	)
	if clip == &"":
		return
	_last_release_clip = clip
	if _animation_player != null and _active_custom_speed > 0.001:
		_animation_player.speed_scale = 1.0 / _active_custom_speed


func _on_damage_received(_actor, amount: float, source) -> void:
	if _dead or not is_instance_valid(_enemy):
		return
	var weight := (
		&"heavy"
		if amount >= _enemy.max_health * EnemyArtMotionContract.heavy_hit_ratio(_asset_id)
		else &"light"
	)
	_play_transient(
		EnemyArtMotionContract.hit_clip(
			_asset_id,
			weight,
			_hit_direction(source)
		),
		1.0
	)


func _on_damage_modifier_changed(_actor, multiplier: float) -> void:
	_guarded = multiplier < 0.99
	if _transient_animation == &"" and is_instance_valid(_enemy):
		_play_loop(_rest_clip())


func _on_died(_actor) -> void:
	_dead = true
	# CombatActor disables physics/collision and hides the actor before emitting
	# died. Restore presentation visibility only so the authored death can play.
	if is_instance_valid(_enemy):
		_enemy.visible = true
	if is_instance_valid(_visual):
		_visual.visible = true
	_play_transient(EnemyArtMotionContract.death_clip(_asset_id), 1.0)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != _transient_animation or _dead:
		return
	_finish_transient()


func _finish_transient() -> void:
	_transient_animation = &""
	_active_custom_speed = 1.0
	if _animation_player != null:
		_animation_player.speed_scale = 1.0
	_play_loop(_rest_clip())


func _rest_clip() -> StringName:
	var guard := EnemyArtMotionContract.guard_clip(_asset_id)
	if _guarded and guard != &"":
		return guard
	return EnemyArtMotionContract.idle_clip(_asset_id)


func _attack_kind_name(kind: int) -> StringName:
	return (
		&"ranged"
		if kind == TrainingEnemy.AttackKind.RANGED
		else &"melee"
	)


func _play_loop(clip: StringName) -> void:
	if clip == &"" or clip == _loop_clip:
		return
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		return
	_animation_player.speed_scale = 1.0
	_animation_player.play(
		resolved,
		EnemyArtMotionContract.blend_seconds(_asset_id),
		1.0
	)
	_transient_animation = &""
	_loop_clip = clip
	_last_played_clip = clip
	_active_custom_speed = 1.0


func _play_transient(clip: StringName, custom_speed: float) -> void:
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		return
	_animation_player.speed_scale = 1.0
	_active_custom_speed = maxf(MIN_PLAYBACK_SPEED, custom_speed)
	_animation_player.play(
		resolved,
		EnemyArtMotionContract.blend_seconds(_asset_id),
		_active_custom_speed
	)
	_transient_animation = resolved
	_loop_clip = &""
	_last_played_clip = clip


func _configure_loop(clip: StringName) -> void:
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		return
	var animation := _animation_player.get_animation(resolved)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR


func _resolve_clip(clip: StringName) -> StringName:
	if _animation_player == null or clip == &"":
		return &""
	if _animation_player.has_animation(clip):
		return clip
	var wanted := String(clip)
	for candidate in _animation_player.get_animation_list():
		var text := String(candidate)
		if text.ends_with("/" + wanted) or text.ends_with("|" + wanted) or text.ends_with(":" + wanted):
			return candidate
	return &""


func _hit_direction(source) -> StringName:
	if not source is Node3D or not is_instance_valid(source) or not is_instance_valid(_enemy):
		return &"front"
	var toward_source := (source as Node3D).global_position - _enemy.global_position
	toward_source.y = 0.0
	if toward_source.length_squared() <= 0.0001:
		return &"front"
	toward_source = toward_source.normalized()
	var forward := -_enemy.global_basis.z.normalized()
	var right := _enemy.global_basis.x.normalized()
	var forward_dot := toward_source.dot(forward)
	var right_dot := toward_source.dot(right)
	if absf(forward_dot) >= absf(right_dot):
		return &"front" if forward_dot >= 0.0 else &"back"
	return &"right" if right_dot >= 0.0 else &"left"


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func is_ready_for_test() -> bool:
	return (
		_animation_player != null
		and EnemyArtMotionContract.is_loaded(_asset_id)
	)


func asset_id_for_test() -> StringName:
	return _asset_id


func animation_player_for_test() -> AnimationPlayer:
	return _animation_player


func resolve_clip_for_test(clip: StringName) -> StringName:
	return _resolve_clip(clip)


func last_played_clip_for_test() -> StringName:
	return _last_played_clip


func last_release_clip_for_test() -> StringName:
	return _last_release_clip


func current_playback_speed_for_test() -> float:
	return _active_custom_speed


func effective_playback_speed_for_test() -> float:
	if _animation_player == null:
		return 0.0
	return _active_custom_speed * _animation_player.speed_scale


func transient_animation_for_test() -> StringName:
	return _transient_animation


func hit_direction_for_test(source: Node3D) -> StringName:
	return _hit_direction(source)


func guarded_for_test() -> bool:
	return _guarded
