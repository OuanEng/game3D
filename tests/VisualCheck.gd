extends SceneTree
## Run with a real renderer (not --headless) to save reproducible QA screenshots.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime"))
	var scene: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scene.intro.animator.seek(2.0, true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/intro.png")
	scene.intro.complete()
	scene.player.camera.rotation.x = -0.3
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/barn.png")
	# A deterministic excavation preview, using real bucket fills and waste dumps.
	scene.player.set_physics_process(false)
	scene.manager.credits = 300 # Fund preview upgrades, not production starting funds.
	scene.manager.buy_upgrade("scoop")
	scene.manager.buy_upgrade("bucket")
	for stroke in range(12):
		if scene.player.bucket_load >= scene.player.bucket_capacity() - 0.000001:
			scene.player.camera.global_position = Vector3(-7, 1.55, 7.3)
			scene.player.camera.look_at(Vector3(-7, 1.2, 5))
			scene.player.dump_bucket(scene.get_node("WasteBin"))
		scene.player.try_scoop_at(Vector3(0, 0, 0.65))
	scene.player.camera.global_position = Vector3(3.8, 4.0, 4.8)
	scene.player.camera.look_at(Vector3(0, 0.8, -0.3))
	scene.player.tools.use_tool(0.1, false, scene.player.camera)
	scene.player.prompt = "Excavated surface / bucket inventory follows removed volume"
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/excavation.png")
	# Render the actual UV shader and translucent foam, then the purchase modal.
	scene.player.set_physics_process(false)
	scene.manager.buy_upgrade("uv")
	var pearl: Pearl = scene.pearls[0]
	scene.player.camera.global_position = pearl.global_position + Vector3(0, 3.5, 1.0)
	scene.player.camera.look_at(pearl.global_position)
	scene.player.tools.select_tool(1)
	scene.player.tools.use_tool(0.1, true, scene.player.camera)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/uv.png")
	scene.player.tools.use_tool(0.1, false, scene.player.camera)
	scene.shop.open_store(scene.player, scene.manager)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/shop.png")
	scene.queue_free()
	await create_timer(0.2).timeout
	quit()
