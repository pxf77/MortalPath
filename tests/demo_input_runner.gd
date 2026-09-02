extends SceneTree
## Normal-input regression, NOT a substitute for human playtesting.
## Never teleports, heals, grants invulnerability, defeats actors, or emits victory.

const MAIN := preload("res://src/main/main.tscn")
const MAX_FRAMES := 18000
var _failures := 0
var _results: Array = []
var _capture := false
var _output := "user://m1-evidence"
var _metrics: Dictionary = {}
var _captured_cues: Dictionary = {}


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--capture":
			_capture = true
		elif argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	if _capture and DisplayServer.get_name() == "headless":
		push_error("--capture requires a graphical display, not --headless.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	for run_index in range(3):
		var demo := MAIN.instantiate() as MortalPathMain
		root.add_child(demo)
		current_scene = demo
		await process_frame
		var player := demo.get_node("Player") as PlayerController
		_metrics = {"run": run_index + 1, "actions": {}, "combo_finishes": 0, "hits": 0, "misses": 0, "damage_taken": 0.0}
		player.action_started.connect(_record_action)
		player.attack_finished.connect(_record_attack)
		player.damage_received.connect(_record_damage)
		if _capture and run_index == 0:
			(demo.get_node("CombatFeedback") as CombatFeedback).cue_played.connect(_record_cue)
		if run_index == 1:
			_tap(&"toggle_feedback_motion")
		if run_index == 2:
			_tap(&"toggle_sound")
		_tap(&"start_demo")
		var previous_phase := "intro"
		var frames_used := 0
		var start_frame := Engine.get_physics_frames()
		for frame in range(MAX_FRAMES):
			await physics_frame
			frames_used = Engine.get_physics_frames() - start_frame
			var phase := demo.phase_name_for_test()
			if phase != previous_phase:
				print("Input run %d: %s, HP %.1f" % [run_index + 1, phase, player.current_health])
				previous_phase = phase
				if _capture:
					await _screenshot("run-%d-%s.png" % [run_index + 1, phase])
			if phase == "victory" or phase == "defeat":
				break
			_drive(demo, player, frame)
		_release_movement()
		_metrics["result"] = demo.phase_name_for_test()
		_metrics["simulation_seconds"] = snappedf(float(frames_used) / 60.0, 0.01)
		_metrics["health_remaining"] = player.current_health
		var guardian := demo.get("_guardian") as CombatActor
		_metrics["guardian_alive"] = guardian != null and not guardian.is_dead
		_metrics["reduced_motion"] = run_index == 1
		_metrics["muted"] = run_index == 2
		_results.append(_metrics.duplicate(true))
		if demo.phase_name_for_test() != "victory":
			_failures += 1
			push_error("Normal-input run %d did not win: %s" % [run_index + 1, str(_metrics)])
		elif not _metrics.guardian_alive:
			_failures += 1
			push_error("Run must escape with the higher-realm guardian still alive.")
		demo.queue_free()
		await process_frame
		await process_frame
	var file := FileAccess.open(_output.path_join("input-runs.json"), FileAccess.WRITE)
	if file == null:
		_failures += 1
	else:
		file.store_string(JSON.stringify({"method": "automated normal input; not human acceptance", "runs": _results, "failures": _failures}, "\t"))
		file.close()
	print(JSON.stringify(_results))
	print("Normal-input runs: 3; failures: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func _drive(demo: MortalPathMain, player: PlayerController, frame: int) -> void:
	var target: Node3D = null
	if demo.phase_name_for_test() == "escape" and demo.escape_portal_active_for_test():
		target = demo.get_node("EscapePortal")
	else:
		var group := "demo_objectives" if demo.phase_name_for_test() == "escape" else "combat_enemies"
		var best_distance := INF
		for candidate in get_nodes_in_group(group):
			if not candidate.can_be_targeted():
				continue
			var distance: float = player.global_position.distance_to(candidate.global_position)
			if distance < best_distance:
				target = candidate
				best_distance = distance
	if target == null:
		_release_movement()
		return
	var offset := target.global_position - player.global_position
	offset.y = 0.0
	_move_toward(offset.normalized(), player)
	if not target is CombatActor:
		return
	# Continuous approach aims with movement, exactly as keyboard-only play does.
	if offset.length() < 2.15 and frame % 12 == 0:
		_tap(&"attack")
	if offset.length() < 7.0 and player.sword_art_cooldown_left() <= 0.0 and player.current_spirit >= 55.0 and frame % 12 == 6:
		_tap(&"sword_art")
	if player.guard_cooldown_left() <= 0.0 and player.current_spirit >= 25.0:
		_tap(&"spirit_guard")
	if player.dodge_cooldown_left() <= 0.0:
		for projectile in get_nodes_in_group("combat_projectiles"):
			if player.global_position.distance_to(projectile.global_position) < 2.0:
				_tap(&"dodge")
				break
		for enemy in get_nodes_in_group("combat_enemies"):
			if not enemy.is_dead and enemy.get("_windup_left") > 0.0 and enemy.get("_windup_left") < 0.18 and player.global_position.distance_to(enemy.global_position) < 2.2:
				_tap(&"dodge")
				break


func _move_toward(direction: Vector3, player: PlayerController) -> void:
	var camera := player.get_viewport().get_camera_3d()
	var right := camera.global_basis.x
	var down := camera.global_basis.z
	right.y = 0.0
	down.y = 0.0
	var horizontal := direction.dot(right.normalized())
	var vertical := direction.dot(down.normalized())
	_release_movement()
	Input.action_press(&"move_right" if horizontal >= 0.0 else &"move_left", absf(horizontal))
	Input.action_press(&"move_down" if vertical >= 0.0 else &"move_up", absf(vertical))


func _release_movement() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _tap(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)


func _record_action(action: StringName, _step: int) -> void:
	_metrics.actions[action] = int(_metrics.actions.get(action, 0)) + 1


func _record_attack(_action: StringName, step: int, hits: int) -> void:
	_metrics.hits += hits
	if hits == 0:
		_metrics.misses += 1
	if step == 3:
		_metrics.combo_finishes += 1


func _record_damage(_actor, amount: float, _source) -> void:
	_metrics.damage_taken += amount


func _record_cue(kind: StringName) -> void:
	if _captured_cues.has(kind):
		return
	_captured_cues[kind] = true
	# Capture this rendered contact frame, not whichever cue happens on a later tick.
	_screenshot("feedback-%s.png" % kind)


func _screenshot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_output.path_join(file_name)))
	if error != OK:
		_failures += 1
		push_error("Could not save evidence: %s" % file_name)
