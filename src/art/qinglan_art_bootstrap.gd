extends Node
## Runtime-only adapter for the versioned Qinglan Valley Art Pack.
## It replaces presentation nodes without changing combat, collision or AI rules.

const COMBAT_CAMERA_SIZE := 15.5
const ESCAPE_CAMERA_SIZE := 17.0
const INTRO_CAMERA_SIZE := 16.5
const CAMERA_ZOOM_SPEED := 6.0

var _demo: MortalPathMain = null
var _actors: Node3D = null
var _camera: Camera3D = null
var _portal_visual: Node3D = null
var _environment_instances: Array[Node3D] = []
var _tracked_visuals: Array[WeakRef] = []


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_bind_current_scene")


func _process(delta: float) -> void:
	if not is_instance_valid(_demo):
		return
	if is_instance_valid(_camera):
		_camera.size = move_toward(_camera.size, _target_camera_size(), CAMERA_ZOOM_SPEED * delta)
	_sync_actor_presentation()
	_animate_world_art(delta)


func _on_node_added(node: Node) -> void:
	if node is MortalPathMain:
		call_deferred("_bind_demo", node)


func _bind_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene is MortalPathMain:
		_bind_demo(scene)


func _bind_demo(scene: MortalPathMain) -> void:
	if not is_instance_valid(scene) or scene == _demo:
		return
	_demo = scene
	_actors = scene.get_node_or_null("Actors") as Node3D
	_camera = scene.get_node_or_null("Camera3D") as Camera3D
	_environment_instances.clear()
	_tracked_visuals.clear()
	_install_environment()

	var player := scene.get_node_or_null("Player") as PlayerController
	if player != null:
		_attach_character(player, &"chr_player_qi_refining_a")
		_install_player_vfx(player)

	var portal := scene.get_node_or_null("EscapePortal") as EscapePortal
	if portal != null:
		_install_portal(portal)

	if _actors != null:
		var callback := Callable(self, "_on_actor_added")
		if not _actors.child_entered_tree.is_connected(callback):
			_actors.child_entered_tree.connect(callback)
		for child in _actors.get_children():
			_on_actor_added(child)


func _on_actor_added(node: Node) -> void:
	call_deferred("_install_dynamic_actor", node)


func _install_dynamic_actor(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is TrainingEnemy:
		var enemy := node as TrainingEnemy
		var asset_id := &"chr_enemy_melee_qi_a"
		if enemy.combat_style == TrainingEnemy.CombatStyle.RANGED:
			asset_id = &"chr_enemy_talisman_qi_a"
		elif enemy.combat_style == TrainingEnemy.CombatStyle.GUARDIAN:
			asset_id = &"chr_guardian_foundation_a"
		_attach_character(enemy, asset_id)
		if enemy.combat_style == TrainingEnemy.CombatStyle.GUARDIAN:
			_install_guard_vfx(enemy.get_node_or_null("GuardVisual") as MeshInstance3D)
	elif node is FormationAnchor:
		_install_anchor(node as FormationAnchor)


func _attach_character(actor: Node3D, asset_id: StringName) -> Node3D:
	var existing := actor.get_node_or_null("ArtVisual") as Node3D
	if existing != null:
		_hide_world_label(actor.get_node_or_null("RealmLabel"))
		return existing
	var visual := ArtPackRegistry.attach_asset(actor, asset_id, "ArtVisual")
	if visual == null:
		return null
	_hide_geometry(actor.get_node_or_null("BodyMesh"))
	_hide_geometry(actor.get_node_or_null("FacingMarker"))
	_hide_world_label(actor.get_node_or_null("RealmLabel"))
	_tracked_visuals.append(weakref(actor))
	return visual


func _install_player_vfx(player: PlayerController) -> void:
	var attack := player.get_node_or_null("AttackIndicator") as MeshInstance3D
	var sword_art := player.get_node_or_null("SwordArtIndicator") as MeshInstance3D
	var guard := player.get_node_or_null("GuardVisual") as MeshInstance3D
	_install_indicator_asset(attack, &"vfx_sword_arc_qi_a", "SwordArcVisual")
	_install_indicator_asset(sword_art, &"vfx_qingfeng_blade_a", "QingfengBladeVisual")
	_install_guard_vfx(guard)


func _install_indicator_asset(indicator: MeshInstance3D, asset_id: StringName, node_name: String) -> void:
	if indicator == null or indicator.get_node_or_null(node_name) != null:
		return
	var visual := ArtPackRegistry.attach_asset(indicator, asset_id, node_name)
	if visual == null:
		return
	indicator.mesh = null
	indicator.material_override = null
	indicator.position.z = 0.0


func _install_guard_vfx(guard: MeshInstance3D) -> void:
	if guard == null or guard.get_node_or_null("GuardRippleVisual") != null:
		return
	var visual := ArtPackRegistry.attach_asset(guard, &"vfx_guard_ripple_a", "GuardRippleVisual")
	if visual == null:
		return
	guard.mesh = null
	guard.material_override = null


func _install_anchor(anchor: FormationAnchor) -> void:
	if anchor.get_node_or_null("ArtVisual") != null:
		_hide_world_label(anchor.get_node_or_null("RealmLabel"))
		return
	var visual := ArtPackRegistry.attach_asset(anchor, &"prop_formation_anchor_qinglan_a", "ArtVisual")
	if visual == null:
		return
	for node_name in ["Base", "Pillar", "Core", "Ring"]:
		_hide_geometry(anchor.get_node_or_null(node_name))
	_hide_world_label(anchor.get_node_or_null("RealmLabel"))
	_tracked_visuals.append(weakref(anchor))


func _install_portal(portal: EscapePortal) -> void:
	_portal_visual = portal.get_node_or_null("ArtVisual") as Node3D
	if _portal_visual == null:
		_portal_visual = ArtPackRegistry.attach_asset(portal, &"prop_escape_portal_qinglan_a", "ArtVisual")
	if _portal_visual == null:
		return
	_hide_geometry(portal.get_node_or_null("Disc"))
	_hide_geometry(portal.get_node_or_null("Core"))
	_hide_world_label(portal.get_node_or_null("Label3D"))


func _install_environment() -> void:
	if not is_instance_valid(_demo):
		return
	for node_name in [
		"StonePath", "RealmCircle", "NorthWestStone", "NorthEastStone",
		"SouthWestStone", "SouthEastStone", "WestPillar", "EastPillar"
	]:
		_hide_geometry(_demo.get_node_or_null(node_name))

	_spawn_environment(&"env_qinglan_path_set_a", Vector3.ZERO, 0.0)
	for item in [
		[Vector3(-9.2, 0.0, -7.2), 18.0],
		[Vector3(9.0, 0.0, -6.4), -22.0],
		[Vector3(-9.5, 0.0, 5.8), -12.0],
		[Vector3(9.4, 0.0, 6.6), 24.0],
		[Vector3(0.0, 0.0, -11.2), 6.0],
	]:
		_spawn_environment(&"env_qinglan_cliff_set_a", item[0], item[1])
	for item in [
		[Vector3(-8.0, 0.0, -1.8), 12.0],
		[Vector3(8.2, 0.0, 1.2), -18.0],
		[Vector3(-7.1, 0.0, 8.2), -8.0],
		[Vector3(7.0, 0.0, -8.8), 26.0],
	]:
		_spawn_environment(&"env_qinglan_bamboo_set_a", item[0], item[1])


func _spawn_environment(asset_id: StringName, position: Vector3, yaw_degrees: float) -> void:
	var instance := ArtPackRegistry.instantiate_asset(asset_id, "Art_%s_%02d" % [asset_id, _environment_instances.size()])
	if instance == null:
		return
	_demo.add_child(instance)
	instance.position = position
	instance.rotation_degrees.y = yaw_degrees
	_environment_instances.append(instance)


func _sync_actor_presentation() -> void:
	for index in range(_tracked_visuals.size() - 1, -1, -1):
		var actor := _tracked_visuals[index].get_ref() as Node3D
		if actor == null:
			_tracked_visuals.remove_at(index)
			continue
		var body := actor.get_node_or_null("BodyMesh") as MeshInstance3D
		var visual := actor.get_node_or_null("ArtVisual") as Node3D
		if body != null and visual != null:
			visual.scale = body.scale


func _animate_world_art(delta: float) -> void:
	if _portal_visual != null and is_instance_valid(_portal_visual):
		var portal := _portal_visual.get_parent() as EscapePortal
		if portal != null:
			_hide_geometry(portal.get_node_or_null("Disc"))
			_hide_geometry(portal.get_node_or_null("Core"))
			_hide_world_label(portal.get_node_or_null("Label3D"))
		var active := portal != null and portal.is_active()
		_portal_visual.rotation.y += delta * (1.35 if active else 0.18)
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * (0.035 if active else 0.008)
		_portal_visual.scale = Vector3.ONE * pulse


func _target_camera_size() -> float:
	if not is_instance_valid(_demo):
		return INTRO_CAMERA_SIZE
	match _demo.phase_name_for_test():
		"combat":
			return COMBAT_CAMERA_SIZE
		"escape":
			return ESCAPE_CAMERA_SIZE
		_:
			return INTRO_CAMERA_SIZE


func environment_instance_count_for_test() -> int:
	return _environment_instances.size()


func bound_scene_for_test() -> MortalPathMain:
	return _demo


func _hide_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visible = false


func _hide_world_label(node: Node) -> void:
	if node is Label3D:
		(node as Label3D).visible = false
