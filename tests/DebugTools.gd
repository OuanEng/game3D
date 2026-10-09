extends SceneTree
## Run with the renderer: input integration needs actual mouse capture support.
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.05).timeout
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await create_timer(0.05).timeout
func run() -> void:
	preload("res://scripts/StageManager.gd").selected_stage = 3
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	var debug: Node = world.get_node("DebugPanel")
	check(not debug.open_panel(), "Debug opened over title menu")
	world.menus.start_shift()
	world.intro.complete()
	await create_timer(0.15).timeout
	await key(KEY_F3)
	check(debug.is_open and paused, "F3 did not open and pause")
	var remaining: float = world.manager.remaining
	await create_timer(0.12).timeout
	check(world.manager.remaining == remaining, "Boss clock advanced in debug")
	debug.grant_cash()
	check(world.manager.credits == 10000, "Cash cheat failed")
	debug.set_infinite(true)
	check(is_inf(world.player.bucket_capacity()), "Capacity is not infinite")
	debug.set_highlight(true)
	check(debug.markers[0].visible, "Buried item not highlighted")
	debug.set_highlight(false)
	check(not debug.markers[0].visible, "Highlight leaked after disabling")
	await key(KEY_ESCAPE)
	check(not debug.is_open and not paused and world.menus.screen == "playing", "ESC conflicted with pause menu")
	world.player.bucket_load = 1.0
	var before: float = world.player.bucket_load
	var removed: float = world.player.try_scoop_at(world.foam_mesh.mound_center)
	check(removed > 0 and world.player.bucket_load > before, "Infinite inventory blocked digging")
	debug.set_infinite(false)
	check(world.player.bucket_load > world.player.bucket_capacity(), "Disable discarded foam")
	check(world.player.try_scoop_at(world.foam_mesh.mound_center) == 0, "Overfull carry allowed normal digging")
	await key(KEY_F3)
	debug.clear_foam()
	check(world.foam_mesh.heights.count(0.0) == world.foam_mesh.heights.size(), "Clear did not flatten all vertices")
	check(world.manager.credits == 10000, "Clear granted unintended credits")
	debug.close_panel()
	await physics_frame
	await physics_frame
	for item in world.pearls:
		check(item.state != Pearl.State.EMBEDDED, "Item remained buried after clearing")
	world.menus.show_pause()
	check(not debug.open_panel(), "Debug stole existing pause ownership")
	world.menus.resume()
	debug.open_panel()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/debug-panel.png")
	debug.close_panel()
	world.queue_free()
	await process_frame
	print("DEBUG TOOLS RESULT: %d failures" % failures)
	quit(1 if failures else 0)
