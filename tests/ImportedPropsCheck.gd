extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var library := preload("res://scripts/ImportedProps.gd")
	var parent := Node3D.new()
	root.add_child(parent)
	for name in ["box-large", "cone", "conveyor", "machine", "crane", "hopper-round"]:
		var model: Node3D = library.place(parent, name, Vector3.ZERO, 2.0, true)
		assert(model != null, "Imported model failed: " + name)
		var bounds: AABB = library.collect_bounds(model, Transform3D.IDENTITY)
		assert(is_equal_approx(maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)), 2.0))
		assert(absf(bounds.position.y) < 0.0001)
		assert(model.get_child(1) is StaticBody3D)
	assert(library.place(parent, "missing-test-model", Vector3.ZERO, 1.0) == null)
	parent.queue_free()
	await process_frame
	print("IMPORTED PROPS: six models, bounds, collision and fallback passed")
	quit()
