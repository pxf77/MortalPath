class_name EscapePortal
extends Area3D

signal escaped(actor)

@onready var _disc: MeshInstance3D = $Disc
@onready var _core: MeshInstance3D = $Core
@onready var _label: Label3D = $Label3D

var active: bool = false
var _elapsed: float = 0.0
var _disc_material: StandardMaterial3D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if DisplayServer.get_name() != "headless":
		_disc_material = _duplicate_surface_material(_disc)
		if _disc_material != null:
			_disc.material_override = _disc_material
	set_active(false)


func _process(delta: float) -> void:
	_elapsed += delta
	_disc.rotation.y += delta * (1.8 if active else 0.35)
	var pulse: float = 1.0 + sin(_elapsed * (4.0 if active else 1.5)) * (0.08 if active else 0.02)
	_core.scale = Vector3.ONE * pulse


func set_active(enabled: bool) -> void:
	active = enabled
	collision_mask = 1 if enabled else 0
	monitoring = enabled
	_disc.visible = true
	_core.visible = true
	_label.text = "遁光阵\n%s" % ("已开启" if enabled else "受锁灵阵压制")
	if DisplayServer.get_name() != "headless":
		_label.modulate = Color(0.72, 0.96, 0.84, 1.0) if enabled else Color(0.58, 0.62, 0.60, 1.0)
	if _disc_material != null:
		_disc_material.albedo_color = Color(0.28, 0.78, 0.58, 0.34) if enabled else Color(0.28, 0.34, 0.31, 0.18)
		_disc_material.emission = Color(0.16, 0.72, 0.48, 1.0) if enabled else Color(0.10, 0.14, 0.12, 1.0)
		_disc_material.emission_energy_multiplier = 1.8 if enabled else 0.2


func is_active() -> bool:
	return active


func _duplicate_surface_material(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return null
	var source_material: Material = mesh_instance.mesh.surface_get_material(0)
	if source_material is StandardMaterial3D:
		return source_material.duplicate() as StandardMaterial3D
	return null


func _on_body_entered(body: Node3D) -> void:
	if not active or not body.is_in_group("player"):
		return
	escaped.emit(body)
