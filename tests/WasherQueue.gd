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
	world.menus.start_shift()
	world.intro.complete()
	world.player.set_physics_process(false)
	world.manager.credits = 10000
	world.manager.buy_upgrade("auto_washer")
	var station: Station = world.get_node("WashingStation")
	station.set_physics_process(false)
	for i in range(4):
		var item: Pearl = world.pearls[i]
		item.state = Pearl.State.EXPOSED
		item.pick_up(world.player.hand)
		check(station.accept_item(item) == (i < 3), "Base queue capacity failed")
	check(world.pearls[3].holder == world.player.hand, "Rejected item was lost")
	check(not station.accept_item(world.pearls[0]), "Duplicate accepted")
	for i in range(3):
		station._physics_process(4.0)
	check(station.clean_items.size() == 3 and station.queue_count() == 0, "Completed items blocked belt")
	check(station.accept_item(world.pearls[3]), "Fourth item blocked by full clean tray")
	station._physics_process(4.0)
	for i in range(4):
		var retrieved := station.take_clean(world.player.hand)
		check(retrieved == world.pearls[i] and retrieved.residue == 0.0, "Tray FIFO lost or duplicated item")
	check(station.take_clean(world.player.hand) == null, "Empty tray returned an item")
	world.manager.buy_upgrade("auto_washer")
	check(station.buffer_capacity() == 4, "Washer upgrade did not expand buffer")
	var fresh: Pearl = world.pearls[4]
	fresh.state = Pearl.State.EXPOSED
	fresh.pick_up(world.player.hand)
	station.accept_item(fresh)
	station._physics_process(2.25)
	check(fresh.residue == 0.0, "Washer upgrade did not improve speed")
	world.player.held = station.take_clean(world.player.hand)
	await physics_frame
	world.player.drop_safely(true)
	check(world.player.held == null and fresh.state == Pearl.State.FREE and fresh.linear_velocity.length() > 3, "Throw failed")
	check(InputMap.action_has_event("throw_item", make_key(KEY_F)), "F binding missing")
	world.queue_free()
	await process_frame
	print("WASHER QUEUE RESULT: %d failures" % failures)
	quit(1 if failures else 0)
func make_key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event
