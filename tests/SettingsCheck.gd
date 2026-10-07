extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	var settings: Node = world.settings
	settings.save_enabled = false
	world.menus.show_settings()
	settings.set_value("language", "th")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/settings-th.png")
	settings.set_value("bgm", 0.25)
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")), linear_to_db(0.25)), "BGM volume failed")
	settings.set_value("focus_mute", true)
	settings._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(AudioServer.is_bus_mute(0), "Focus mute failed")
	settings._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not AudioServer.is_bus_mute(0), "Focus audio restore failed")
	settings.set_value("invert", true)
	check(world.player.invert_y, "Invert setting missing")
	settings.pending_action = "throw_item"
	settings.pending_button = Button.new()
	root.add_child(settings.pending_button)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	settings._input(key)
	check(InputMap.action_get_events("throw_item")[0].physical_keycode == KEY_T, "Rebinding failed")
	settings.reset_controls()
	check(InputMap.action_get_events("throw_item")[0].physical_keycode == KEY_F, "Default controls not restored")
	await process_frame
	settings.set_value("quality", 0)
	world.menus.start_shift()
	world.intro.complete()
	check(world.foam_mesh.columns == 41 and world.foam_mesh.rows == 33, "Low grid not applied")
	settings.set_value("quality", 2)
	check(world.foam_mesh.columns == 41, "Active grid was overwritten")
	settings.set_value("blur", true)
	await process_frame
	await RenderingServer.frame_post_draw
	world.menus.show_pause()
	world.menus.show_settings()
	check(paused, "Settings unpaused game")
	settings.pending_button.queue_free()
	world.queue_free()
	paused = false
	await process_frame
	print("SETTINGS RESULT: %d failures" % failures)
	quit(1 if failures else 0)
