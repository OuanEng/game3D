class_name Foam
extends StaticBody3D
## One inexpensive foam cell. Only active tool targets move/shrink; no rigid-body pile.
@export var clear_seconds: float = 0.22
var amount: float = 1.0
var visual: MeshInstance3D
var cleared: bool = false
var container: Node3D
var surface: StandardMaterial3D
var shape: BoxShape3D
var uv_translucent: bool = false

func _ready() -> void:
	collision_layer = 8 # Layer 4: Foam. Blocks player/tool rays, never falling pearls.
	collision_mask = 2
	add_to_group("foam")
	visual = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.34
	mesh.height = 0.68
	mesh.radial_segments = 10
	mesh.rings = 5
	visual.mesh = mesh
	surface = Props.material(Color(0.78, 0.83, 0.80))
	surface.roughness = 0.96
	surface.metallic_specular = 0.12
	visual.material_override = surface
	add_child(visual)
	var collider := CollisionShape3D.new()
	shape = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.54
	collider.shape = shape
	add_child(collider)

func brush(delta: float) -> void:
	if cleared:
		return
	amount = maxf(0.0, amount - delta / maxf(clear_seconds, 0.01))
	# Resize mesh AND shape so a shrinking visual never leaves an invisible wall.
	visual.scale = Vector3.ONE * maxf(amount, 0.05)
	shape.size = Vector3.ONE * maxf(0.54 * amount, 0.025)
	if amount <= 0.0:
		cleared = true
		collision_layer = 0
		remove_from_group("foam")
		queue_free()

func covers(point: Vector3) -> bool:
	var offset := to_local(point).abs()
	var extent := 0.34 * amount
	return not cleared and offset.x < extent and offset.y < extent and offset.z < extent

func set_uv_translucent(enabled: bool) -> void:
	# UV changes foam only. Pearls keep depth testing, so walls still occlude them.
	if uv_translucent == enabled:
		return
	uv_translucent = enabled
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
	surface.albedo_color = Color(0.21, 0.37, 0.49, 0.055) if enabled else Color(0.78, 0.83, 0.80)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
