class_name FormationAnchor
extends CombatActor

signal anchor_broken(anchor)

@onready var _core: MeshInstance3D = $Core
@onready var _ring: MeshInstance3D = $Ring
@onready var _realm_label: Label3D = $RealmLabel

var _elapsed: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("combat_targets")
	add_to_group("demo_objectives")
	died.connect(_on_died)
	health_changed.connect(_on_health_changed)
	_update_label()


func _process(delta: float) -> void:
	if is_dead:
		return
	_elapsed += delta
	_ring.rotation.y += delta * 1.35
	_core.position.y = 0.92 + sin(_elapsed * 2.4) * 0.08
	var pulse := 1.0 + sin(_elapsed * 3.0) * 0.06
	_core.scale = Vector3.ONE * pulse


func _on_health_changed(_actor, _current_health: float, _max_health: float) -> void:
	_update_label()


func _on_died(_actor) -> void:
	anchor_broken.emit(self)


func _update_label() -> void:
	if is_instance_valid(_realm_label):
		_realm_label.text = "%s\nHP %.0f / %.0f" % [actor_name, current_health, max_health]
