class_name Station
extends StaticBody3D
enum Kind { WASH, DISPLAY }
@export var kind: Kind = Kind.WASH

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 0.15, 0.85)
	collider.shape = shape
	add_child(collider)

func slot(index: int) -> Vector3:
	return global_position + Vector3(-0.45 + (index % 4) * 0.3, 0.18, -0.2 + (index / 4) * 0.35)
