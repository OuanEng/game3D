extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/main-menu.png")
	scene.menus.start_shift()
	scene.intro.complete()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/minimal-hud.png")
	scene.player.bucket_load = scene.player.bucket_capacity()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/capacity-full.png")
	scene.player.set_physics_process(false)
	scene.manager.credits = 1000
	scene.manager.buy_upgrade("uv")
	var item: Pearl = scene.pearls[0]
	var original := item.global_position
	item.global_position.y = scene.foam_mesh.sample_height(original) - Pearl.RADIUS - 0.06
	scene.player.camera.global_position = item.global_position + Vector3(0, 2.3, 0.3)
	scene.player.camera.look_at(item.global_position)
	scene.player.tools.select_tool(1)
	scene.player.tools.use_tool(0.1, true, scene.player.camera)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/uv-thin.png")
	item.global_position.y -= 1.0
	scene.player.tools.use_tool(0.1, true, scene.player.camera)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/uv-deep.png")
	item.global_position = original
	scene.player.tools.use_tool(0.1, false, scene.player.camera)
	scene.menus.show_pause()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/pause-menu.png")
	scene.menus.pause_upgrades()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/upgrades.png")
	paused = false
	quit()
