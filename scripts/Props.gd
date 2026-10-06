class_name Props
extends RefCounted
## Small primitive factory. Replace these meshes with art without changing gameplay.

static func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = 0.32
	return result

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.position = at
	if solid:
		(root as StaticBody3D).collision_layer = 1
		(root as StaticBody3D).collision_mask = 6
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	root.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collider.shape = bounds
		root.add_child(collider)
	parent.add_child(root)
	return root

static func sign_at(parent: Node3D, text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 48
	label.pixel_size = 0.006
	label.no_depth_test = false
	parent.add_child(label)
