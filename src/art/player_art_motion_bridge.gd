class_name PlayerArtMotionBridge
extends Node
## Maps existing player signals to the versioned presentation asset.
## Animation and ribbon trails never own movement, hit detection or damage timing.

const MIN_PLAYBACK_SPEED := 0.01
const MAX_DURATION_ALIGNMENT_SPEED := 4.0

var _player: PlayerController = null
var _visual: Node3D = null
var _animation_player: AnimationPlayer = null
var _sword_root: Node3D = null
var _sword_tip: Node3D = null
var _trail: FlyingSwordTrail3D = null
var _transient_animation: StringName = &""
var _last_played_clip: StringName = &""
var _last_release_clip: StringName = &""
var _loop_clip: StringName = &""
var _active_custom_speed := 1.0
var _moving := false
var _last_screen_direction := Vector2.ZERO
var _transition_target_loop: StringName = &""
var _unlock_visual_after_transition := false
var _visual_screen_locked := false
var _dead := false


func configure(player: PlayerController, visual: Node3D) -> void:
	_player = player
	_visual = visual
	_animation_player = _find_animation_player(visual)
	_sword_root = _find_named_node(visual, PlayerArtMotionContract.sword_root_node()) as Node3D
	_sword_tip = _find_named_node(visual, PlayerArtMotionContract.sword_tip_node()) as Node3D
	if _animation_player == null:
		push_warning("player art asset has no AnimationPlayer")
		return

	_configure_loop(PlayerArtMotionContract.idle_clip())
	for direction in [Vector2(0.0, -1.0), Vector2(0.707, -0.707), Vector2(1.0, 0.0), Vector2(0.707, 0.707), Vector2(0.0, 1.0), Vector2(-0.707, 0.707), Vector2(-1.0, 0.0), Vector2(-0.707, -0.707)]:
		_configure_loop(PlayerArtMotionContract.locomotion_clip_for_screen_vector(direction))
	_connect_player_signals()
	_install_trail()
	_play_loop(PlayerArtMotionContract.idle_clip())


func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or _animation_player == null or _dead:
		return
	if _visual_screen_locked:
		_set_visual_screen_locked(true)
	if _transient_animation != &"":
		if _animation_player.is_playing():
			return
		_finish_transient()

	var screen_direction := _screen_velocity_direction()
	var is_moving := screen_direction.length_squared() > 0.0001 and _player.input_enabled
	if is_moving:
		_set_visual_screen_locked(true)
		var desired := PlayerArtMotionContract.locomotion_clip_for_screen_vector(screen_direction)
		if not _moving:
			_moving = true
			_last_screen_direction = screen_direction
			_play_transition(PlayerArtMotionContract.locomotion_start_clip(), desired)
			return
		if not _last_screen_direction.is_zero_approx() and _last_screen_direction.dot(screen_direction) <= PlayerArtMotionContract.locomotion_turn_threshold_dot():
			_last_screen_direction = screen_direction
			_play_transition(PlayerArtMotionContract.locomotion_turn_clip(), desired)
			return
		_last_screen_direction = screen_direction
		_play_loop(desired)
		return

	if _moving:
		_moving = false
		_last_screen_direction = Vector2.ZERO
		_play_transition(
			PlayerArtMotionContract.locomotion_stop_clip(),
			PlayerArtMotionContract.idle_clip(),
			true
		)
		return
	_set_visual_screen_locked(false)
	_play_loop(PlayerArtMotionContract.idle_clip())


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
	_set_visual_screen_locked(false)
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


func _on_damage_received(_actor, amount: float, source) -> void:
	if _dead or not is_instance_valid(_player):
		return
	_set_visual_screen_locked(false)
	var weight := &"heavy" if amount >= _player.max_health * PlayerArtMotionContract.heavy_hit_ratio() else &"light"
	var clip := PlayerArtMotionContract.hit_clip(weight, _hit_direction(source))
	_play_transient(clip, 1.0)


func _on_died(_actor) -> void:
	_dead = true
	_set_visual_screen_locked(false)
	# CombatActor hides dead actors before emitting died. Restore presentation
	# visibility only; collision and physics remain disabled by the combat core.
	if is_instance_valid(_player):
		_player.visible = true
	if is_instance_valid(_visual):
		_visual.visible = true
	if is_instance_valid(_trail):
		_trail.stop_emission()
	_play_transient(PlayerArtMotionContract.death_clip(), 1.0)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != _transient_animation or _dead:
		return
	_finish_transient()


func _play_loop(clip: StringName) -> void:
	if clip == &"" or clip == _loop_clip:
		return
	var resolved := _resolve_clip(clip)
	if resolved == &"":
		return
	_animation_player.speed_scale = 1.0
	_animation_player.play(resolved, PlayerArtMotionContract.locomotion_blend_seconds(), 1.0)
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
	_transition_target_loop = &""
	_unlock_visual_after_transition = false
	_loop_clip = &""
	_last_played_clip = clip


func _play_transition(clip: StringName, target_loop: StringName, unlock_after: bool = false) -> void:
	_play_transient(clip, 1.0)
	if _transient_animation == &"":
		if unlock_after:
			_set_visual_screen_locked(false)
		_play_loop(target_loop)
		return
	_transition_target_loop = target_loop
	_unlock_visual_after_transition = unlock_after


func _finish_transient() -> void:
	_transient_animation = &""
	_active_custom_speed = 1.0
	_animation_player.speed_scale = 1.0
	var next_loop := _transition_target_loop
	var unlock_after := _unlock_visual_after_transition
	_transition_target_loop = &""
	_unlock_visual_after_transition = false
	if unlock_after:
		_set_visual_screen_locked(false)
	if next_loop != &"":
		_play_loop(next_loop)


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


func _screen_velocity_direction() -> Vector2:
	if not is_instance_valid(_player) or _player.velocity.length_squared() <= 0.04:
		return Vector2.ZERO
	var camera := _player.get_viewport().get_camera_3d()
	if camera == null:
		return Vector2(_player.velocity.x, _player.velocity.z).normalized()
	var right := camera.global_basis.x
	var down := camera.global_basis.z
	right.y = 0.0
	down.y = 0.0
	return Vector2(
		_player.velocity.dot(right.normalized()),
		_player.velocity.dot(down.normalized())
	).normalized()


func _set_visual_screen_locked(locked: bool) -> void:
	_visual_screen_locked = locked
	if not is_instance_valid(_visual) or not is_instance_valid(_player):
		return
	_visual.rotation.y = -_player.rotation.y if locked else 0.0


func _hit_direction(source) -> StringName:
	if not source is Node3D or not is_instance_valid(source) or not is_instance_valid(_player):
		return &"front"
	var toward_source := (source as Node3D).global_position - _player.global_position
	toward_source.y = 0.0
	if toward_source.length_squared() <= 0.0001:
		return &"front"
	toward_source = toward_source.normalized()
	var forward := -_player.global_basis.z.normalized()
	var right := _player.global_basis.x.normalized()
	var forward_dot := toward_source.dot(forward)
	var right_dot := toward_source.dot(right)
	if absf(forward_dot) >= absf(right_dot):
		return &"front" if forward_dot >= 0.0 else &"back"
	return &"right" if right_dot >= 0.0 else &"left"


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
	return _animation_player != null and is_instance_valid(_sword_root) and is_instance_valid(_sword_tip) and is_instance_valid(_trail) and PlayerArtMotionContract.is_loaded()


func animation_player_for_test() -> AnimationPlayer:
	return _animation_player


func trail_for_test() -> FlyingSwordTrail3D:
	return _trail


func sword_root_for_test() -> Node3D:
	return _sword_root


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


func screen_direction_clip_for_test(direction: Vector2) -> StringName:
	return PlayerArtMotionContract.locomotion_clip_for_screen_vector(direction)


func hit_direction_for_test(source: Node3D) -> StringName:
	return _hit_direction(source)


func visual_screen_locked_for_test() -> bool:
	return _visual_screen_locked
