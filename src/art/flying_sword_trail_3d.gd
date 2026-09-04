class_name FlyingSwordTrail3D
extends MeshInstance3D
## World-space flying-sword ribbon sampled from the exported sword tip.
## Presentation only: it never changes attack range, hit detection or damage timing.

const MAX_POINTS := 28
const DEFAULT_SAMPLE_SPACING_M := 0.035
const DEFAULT_OPACITY := 0.78
const DEFAULT_COLOR := Color(0.43, 0.78, 0.64, 1.0)
const MIN_SAMPLE_SPACING_M := 0.01
const MAX_SAMPLE_SPACING_M := 0.12

var source_tip: Node3D = null
var _points: Array[Dictionary] = []
var _emit_left := 0.0
var _lifetime := 0.18
var _width := 0.09
var _opacity := DEFAULT_OPACITY
var _sample_spacing := DEFAULT_SAMPLE_SPACING_M
var _last_rule: Dictionary = {}
var _started_count := 0
var _peak_vertex_count := 0
var _peak_rendered_width := 0.0
var _observed_process_count := 0
var _observed_delta_sum := 0.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = _build_material()
	_apply_material_parameters()
	visible = false


func configure(tip: Node3D) -> void:
	source_tip = tip


func emit_for(rule: Dictionary) -> void:
	if rule.is_empty():
		return
	_last_rule = rule.duplicate(true)
	_lifetime = clampf(float(rule.get("trail_duration_seconds", 0.18)), 0.08, 0.40)
	_width = clampf(float(rule.get("trail_width_m", 0.09)), 0.04, 0.18)
	_opacity = clampf(float(rule.get("trail_opacity", DEFAULT_OPACITY)), 0.05, 1.0)
	_sample_spacing = clampf(
		float(rule.get("sample_spacing_m", DEFAULT_SAMPLE_SPACING_M)),
		MIN_SAMPLE_SPACING_M,
		MAX_SAMPLE_SPACING_M
	)
	_emit_left = _lifetime
	_points.clear()
	_peak_vertex_count = 0
	_peak_rendered_width = 0.0
	_observed_process_count = 0
	_observed_delta_sum = 0.0
	_started_count += 1
	_apply_material_parameters()
	_sample_point(true)
	_rebuild_mesh()


func stop_emission() -> void:
	_emit_left = 0.0


func clear_trail() -> void:
	_points.clear()
	_emit_left = 0.0
	mesh = null
	visible = false
	_peak_vertex_count = 0
	_peak_rendered_width = 0.0
	_observed_process_count = 0
	_observed_delta_sum = 0.0


func _process(delta: float) -> void:
	if _emit_left > 0.0 or not _points.is_empty():
		_observed_process_count += 1
		_observed_delta_sum += delta

	for index in range(_points.size() - 1, -1, -1):
		var point: Dictionary = _points[index]
		point["age"] = float(point.get("age", 0.0)) + delta
		if float(point["age"]) > _lifetime:
			_points.remove_at(index)
		else:
			_points[index] = point

	if _emit_left > 0.0:
		_emit_left = maxf(0.0, _emit_left - delta)
		_sample_point(false)

	_rebuild_mesh()


func _sample_point(force: bool) -> void:
	if not is_instance_valid(source_tip):
		return
	var position := source_tip.global_position
	if not force and not _points.is_empty():
		var last_position: Vector3 = _points[-1]["position"]
		if last_position.distance_to(position) < _sample_spacing:
			return
	_points.append({"position": position, "age": 0.0})
	while _points.size() > MAX_POINTS:
		_points.pop_front()


func _rebuild_mesh() -> void:
	if _points.size() < 2:
		mesh = null
		visible = false
		return

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var segment_denominator := maxf(float(_points.size() - 1), 1.0)
	var current_max_width := 0.0

	for index in range(_points.size() - 1):
		var first: Dictionary = _points[index]
		var second: Dictionary = _points[index + 1]
		var first_position: Vector3 = first["position"]
		var second_position: Vector3 = second["position"]
		var direction := second_position - first_position
		if direction.length_squared() <= 0.000001:
			continue

		var side := direction.normalized().cross(Vector3.UP)
		if side.length_squared() <= 0.000001:
			side = Vector3.RIGHT
		side = side.normalized()

		var first_life := _life_scale(float(first["age"]))
		var second_life := _life_scale(float(second["age"]))
		var first_width := _width * 0.5 * first_life
		var second_width := _width * 0.5 * second_life
		current_max_width = maxf(
			current_max_width,
			maxf(first_width * 2.0, second_width * 2.0)
		)

		var first_color := DEFAULT_COLOR
		var second_color := DEFAULT_COLOR
		first_color.a = first_life
		second_color.a = second_life

		var first_left := to_local(first_position - side * first_width)
		var first_right := to_local(first_position + side * first_width)
		var second_left := to_local(second_position - side * second_width)
		var second_right := to_local(second_position + side * second_width)
		var first_u := float(index) / segment_denominator
		var second_u := float(index + 1) / segment_denominator

		vertices.append_array(PackedVector3Array([
			first_left, first_right, second_right,
			first_left, second_right, second_left,
		]))
		colors.append_array(PackedColorArray([
			first_color, first_color, second_color,
			first_color, second_color, second_color,
		]))
		uvs.append_array(PackedVector2Array([
			Vector2(first_u, 0.0), Vector2(first_u, 1.0), Vector2(second_u, 1.0),
			Vector2(first_u, 0.0), Vector2(second_u, 1.0), Vector2(second_u, 0.0),
		]))

	if vertices.is_empty():
		mesh = null
		visible = false
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var trail_mesh := ArrayMesh.new()
	trail_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = trail_mesh
	visible = true
	_peak_vertex_count = maxi(_peak_vertex_count, vertices.size())
	_peak_rendered_width = maxf(_peak_rendered_width, current_max_width)


func _life_scale(age: float) -> float:
	return clampf(1.0 - age / maxf(_lifetime, 0.001), 0.0, 1.0)


func _build_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(0.84, 1.0, 0.94, 1.0);
uniform vec4 edge_color : source_color = vec4(0.20, 0.62, 0.48, 0.52);
uniform float core_half_width : hint_range(0.05, 0.80) = 0.24;
uniform float opacity : hint_range(0.0, 1.0) = 0.78;

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float edge_fade = 1.0 - smoothstep(0.72, 1.0, across);
	float core = 1.0 - smoothstep(core_half_width, min(core_half_width + 0.24, 0.98), across);
	vec3 ribbon_color = mix(edge_color.rgb, core_color.rgb, core);
	float channel_alpha = mix(edge_color.a, core_color.a, core);
	ALBEDO = ribbon_color;
	EMISSION = ribbon_color * mix(0.75, 1.75, core);
	ALPHA = COLOR.a * opacity * edge_fade * channel_alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("core_color", Color(0.84, 1.0, 0.94, 1.0))
	material.set_shader_parameter("edge_color", Color(0.20, 0.62, 0.48, 0.52))
	material.set_shader_parameter("core_half_width", 0.24)
	material.set_shader_parameter("opacity", _opacity)
	return material


func _apply_material_parameters() -> void:
	var shader_material := material_override as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("opacity", _opacity)


func is_emitting_for_test() -> bool:
	return _emit_left > 0.0


func sample_count_for_test() -> int:
	return _points.size()


func started_count_for_test() -> int:
	return _started_count


func last_rule_for_test() -> Dictionary:
	return _last_rule.duplicate(true)


func material_is_shader_for_test() -> bool:
	return material_override is ShaderMaterial


func shader_code_for_test() -> String:
	var shader_material := material_override as ShaderMaterial
	if shader_material == null or shader_material.shader == null:
		return ""
	return shader_material.shader.code


func configured_lifetime_for_test() -> float:
	return _lifetime


func configured_width_for_test() -> float:
	return _width


func configured_opacity_for_test() -> float:
	return _opacity


func configured_sample_spacing_for_test() -> float:
	return _sample_spacing


func peak_vertex_count_for_test() -> int:
	return _peak_vertex_count


func peak_rendered_width_for_test() -> float:
	return _peak_rendered_width


func observed_process_count_for_test() -> int:
	return _observed_process_count


func observed_average_delta_for_test() -> float:
	if _observed_process_count <= 0:
		return 0.0
	return _observed_delta_sum / float(_observed_process_count)
