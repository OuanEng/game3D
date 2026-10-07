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
	world.menus.start_shift(GameManager.Mode.HARDCORE)
	world.intro.complete()
	var manager: GameManager = world.manager
	check(manager.is_hardcore() and manager.remaining == 600, "Hardcore timer/mode missing")
	manager.credits = 100000
	for id in GameManager.UPGRADES:
		check(not manager.buy_upgrade(id), "Hardcore purchase allowed: " + id)
		manager.owned[id] = 5
		check(manager.level(id) == 0, "Stale ownership bypassed mode")
	for i in range(1, 5):
		check(not world.player.tools.select_tool(i), "Powered tool allowed")
	check(world.player.bucket_capacity() == 0.012 and world.player.scoop_radius() == 0.25, "Bare hands stats changed")
	world.shop.open_store(world.player, manager)
	check(not world.shop.is_open, "Shop UI opened")
	world.menus.show_pause()
	world.menus.pause_upgrades()
	check(paused and world.menus.visible and not world.shop.is_open, "Pause shop bypass")
	world.menus.resume()
	var station: Station = world.get_node("WashingStation")
	var item: Pearl = world.pearls[0]
	item.state = Pearl.State.EXPOSED
	item.pick_up(world.player.hand)
	check(not station.accept_item(item), "Automatic washer allowed")
	item.wash(3.0)
	check(item.residue == 0, "Manual wash failed")
	manager.select_mode(GameManager.Mode.NORMAL)
	check(manager.is_hardcore(), "Midshift rule switching allowed")
	world.queue_free()
	await process_frame
	var normal: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(normal)
	normal.menus.start_shift()
	normal.intro.complete()
	normal.manager.credits = 1000
	check(not normal.manager.is_hardcore() and normal.manager.remaining == 900, "Hardcore leaked into normal")
	check(normal.manager.buy_upgrade("bucket"), "Normal shop broken")
	normal.queue_free()
	await process_frame
	print("HARDCORE RESULT: %d failures" % failures)
	quit(1 if failures else 0)
