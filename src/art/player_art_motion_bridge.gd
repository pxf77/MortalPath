class_name PlayerArtMotionBridge
extends Node
## Maps existing player signals to the versioned presentation asset.
## Animation and ribbon trails never own movement, hit detection or damage timing.

const HIT_HEAVY_RATIO := 0.18
const MIN_PLAYBACK_SPEED := 0.01
const MAX_DURATION_ALIGNMENT_SPEED := 4.0

var _player: PlayerController = null
var _visual: Node3D = null
var _animation_player: AnimationPlayer = null
var _sword_tip: Node3D = null
var _trail: FlyingSwordTrail3D = null
var _transient_animation: StringName = &""
var _last_played_clip: StringName = &""
var _last_release_clip: StringName = &""
var _loop_clip: StringName = &""
var _active_custom_speed := 1.0
var _dead := false


func configure(player: PlayerController, visual: Node3D) -> void:
	_player = player
	_visual = visual
	_animation_player = _find_animation_player(visual)
	_sword_tip = _find_named_node(visual, PlayerArtMotionContract.sword_tip_node()) as Node3D
	if _animation_player == null:
		push_warning("player art asset has no AnimationPlayer")
		return

	_configure_loop(PlayerArtMotionContract.idle_clip())
	_configure_loop(PlayerArtMotionContract.locomotion_clip())
	_connect_player_signals()
	_install_trail()
	_play_loop(PlayerArtMotionContract.idle_clip())


func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or _animation_player == null or _dead:
		return
	if _transient_animation != &"":
		if _animation_player.is_playing():
			return
		_transient_animation = &""
		_active_custom_speed = 1.0
		_animation_player.speed_scale = 1.0
	var desired := PlayerArtMotionContract.idle_clip()
	if _player.velocity.length_squared() > 0.04 and _player.input_enabled:
		desired = PlayerArtMotionContract.locomotion_clip()
	_play_loop(desired)


func _exit_tree() -> void:
	if is_instance_valid(_trail):
		_trail.queue_free()


func _connect_player_signals() -> void:
	if not _player.action_started.is_connected(_on_action_started):
		_player.action_started.connect(_on_action_started)
	if not _player.action_released.is_connected(_on_action_released):
		_player.action_released.connect(_on_action_released)
	if not _player.damage_received.is_connected(_on_damage_received):
		_player.damage_received.connect(_on_damage_received)
	if not _player.died.is_connected(_on_died):
		_player.died.connect(_on_died)
	if not _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.connect(_on_animation_finished)


func _install_trail() -> void:
	if not is_instance_valid(_sword_tip) or is_instance_valid(_trail):
		return
	_trail = FlyingSwordTrail3D.new()
	_trail.name = "FlyingSwordTrail"
	var scene := get_tree().current_scene
	if scene != null:
		scene.add_child(_trail)
	else:
		get_tree().root.add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY
	_trail.configure(_sword_tip)


func _on_action_started(action: StringName, combo_step: int) -> void:
	if _dead:
		return
	var clip := PlayerArtMotionContract.clip_for_action(action, combo_step)
	if clip == &"":
		return
	var speed := PlayerArtMotionContract.playback_speed_for(
		action,
		combo_step,
		_logic_windup_seconds(action, combo_step)
	)
	if action == &"dodge" and is_instance_valid(_player):
		speed = _duration_aligned_speed(clip, _player.dodge_duration)
	_play_transient(clip, speed)


func _on_action_released(action: StringName, combo_step: int) -> void:
	if _dead:
		return
	var clip := PlayerArtMotionContract.clip_for_action(action, combo_step)
	if clip == &"":
		return
	_last_release_clip = clip
	var rule := PlayerArtMotionContract.rule_for_action(action, combo_step)
	if not rule.is_empty() and is_instance_valid(_trail):
		_trail.emit_for(rule)
	if _animation_player != null and _active_custom_speed > 0.001:
		# AnimationPlayer multiplies play(custom_speed) by speed_scale. The windup
		# uses an accelerated custom speed; after release, its reciprocal restores
		# the remaining recovery frames to authored 1x speed.
		_animation_player.speed_scale = 1.0 / _active_custom_speed


func _on_damage_received(_actor, amount: float, _source) -> void:
	if _dead or not is_instance_valid(_player):
		return
	var clip := &"hit_heavy" if amount >= _player.max_health * HIT_HEAVY_RATIO else &"hit_light"
	_play_transient(clip, 1.0)


func _on_died(_actor) -> void:
	_dead = true
	# CombatActor hides dead actors before emitting died. Restore presentation
	# visibility only; collision and physics remain disabled by the combat core.
	if is_instance_valid(_player):
		_player.visible = true
	if is_instance_valid(_visual):
		_visual.visible = true
	if is_instance_valid(_trail):
		_trail.stop_emission()
	_play_transient(&"death", 1.0)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != _transient_animation or _dead:
		return
	_transient_animation = &""
	_active_custom_speed = 1.0
	_animation_player.speed_scale = 1.0


func _play_loop(clip: StringName) -> void:
	if clip == &"" or clip == _loop_clip:
		return
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		return
	_animation_player.speed_scale = 1.0
	_animation_player.play(resolved, 0.12, 1.0)
	_loop_clip = clip
	_last_played_clip = clip


func _play_transient(clip: StringName, custom_speed: float) -> void:
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		return
	_animation_player.speed_scale = 1.0
	_active_custom_speed = maxf(MIN_PLAYBACK_SPEED, custom_speed)
	_animation_player.play(resolved, 0.06, _active_custom_speed)
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
	if _animation_player == null:
		return &""
	if _animation_player.has_animation(clip):
		return clip
	var wanted := String(clip)
	for candidate in _animation_player.get_animation_list():
		var text := String(candidate)
		if text.ends_with("/" + wanted) or text.ends_with("|" + wanted) or text.ends_with(":" + wanted):
			return candidate
	return &""


func _logic_windup_seconds(action: StringName, combo_step: int) -> float:
	if not is_instance_valid(_player):
		return 0.0
	return _player.action_windup_seconds(action, combo_step)


func _duration_aligned_speed(clip: StringName, target_duration: float) -> float:
	if _animation_player == null or target_duration <= 0.001:
		return 1.0
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		return 1.0
	var animation := _animation_player.get_animation(resolved)
	if animation == null or animation.length <= 0.001:
		return 1.0
	return clampf(
		animation.length / target_duration,
		MIN_PLAYBACK_SPEED,
		MAX_DURATION_ALIGNMENT_SPEED
	)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_named_node(node: Node, wanted: StringName) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named_node(child, wanted)
		if found != null:
			return found
	return null


func is_ready_for_test() -> bool:
	return _animation_player != null and is_instance_valid(_sword_tip) and is_instance_valid(_trail) and PlayerArtMotionContract.is_loaded()


func animation_player_for_test() -> AnimationPlayer:
	return _animation_player


func trail_for_test() -> FlyingSwordTrail3D:
	return _trail


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
