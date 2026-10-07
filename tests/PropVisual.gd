extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/prop-" + label + ".png")
func run() -> void:
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.menus.start_shift()
	world.intro.complete()
	world.player.set_physics_process(false)
	world.player.tools.use_tool(0.016, false, world.player.camera)
	await shot("hands")
	world.manager.credits = 100000
	world.manager.buy_upgrade("bucket")
	world.player.bucket_load = 0.2
	world.player.tools.use_tool(0.016, false, world.player.camera)
	await shot("plastic-bucket")
	for id in ["bucket", "bucket", "scoop", "scoop", "scoop", "gloves", "gloves", "gloves", "uv", "detector", "blower", "vacuum", "auto_washer"]:
		world.manager.buy_upgrade(id)
	world.player.tools.use_tool(0.016, false, world.player.camera)
	await shot("steel-scoop")
	for slot in [1, 2, 3, 4]:
		world.player.tools.select_tool(slot)
		world.player.tools.use_tool(0.016, true, world.player.camera)
		await create_timer(0.15).timeout
		await shot("tool-%d" % slot)
	world.player.tools.use_tool(0.016, false, world.player.camera)
	var station: Station = world.get_node("WashingStation")
	var item: Pearl = world.pearls[0]
	item.state = Pearl.State.EXPOSED
	item.pick_up(world.player.hand)
	station.accept_item(item)
	world.player.camera.global_position = station.global_position + Vector3(1.2, 1.1, 1.4)
	world.player.camera.look_at(station.global_position + Vector3(0, 0.3, 0))
	await create_timer(0.3).timeout
	await shot("washer")
	quit()
