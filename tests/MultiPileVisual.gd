extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	preload("res://scripts/StageManager.gd").selected_stage = 3
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.settings.save_enabled = false
	world.menus.start_shift()
	world.intro.complete()
	world.player.set_physics_process(false)
	world.stages.set_physics_process(false)
	world.manager.credits = 12580
	world.manager.owned.blower = 1
	world.player.tools.select_tool(3)
	world.player.tools.use_tool(0.0, false, world.player.camera)
	world.manager.blower_charge = 3.0
	world.player.camera.global_position = Vector3(0, 7, 9)
	world.player.camera.look_at(Vector3(0, 0.8, -3))
	for locale in ["en", "th"]:
		TranslationServer.set_locale(locale)
		world.stages.trigger_event(2)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/multipile-%s.png" % locale)
	world.stages.end_event()
	world.shop.open_store(world.player, world.manager)
	await create_timer(0.2).timeout
	world.shop._rows.get_parent().scroll_vertical = 10000
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/battery-shop.png")
	world.queue_free()
	await process_frame
	print("MULTIPILE VISUAL COMPLETE")
	quit()
