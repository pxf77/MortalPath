extends SceneTree
## Executes the real FlyingSwordTrail3D._process loop under --fixed-fps.
## Each invocation writes one machine-readable report for cross-FPS comparison.

const TEST_RULE := {
	"trail_duration_seconds": 0.23,
	"trail_width_m": 0.13,
	"trail_opacity": 0.82,
	"sample_spacing_m": 0.04,
}

var _fps := 60
var _output_path := "res://build/m1-evidence/validation/trail-60.json"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fps="):
			_fps = maxi(1, int(argument.trim_prefix("--fps=")))
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "TrailCalibrationStage"
	root.add_child(stage)

	var tip := Node3D.new()
	tip.name = "SwordTip"
	stage.add_child(tip)

	var trail := FlyingSwordTrail3D.new()
	trail.name = "Trail"
	stage.add_child(trail)
	trail.configure(tip)
	await process_frame

	tip.position = Vector3(0.0, 0.82, 0.0)
	trail.emit_for(TEST_RULE)

	var simulated_seconds := 0.20
	var frames := maxi(6, ceili(simulated_seconds * float(_fps)))
	for frame_index in range(frames):
		var time_seconds := float(frame_index + 1) / float(_fps)
		tip.position = Vector3(
			sin(time_seconds * TAU * 1.35) * 0.92,
			0.82 + sin(time_seconds * TAU) * 0.06,
			-time_seconds * 5.8
		)
		await process_frame

	var average_delta := trail.observed_average_delta_for_test()
	var observed_fps := 0.0 if average_delta <= 0.0 else 1.0 / average_delta
	var expected_delta := 1.0 / float(_fps)
	var delta_error_ratio := (
		1.0
		if average_delta <= 0.0
		else absf(average_delta - expected_delta) / expected_delta
	)
	var configured_width := trail.configured_width_for_test()
	var peak_width := trail.peak_rendered_width_for_test()
	var width_error_ratio := (
		1.0
		if configured_width <= 0.0
		else absf(peak_width - configured_width) / configured_width
	)
	var shader_code := trail.shader_code_for_test()
	var failures: Array[String] = []

	if not trail.material_is_shader_for_test():
		failures.append("trail material must be ShaderMaterial")
	if not shader_code.contains("core_color") or not shader_code.contains("edge_color"):
		failures.append("shader must provide distinct core and edge channels")
	if not shader_code.contains("UV.y") or not shader_code.contains("COLOR.a"):
		failures.append("shader must consume ribbon UV and lifetime vertex alpha")
	if delta_error_ratio > 0.02:
		failures.append("observed process delta does not match requested fixed FPS")
	if width_error_ratio > 0.06:
		failures.append("rendered trail width differs from the authored rule by more than 6%")
	if not is_equal_approx(trail.configured_opacity_for_test(), float(TEST_RULE["trail_opacity"])):
		failures.append("trail opacity was not consumed from the authored rule")
	if not is_equal_approx(
		trail.configured_sample_spacing_for_test(),
		float(TEST_RULE["sample_spacing_m"])
	):
		failures.append("sample spacing was not consumed from the authored rule")
	if trail.peak_vertex_count_for_test() < 12:
		failures.append("real process loop did not generate enough ribbon geometry")
	var expected_measured_ticks := maxi(frames - 1, 1)
	if trail.observed_process_count_for_test() < expected_measured_ticks:
		failures.append("trail did not receive every measured fixed-FPS process tick")

	var report := {
		"schema_version": 1,
		"requested_fixed_fps": _fps,
		"frames_awaited": frames,
		"observed_process_count": trail.observed_process_count_for_test(),
		"warmup_ticks_excluded": 1,
		"observed_average_delta_seconds": average_delta,
		"observed_fps": observed_fps,
		"delta_error_ratio": delta_error_ratio,
		"shader_material": trail.material_is_shader_for_test(),
		"shader_has_core_edge_channels": (
			shader_code.contains("core_color")
			and shader_code.contains("edge_color")
			and shader_code.contains("UV.y")
			and shader_code.contains("COLOR.a")
		),
		"configured_lifetime_seconds": trail.configured_lifetime_for_test(),
		"configured_width_m": configured_width,
		"peak_rendered_width_m": peak_width,
		"width_error_ratio": width_error_ratio,
		"configured_opacity": trail.configured_opacity_for_test(),
		"configured_sample_spacing_m": trail.configured_sample_spacing_for_test(),
		"peak_vertex_count": trail.peak_vertex_count_for_test(),
		"remaining_sample_count": trail.sample_count_for_test(),
		"failures": failures,
		"ok": failures.is_empty(),
	}
	var absolute_directory := ProjectSettings.globalize_path(_output_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_directory)
	var file := FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write trail FPS report: %s" % _output_path)
		stage.queue_free()
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
