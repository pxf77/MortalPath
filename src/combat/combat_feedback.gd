class_name CombatFeedback
extends Node3D
## Scene-local presentation; never changes Engine.time_scale or combat stats.

signal cue_played(kind: StringName)

const EFFECT_LIMIT := 32
const COLORS := {
	&"hit": Color(0.92, 0.90, 0.73),
	&"hurt": Color(0.92, 0.38, 0.25),
	&"guard": Color(0.38, 0.73, 0.95),
	&"evade": Color(0.53, 0.80, 0.75),
	&"break": Color(1.0, 0.65, 0.28),
	&"death": Color(0.65, 0.56, 0.41),
}

var reduced_motion := false
var audio: CombatAudio
var _actors: Array[WeakRef] = []
var _effects: Array[Dictionary] = []
var _flashes: Dictionary = {}
var _shake := 0.0
var _elapsed := 0.0
var _last_cue_msec: Dictionary = {}


func _ready() -> void:
	audio = CombatAudio.new()
	add_child(audio)


func observe(actor: CombatActor) -> void:
	if actor.impact_resolved.is_connected(_on_impact):
		return
	_actors.append(weakref(actor))
	actor.hit_pause_enabled = not reduced_motion
	actor.impact_resolved.connect(_on_impact)
	if actor is PlayerController:
		actor.action_started.connect(_on_action_started.bind(actor))
		actor.action_released.connect(_play_cue)
	elif actor is TrainingEnemy:
		actor.spell_released.connect(_play_cue)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_shake = 0.0
	for reference in _actors:
		var actor := reference.get_ref() as CombatActor
		if actor != null:
			actor.hit_pause_enabled = not value


func camera_offset() -> Vector2:
	if reduced_motion:
		return Vector2.ZERO
	return Vector2(sin(_elapsed * 93.0), sin(_elapsed * 71.0)) * _shake


func _process(delta: float) -> void:
	_elapsed += delta
	_shake = move_toward(_shake, 0.0, delta * 0.7)
	for index in range(_effects.size() - 1, -1, -1):
		var effect := _effects[index]
		var mesh: MeshInstance3D = effect.mesh
		effect.age += delta
		var progress: float = minf(1.0, effect.age / effect.duration)
		mesh.position += effect.velocity * delta
		mesh.scale = effect.initial_scale * (1.0 + progress * 1.4)
		var material := mesh.material_override as StandardMaterial3D
		material.albedo_color.a = (1.0 - progress) * 0.75
		if progress >= 1.0:
			mesh.queue_free()
			_effects.remove_at(index)
	for id in _flashes.keys():
		var flash: Dictionary = _flashes[id]
		var body := flash.body.get_ref() as MeshInstance3D
		flash.left -= delta
		if body == null or flash.left <= 0.0:
			if body != null and DisplayServer.get_name() != "headless":
				body.material_overlay = flash.original
			_flashes.erase(id)


func _on_impact(actor: CombatActor, _source: CombatActor, kind: StringName, _amount: float) -> void:
	var cue := kind
	if kind == &"hit" and actor is PlayerController:
		cue = &"hurt"
	var color: Color = COLORS[cue]
	_play_cue(cue)
	if kind != &"evade":
		_flash(actor, color)
		if not reduced_motion:
			_shake = maxf(_shake, 0.12 if cue == &"hurt" or kind == &"break" else 0.055)
	var point := actor.global_position + Vector3(0.0, 0.8, 0.0)
	_spawn_effect(point, color, 0.28, kind == &"guard" or kind == &"evade", Vector3.ZERO)
	if kind == &"death" or kind == &"break":
		for index in range(5):
			var angle := float(index) * TAU / 5.0
			var drift := Vector3(cos(angle), 0.7, sin(angle)) * (0.35 if reduced_motion else 1.3)
			_spawn_effect(point, color, 0.48, false, drift)


func _on_action_started(action: StringName, combo_step: int, actor: PlayerController) -> void:
	if action == &"dodge" or action == &"guard_cast":
		_play_cue(action, combo_step)
		_spawn_effect(actor.global_position + Vector3(0.0, 0.12, 0.0), Color(0.34, 0.68, 0.58), 0.30, true, Vector3.ZERO)


func _play_cue(cue: StringName, combo_step: int = 0) -> void:
	# Multi-target contacts share one sound per 45 ms, not a clipped sound stack.
	var now := Time.get_ticks_msec()
	if now - int(_last_cue_msec.get(cue, -1000)) < 45:
		return
	_last_cue_msec[cue] = now
	if audio != null:
		audio.play_cue(cue, combo_step)
	cue_played.emit(cue)


func _flash(actor: CombatActor, color: Color) -> void:
	var body := actor.get_node_or_null("BodyMesh") as MeshInstance3D
	if body == null:
		body = actor.get_node_or_null("Core") as MeshInstance3D
	if body == null:
		return
	var id := body.get_instance_id()
	if not _flashes.has(id):
		_flashes[id] = {"body": weakref(body), "original": body.material_overlay, "left": 0.09}
	else:
		_flashes[id].left = 0.09
	var material := _material(color)
	material.albedo_color.a = 0.65
	if DisplayServer.get_name() != "headless":
		body.material_overlay = material


func _spawn_effect(point: Vector3, color: Color, duration: float, ring: bool, drift: Vector3) -> void:
	# Geometry is exercised by the graphical regression, not the dummy renderer.
	# Combat events and flash timing remain testable headless.
	if DisplayServer.get_name() == "headless":
		return
	if _effects.size() >= EFFECT_LIMIT:
		var oldest: Dictionary = _effects.pop_front()
		oldest.mesh.queue_free()
	var visual := MeshInstance3D.new()
	if ring:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.43
		torus.outer_radius = 0.51
		torus.rings = 16
		torus.ring_segments = 8
		visual.mesh = torus
	else:
		var shard := BoxMesh.new()
		shard.size = Vector3(0.12, 0.19, 0.12)
		visual.mesh = shard
	visual.material_override = _material(color)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	visual.global_position = point
	_effects.append({"mesh": visual, "age": 0.0, "duration": duration, "velocity": drift, "initial_scale": visual.scale})


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
