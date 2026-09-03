class_name FlyingSwordTrail3D
extends MeshInstance3D
## Lightweight world-space ribbon sampled from the exported flying-sword tip.
## It owns presentation only and never changes combat hit detection.

const MAX_POINTS := 28
const MIN_SAMPLE_DISTANCE := 0.035
const DEFAULT_COLOR := Color(0.43, 0.78, 0.64, 0.78)

var source_tip: Node3D = null
var _points: Array[Dictionary] = []
var _emit_left := 0.0
var _lifetime := 0.18
var _width := 0.09
var _last_rule: Dictionary = {}
var _started_count := 0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = _build_material()
	visible = false


func configure(tip: Node3D) -> void:
	source_tip = tip


func emit_for(rule: Dictionary) -> void:
	if rule.is_empty():
		return
	_last_rule = rule.duplicate(true)
	_lifetime = clampf(float(rule.get("trail_duration_seconds", 0.18)), 0.08, 0.40)
	_width = clampf(float(rule.get("trail_width_m", 0.09)), 0.04, 0.18)
	_emit_left = _lifetime
	_points.clear()
	_started_count += 1
	_sample_point(true)
	_rebuild_mesh()


func stop_emission() -> void:
	_emit_left = 0.0


func clear_trail() -> void:
	_points.clear()
	_emit_left = 0.0
	mesh = null
	visible = false


func _process(delta: float) -> void:
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
		if last_position.distance_to(position) < MIN_SAMPLE_DISTANCE:
			return
	_points.append({"position": position, "age": 0.0})
	while _points.size() > MAX_POINTS:
		_points.pop_front()


func _rebuild_mesh() -> void:
	if DisplayServer.get_name() == "headless":
		visible = _points.size() >= 2
		return
	if _points.size() < 2:
		mesh = null
		visible = false
		return

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
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
		var first_width := _width * 0.5 * _life_scale(float(first["age"]))
		var second_width := _width * 0.5 * _life_scale(float(second["age"]))
		var first_color := DEFAULT_COLOR
		var second_color := DEFAULT_COLOR
		first_color.a *= _life_scale(float(first["age"]))
		second_color.a *= _life_scale(float(second["age"]))

		var first_left := to_local(first_position - side * first_width)
		var first_right := to_local(first_position + side * first_width)
		var second_left := to_local(second_position - side * second_width)
		var second_right := to_local(second_position + side * second_width)
		vertices.append_array(PackedVector3Array([
			first_left, first_right, second_right,
			first_left, second_right, second_left,
		]))
		colors.append_array(PackedColorArray([
			first_color, first_color, second_color,
			first_color, second_color, second_color,
		]))

	if vertices.is_empty():
		mesh = null
		visible = false
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var trail_mesh := ArrayMesh.new()
	trail_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = trail_mesh
	visible = true


func _life_scale(age: float) -> float:
	return clampf(1.0 - age / maxf(_lifetime, 0.001), 0.0, 1.0)


func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = Color(0.11, 0.30, 0.22)
	material.emission_energy_multiplier = 0.65
	return material


func is_emitting_for_test() -> bool:
	return _emit_left > 0.0


func sample_count_for_test() -> int:
	return _points.size()


func started_count_for_test() -> int:
	return _started_count


func last_rule_for_test() -> Dictionary:
	return _last_rule.duplicate(true)
