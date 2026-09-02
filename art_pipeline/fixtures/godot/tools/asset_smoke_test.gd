extends SceneTree

const ASSET_ROOT := "res://assets"
const REPORT_PATH := "res://reports/godot-smoke.json"

var failures: Array[String] = []
var asset_reports: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var asset_paths: Array[String] = []
	_collect_assets(ASSET_ROOT, asset_paths)

	if asset_paths.is_empty():
		failures.append("no .glb or .gltf assets found under %s" % ASSET_ROOT)

	for asset_path in asset_paths:
		_check_asset(asset_path)

	var report := {
		"schema_version": 1,
		"tested_assets": asset_reports,
		"errors": failures,
		"ok": failures.is_empty(),
	}
	_write_report(report)

	if failures.is_empty():
		print("Godot imported %d art asset(s) successfully." % asset_reports.size())
		quit(0)
		return

	for failure in failures:
		printerr("ERROR: %s" % failure)
	quit(1)


func _collect_assets(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failures.append("cannot open asset directory: %s" % directory_path)
		return

	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if entry == "." or entry == ".." or entry.begins_with("."):
			entry = directory.get_next()
			continue

		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_assets(path, output)
		elif entry.ends_with(".glb") or entry.ends_with(".gltf"):
			output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _check_asset(asset_path: String) -> void:
	var resource := ResourceLoader.load(asset_path)
	if resource == null:
		failures.append("ResourceLoader failed: %s" % asset_path)
		return
	if not resource is PackedScene:
		failures.append("asset is not imported as PackedScene: %s" % asset_path)
		return

	var instance := (resource as PackedScene).instantiate()
	root.add_child(instance)
	var mesh_count := _count_meshes(instance)
	var animation_player_count := _count_type(instance, "AnimationPlayer")
	var skeleton_count := _count_type(instance, "Skeleton3D")

	if mesh_count == 0:
		failures.append("asset contains no MeshInstance3D: %s" % asset_path)

	asset_reports.append({
		"path": asset_path,
		"mesh_count": mesh_count,
		"animation_player_count": animation_player_count,
		"skeleton_count": skeleton_count,
	})
	instance.free()


func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count


func _count_type(node: Node, class_name_to_match: String) -> int:
	var count := 1 if node.is_class(class_name_to_match) else 0
	for child in node.get_children():
		count += _count_type(child, class_name_to_match)
	return count


func _write_report(report: Dictionary) -> void:
	var absolute_report_dir := ProjectSettings.globalize_path("res://reports")
	var error := DirAccess.make_dir_recursive_absolute(absolute_report_dir)
	if error != OK and error != ERR_ALREADY_EXISTS:
		failures.append("cannot create report directory: %s" % error_string(error))
		return

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("cannot write Godot report: %s" % REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
