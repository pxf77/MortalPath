class_name EnemyCombatVfxBridge
extends Node
## Presentation-only adapter for enemy telegraphs, projectiles and player impacts.
## Combat timing, movement, collision, damage and lifetime remain game-owned.

const MELEE_TELEGRAPH := &"vfx_enemy_melee_telegraph_v0_7"
const TALISMAN_TELEGRAPH := &"vfx_enemy_talisman_telegraph_v0_7"
const GUARDIAN_TELEGRAPH := &"vfx_guardian_telegraph_v0_7"
const TALISMAN_PROJECTILE := &"vfx_enemy_talisman_projectile_v0_7"
const GUARDIAN_PROJECTILE := &"vfx_guardian_projectile_v0_7"
const QI_IMPACT := &"vfx_enemy_impact_qi_v0_7"
const GUARDIAN_IMPACT := &"vfx_guardian_impact_v0_7"

var _demo: MortalPathMain = null
var _player: PlayerController = null
var _telegraphs: Array[Dictionary] = []
var _projectiles: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _last_impact_asset: StringName = &""


func configure(demo: MortalPathMain, player: PlayerController) -> void:
	if is_instance_valid(_player):
		var old_callback := Callable(self, "_on_player_impact")
		if _player.impact_resolved.is_connected(old_callback):
			_player.impact_resolved.disconnect(old_callback)
	_demo = demo
	_player = player
	_telegraphs.clear()
	_projectiles.clear()
	_impacts.clear()
	_last_impact_asset = &""
	if is_instance_valid(_player):
		var callback := Callable(self, "_on_player_impact")
		if not _player.impact_resolved.is_connected(callback):
			_player.impact_resolved.connect(callback)


func _process(delta: float) -> void:
	_update_telegraphs(delta)
	_update_projectiles(delta)
	_update_impacts(delta)


func install_enemy(enemy: TrainingEnemy) -> void:
	if not is_instance_valid(enemy):
		return
	var telegraph := enemy.get_node_or_null("Telegraph") as MeshInstance3D
	if telegraph == null or telegraph.get_node_or_null("EnemyTelegraphVisual") != null:
		return
	var asset_id := telegraph_asset_for_style(enemy.combat_style)
	var visual := ArtPackRegistry.attach_asset(
		telegraph,
		asset_id,
		"EnemyTelegraphVisual"
	)
	if visual == null:
		return
	telegraph.mesh = null
	telegraph.material_override = null
	telegraph.rotation = Vector3.ZERO
	_telegraphs.append({
		"host": weakref(telegraph),
		"visual": weakref(visual),
		"asset_id": asset_id,
		"elapsed": 0.0,
	})


func install_projectile(projectile: CombatProjectile) -> void:
	if not is_instance_valid(projectile):
		return
	var mesh := projectile.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null or projectile.get_node_or_null("EnemyProjectileVisual") != null:
		return
	var enemy := projectile.source_actor as TrainingEnemy
	if enemy == null:
		return
	var asset_id := (
		GUARDIAN_PROJECTILE
		if enemy.combat_style == TrainingEnemy.CombatStyle.GUARDIAN
		else TALISMAN_PROJECTILE
	)
	var visual := ArtPackRegistry.attach_asset(
		projectile,
		asset_id,
		"EnemyProjectileVisual"
	)
	if visual == null:
		return
	mesh.mesh = null
	mesh.material_override = null
	_projectiles.append({
		"host": weakref(projectile),
		"visual": weakref(visual),
		"asset_id": asset_id,
		"angle": 0.0,
	})


func _update_telegraphs(delta: float) -> void:
	for index in range(_telegraphs.size() - 1, -1, -1):
		var item := _telegraphs[index]
		var host := (item["host"] as WeakRef).get_ref() as MeshInstance3D
		var visual := (item["visual"] as WeakRef).get_ref() as Node3D
		if host == null or visual == null:
			_telegraphs.remove_at(index)
			continue
		host.rotation = Vector3.ZERO
		if not host.visible:
			item["elapsed"] = 0.0
			visual.scale = Vector3.ONE
			visual.rotation = Vector3.ZERO
			continue
		var asset_id: StringName = item["asset_id"]
		var elapsed := float(item["elapsed"]) + delta
		item["elapsed"] = elapsed
		var wave := sin(elapsed * 10.0) * 0.5 + 0.5
		var pulse := lerpf(
			EnemyCombatVfxContract.pulse_min(asset_id),
			EnemyCombatVfxContract.pulse_max(asset_id),
			wave
		)
		visual.scale = Vector3.ONE * pulse
		visual.rotation.y += deg_to_rad(
			EnemyCombatVfxContract.rotation_speed(asset_id)
		) * delta


func _update_projectiles(delta: float) -> void:
	for index in range(_projectiles.size() - 1, -1, -1):
		var item := _projectiles[index]
		var host := (item["host"] as WeakRef).get_ref() as CombatProjectile
		var visual := (item["visual"] as WeakRef).get_ref() as Node3D
		if host == null or visual == null:
			_projectiles.remove_at(index)
			continue
		var asset_id: StringName = item["asset_id"]
		var angle := float(item["angle"]) + deg_to_rad(
			EnemyCombatVfxContract.rotation_speed(asset_id)
		) * delta
		item["angle"] = angle
		visual.rotation.y = angle - host.rotation.y


func _update_impacts(delta: float) -> void:
	for index in range(_impacts.size() - 1, -1, -1):
		var item := _impacts[index]
		var visual := (item["visual"] as WeakRef).get_ref() as Node3D
		if visual == null:
			_impacts.remove_at(index)
			continue
		var asset_id: StringName = item["asset_id"]
		var elapsed := float(item["elapsed"]) + delta
		var duration := EnemyCombatVfxContract.duration(asset_id)
		item["elapsed"] = elapsed
		if elapsed >= duration:
			visual.queue_free()
			_impacts.remove_at(index)
			continue
		var progress := elapsed / duration
		var scale_value := lerpf(
			EnemyCombatVfxContract.impact_scale_start(asset_id),
			EnemyCombatVfxContract.impact_scale_end(asset_id),
			progress
		)
		visual.scale = Vector3.ONE * scale_value
		var position: Vector3 = item["origin"]
		position.y += EnemyCombatVfxContract.impact_rise(asset_id) * progress
		visual.global_position = position


func _on_player_impact(_actor, source, kind: StringName, _amount: float) -> void:
	if kind == &"evade" or not source is TrainingEnemy:
		return
	var enemy := source as TrainingEnemy
	var asset_id := (
		GUARDIAN_IMPACT
		if enemy.combat_style == TrainingEnemy.CombatStyle.GUARDIAN
		else QI_IMPACT
	)
	_spawn_impact(asset_id)


func _spawn_impact(asset_id: StringName) -> void:
	if not is_instance_valid(_demo) or not is_instance_valid(_player):
		return
	var visual := ArtPackRegistry.instantiate_asset(asset_id, "EnemyImpactVisual")
	if visual == null:
		return
	_demo.add_child(visual)
	var origin := _player.global_position + Vector3(0.0, 0.62, 0.0)
	visual.global_position = origin
	visual.scale = Vector3.ONE * EnemyCombatVfxContract.impact_scale_start(asset_id)
	_impacts.append({
		"visual": weakref(visual),
		"asset_id": asset_id,
		"origin": origin,
		"elapsed": 0.0,
	})
	_last_impact_asset = asset_id


static func telegraph_asset_for_style(style: int) -> StringName:
	match style:
		TrainingEnemy.CombatStyle.RANGED:
			return TALISMAN_TELEGRAPH
		TrainingEnemy.CombatStyle.GUARDIAN:
			return GUARDIAN_TELEGRAPH
		_:
			return MELEE_TELEGRAPH


func active_impact_count_for_test() -> int:
	return _impacts.size()


func last_impact_asset_for_test() -> StringName:
	return _last_impact_asset
