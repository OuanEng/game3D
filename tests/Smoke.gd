extends SceneTree
## Integration tests use real meshes, collision queries, inventory and scene wiring.
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func terrain_ray(terrain: FoamMesh, point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 6, point - Vector3.UP * 2, 8)
	return terrain.get_world_3d().direct_space_state.intersect_ray(query)

func run() -> void:
	var scene: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var manager: GameManager = scene.manager
	var player: Player = scene.player
	var terrain: FoamMesh = scene.foam_mesh
	player.set_physics_process(false)
	manager.set_physics_process(false)
	check(scene.has_node("FactoryWorld") and scene.has_node("FoamMesh") and scene.has_node("WasteBin") and scene.has_node("StoreUI"), "Scene architecture present")
	check(get_nodes_in_group("foam").is_empty(), "No chunk foam is instantiated")
	check(manager.phase == GameManager.Phase.INTRO and not manager.running, "Intro locks round")
	var intro_time := manager.remaining
	manager._physics_process(1)
	check(manager.remaining == intro_time, "Timer stopped during intro")
	scene.intro.complete()
	check(player.camera.current and manager.running, "Skip hands off to player")
	manager.remaining = 299
	scene.intro.complete()
	check(manager.remaining == 299, "Repeated handoff cannot reset clock")
	check(manager.total == 8 and manager.credits == 0, "Items and empty wallet initialized")
	scene.menus.screen = "playing"
	scene.menus.show_pause()
	var paused_time := manager.remaining
	await create_timer(0.1).timeout
	check(paused and manager.remaining == paused_time, "Pause freezes boss clock")
	scene.menus.resume()
	check(not paused, "Resume unpauses scene")
	manager.credits = 60 # Seed funds only for the purchase validation below.
	check(not player.tools.select_tool(1), "UV starts locked")
	scene.shop.open_store(player, manager)
	check(player.store_open and scene.shop.is_open, "Shop gates player")
	check(manager.buy_upgrade("uv") and manager.credits == 35, "UV purchased")
	check(not manager.buy_upgrade("uv") and not manager.buy_upgrade("bucket"), "Insufficient funds for next UV level and bucket rejected")
	var before_shop := manager.remaining
	manager._physics_process(0.1)
	check(manager.remaining < before_shop, "Shop clock keeps running")
	scene.shop.close_store()

	# Exact volume conservation includes boundary triangle weights and partial cuts.
	var point := Vector3(-0.7, 0, -0.8)
	var untouched_height := terrain.sample_height(Vector3(2.2, 0, -1))
	var initial_height := terrain.sample_height(point)
	var initial_volume := terrain.remaining_volume()
	var initial_hit := terrain_ray(terrain, point)
	check(not initial_hit.is_empty() and absf(initial_hit.position.y - initial_height) < 0.0001, "Initial mesh ray height matches sampler")
	var removed := terrain.excavate(point, 0.48, 0.18, 0.007)
	check(absf(removed - 0.007) < 0.00000001, "Near-full bucket scales the terrain cut")
	check(absf(initial_volume - terrain.remaining_volume() - removed) < 0.00000001, "Terrain integral equals removed volume")
	check(terrain.sample_height(point) < initial_height, "Surface lowers at scoop")
	check(terrain.sample_height(Vector3(2.2, 0, -1)) == untouched_height, "Outside vertices unchanged")
	var after_cut := terrain.remaining_volume()
	check(terrain.excavate(point, 0.48, 0.18, 0.0) == 0.0 and terrain.remaining_volume() == after_cut, "Zero capacity cannot deform")
	await physics_frame
	await physics_frame
	var edited_hit := terrain_ray(terrain, point)
	check(not edited_hit.is_empty() and absf(edited_hit.position.y - terrain.sample_height(point)) < 0.0001, "Updated collider matches edited mesh")

	# Player inventory uses the exact returned volume. Holding LMB is not repeated digging.
	var top_point := terrain.mound_center
	top_point.y = terrain.sample_height(top_point)
	player.camera.global_position = top_point + Vector3(0, 1.5, 0.3)
	player.camera.look_at(top_point)
	player.tools.select_tool(0)
	var before_press := terrain.remaining_volume()
	player.tools.use_tool(0.016, true, player.camera, true)
	check(player.bucket_load > 0 and absf(before_press - terrain.remaining_volume() - player.bucket_load) < 0.00000001, "One click transfers actual removed volume")
	var after_press := terrain.remaining_volume()
	player.tools.use_tool(0.016, true, player.camera, false)
	check(terrain.remaining_volume() == after_press, "Holding scoop does not repeat a stroke")
	for index in range(20):
		player.try_scoop_at(point)
	check(absf(player.bucket_load - player.bucket_capacity()) < 0.000001, "Repeated scoops fill bucket without overflow")
	var full_volume := terrain.remaining_volume()
	check(player.try_scoop_at(point) == 0 and terrain.remaining_volume() == full_volume, "Full bucket prevents excavation")
	var waste: WasteBin = scene.get_node("WasteBin")
	check(player.dump_bucket(waste) == 0 and player.bucket_load > 0, "Cannot dump remotely")
	player.camera.global_position = waste.global_position + Vector3(0, 1.55, 2.2)
	player.camera.look_at(waste.global_position + Vector3(0, 1.2, 0))
	var dumped := player.dump_bucket(waste)
	check(dumped > 0 and player.bucket_load == 0, "Waste station empties bucket")
	check(InputMap.action_get_events("dump_foam")[0].physical_keycode == KEY_Q, "Q is bound to foam disposal")
	# Looking away still allows the dedicated Q command near the bin.
	player.camera.look_at(player.camera.global_position + Vector3.RIGHT)
	for repeat in range(3):
		player.bucket_load = player.bucket_capacity()
		check(player.try_dump_foam() > 0.0 and player.bucket_load == 0.0, "Repeated full hand loads can be emptied")
	var earned := manager.credits
	check(player.try_dump_foam() == 0.0 and manager.credits == earned, "Empty dumping never generates money")
	player.bucket_load = player.bucket_capacity()
	paused = true
	check(player.try_dump_foam() == 0.0 and player.bucket_load > 0.0, "Dump is disabled while paused")
	paused = false
	var barrier := Props.box(scene, waste.global_position + Vector3(0, 1.3, 1.35), Vector3(2.5, 2.6, 0.12), Color.BLACK)
	await physics_frame
	await physics_frame
	check(player.try_dump_foam() == 0.0 and player.bucket_load > 0.0, "Q cannot dump through a wall")
	barrier.queue_free()
	await physics_frame
	await physics_frame
	check(player.try_dump_foam() > 0.0, "Disposal works after blocker removed")
	check(player.try_scoop_at(point) > 0, "Scooping resumes after disposal")
	# Deliberately funded wallet exercises upgrades without requiring a full economy run.
	manager.credits = 300
	var carried := player.bucket_load
	check(manager.buy_upgrade("bucket") and player.bucket_capacity() == 0.50, "Capacity upgrade applied")
	check(player.bucket_load == carried, "Capacity upgrade preserves contents")
	check(manager.buy_upgrade("scoop") and player.scoop_radius() == 0.75 and player.scoop_depth() == 0.30, "Scoop dimensions upgrade")
	check(manager.buy_upgrade("detector"), "Detector purchase")
	check(not manager.owns_tool(3), "Blower remains locked before purchase")

	# UV can reveal a buried pearl, but does not make it retrievable.
	var pearl: Pearl = scene.pearls[0]
	pearl.global_position.y = terrain.sample_height(pearl.global_position) - 0.095 - 0.12
	check(not pearl.pick_up(player.hand), "Buried pearl rejects pickup")
	player.camera.global_position = pearl.global_position + Vector3(0, 4, 1)
	player.camera.look_at(pearl.global_position)
	player.tools.select_tool(1)
	player.tools.use_tool(0.1, true, player.camera)
	check(pearl.uv_strength > 0 and not pearl.is_retrievable(), "UV locates without exposing pearl")
	var wall := Props.box(scene, pearl.global_position + Vector3(0, 2.7, 0.675), Vector3(1.5, 0.2, 1.5), Color.BLACK)
	await physics_frame
	await physics_frame
	player.tools.use_tool(0.1, true, player.camera)
	check(pearl.uv_strength == 0, "UV respects world blockers")
	wall.queue_free()
	await physics_frame
	player.tools.select_tool(0)
	check(pearl.uv_strength == 0, "Switch clears UV")
	# Controlled shallow cuts expose the top before fully clearing the sphere bottom.
	for index in range(150):
		if not terrain.is_covered(pearl.global_position):
			break
		terrain.excavate(pearl.global_position, 0.7, 0.03, 99)
	await physics_frame
	await physics_frame
	check(pearl.state == Pearl.State.EXPOSED and pearl.freeze, "Partially exposed pearl remains stable")
	check(pearl.pick_up(player.hand), "Exposed pearl can be retrieved")
	check(not manager.collect(pearl, Vector3.ZERO), "Dirty deposit rejected")
	pearl.wash(2.1)
	var reward_before := manager.credits
	var return_box: Station = scene.get_node("CollectionBox")
	check(manager.collect(pearl, return_box.slot(manager.collected)), "Clean deposit accepted")
	check(not manager.collect(pearl, Vector3.ZERO) and manager.credits == reward_before + 25, "Duplicate deposit cannot reward twice")

	# A completely excavated region is flat, nonnegative and contains no hidden residue volume.
	terrain.excavate(Vector3(0, 0, -1), 50.0, 50.0, 9999)
	check(terrain.remaining_volume() < 0.00000001, "Deep cut clamps at ground")
	check(terrain.excavate(point, 1, 1, 99) == 0, "Empty terrain cannot generate inventory")
	await physics_frame
	await physics_frame
	await create_timer(1.5).timeout
	for index in range(1, 8):
		var other: Pearl = scene.pearls[index]
		check(other.state == Pearl.State.FREE and not other.freeze and other.collision_mask == 13, "Fully cleared pearl uses terrain physics")
		check(absf(other.global_position.y - terrain.sample_height(other.global_position) - 0.095) < 0.04, "Released pearl rests on updated terrain")
		check(other.pick_up(player.hand), "Free pearl pickup")
		other.wash(2.1)
		# Deposits remain reachable after multiple objects occupy display slots.
		player.camera.global_position = return_box.global_position + Vector3(0, 0.55, 2.1)
		player.camera.look_at(return_box.global_position + Vector3(0, 0.18, 0))
		var box_hit := player.cast_from_camera(player.reach, 1 | 4 | 8 | 16)
		check(not box_hit.is_empty() and box_hit.collider == return_box, "Return-box interaction is not blocked after multiple deposits")
		check(manager.collect(other, return_box.slot(manager.collected)), "Remaining pearl returned")
	check(manager.phase == GameManager.Phase.WON and not manager.running, "Round won")
	check(player.try_scoop_at(point) == 0, "No excavation after end")
	scene.queue_free()
	await process_frame
	scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.menus.start_shift()
	scene.intro.animator.advance(12)
	await process_frame
	check(scene.manager.running and scene.player.bucket_load == 0 and scene.player.bucket_capacity() == 0.012, "Natural intro and restart reset hand capacity/upgrades")
	scene.shop.open_store(scene.player, scene.manager)
	scene.manager.remaining = 0.001
	scene.manager._physics_process(0.01)
	check(scene.manager.phase == GameManager.Phase.LOST and not scene.shop.is_open, "Timeout closes shop")
	scene.queue_free()
	await create_timer(0.2).timeout
	print("SMOKE RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
