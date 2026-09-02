class_name EscapePortal
extends Area3D

signal escaped(actor)

@onready var _disc: MeshInstance3D = $Disc
@onready var _core: MeshInstance3D = $Core
@onready var _label: Label3D = $Label3D

var active: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_active(false)


func _process(delta: float) -> void:
	_elapsed += delta
	_disc.rotation.y += delta * (1.8 if active else 0.35)
	var pulse := 1.0 + sin(_elapsed * (4.0 if active else 1.5)) * (0.08 if active else 0.02)
	_core.scale = Vector3.ONE * pulse


func set_active(enabled: bool) -> void:
	active = enabled
	collision_mask = 1 if enabled else 0
	monitoring = enabled
	_disc.visible = true
	_core.visible = true
	_label.text = "遁光阵\n%s" % ("已开启" if enabled else "受锁灵阵压制")
	_label.modulate = Color(0.72, 0.96, 0.84, 1.0) if enabled else Color(0.58, 0.62, 0.60, 1.0)
	var disc_material := _disc.get_active_material(0)
	if disc_material is StandardMaterial3D:
		var material := disc_material.duplicate() as StandardMaterial3D
		material.albedo_color = Color(0.28, 0.78, 0.58, 0.34) if enabled else Color(0.28, 0.34, 0.31, 0.18)
		material.emission = Color(0.16, 0.72, 0.48, 1.0) if enabled else Color(0.10, 0.14, 0.12, 1.0)
		material.emission_energy_multiplier = 1.8 if enabled else 0.2
		_disc.material_override = material


func is_active() -> bool:
	return active


func _on_body_entered(body: Node3D) -> void:
	if not active or not body.is_in_group("player"):
		return
	escaped.emit(body)
