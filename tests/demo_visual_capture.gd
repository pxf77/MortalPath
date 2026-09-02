extends SceneTree

const MAIN_SCENE := preload("res://src/main/main.tscn")
const OUTPUT_DIR := "res://demo-evidence"

var _capture_failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i.ZERO)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var demo := MAIN_SCENE.instantiate() as MortalPathMain
	root.add_child(demo)
	current_scene = demo
	await _wait_seconds(1.5)
	await _capture("01-intro.png")

	demo.start_demo_for_test()
	await process_frame
	var player := demo.get_node("Player") as PlayerController
	if player == null:
		push_error("Visual capture could not resolve the player.")
		quit(1)
		return

	# The capture driver tours the playable flow; normal CI separately validates
	# damage, failure and victory rules without granting invulnerability.
	player.invulnerable = true
	await _wait_seconds(1.0)
	await _capture("02-combat-wave.png")

	player.global_position = Vector3(0.0, 0.0, 2.2)
	player.call("_perform_combo_attack")
	await _wait_seconds(0.30)
	player.call("_perform_combo_attack")
	await _wait_seconds(0.34)
	player.call("_perform_combo_attack")
	await _wait_seconds(0.08)
	await _capture("03-three-hit-combo.png")

	player.call("_try_spirit_guard")
	await _wait_seconds(0.22)
	player.call("_try_sword_art")
	await _wait_seconds(0.08)
	await _capture("04-sword-art-and-guard.png")
	await _wait_seconds(0.90)

	demo.force_complete_phase_for_test()
	await process_frame
	await process_frame
	player.invulnerable = true
	player.global_position = Vector3(0.0, 0.0, 4.8)
	await _wait_seconds(1.0)
	await _capture("05-foundation-pressure.png")
	await _wait_seconds(0.90)

	demo.force_complete_phase_for_test()
	await process_frame
	await process_frame
	await _wait_seconds(0.65)
	await _capture("06-escape-portal-active.png")
	await _wait_seconds(0.75)

	var portal := demo.get_node("EscapePortal") as EscapePortal
	if portal == null or not portal.is_active():
		push_error("Visual capture expected an active escape portal.")
		_capture_failures += 1
	else:
		portal.escaped.emit(player)
		await process_frame
		await _wait_seconds(0.65)
		await _capture("07-victory.png")

	await _wait_seconds(1.0)
	demo.queue_free()
	await process_frame
	if _capture_failures == 0:
		print("MortalPath visual demo capture passed.")
	else:
		push_error("MortalPath visual demo capture failed: %d issue(s)." % _capture_failures)
	quit(_capture_failures)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("No viewport texture while capturing %s." % file_name)
		_capture_failures += 1
		return

	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Viewport image is empty while capturing %s." % file_name)
		_capture_failures += 1
		return

	var output_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Failed to save %s: error %d." % [output_path, error])
		_capture_failures += 1
	else:
		print("Captured %s" % output_path)


func _wait_seconds(duration: float) -> void:
	await create_timer(duration).timeout
