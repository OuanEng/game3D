extends RefCounted
## Imported scenes are visual children; gameplay collision remains a simple box.
## Dynamic loading allows a missing optional model to use procedural fallback art.
const ROOT := "res://assets/third_party/kenney_factory/"

static func place(parent: Node3D, model: String, at: Vector3, longest_side: float, solid := false) -> Node3D:
	var path := ROOT + model + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var visual := scene.instantiate() as Node3D
	if visual == null:
		return null
	var bounds := collect_bounds(visual, Transform3D.IDENTITY)
	if bounds.size.length_squared() < 0.000001:
		visual.free()
		return null
	var wrapper := Node3D.new()
	wrapper.name = "Imported_" + model
	parent.add_child(wrapper)
	wrapper.position = at
	var normalized := Node3D.new()
	wrapper.add_child(normalized)
	normalized.add_child(visual)
	var factor := longest_side / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	normalized.scale = Vector3.ONE * factor
	normalized.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 6
		wrapper.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size * factor
		shape.shape = box
		shape.position.y = box.size.y * 0.5
		body.add_child(shape)
	return wrapper

static func collect_bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	var transform := parent_transform * node.transform
	var result := AABB()
	var found := false
	if node is MeshInstance3D and node.mesh != null:
		result = transform * node.get_aabb()
		found = true
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := collect_bounds(child, transform)
			if child_bounds.size.length_squared() > 0.000001:
				result = result.merge(child_bounds) if found else child_bounds
				found = true
	return result
