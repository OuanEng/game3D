extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.menus.start_shift()
	world.intro.complete()
	world.player.set_physics_process(false)
	world.player.camera.global_position = Vector3(-7.5,2.4,8.1)
	world.player.camera.look_at(Vector3(-7.5,1.35,6.0))
	var station: Station = world.get_node("WashingStation")
	station.manual_flow_remaining = 3.0
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/wash-basin.png")
	world.queue_free()
	await process_frame
	quit()
