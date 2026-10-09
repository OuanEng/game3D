extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for index in range(4):
		preload("res://scripts/StageManager.gd").selected_stage = index
		var world: Node3D = load("res://Main.tscn").instantiate()
		root.add_child(world)
		world.settings.save_enabled = false
		TranslationServer.set_locale("th")
		world.stages.unlocked = 3
		world.stages.equipment.scoop = 2
		world.menus.show_stages(false)
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/stage-%d.png" % index)
		world.queue_free()
		await process_frame
	print("STAGE VISUAL COMPLETE")
	quit()
