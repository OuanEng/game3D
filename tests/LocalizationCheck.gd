extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/" + name + ".png")
func run() -> void:
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.menus.switch_language()
	check(TranslationServer.get_locale().begins_with("th"), "TH switch failed")
	check(TranslationServer.translate("Resume") == "เล่นต่อ", "Thai message missing")
	await shot("main-th")
	world.menus.start_shift(GameManager.Mode.HARDCORE)
	world.intro.complete()
	world.menus.show_pause()
	var before: float = world.manager.remaining
	await shot("pause-th")
	world.menus.switch_language()
	check(paused and world.manager.remaining == before and world.manager.is_hardcore(), "Locale switch changed game state")
	check(TranslationServer.translate("Resume") == "Resume", "English restore failed")
	world.menus.resume()
	world.queue_free()
	await process_frame
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.menus.switch_language()
	world.menus.start_shift()
	world.intro.complete()
	world.manager.credits = 1000
	world.menus.show_pause()
	world.menus.pause_upgrades()
	check(world.manager.get_upgrade_catalog()["bucket"]["name"].begins_with("ถังโฟม"), "Upgrade name untranslated")
	check(world.pearls[0].localized_name() != world.pearls[0].item_name, "Item name untranslated")
	await shot("shop-th")
	TranslationServer.set_locale("en")
	await process_frame
	check(world.manager.get_upgrade_catalog()["bucket"]["name"].begins_with("Portable"), "Live catalog locale restore failed")
	world.shop.close_store()
	world.menus.resume()
	world.queue_free()
	await process_frame
	print("LOCALIZATION RESULT: %d failures" % failures)
	quit(1 if failures else 0)
