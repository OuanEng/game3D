extends SceneTree
var failures := 0
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.menus.start_shift()
	world.intro.complete()
	var manager: GameManager = world.manager
	var player: Player = world.player
	player.set_physics_process(false)
	check(manager.UPGRADES.size() == 12, "Exactly twelve upgrades")
	manager.credits = 1000000
	for id in manager.UPGRADES:
		check(manager.buy_upgrade(id), "Purchase " + id)
	check(manager.upgrade_price("bucket") == 96, "Exponential price after first level")
	check(manager.buy_upgrade("bucket") and is_equal_approx(player.bucket_capacity(), 0.8), "Capacity level two")
	check(not manager.buy_upgrade("detector"), "Single unlock cannot be repurchased")
	check(manager.buy_upgrade("uv") and manager.level("uv") == 2, "UV intensity can be upgraded")
	check(player.effective_pickup_reach() > player.reach, "Grabber increases reach")
	check(manager.remaining > 900.0, "Distraction extends timer")
	for i in range(3):
		check(manager.buy_upgrade("bucket"), "Buy next storage level")
	check(not manager.buy_upgrade("bucket"), "Level cap prevents further purchases")
	world.menus.show_pause()
	world.menus.pause_upgrades()
	check(paused and world.shop.is_open, "Shop opens while pause remains active")
	var before := manager.remaining
	await create_timer(0.1).timeout
	check(manager.remaining == before, "No time consumed in pause shop")
	world.shop.close_store()
	check(world.menus.screen == "pause" and paused, "Shop returns to pause")
	world.menus.resume()
	var station: Station = world.get_node("WashingStation")
	var item: Pearl = world.pearls[0]
	item.state = Pearl.State.EXPOSED
	check(item.pick_up(player.hand), "Hold test item")
	station.accept_item(item)
	station._physics_process(4.0)
	check(item.residue <= 0.0 and item in station.clean_items, "Belt cleans item and moves it to the tray")
	check(player.tools.select_tool(3) and player.tools.select_tool(4), "New tool slots selectable")
	world.queue_free()
	await process_frame
	print("UPGRADE RESULT: %d failures" % failures)
	quit(1 if failures else 0)
