extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func next_button(world: Node) -> Button:
	for child in world.menus.column.get_children():
		if child is Button and child.text == "Next Stage":
			return child
	return null
func settle() -> void:
	for i in range(5):
		await process_frame
func run() -> void:
	preload("res://scripts/StageManager.gd").selected_stage = 0
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.settings.save_enabled = false
	world.settings.set_value("brightness", 2.5)
	var environment: Environment = world.barn.get_node("WorldEnvironment").environment
	check(is_equal_approx(environment.ambient_light_energy, 0.6), "Brightness applies immediately")
	world.menus.start_shift()
	world.intro.complete()
	world.manager.collected = world.manager.total
	world.manager.finish(true)
	check(world.menus.screen == "results" and next_button(world) != null and not next_button(world).disabled, "Completion offers unlocked next stage")
	world.menus.show_settings()
	world.menus.back_from_settings()
	check(world.menus.screen == "results", "Settings returns to results")
	next_button(world).pressed.emit()
	await settle()
	world = current_scene
	check(world.stages.selected_stage == 1 and world.menus.screen == "playing", "Next button loads next stage")
	world.intro.complete()
	var debug: Node = world.get_node("DebugPanel")
	check(debug.open_panel(), "Debug panel opens")
	debug.jump_to_stage(3)
	await settle()
	world = current_scene
	check(world.stages.selected_stage == 3 and not paused, "F3 jumps directly to requested stage")
	world.intro.complete()
	world.manager.collected = world.manager.total
	world.manager.finish(true)
	check(next_button(world) == null, "Final stage does not offer nonexistent stage five")
	world.queue_free()
	await process_frame
	print("RESULTS / BRIGHTNESS / SHORTCUTS: %d failures" % failures)
	quit(1 if failures else 0)
