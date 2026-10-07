extends SceneTree
## Run with Godot --headless --path . --script res://tests/UVBalance.gd.
## Tests the actual height sampler and physics blockers, not a mocked depth gate.
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var pile := FoamMesh.new()
	pile.spawn_pearls_on_ready = false
	pile.mound_radii = Vector2(5, 5)
	pile.mound_height = 3.0
	pile.columns = 31
	pile.rows = 31
	world.add_child(pile)
	var manager := GameManager.new()
	world.add_child(manager)
	manager.owned["uv"] = 1
	var tools := Tools.new()
	tools.pile = pile
	tools.manager = manager
	world.add_child(tools)
	for kind in range(3):
		var item := Pearl.new()
		item.item_kind = kind
		item.foam_container = pile
		item.position = Vector3(0, 1.0, -1)
		world.add_child(item)
		item.set_physics_process(false)
		pile.pearls.append(item)
		var mesh: MeshInstance3D = item.get_child(0)
		var shape: CollisionShape3D = item.get_child(1)
		check(mesh.mesh is SphereMesh and shape.shape is SphereShape3D, "Every target kind is a sphere with spherical collision")
		check(is_equal_approx(mesh.mesh.radius, shape.shape.radius), "Mesh and collider share a radius")
	await physics_frame
	await physics_frame
	var item := pile.pearls[0]
	var surface := pile.sample_height(item.global_position)
	var origin := Vector3(0, surface + 2.0, -1)
	var forward := (item.global_position - origin).normalized()
	check(tools.uv_visibility(item, origin, forward).is_empty(), "Deep item stays invisible")
	item.global_position.y = surface - Pearl.RADIUS - 0.08
	var shallow := tools.uv_visibility(item, origin, Vector3.DOWN)
	check(shallow.get("strength", 0.0) > 0.0 and shallow.has("surface"), "Thin layer produces a localized surface hint")
	check(tools.uv_visibility(item, origin, Vector3.UP).is_empty(), "Beam facing away cannot highlight item")
	manager.owned["uv"] = 5
	check(tools.uv_visibility(item, origin, Vector3.DOWN).get("strength", 0.0) > shallow.get("strength", 0.0), "UV levels increase brightness")
	item.global_position.y = surface - Pearl.RADIUS - Tools.UV_MAX_COVER - 0.01
	check(tools.uv_visibility(item, origin, Vector3.DOWN).is_empty(), "Maximum UV level does not increase penetration")
	item.global_position.y = surface - Pearl.RADIUS - 0.08
	tools._update_uv(origin, Vector3.DOWN)
	check(item.uv_strength > 0 and pile.material.get_shader_parameter("uv_hint_count") == 1, "Shader receives only the shallow target, not the two deep ones")
	var wall := Props.box(world, Vector3(0, surface + 1.0, -1), Vector3(2, 0.15, 2), Color.BLACK)
	await physics_frame
	await physics_frame
	tools._update_uv(origin, Vector3.DOWN)
	check(item.uv_strength == 0 and pile.material.get_shader_parameter("uv_hint_count") == 0, "Solid blocker clears both fluorescence and terrain hint")
	wall.queue_free()
	await physics_frame
	await physics_frame
	item.state = Pearl.State.HELD
	check(tools.uv_visibility(item, origin, Vector3.DOWN).is_empty(), "Held item is excluded")
	item.state = Pearl.State.EMBEDDED
	item.global_position = Vector3(-1.8, 0, -1)
	item.global_position.y = pile.sample_height(item.global_position) - Pearl.RADIUS - 0.08
	origin = Vector3(4.7, 1.0, -1)
	forward = (item.global_position - origin).normalized()
	check(origin.distance_to(item.global_position) < 7.0, "Far-side scenario remains inside beam range")
	check(tools.uv_visibility(item, origin, forward).is_empty(), "Far-side shallow item cannot glow through intervening mountain")
	world.queue_free()
	await process_frame
	print("UV BALANCE RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
